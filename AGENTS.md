# XRPL Mobile Wallet — Agent Instructions

Android Flutter wallet for the XRP Ledger (app title: **XRPL Mobile Wallet**).
Local-first: secrets in Keystore, metadata in SQLite, background watcher is
address-only. Unlock-screen runner title: **Zerpland**.

**Destined for the Google Play Store.** This is a shipping product for
third-party users holding real funds — sideloading is only for development and
progress checks. Consequences that bind every decision:

- **No design may have a "user loses their funds" failure mode.** Assume users
  enroll fingerprints, change screen locks, replace phones, and do not have
  their recovery phrase written down. A mechanism that is merely inconvenient
  for the maintainer can be catastrophic for a stranger.
- Play obligations are real work, not paperwork: financial-services / crypto
  declaration, Data Safety form, privacy-policy URL, and Play's rolling target
  API requirement (currently satisfied by `targetSdk` 36).
- Play distribution ships an **App Bundle** signed with the upload keystore
  (`android/key.properties`); `tool/build_release.sh` remains the sideload path.

Plan: `docs/design/2026-09-06-consolidated-plan.md` (Part I = shipped spec —
core design, attach-keys, game PIN, XRP⇄RLUSD trade, timed XRP escrow;
Part II = remaining queue — batch recipes beyond XRP multi-send, escrow deferred items, trade polish)
History: `docs/history/2026-07-20-xrpl-mobile-wallet.md`
User-facing notes: `README.md`

---

## Stack

| Area | Choice |
|------|--------|
| UI | Flutter 3 / Dart 3 (`sdk: ^3.10.4`), Material 3 dark (seed `0xFF00A3BF`), Riverpod 2 |
| XRPL | `xrpl_dart` + `blockchain_utils` |
| Secrets | `flutter_secure_storage` (Android Keystore) via `KeyVault` |
| DB | Drift + SQLite (`lib/data/database/`), `schemaVersion` 4 |
| Watcher | `flutter_background_service` FGS (`dataSync`) + WSS; public addresses only |
| Ledger USB | `ledger_usb_plus` — **local patched copy** at `packages/ledger_usb_plus` (path dep; fixes Android endpoint discovery). Edit the local copy, not pub cache. |
| Package / Android | `xrpl_mobile_wallet` / `info.richlist.wallet` (Java 17, core-library desugaring for notifications) |
| Lints | `package:flutter_lints/flutter.yaml`; analyzer excludes `build/` and platform folders |

---

## Layout

```
lib/
  main.dart, app.dart          # bootstrap, ProviderScope, lock gate
  config/                      # app knobs, storage key names, network id, theme, app_exit
  domain/                      # amount, wallet, validation, tokens, network, oracle (no I/O)
  data/                        # database, secure, xrpl_rpc, ledger_device, endpoints, payments, trade, wallet, watcher, game
  state/                       # Riverpod controllers + providers.dart
  ui/                          # shell, wallets/{list,detail,create,import,receive,attach_keys}, lock/{pin,runner}, send, activity, trade, settings/{network,security,backup,escrow,monitoring,wallet}
test/                          # mirrors lib
packages/ledger_usb_plus/      # vendored Ledger USB plugin (path dep, see Stack)
assets/tokens/                 # XRPSCAN snapshot (offline names)
android/app/src/main/kotlin/info/richlist/wallet/MainActivity.kt  # FLAG_SECURE channel
tool/fetch_xrpscan_tokens.py   # regenerate token catalog
```

Prefer package imports: `package:xrpl_mobile_wallet/...` (relative imports are fine only inside the same small file tree, e.g. `app.dart`).

---

## Commands

Put `flutter` on your `PATH`. Do not hard-code a machine-specific SDK prefix.

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Layout sandbox (not the Play app): `widgetbook/` is a **separate** Flutter project. Never ship it in the release APK.

```bash
cd widgetbook && flutter run -d chrome
```

Release APKs must go through `tool/build_release.sh` — it adds
`--obfuscate --split-debug-info=build/symbols/android` (Dart AOT
obfuscation, XRW-23; the flutter tool otherwise defaults to un-obfuscated).
Symbol maps in `build/symbols/` are needed to symbolicate release stack
traces; never commit or distribute them. Plain
`flutter build apk --release` still works but produces an un-obfuscated
snapshot.

```bash
tool/build_release.sh        # → build/app/outputs/flutter-apk/app-release.apk (obfuscated)
```

Regenerate Drift after schema edits:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Android toolchain: JDK 17, Android SDK with platform-tools and a recent `platforms;android-*` + `build-tools`. **CMake for APK builds must be the SDK-bundled one** (`sdkmanager "cmake;3.22.1"`): the transitive `jni` package's Android module fails with `[CXX1301]` if only system CMake is installed.

Do not commit `*.apk` / `build/` / `android/key.properties` / keystores.
Play bundles sign with the upload keystore via `android/key.properties`.
Without that file, release falls back to debug signing for personal sideload.

---

## Security (non-negotiable)

