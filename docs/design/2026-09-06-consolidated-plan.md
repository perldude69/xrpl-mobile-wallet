# XRPL Mobile Wallet — Consolidated Plan

**Date:** 2026-09-06
**App:** XRPL Mobile Wallet (package `info.richlist.wallet`, app title *Zerp Wallet*,
unlock-screen runner *Zerpland*)
**Status:** Living document. Part I is a spec of shipped behaviour; Part II is the
work queue.

This file supersedes and folds in:

| Folded-in document | Covers |
|--------------------|--------|
| `2026-07-20-xrpl-mobile-wallet-design.md` | Core product shape, architecture, data model, security, watcher |
| `2026-08-02-attach-keys-watch-wallet-design.md` | Attaching signing keys to a watch-only wallet |
| `2026-08-03-game-pin-design.md` | Optional second (game) PIN → Zerpland decoy |
| `2026-09-05-smart-trade-execution-plan.md` | XRPL trading — reshaped to XRP ⇄ RLUSD only; mostly queued (Part II §A) |

Companion records, not folded in: `../history/2026-07-20-xrpl-mobile-wallet.md`
(build log), `../../CHANGELOG.md`, `../audit/` (security audits), `../../AGENTS.md`
(authoritative agent guide — stack, layout, commands, non-negotiables).

---

# Part I — Implemented

Everything in this part is in the tree today and covered by
`flutter analyze` + `flutter test`. Paths are the current source of truth; this
text is the intent behind them.

## 1. Product shape & architecture

A personal, sideloadable **Android-first Flutter** wallet for the XRP Ledger:

- Import **signing** wallets (24- or 12-word BIP39, or classic family seed `s…`)
  and **create** new ones (OS CSPRNG + dice/word entropy ritual).
- Add **watch-only** wallets (classic address `r…`).
- Show **XRP + issued-currency** balances and history.
- **Send** XRP and issued currencies, signed on-device or on a connected Ledger.
- Add the **RLUSD** trust line (signing or Ledger).
- Run an **address-only background watcher** (foreground service) that raises a
  local notification on validated account activity.
- **Mainnet + Testnet**, with an ordered, user-editable endpoint catalog.
- Optional **game PIN** duress decoy → *Zerpland* endless runner.
- Optional **XRP/USD** portfolio display from an on-ledger oracle.
- Ships as a sideload APK; Play bundle signing supported but not required.

**Two-process model:**

| Process | Holds secrets? | Role |
|---------|----------------|------|
| Flutter UI | Yes (`KeyVault` / `PinService`, ephemeral at sign time) | Import, create, display, sign, submit |
| Watcher FGS (`lib/data/watcher/watcher_service.dart`) | **No** | WSS-subscribe to public addresses; local notify |

**Layers:** UI → state (Riverpod) → data services; `domain/` stays pure
(validation, formatting, parsers). Material 3 dark, seed `0xFF00A3BF`.

## 2. Data model & storage

Drift/SQLite `schemaVersion` 4 (`lib/data/database/`).

| Store | Data |
|-------|------|
| `flutter_secure_storage` (Android Keystore) | Mnemonics, family seeds, PIN + game-PIN verifiers. Key **names** are runtime-derived (`KeyNames`, SHA-256 of XOR-encoded role tags). |
| SQLite | `Wallets`, `Balances`, `CachedTxs`, `AppSettingsRows`, `TradeExecutions`, `TradeFills` — non-secret metadata only |
| SharedPreferences | Theme, last selected wallet, endpoint selection, last price rate, watcher heartbeat |
| `watcher_address_book.json` | Public addresses + active network only |

`WalletAccount`: id, label, address, `kind` (`signing` | `watchOnly`),
`preferredNetwork`, `importMethod` (`mnemonic` | `familySeed` | `addressOnly`),
createdAt, sortOrder, optional ARGB accent, `useLedger`, `ledgerAccountIndex`.

`canSign` = `kind == signing || useLedger`; `hasLocalKeys` = `kind == signing`.

**Migrations:** v2 `accentColor`; v3 `useLedger` + `ledgerAccountIndex`; v4
`trade_executions` + `trade_fills`. Never hand-edit `app_database.g.dart`;
regenerate with `build_runner`.

