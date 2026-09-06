# Contributing to Zerp Wallet

Thanks for helping. This is a local-first Flutter wallet: UI → Riverpod → data,
with domain kept pure. The folder layout is the security story, not fashion.

## Setup

Install a current [Flutter](https://docs.flutter.dev/get-started/install) SDK
and put `flutter` on your `PATH`. Then:

```bash
flutter pub get
flutter analyze
flutter test
```

Android builds also need JDK 17 and an Android SDK. Release APKs currently use
the debug signing config for sideload (`android/app/build.gradle.kts`).

## Checks that must stay green

Every change should pass:

```bash
flutter analyze
flutter test
```

If you touch import, send, or derivation, the golden address tests must still
pass:

- BIP39 mnemonic (BIP44 `m/44'/144'/0'/0/0` + **secp256k1**): abandon phrase →
  `rHsMGQEkVNJmpGWs8XUBoTBiAAbwxZN5v3`
- Family seed: genesis `snoPBrXtMeMyMHUVTgbuqAfg1SUTb` →
  `rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh`

Do **not** prefer ed25519 for mnemonic HD.

## Drift

Edit `lib/data/database/tables.dart` and `app_database.dart` (paths may move; see
`AGENTS.md`). Never hand-edit `app_database.g.dart`. After schema edits:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Secrets boundary

- Mnemonics, family seeds, PINs, and raw keys live only in the UI process via
  `KeyVault` / `PinService`.
- The watcher isolate (`lib/data/watcher/watcher_service.dart`) and the
  UI-isolate watcher client must never import `data/secure/`.
- Do not commit `*.apk`, `build/`, node access tokens, or personal machine
  paths.

## USB Ledger

`packages/ledger_usb_plus` is a **path dependency**. Edit that tree, not the
pub cache. Keep its upstream MIT header.

## Pull requests

Use the PR template checklist. Do not paste seeds, PINs, or node tokens in
descriptions or screenshots.