1. **Secrets boundary** — Mnemonics, family seeds, and raw private key material live only in the UI process via `KeyVault` / `PinService`. Never load them in the watcher isolate (`lib/data/watcher/watcher_service.dart`) or `AccountWatcher`.
2. **Watcher is address-only** — Shared book is public addresses + network (`watcher_address_book.json`). No secrets on disk outside secure storage.
3. **Wallet entropy** — New wallets: OS CSPRNG (`Random.secure`) is always the primary entropy; dice/word ritual is **mixed in**, never a replacement. See `EntropyMixer` domain string; do not weaken or skip OS entropy. Never use package Fortuna for seed bytes.
4. **Screen security** — Keep screenshot blocking on create/import/attach-keys secret screens (`ScreenSecurity` → `MainActivity` FLAG_SECURE).
5. **No logging secrets** — Never log mnemonics, seeds, PINs, or private keys. Status UI must show endpoint **host only** — never a URL query string.
6. **PIN** — Min length **8** (`AppConfig.pinMinLength`); auto-lock after `AppConfig.autoLockSeconds` (90s) in background. Leave the process with `exitApplication()` (`SystemNavigator.pop`), not `exit(0)`. The PIN is a **cryptographic factor**, not just a lockout — see rule 7 — so its entropy is a security parameter and the minimum must not be lowered.
7. **Secrets at rest** — A seed is stored only as an `Argon2id(PIN)` + AES-256-GCM `SecretEnvelope`, never as plaintext, and the envelope then goes into Keystore-backed storage. Two rules follow:
   - **Never auth-bind the key that protects a seed.** `setUserAuthenticationRequired(true)` keys are destroyed by biometric enrollment or screen-lock removal, which would silently take a user's funds with it. Biometrics are a **convenience** layer only (they cache the derived key); losing that layer must only ever cost a PIN prompt.
   - Decryption failure is surfaced as an explicit "keys unavailable" state that offers *Attach keys* — never a silent wipe, never a crash. `resetOnError` stays `false`.
8. **Game PIN** — Optional second salted hash (`game_pin_hash` / `game_pin_salt`) via `PinService`. Unlock: wallet PIN first, then game PIN → Zerpland runner while staying locked. Must differ from wallet PIN. When a game PIN is set, do **not** open the game after 3 failed attempts (only the game PIN does). Settings: set / change / clear (wallet PIN required). Spec: `docs/design/2026-09-06-consolidated-plan.md` §I.10.

---

## Crypto / derivation rules

| Import kind | Algorithm / path | Notes |
|-------------|------------------|-------|
| BIP39 mnemonic | BIP44 `m/44'/144'/0'/0/0` + **secp256k1** | Must match `xrpl.js` `Wallet.fromMnemonic` |
| Family seed `s…` | `XRPPrivateKey.fromSeed` | Often ed25519; separate path |
| Watch-only `r…` | Address only | No secret |
| Ledger USB | `m/44'/144'/index'/0/0` secp256k1 | Device holds keys; phone never stores them |

- **Do not prefer ed25519 for mnemonic HD.** That bug caused address mismatch with desktop; golden test pins abandon phrase → `rHsMGQEkVNJmpGWs8XUBoTBiAAbwxZN5v3`. Family-seed golden: genesis `snoPBrXtMeMyMHUVTgbuqAfg1SUTb` → `rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh`.
- Signing (`PaymentService.privateKeyFromSecret`): secp256k1 first for mnemonics; ed25519 only as fallback when `expectedAddress` matches a legacy mis-import.
- Create + import mnemonic derivation must stay aligned (`WalletGenerator` ↔ `WalletImporter`).

When changing key derivation, update golden tests in `test/data/wallet_importer_test.dart` and `test/data/payments/payment_validators_test.dart`.

---

## Architecture habits

- **Layers:** UI → state (Riverpod) → data services; domain stays pure (validation, display helpers, parsers).
- **Networks:** `NetworkId.mainnet` / `testnet`; defaults in `config/network_id.dart`. Watcher follows **active** network.
- **Mainnet endpoints (ordered failover — user can disable in Settings):**
  - Catalog default: xrplcluster → mainnet.xrpl-rpc.com (Ankr). Selection via `EndpointPreferences` (SharedPreferences). Empty built-in selection falls back to the full catalog, then custom HTTPS/WSS URLs.
  - **HTTP JSON-RPC:** `XrplRpcClient.connect` probes enabled URLs with `server_info`.
  - **WSS:** watcher tries enabled URLs in catalog order, then custom WSS.
  - **Testnet** stays on Ripple altnet HTTP/WSS (not user-selectable).