## 3. Security model

The non-negotiables (mirrored in `AGENTS.md` §Security):

1. **Secrets boundary** — raw key material only in the UI process via `KeyVault` /
   `PinService`; never in the watcher isolate.
2. **Watcher is address-only** — no secrets on disk outside secure storage.
3. **Wallet entropy** — new wallets always use OS CSPRNG (`Random.secure`) as
   primary entropy; the dice/word ritual is *mixed in* via `EntropyMixer`, never a
   replacement. Never Fortuna for seed bytes.
4. **Screen security** — `FLAG_SECURE` on create / import / attach-keys secret
   screens (`ScreenSecurity` → `MainActivity`), plus obscured-touch filtering.
5. **No logging secrets** — status UI shows endpoint **host only**, never a query
   string.
6. **PIN** — min length 6; auto-lock after `AppConfig.autoLockSeconds` (90 s) in
   background; leave the process with `exitApplication()` (`SystemNavigator.pop`).
7. **Game PIN** — see §10.

Packaging: `allowBackup=false`; only the launcher `MainActivity` exported; no
cleartext traffic; release APKs go through `tool/build_release.sh`
(`--obfuscate --split-debug-info`); symbol maps stay local.

## 4. Wallet import & create

- BIP39 **12 or 24** words (24 emphasised), family seed `s…`, or watch-only
  classic `r…` with checksum. Reject duplicate address
  (`WalletListController.ensureUniqueAddress`).
- Import mnemonic entry is an **8×3 grid** (cells numbered 1–24) with English
  BIP39 autocomplete and paste-to-fill; 12 words accepted only when cells 1–12
  are filled and 13–24 empty.
- Create flow: entropy ritual (dice pad + words) mixed with OS CSPRNG; phrase
  shown once for on-screen manual backup only — **no clipboard copy** of the
  recovery phrase (XRW-24).
- Secret text controllers are scrubbed on dispose; autofill hints empty;
  `enableIMEPersonalizedLearning: false`.
- UI error paths use fixed messages via `userFacingError()` — no raw exception
  passthrough in `lib/ui` (XRW-25).

## 5. Attach keys to a watch-only wallet

Upgrade `watchOnly` → `signing` **in place** (same `walletId`, same address).

- Wallet detail shows **Add keys** only when `!account.canSign`.
- Chooser → one of: paste phrase / 8×3 grid / family seed. Grid rules as in §4.
- Derivation **reuses `WalletImporter`** (`deriveMnemonicForAddress` /
  `deriveFamilySeedForAddress`) — never reimplement curves or paths.
- **Hard gate:** `derivedAddress == wallet.address` (case-sensitive classic
  compare). Mismatch → user error `"This secret does not match this wallet's
  address."`, no KeyVault write, no kind change, no new row.
- On match: `WalletListController.attachKeys` does
  `KeyVault.saveSecret` → set `kind = signing`, `importMethod` accordingly →
  reload. Address, label, balances, cached txs unchanged.
- `ScreenSecurity` on while entry screens are mounted.

Errors: *Enter 12 or 24 recovery words* / *Invalid recovery phrase* / *Invalid
family seed* / *…does not match this wallet's address* / *Wallet not found /
already has keys*.

## 6. Send payments

- `PaymentService` builds / signs / submits software txs; secrets are passed in
  from `KeyVault` at the call site, held in a local variable, never stored on the
  service or logged.
- Amounts via `XrpAmount` (drops as `BigInt` strings).
- Guards: reviewed-fee, fee cap (`AppConfig.maxFeeDrops` = 0.1 XRP), spendable
  balance, destination-tag policy, destination ≠ self, unfunded-destination
  reserve.
- Signing algorithm: **secp256k1 first** for mnemonics; ed25519 only as a
  fallback when `expectedAddress` matches a legacy mis-import (see §11).
- Ledger send signs the blob on-device (path `m/44'/144'/index'/0/0`, secp256k1)
  then submits; address mismatch → clear user error. Ledger private keys are
  never stored.
