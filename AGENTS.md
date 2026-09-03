# XRPL Mobile Wallet — Agent Instructions

Android-first Flutter wallet for the XRP Ledger (app title: **XRPL Mobile Wallet**).
Local-first: secrets in Keystore, metadata in SQLite, background watcher is
address-only. Unlock-screen runner title: **Zerpland**.

Design: `docs/design/2026-07-20-xrpl-mobile-wallet-design.md`
Attach-keys: `docs/design/2026-08-02-attach-keys-watch-wallet-design.md`
Game PIN: `docs/design/2026-08-03-game-pin-design.md`
History: `docs/history/2026-07-20-xrpl-mobile-wallet.md`
User-facing notes: `README.md`

---

## Stack

| Area | Choice |
|------|--------|
| UI | Flutter 3 / Dart 3 (`sdk: ^3.10.4`), Material 3 dark (seed `0xFF00A3BF`), Riverpod 2 |
| XRPL | `xrpl_dart` + `blockchain_utils` |
| Secrets | `flutter_secure_storage` (Android Keystore) via `KeyVault` |
| DB | Drift + SQLite (`lib/data/database/`), `schemaVersion` 3 |
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
  data/                        # database, secure, xrpl_rpc, ledger_device, endpoints, payments, wallet, watcher, game
  state/                       # Riverpod controllers + providers.dart
  ui/                          # shell, wallets/{list,detail,create,import,receive,attach_keys}, lock/{pin,runner}, send, activity, settings/{network,security,backup}, network
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
flutter build apk --release   # → build/app/outputs/flutter-apk/app-release.apk
```

Regenerate Drift after schema edits:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Android toolchain: JDK 17, Android SDK with platform-tools and a recent `platforms;android-*` + `build-tools`. **CMake for APK builds must be the SDK-bundled one** (`sdkmanager "cmake;3.22.1"`): the transitive `jni` package's Android module fails with `[CXX1301]` if only system CMake is installed.

Do not commit `*.apk` / `build/`. Release currently uses debug signing for personal sideload.

---

## Security (non-negotiable)

1. **Secrets boundary** — Mnemonics, family seeds, and raw private key material live only in the UI process via `KeyVault` / `PinService`. Never load them in the watcher isolate (`lib/data/watcher/watcher_service.dart`) or `AccountWatcher`.
2. **Watcher is address-only** — Shared book is public addresses + network (`watcher_address_book.json`). No secrets on disk outside secure storage.
3. **Wallet entropy** — New wallets: OS CSPRNG (`Random.secure`) is always the primary entropy; dice/word ritual is **mixed in**, never a replacement. See `EntropyMixer` domain string; do not weaken or skip OS entropy. Never use package Fortuna for seed bytes.
4. **Screen security** — Keep screenshot blocking on create/import/attach-keys secret screens (`ScreenSecurity` → `MainActivity` FLAG_SECURE).
5. **No logging secrets** — Never log mnemonics, seeds, PINs, or private keys. Status UI must show endpoint **host only** — never a URL query string.
6. **PIN** — Min length 6; auto-lock after `AppConfig.autoLockSeconds` (90s) in background. Leave the process with `exitApplication()` (`SystemNavigator.pop`), not `exit(0)`.
7. **Game PIN** — Optional second salted hash (`game_pin_hash` / `game_pin_salt`) via `PinService`. Unlock: wallet PIN first, then game PIN → Zerpland runner while staying locked. Must differ from wallet PIN. When a game PIN is set, do **not** open the game after 3 failed attempts (only the game PIN does). Settings: set / change / clear (wallet PIN required). Spec: `docs/design/2026-08-03-game-pin-design.md`.

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
- **Payments:** Build/sign/submit software txs in `PaymentService`; secrets passed in from KeyVault at the call site, not stored on the service. Amounts via `XrpAmount` (drops as `BigInt` strings). Ledger send signs on device then submits the blob.
- **Drift:** Edit `tables.dart` / `app_database.dart`; never hand-edit `app_database.g.dart`. Migrations: v2 `accentColor`, v3 `useLedger` + `ledgerAccountIndex`.
- **Game scores:** local top-5 only (`RunnerScoreboard`); no network.

---

## Testing

- Unit tests for validation, entropy, import, payment key derivation, export encrypt/decrypt, parsers, oracle TrustSet parse, connection health, endpoint prefs, Ledger APDU helpers.
- Prefer golden addresses / known vectors over weak `startsWith('r')` checks for crypto.
- Run `flutter test` before claiming crypto or import work is done.
- Widget tests may stub lock/watcher; do not require a live ledger or USB device for unit tests.

---

## Product scope notes

- Android-first sideload; not a Play Store product.
- Features in tree: create (entropy ritual), import (mnemonic / family seed / watch-only / encrypted export), send, receive, activity, PIN + optional game PIN + biometrics, FGS watcher, unlock-screen Zerpland runner (game PIN or 3-fail decoy when no game PIN; top-5 local leaderboard), XRP/USD portfolio display, connection status chip.
- Ledger Device checkbox on wallet detail enables Send for watch-only (USB, XRP app, path `m/44'/144'/index'/0/0`); no seed on phone; address mismatch → user error. See `lib/data/ledger_device/`.
- Non-goals unless asked: DEX, NFTs, multi-sig UX, remote push server, iOS release polish.

---

## Working style

- Match existing patterns (Riverpod controllers, Drift tables, Material screens) instead of new frameworks.
- Keep security comments accurate; wrong crypto docs have already caused real bugs.
- Prefer small, tested changes around keys and signing over large refactors.
- Do not invent remote backends; this app is local-first.
