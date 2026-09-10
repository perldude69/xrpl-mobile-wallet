# XRPL Mobile Wallet — Consolidated Plan

**Date:** 2026-09-07
**App:** XRPL Mobile Wallet (package `info.richlist.wallet`, app title *Zerp Wallet*,
unlock-screen runner *Zerpland*)
**Status:** Living document. Part I is shipped behaviour. Part II is the remaining
queue.

This file supersedes and folds in:

| Folded-in document | Covers |
|--------------------|--------|
| `2026-07-20-xrpl-mobile-wallet-design.md` | Core product shape, architecture, data model, security, watcher |
| `2026-08-02-attach-keys-watch-wallet-design.md` | Attaching signing keys to a watch-only wallet |
| `2026-08-03-game-pin-design.md` | Optional second (game) PIN → Zerpland decoy |
| `2026-09-05-smart-trade-execution-plan.md` | XRPL trading — XRP ⇄ RLUSD only; R1–R5 shipped (Part I §13) |

Companion records, not folded in: `../history/2026-07-20-xrpl-mobile-wallet.md`
(build log), `../../CHANGELOG.md`, `../audit/` (security audits), `../../AGENTS.md`
(authoritative agent guide — stack, layout, commands, non-negotiables).

---

# Part I — Implemented

Everything in this part is in the tree today. Paths are the source of truth;
this text is the intent behind them.

## 1. Product shape & architecture

A personal **Android-first Flutter** wallet for the XRP Ledger, destined for
Google Play. Sideload builds are for development only.

- Import **signing** wallets (24- or 12-word BIP39, or classic family seed `s…`)
  and **create** new ones (OS CSPRNG + dice/word entropy ritual).
- Add **watch-only** wallets (classic address `r…`).
- Show **XRP + issued-currency** balances and history.
- **Send** XRP and issued currencies, signed on-device or on a connected Ledger.
- Add the **RLUSD** trust line (signing or Ledger).
- **Trade** XRP ⇄ RLUSD (market IOC/FOK and resting limit; software or Ledger).
- **Timed XRP escrow:** create, list, finish, cancel (software or Ledger).
- Run an **address-only background watcher** (foreground service) that raises a
  local notification on validated account activity.
- **Mainnet + Testnet**, with an ordered, user-editable endpoint catalog.
- Optional **game PIN** duress decoy → *Zerpland* endless runner.
- Optional **XRP/USD** portfolio display from an on-ledger oracle.

**Two-process model:**

| Process | Holds secrets? | Role |
|---------|----------------|------|
| Flutter UI | Yes (`KeyVault` / `PinService`, ephemeral at sign time) | Import, create, display, sign, submit |
| Watcher FGS (`lib/data/watcher/watcher_service.dart`) | **No** | WSS-subscribe to public addresses; local notify |

**Layers:** UI → state (Riverpod) → data services; `domain/` stays pure
(validation, formatting, parsers). Material 3 dark, seed `0xFF00A3BF`.

Settings are split into Network, Wallet, Security, Monitoring, Escrow, and About
(`lib/ui/settings/`).

## 2. Data model & storage

Drift/SQLite `schemaVersion` 4 (`lib/data/database/`).

| Store | Data |
|-------|------|
| `flutter_secure_storage` (Android Keystore) | PIN-sealed seed envelopes, PIN + game-PIN verifiers. Key **names** are runtime-derived (`KeyNames`, SHA-256 of XOR-encoded role tags). |
| SQLite | `Wallets`, `Balances`, `CachedTxs`, `AppSettingsRows`, `TradeExecutions`, `TradeFills` — non-secret metadata only |
| SharedPreferences | Theme, last selected wallet, endpoint selection, last price rate, watcher heartbeat |
| `watcher_address_book.json` | Public addresses + active network only |

`WalletAccount`: id, label, address, `kind` (`signing` | `watchOnly`),
`preferredNetwork`, `importMethod` (`mnemonic` | `familySeed` | `addressOnly` |
`ledger`), createdAt, sortOrder, optional ARGB accent, `useLedger`,
`ledgerAccountIndex`.

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
6. **PIN** — min length **8** (`AppConfig.pinMinLength`); auto-lock after
   `AppConfig.autoLockSeconds` (90 s) in background; leave the process with
   `exitApplication()` (`SystemNavigator.pop`). The PIN is a **cryptographic
   factor**, not just a lockout.
7. **Secrets at rest** — a seed is stored only as an `Argon2id(PIN)` + AES-256-GCM
   `SecretEnvelope`, then in Keystore-backed storage. **Never**
   `setUserAuthenticationRequired(true)` on the key that protects a seed
   (biometric enrollment or screen-lock removal would destroy it). Biometrics
   are convenience only (they cache the derived key). Decryption failure is an
   explicit “keys unavailable” state with *Attach keys* — never a silent wipe.
   `resetOnError` stays `false`.
8. **Game PIN** — see §10.

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
  compare). Mismatch → user error, no KeyVault write, no kind change, no new row.