- Raw transport errors from the submit path are wrapped in
  `PaymentOperationException(stage)`; typed XRPL errors (`RPCError`,
  `BaseXRPLPluginException`) are rethrown for the caller to map.
- The generic sign/submit helper (`signAndSubmitTransaction` → `_signAndSubmit`)
  is shared by Payment, RLUSD `TrustSet`, and the Trade `OfferCreate` /
  `OfferCancel` path; the fee cap applies to all of them.

## 7. Background watcher & notifications

- Sticky FGS (`dataSync`): *"XRPL Watcher: N accounts · network · state"*.
- WSS `subscribe accounts:[…]` on the **active** network, trying enabled
  endpoints in catalog order then custom WSS.
- Notify on validated txs, dedupe by hash; body from public ledger data.
- Toggle in Settings; local notifications only (no Firebase).
- Connection chip combines `NetworkController` RPC state + watcher heartbeat
  (`WatcherStatusStore`) into green/yellow/red via `ConnectionHealth`; host only.

## 8. Activity feed

Cross-wallet validated-tx feed (`ActivityController`); notification taps
deep-link here; tx detail screen per entry.

## 9. Networks & endpoints

- `NetworkId.mainnet` / `testnet`; defaults in `config/network_id.dart`.
- **Mainnet** endpoints are user-selectable and reorderable
  (`EndpointPreferences`, persisted in SharedPreferences):
  - HTTP JSON-RPC catalog default order: `xrplcluster.com` → `mainnet.xrpl-rpc.com`
    (Ankr). `rpc.rich-list.info` is maintainer-operated and **opt-in only** — in
    the catalog but excluded from the default selection (XRW-27).
  - WSS catalog: `xrplcluster.com` → `mainnet.xrpl-rpc.com`.
  - Empty selection falls back to the **default set** (not the raw catalog), then
    custom HTTPS/WSS URLs.
  - `XrplRpcClient.connect` probes enabled URLs with `server_info` and keeps the
    first that answers.
- **Testnet** HTTP: `testnet.xrpl-rpc.com` → Ripple altnet; WSS: Ripple altnet.
  Not user-selectable.
- All endpoints TLS-only (`EndpointUrl.validate` rejects `http`/`ws`); status UI
  shows host only.
- Per-account preferred network + badge; the wallet list shows only wallets whose
  `preferredNetwork` matches the active network; watcher follows the active
  network.
- Testnet-only helpers: `TestnetFaucetService.fund()` (XRP) and links to the
  official / Bithomp RLUSD faucets, shown only on testnet wallet detail.

## 10. Game PIN (duress decoy) → Zerpland

Optional second PIN. On the unlock screen:

| Input | Result |
|-------|--------|
| Correct **wallet PIN** | Unlock wallet |
| Correct **game PIN** (if set) | Full-screen Zerpland runner; stay `locked` |
| Wrong PIN | Same *"Incorrect PIN"* either way |
| **No game PIN**, 3 failed attempts | Zerpland (legacy decoy) |
| **Game PIN set** | 3-fail decoy disabled; only the game PIN opens the game |
| Biometrics | Unlocks wallet only |

Rules: same format as wallet PIN (≥ 6 digits); must **differ** from the wallet
PIN (changing the wallet PIN to equal the game PIN is rejected); set / change /
clear always require the wallet PIN; wipe clears both. Storage:
`game_pin_hash` / `game_pin_salt`, same SHA-256(`salt:pin`) scheme as the wallet
PIN, separate salt. The game path never reads `KeyVault`. UI wording stays
neutral ("Game PIN" / Zerpland). Local top-5 leaderboard (`RunnerScoreboard`),
no network. Spec detail in `pin_service.dart` / `lock_controller.dart` /
`unlock_screen.dart`; covered by `test/data/pin_service_test.dart`.

Out of scope: fake balances / decoy wallets, first-run requirement, hiding
Zerpland from Settings, timing-attack hardening beyond equal-length messaging.

## 11. Crypto & derivation