- **Connection chip:** RPC state from `NetworkController` + watcher heartbeat (`WatcherStatusStore` / SharedPreferences). Pure combine in `ConnectionHealth` (green/yellow/red). Host only in UI.
- **Wallet kinds:** `WalletKind.signing` (local keys in KeyVault) vs `watchOnly`. `WalletAccount.canSign` is true when signing **or** `useLedger`. **`useLedger`** checkbox enables Send without keys: path `m/44'/144'/index'/0/0` via USB Ledger XRP app (`lib/data/ledger_device/`, `LedgerXrpDevice` in send). Never store Ledger private keys. Address mismatch → clear user error. USB is not a runtime permission — `UsbManager.requestPermission` + `USB_DEVICE_ATTACHED` / `usb_device_filter.xml`.
- **Attach keys:** Watch-only detail → Add keys (paste / 8×3 grid / family seed). Reuse `WalletImporter.derive*ForAddress`; persist via `WalletListController.attachKeys` (same `walletId`, never change address). Grid rules in `MnemonicGrid`.
- **Accent color:** optional ARGB on the wallet row; null → derive from address (`WalletColor`).
- **Token names:** Bundled XRPSCAN snapshot + hex→ASCII fallback; no network fetch required for labels. Loaded in `main()` into `CurrencyDisplay`.
- **XRP/USD:** XRPL-Labs TrustSet oracle `rXUMMaPpZqPutoRszR29jtC8amWq3APkx` (`XrpUsdOracle` parser, `PriceFeedController`, last rate in prefs). Portfolio toggle XRP vs USD — not a trading feed.
- **Payments:** Build/sign/submit software txs in `PaymentService`; secrets passed in from KeyVault at the call site, not stored on the service. Amounts via `XrpAmount` (drops as `BigInt` strings). Ledger send signs on device then submits the blob. RLUSD TrustSet (official issuer, NoRipple) uses the same generic sign/submit helper as Payment; only shown when `canSign` and the line is not already on `account_lines`.
- **Drift:** Edit `tables.dart` / `app_database.dart`; never hand-edit `app_database.g.dart`. Migrations: v2 `accentColor`, v3 `useLedger` + `ledgerAccountIndex`, v4 `trade_executions` + `trade_fills`.
- **Trade:** XRP ⇄ RLUSD only. Pure logic in `lib/domain/trade/` (no `double` — money maths goes through `TradeDecimal`); services in `lib/data/trade/`; `TradeRepository` is the only thing that touches the trade tables. The reconciler runs in the **UI process** (kicked from `LockLifecycle` at unlock and on resume), never in the watcher isolate — a second `AppDatabase` on the same file corrupts. Its three rules: never blind-retry an ambiguous submission, `LastLedgerSequence` is the only proof a transaction is dead, and fills come from validated metadata only (`FillParser`), never client-side subtraction. Signing is local keys **or** Ledger. Plan: `docs/design/2026-09-06-consolidated-plan.md` §I.13.
- **Escrow:** XRP-only timed escrow (`EscrowService`). Create from wallet detail; list/finish/cancel on Settings → Escrow. Finish only after `FinishAfter` and before `CancelAfter`; cancel only after `CancelAfter`. No background signing. Conditional / token escrow deferred. Plan: `docs/design/2026-09-06-consolidated-plan.md` §I.14.
- **Batch:** `BatchV1_1` only. Slice 1 is single-account XRP multi-send (2–8 inner Payments, All-or-nothing) from Send, gated on the connected node’s `feature` RPC. Inners are unsigned (`tfInnerBatchTxn`, fee 0). No generic builder; Ledger Batch signing is not exposed yet. Plan: `docs/design/2026-09-06-consolidated-plan.md` §II.B.
- **Game scores:** local top-5 only (`RunnerScoreboard`); no network.

---

## Testing

- Unit tests for validation, entropy, import, payment key derivation, export encrypt/decrypt, parsers, oracle TrustSet parse, connection health, endpoint prefs, Ledger APDU helpers.
- Prefer golden addresses / known vectors over weak `startsWith('r')` checks for crypto.
- Run `flutter test` before claiming crypto or import work is done.
- Widget tests may stub lock/watcher; do not require a live ledger or USB device for unit tests.

---

## Product scope notes

- **Google Play release is the goal**; sideload builds are for development.
  Treat user-facing failure modes, recovery paths and error copy as shippable
  product surface, not developer conveniences.
- Features in tree: create (entropy ritual), import (mnemonic / family seed / watch-only / encrypted export), send, receive, RLUSD trust line (signing / Ledger), XRP⇄RLUSD trade (market + limit, software or Ledger), timed XRP escrow (create / finish / cancel), activity, PIN + optional game PIN + biometrics, FGS watcher, unlock-screen Zerpland runner (game PIN or 3-fail decoy when no game PIN; top-5 local leaderboard), XRP/USD portfolio display, connection status chip.
- Ledger Device checkbox on wallet detail enables Send, trade, and escrow for watch-only (USB, XRP app, path `m/44'/144'/index'/0/0`); no seed on phone; address mismatch → user error. See `lib/data/ledger_device/`.
- Non-goals unless asked: extra DEX pairs, NFTs, multi-sig UX, remote push server, iOS release polish, arbitrary batch builder / multi-account Batch, conditional/token escrow.
- Secret-at-rest design (Argon2id PIN envelope, biometrics as convenience only):
  `docs/design/2026-09-06-auth-bound-secret-storage.md`.

---

## Working style

- Match existing patterns (Riverpod controllers, Drift tables, Material screens) instead of new frameworks.
- Keep security comments accurate; wrong crypto docs have already caused real bugs.
- Prefer small, tested changes around keys and signing over large refactors.
- Do not invent remote backends; this app is local-first.