- On match: `WalletListController.attachKeys` does
  `KeyVault.saveSecret` → set `kind = signing`, `importMethod` accordingly →
  reload. Address, label, balances, cached txs unchanged.
- `ScreenSecurity` on while entry screens are mounted.

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
  is shared by Payment, RLUSD `TrustSet`, Trade `OfferCreate` / `OfferCancel`,
  and Escrow create / finish / cancel.

## 7. Background watcher & notifications

- Sticky FGS (`dataSync`): *"XRPL Watcher: N accounts · network · state"*.
- WSS `subscribe accounts:[…]` on the **active** network, trying enabled
  endpoints in catalog order then custom WSS.
- Notify on validated txs, dedupe by hash; body from public ledger data.
- Toggle in Settings → Monitoring; local notifications only (no Firebase).
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

Rules: same format as wallet PIN (≥ **8** digits); must **differ** from the
wallet PIN (changing the wallet PIN to equal the game PIN is rejected); set /
change / clear always require the wallet PIN; wipe clears both. Storage:
`game_pin_hash` / `game_pin_salt`. The game path never reads `KeyVault`. Local
top-5 leaderboard (`RunnerScoreboard`), no network.

Out of scope: fake balances / decoy wallets, first-run requirement, hiding
Zerpland from Settings.

## 11. Crypto & derivation

| Import kind | Path / algorithm | Notes |
|-------------|------------------|-------|
| BIP39 mnemonic | BIP44 `m/44'/144'/0'/0/0` + **secp256k1** | Must match `xrpl.js` `Wallet.fromMnemonic` |
| Family seed `s…` | `XRPPrivateKey.fromSeed` | Often ed25519; separate path |
| Watch-only `r…` | address only | no secret |
| Ledger USB | `m/44'/144'/index'/0/0` secp256k1 | device holds keys |

- **Do not prefer ed25519 for mnemonic HD.** Golden: `abandon … about` →
  `rHsMGQEkVNJmpGWs8XUBoTBiAAbwxZN5v3`; genesis family seed
  `snoPBrXtMeMyMHUVTgbuqAfg1SUTb` → `rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh`.
- `PaymentService.privateKeyFromSecret`: secp256k1 first for mnemonics; ed25519
  only when `expectedAddress` matches a legacy mis-import. Correcting such an
  address = re-import the phrase; no automatic DB migration.
- Create ↔ import derivation must stay aligned (`WalletGenerator` ↔
  `WalletImporter`).

## 12. RLUSD trust line

Official issuer, `NoRipple`, hex currency code, fixed limit (`domain/tokens/rlusd.dart`).
Built through the same generic sign/submit helper as Payment; offered only when
`canSign` and the line is not already on `account_lines`. Signing or Ledger.

## 13. Trade — XRP ⇄ RLUSD (shipped)

Entry: *Trade* on wallet detail (all wallets; watch-only is review-only).
Dashboard: `lib/ui/trade/trade_dashboard_screen.dart`. Pair is **XRP ⇄ RLUSD
only** (`domain/trade/trade_pair.dart`), official issuer per network.

**Shipped:**

- Domain maths in `lib/domain/trade/` (no `double`; `TradeDecimal`).
- `OfferService` / `TradeRepository` / `TradeReconciler` / `OrderBookService`.
- `TradeController` (per-wallet) + `orderBookProvider`.
- Market orders: `tfImmediateOrCancel` default, `tfFillOrKill` option, max
  slippage → limit rate.
- Resting limit orders: priced `OfferCreate`, optional `tfSell` / expiration,
  owner-reserve preflight, sequenced cancel-all.
- Validated `book_offers` panel (best bid/ask, depth); stale book refused.
- RLUSD trust-line preflight before an RLUSD-side order (`AddRlusdButton`).
- Software **and Ledger** signing for market, limit, and cancel (one order per
  device signature). Watch-only can review the book and open offers, not submit.
- Reconciler in the **UI process** (`LockLifecycle` at unlock and on resume),
  never in the watcher isolate. Rules: never blind-retry an ambiguous
  submission; `LastLedgerSequence` is the only proof a tx is dead; fills come
  from validated metadata (`FillParser`) only.
- Unfunded offers are **detected and flagged**; Trade offers a PIN-gated
  cancel pass (the ledger will not remove them).

**Hard rule:** the reconciler must not run in the watcher isolate (second
`AppDatabase` on the same file corrupts) and must not depend on the Trade
screen being open.

## 14. Escrow — timed XRP (shipped)

XRP-only timed escrow with mandatory expiration. No background signing.

- **Create** from wallet detail (`CreateEscrowScreen`): destination (or self),
  optional destination tag, amount, finish/cancel times, spendable + extra
  owner-reserve preflight, review, PIN, software or Ledger sign.
- **List** on Settings → Escrow (`EscrowSettings`): outgoing
  (`account_objects` type `escrow`) plus incoming from recent `account_tx`.
  Amounts in XRP; release/refund times; locked-funds and reserve copy.