| Import kind | Path / algorithm | Notes |
|-------------|------------------|-------|
| BIP39 mnemonic | BIP44 `m/44'/144'/0'/0/0` + **secp256k1** | Must match `xrpl.js` `Wallet.fromMnemonic` |
| Family seed `s…` | `XRPPrivateKey.fromSeed` | Often ed25519; separate path |
| Watch-only `r…` | address only | no secret |
| Ledger USB | `m/44'/144'/index'/0/0` secp256k1 | device holds keys |

- **Do not prefer ed25519 for mnemonic HD.** That bug caused a desktop address
  mismatch. Golden: `abandon … about` → `rHsMGQEkVNJmpGWs8XUBoTBiAAbwxZN5v3`;
  genesis family seed `snoPBrXtMeMyMHUVTgbuqAfg1SUTb` →
  `rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh`.
- `PaymentService.privateKeyFromSecret`: secp256k1 first for mnemonics; ed25519
  only when `expectedAddress` matches a legacy mis-import (lets old ed25519 rows
  still send). Correcting such an address = re-import the phrase; no automatic DB
  migration.
- Create ↔ import derivation must stay aligned (`WalletGenerator` ↔
  `WalletImporter`). Changing derivation ⇒ update goldens in
  `test/data/wallet_importer_test.dart` and
  `test/data/payments/payment_validators_test.dart`.

## 12. RLUSD trust line

Official issuer, `NoRipple`, hex currency code, fixed limit (`domain/tokens/rlusd.dart`).
Built through the same generic sign/submit helper as Payment; offered only when
`canSign` and the line is not already on `account_lines`. Signing or Ledger.
Covered by `test/data/payments/rlusd_trust_set_test.dart`.

## 13. Trade — shipped slice

The first slice of the Smart Trade Execution plan (Part II §A). Implemented:

- **Entry point:** *Trade* action on wallet detail.
- **Dashboard shell** (`lib/ui/trade/trade_dashboard_screen.dart`).
- **Open offers:** `XrplRpcClient.fetchAccountOffers` (`account_offers`, limit
  200) + list rendering (`takerPays for takerGets`, offer sequence).
- **Single `OfferCreate` limit order:** asset-pair picker (XRP + issued balances
  the wallet holds) → draft dialog → **review dialog showing the estimated
  network fee and owner-reserve increment** (preflighted via
  `fetchMinimumFeeDrops` + `fetchOwnerReserveIncrementDrops`) and a funds-locked
  note → wallet-PIN prompt → `signAndSubmitTransaction`.
- **`OfferCancel`:** per-offer *Cancel*, plus *Cancel all* (confirm → per-offer
  PIN). Frees reserve.
- **Signing gate:** trades sign **locally only** (`hasLocalKeys`). Ledger and
  watch-only wallets get a review-only dashboard with explicit copy; cancel
  controls are hidden for them.
- **Persistence:** the `trade_executions` row is written **only after the PIN is
  verified** (status `signing` → `submitted` / `failed`, from the `TradeStatus`
  enum). `last_error` stores a fixed category slug (`tradeErrorCategory`) or
  `engine:<code>`, never raw exception text.
- **Error handling:** all snackbars use fixed strings (`tradeFailureMessage` in
  `ui/trade/trade_errors.dart`); no `e.message` / `e.toString()` reaches the UI.
- **Tests:** `test/data/payments/offer_construction_test.dart` (golden
  `OfferCreate` / `OfferCancel` fields), `test/domain/trade/trade_amounts_test.dart`
  (XRP↔drops, sub-drop rejection, issued amounts),
  `test/domain/trade/trade_status_test.dart` (terminal set, unknown-value
  fallback), `test/data/database/trade_tables_test.dart` (active-row query, fill
  idempotency), `test/ui/trade/trade_errors_test.dart` (error mappers).

**Note on scope:** the shipped picker currently allows any issued asset the
wallet holds a balance in. Going forward, trading is scoped to **XRP ⇄ RLUSD
only** (Part II §A); R2/R3 replace the free-form draft dialog with an
XRP/RLUSD-only market + limit form, and the raw "sell amount / buy amount" inputs
become "amount + limit rate / max slippage".

Everything else in the trade plan is queued — see Part II §A.

## 14. Portfolio, connection chip, misc

- **XRP/USD:** XRPL-Labs TrustSet oracle `rXUMMaPpZqPutoRszR29jtC8amWq3APkx`
  (`XrpUsdOracle` parser, `PriceFeedController`, last rate in prefs). Portfolio
  toggle XRP vs USD — not a trading feed.
- **Token names:** bundled XRPSCAN snapshot + hex→ASCII fallback; no network
  fetch for labels.
- **Backup:** password-encrypted JSON export/import of wallet **names + addresses
  only** (AES-GCM-256 + PBKDF2; generic envelope). Export entries now also carry
  `preferredNetwork`.
- **Accent colour:** optional ARGB per row; null → derived from address.
- App version string: `AppConfig.appVersionName` (single source, shown in
  Settings → About).

---

# Part II — Queued for implementation

## A. XRP ⇄ RLUSD trading

Origin: `2026-09-05-smart-trade-execution-plan.md`, reshaped 2026-09-06.

### Scope

**One pair: XRP ⇄ RLUSD**, official issuer per network
(`Rlusd.issuerFor` — mainnet `rMxCKbEDwqr76QuheSUMdEGf4B9xJ8m5De`, testnet
`rQhWct2fv4Vc4KRjRgMrxa8xPN9Zx9iLKV`), currency hex
`524C555344000000000000000000000000000000`. All trading is `OfferCreate` /
`OfferCancel` on the **direct XRP/RLUSD order book**. No other assets, no pair
picker, no token registry lookups for trading, no cross-currency pathfinding, no
auto-bridging, no automation. Adding assets later ⇒ revisit §C.

**Why this is enough.** An `OfferCreate` at a limit rate already crosses every
better offer immediately and rests the remainder — it *is* a resting limit order
with automatic partial fill. Since the AMM amendment the same `OfferCreate` also
executes against any XRP/RLUSD AMM pool when that improves the price (the ledger's
Flow engine picks the best of CLOB + AMM). The client's job is to **show the
effective rate and bound the slippage**, not to route.

### Order types

1. **Market — Immediate-or-Cancel / Fill-or-Kill.** `OfferCreate` with
   `tfImmediateOrCancel` (default) or `tfFillOrKill`. The user gives an amount and
   a **max slippage**; that converts to a limit rate (`taker_gets` / `taker_pays`)
   in `domain/trade/`. No owner reserve, nothing left resting. This is the
   primary retail action and ships first.
2. **Limit — resting.** Priced `OfferCreate`, `tfSell` optional, `Expiration`
   optional. Rests on the book and costs **0.2 XRP owner reserve** per offer
   until filled or cancelled.

`tfSell` is explicit in the review: without it, "you pay **at most** X, you
receive **at least** Y, any leftover returns to you"; with it, "you sell the full
X even if the rate is better than your limit."

### Foundations (land before more order types)

- [x] **`domain/trade/` seeded** — `trade_status.dart` (lifecycle enum, terminal
      set, `fromStorage` that maps unknown values to `interrupted` so a stale row
      reconciles rather than looking done) and `trade_amounts.dart`
      (`offerAmount` + `describe`, moved out of the UI file). Error mapping split
      to `ui/trade/trade_errors.dart`. Tests mirror the new homes.
- [x] **`domain/trade/` completed (R2)** — `trade_decimal.dart` (exact base-10
      arithmetic; no `double` anywhere in the trade path), `trade_pair.dart`
      (XRP/RLUSD identity per network, `TradeSide`), `trade_rate.dart`
      (rate ↔ inverse, `taker_gets`/`taker_pays` both directions, per-asset
      precision), `slippage.dart` (bound → limit rate, capped at 50%),
      `order_draft.dart` (sealed market/limit, `tfSell`, `TimeInForce`).
      **Rounding invariant:** the derived leg rounds in whichever direction
      favours the account, so a constructed offer's implied rate is never worse
      than the rate asked for.