- **Finish** after `FinishAfter` and **before** `CancelAfter`; **Cancel** only
  after `CancelAfter`. Inspect-by-owner-and-sequence can finish/cancel too.
- Review (amount, destination, times, fee wallet, estimated fee, reserve
  effect, memo) then wallet PIN. Ledger-only wallets can pay the fee.
- Wallet detail shows locked XRP for open escrows on that address.
- Conditional and token/RLUSD escrow rows are shown as not supported.

Paths: `lib/data/payments/escrow_service.dart`,
`lib/ui/settings/escrow_settings.dart`,
`lib/ui/wallets/detail/create_escrow_screen.dart`. Tests:
`test/data/payments/escrow_test.dart`.

## 15. Portfolio, connection chip, misc

- **XRP/USD:** XRPL-Labs TrustSet oracle `rXUMMaPpZqPutoRszR29jtC8amWq3APkx`
  (`XrpUsdOracle` parser, `PriceFeedController`, last rate in prefs). Portfolio
  toggle XRP vs USD — not a trading feed.
- **Token names:** bundled XRPSCAN snapshot + hex→ASCII fallback; no network
  fetch for labels.
- **Backup:** password-encrypted JSON export/import of wallet **names + addresses
  only** (AES-GCM-256 + PBKDF2). Export entries carry `preferredNetwork`.
- **Accent colour:** optional ARGB per row; null → derived from address.
- App version string: `AppConfig.appVersionName` (Settings → About).

---

# Part II — Remaining queue

## A. Trade polish

R1–R5 are shipped. Left:

- Unfunded offers are flagged on Trade and cancelled with one PIN-gated
  `OfferCancel` pass. The ledger does not remove them; they hold owner
  reserve until cancelled. Background cancel is out of scope.
- Richer fill-rate copy (issuer transfer fee is 0% for RLUSD and is already
  noted; AMM-inclusion wording can be clearer).
- Do **not** add pairs, pathfinding, AMM deposit/withdraw, or unattended
  execution.

## B. Batch transactions

Slice 1 is in tree: single-account **XRP multi-destination Send** (2–8
Payments, `tfAllOrNothing` only) gated on the connected node’s `BatchV1_1`
(`feature` RPC). Original `Batch` amendment is obsolete. Ledger wallets stay
on single Payment until the XRP app is proven to parse `Batch` blobs.

Paths: `lib/domain/payments/batch_plan.dart`,
`lib/data/payments/batch_service.dart`, Send screen
“Add another destination”. Tests: `test/data/payments/batch_test.dart`.

Still remaining:

1. RLUSD multi-send after the XRP path is proven on Testnet.
2. Named recipes (Independent multi-OfferCancel, OfferCancel+OfferCreate
   replace, TrustSet+first buy, escrow multi-finish). No generic builder.
3. Other modes, multi-account `BatchSigners`, Ledger signing.
4. No unattended submission.

## C. Escrow — deferred

The timed XRP lifecycle in Part I §14 is shipped. Still deferred:

- Conditional escrow and crypto-condition fulfillment secrets.
- Token / RLUSD escrow.
- Unattended / background completion.

## D. Smaller items (from the security audits)

- [x] `submitted` trade rows are non-terminal in `getActiveTradeExecutions()` —
      the reconciler moves them to a ledger-confirmed status.
- [x] `--strip` via `--extra-gen-snapshot-options=--strip` in
      `tool/build_release.sh` so gen_snapshot drops DWARF from the AOT snapshot.
- [x] Same classic address is allowed once per network: `reload()` filters to
      the active network and `ensureUniqueAddress` checks that list. Pinned in
      `test/state/wallet_total_xrp_test.dart`.
- [ ] Note only: on Android 16 the OS attributes `ACCESS_LOCAL_NETWORK`
      (pre-granted). With custom endpoints a user can target a LAN node. Low
      risk; documented, no action planned.

## E. Explicitly out of scope (unless asked)

**Trading — deferred, revisit only if the asset universe grows beyond XRP/RLUSD:**

- Additional pairs + a pair picker / issuer selection.
- Cross-currency pathfinding (`ripple_path_find`), path-based `Payment`,
  XRP auto-bridging routing.
- Order-book depth analytics / "pressure" indicators.
- TWAP / iceberg / sliced execution and a chunk planner.
- `amm_info` reads, AMM `Deposit` / `Withdraw`, AMM analytics.
- Route comparison / route-explanation UI.
- Performance dashboards beyond the existing fills list.

**Trading — out permanently while secrets are UI-process-only:**

- Automated / unattended execution of any kind.

**General:**

- NFTs, multi-sig UX, remote push server, cloud seed backup, iOS release polish,
  multi-language BIP39, fake-balance decoys, removing keys / downgrading
  signing → watch-only, YubiKey as an extra at-rest factor (see
  `2026-09-06-yubikey-exploration.md`).