- [x] **Reconciliation & honest state.** — `data/trade/trade_reconciler.dart`,
      kicked from `LockLifecycle` at unlock and on resume. Added
      `TradeStatus.resting` so "confirmed and waiting" is no longer conflated
      with "we don't know if it landed".
  - Reconcile every non-terminal `trade_executions` row against the ledger
    **after submit** and **on app restart** before allowing another action;
    an ambiguous submission stays `submitted` until a tx hash or account state
    proves otherwise — never blind-retry.
  - `LastLedgerSequence` on every trade tx (autofill sets it); rule: past LLS and
    not in a validated ledger ⇒ **definitively failed**, safe to retry.
  - Real fill data from validated tx metadata
    (`meta.AffectedNodes` / `DeliveredAmount` / `Offer` node deltas) — never
    client-side subtraction (drifts on RLUSD decimals).
  - Detect and clean up **unfunded offers** (a funded offer can become unfunded
    and linger on the book, skipped). *Detection shipped* — `OpenOffer.isFunded`
    compares the offer's `TakerGets` against the held balance and the dashboard
    calls it out; automatic cleanup is still manual cancellation.
  - Trimmed **state machine**:
    `draft → reviewing → awaiting_approval → signing → submitted → resting → partially_filled → closed{filled | cancelled | expired | failed}` + `interrupted` (recovery only).
- [ ] **RLUSD trust-line preflight** — reuse `Rlusd.hasLine` and the
      `AddRlusdButton` flow: block an RLUSD-side trade until the line exists,
      offer to create it inline (also surface the issuer transfer fee —
      currently 0 for RLUSD — from `account_info` on the issuer).
- [ ] **Reserve gate** — before a resting offer: current owner-object count +
      reserve, "+0.2 XRP for this offer", spendable-after. Block if it would push
      the account below its reserve.

### UI

- [ ] **XRP/RLUSD book view** — best bid / best ask / spread / mid + a few depth
      levels from `book_offers` in both directions. Read-only; the basis for
      choosing a limit rate. Guard on ledger staleness before quoting.
- **Trade dashboard** (exists) — open-offer list + cancel / cancel-all
  (submitted with correct sequential `Sequence` numbers or tickets, not in
  parallel), plus **active** and **recent** sections read from
  `trade_executions`.
- **Review shows:** exact tx type + fields; direction; amount; limit rate + worst
  rate; estimated fill rate (may include AMM liquidity); network fee; reserve
  effect; whether funds stay locked; expiration. *(Fee, reserve, funds-locked
  note already implemented.)*

### Signing

- Local keys: both order types.
- **Ledger:** one order per on-device signature — a single market or single limit
  order only. No batching, no per-chunk loops (XRW-30 gate stays until this
  lands).

### Implementation layout

The shipped trade slice is a **spike**: one 700-line `ConsumerStatefulWidget`
doing RPC, Drift writes, `KeyVault` reads, `PaymentService` construction, domain
maths and error mapping. `send_screen.dart` has the same shape, so the app really
has two patterns — controller-backed (`wallet_list`, `activity`, `network`,
`price_feed`, `lock`) and fat-widget (`send`, `trade`). Everything below moves
trade onto the controller pattern before R3/R4 pile more on.

```
lib/domain/trade/            # pure, no I/O, no Flutter — vector-tested (R2)
  trade_status.dart          # ✅ lifecycle enum + terminal set + fromStorage
  trade_amounts.dart         # ✅ offerAmount + describe (moved out of the UI)
  trade_decimal.dart         # ✅ exact base-10 arithmetic (no double, ever)
  trade_pair.dart            # ✅ TradeAsset/TradeSide, XRP/RLUSD per network
  trade_rate.dart            # ✅ rate ↔ inverse; taker_gets/taker_pays
  slippage.dart              # ✅ max-slippage → limit rate → taker amounts
  order_draft.dart           # ✅ sealed MarketOrderDraft | LimitOrderDraft
  fill_parser.dart           # ✅ validated tx meta → deltas / offer outcome
  order_book.dart            # book_offers rows → BookSnapshot            (R4)

lib/data/trade/
  offer_service.dart         # ✅ draft → OfferCreate/OfferCancel; delegates to
                             #   PaymentService.signAndSubmitTransaction so the
                             #   fee cap + expectedAddress check stay the single
                             #   chokepoint for every signed transaction
  trade_repository.dart      # ✅ the ONLY place that touches the trade tables
  trade_reconciler.dart      # ✅ non-terminal rows × ledger; LastLedgerSequence
                             #   rule; account_tx sweep for resting offers
  trade_error_slug.dart      # ✅ persisted error slugs (moved out of ui/, so
                             #   data and state never import upward)
  order_book_service.dart    # book_offers RPC → domain BookSnapshot     (R4)

lib/state/
  trade_controller.dart      # ✅ StateNotifier: offers, executions, busy/error
                             #   + tradeRepositoryProvider, tradeReconcilerProvider
  order_book_controller.dart # StateNotifier: snapshot + staleness       (R4)

lib/ui/trade/
  trade_dashboard_screen.dart  # ✅ thin — watches the controller only
  trade_errors.dart            # ✅ fixed user-facing strings
  trade_status_labels.dart     # ✅ status wording that does not overclaim
  order_book_panel.dart                                                  # (R4)
  market_order_sheet.dart                                                # (R3)
  limit_order_sheet.dart                                                 # (R4)
  order_review_dialog.dart                                               # (R3)
  trade_history_list.dart                                                # (R6)
```

`XrplRpcClient` gained `fetchCurrentLedgerIndex`, `fetchTransaction` and
`fetchAccountTxDetails` for R1. `book_offers` lands there in R4 — do not fork a
second client.

`XrplRpcClient` stays the single RPC wrapper — `book_offers` and `tx` go there
alongside the existing balances / tx / offers / fee / reserve calls. Do not fork
a second client.

**Provider scoping** (these differ, and getting them backwards means
reconciliation only runs while you happen to be looking at the screen):

| Provider | Shape | Why |
|----------|-------|-----|
| `TradeController` | `StateNotifierProvider.autoDispose.family<…, String walletId>` | Screen-scoped, one per wallet (`trade_executions` is already `walletId`-keyed); tears down on leaving so the book stops polling |
| `OrderBookController` | `StateNotifierProvider.autoDispose` | Screen-scoped; polling must stop with the screen |
| `TradeReconciler` | plain `Provider` | App-scoped: runs at startup and on resume across **all** wallets, whether or not Trade was ever opened |

Put each provider next to its own file (as `xrplRpcClientProvider` already lives
in `network_controller.dart`). `state/providers.dart` stays for cross-cutting
singletons only — it is 17 lines and should remain so.

**Reconciler placement — hard rule.** The reconciler runs **in the UI process**,
kicked from the existing `LockLifecycle` post-frame callback in `app.dart`
(which already syncs the address book and starts the watcher) and again on
`AppLifecycleState.resumed`. It must **not** run in the watcher isolate: a second
`AppDatabase` on the same file is the "created the database class AppDatabase
multiple times" hazard, and the watcher stays address-only regardless. It must
also not be kicked from the Trade screen — an order placed and then backgrounded
has to resolve without the screen.

**Not in scope of this work:** refactoring `send_screen.dart`. R1/R2 establish the
module and controller shape; send can adopt it later as its own change. Rewriting
a 949-line money-moving screen while also changing trading behaviour is how
regressions get in.

### Persistence — done

Reshaped while `schemaVersion` 4 was still unreleased (HEAD ships v3), so there is
no migration scar:

- `TradeExecutionSteps` **removed** — it was write-only scaffolding for the
  sliced-execution engine that is no longer planned.
- `TradeFills` **added** (`executionId` + `txHash` primary key, `ledgerIndex`,
  `filledBase`, `filledQuote`, `rate`, `feeDrops`, `date`). One resting offer is
  partially filled by many *later* taker transactions in different ledgers, so
  one execution genuinely has N fills. The composite key makes replaying
  reconciliation over the same ledger range idempotent.
- `TradeExecutions` trimmed and sharpened: dropped `strategy` and `approvalMode`
  (no strategies; approval is always PIN-per-transaction); `deadline` →
  `expiration`; added `orderType` (`market` | `limit`), `txHash`,
  `offerSequence`, and `lastLedgerSequence` for the LLS failure rule.
- `filledAmount` is documented as reconciler-maintained from validated ledger
  metadata — never client-side subtraction.

### Reshaped roadmap

| Step | Delivers | Notes |
|------|----------|-------|
| ~~**R1 — Reconciliation & honest state**~~ | **Shipped 2026-09-06.** `TradeReconciler` kicked from `LockLifecycle` at unlock and on resume; `LastLedgerSequence` failure rule; fills parsed from validated metadata into `TradeFills`; `account_tx` sweep so a stranger's transaction crossing a resting offer is picked up; unfunded-offer detection; `TradeController` replacing the widget's orchestration; active + history sections on the dashboard | `deleteWalletCascade` now clears trade rows too. Remaining from the original scope: automatic cleanup of an unfunded offer (detected and flagged, cancellation is manual). |
| ~~**R2 — `domain/trade/` + tests**~~ | **Shipped 2026-09-06.** Exact decimal arithmetic, rate ↔ inverse, `tfSell`, per-asset precision, slippage → limit rate, sealed order drafts, XRP⇄RLUSD vectors | Unblocks R3/R4. |
| **R3 — Market order (IOC/FOK)** | `tfImmediateOrCancel` default + `tfFillOrKill` option; max-slippage input → limit rate; RLUSD trust-line preflight; no reserve | First genuinely useful trading action; safest (no resting exposure). |
| **R4 — Resting limit order** | Priced `OfferCreate` (+ optional `tfSell`, `Expiration`); reserve gate; book view to pick the rate; exact-field cancel review; sequenced cancel-all | |
| **R5 — Ledger signing** | Single market / limit order signed on device | Lifts the XRW-30 review-only gate for Ledger. |
| **R6 — Polish** | Effective-rate estimate incl. issuer transfer fee (0 for RLUSD) and an AMM-inclusion note; plain fills list with real executed rates; book staleness guard | |

### Testing requirements

Offer parse + cancel vectors; exact `OfferCreate` / `OfferCancel` field
construction for both directions; rate inversion and `tfSell`; XRP-drops vs
RLUSD-decimal boundaries; slippage → limit-rate conversion; reconciliation for
partial / expired / failed / ambiguous / unfunded; restart + migration with
active rows; Ledger and software signing without live hardware; device tests for
PIN confirmation and screen security. No live network or real funds in unit
tests.

## B. Smaller queued items (from the security audits)

- [x] `submitted` trade rows are non-terminal in `getActiveTradeExecutions()` —
      resolved by **R1**: the reconciler now moves them to a status the ledger
      confirmed instead of leaving them there forever.
- [ ] Consider adding `--strip` to `tool/build_release.sh` to silence the
      "unobfuscated DWARF in the generated ELF" warning and drop DWARF from the
      intermediate library (the shipped `libapp.so` is already section-clean).
- [ ] Confirm intent of `WalletListController.reload()` per-network wallet
      filtering — importing the same address under two networks is no longer
      de-duplicated. Likely intentional (per-network wallets); add a test that
      pins the decision.
- [ ] Note only: on Android 16 the OS attributes `ACCESS_LOCAL_NETWORK`
      (pre-granted). With custom endpoints a user can target a LAN node. Low
      risk; documented, no action planned.

## C. Explicitly out of scope (unless asked)

**Trading — deferred, revisit only if the asset universe grows beyond XRP/RLUSD:**

- Additional pairs + a pair picker / issuer selection.
- Cross-currency pathfinding (`ripple_path_find`), path-based `Payment`,
  XRP auto-bridging routing.
- Order-book depth analytics / "pressure" indicators.
- TWAP / iceberg / sliced execution and a chunk planner.
- `amm_info` reads, AMM `Deposit` / `Withdraw`, AMM analytics.
- Route comparison / route-explanation UI.
- Performance dashboards (average price, impact, unfilled over time) beyond a
  plain fills list.

**Trading — out permanently while secrets are UI-process-only:**

- Automated / unattended execution of any kind (nothing can hold signing
  capability in the background without breaking the secrets boundary).

**General:**

- NFTs, multi-sig UX, remote push server, cloud seed backup, iOS release polish,
  multi-language BIP39, fake-balance decoys, removing keys / downgrading
  signing → watch-only.
