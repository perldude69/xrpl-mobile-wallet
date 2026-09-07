# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.1] - 2026-09-07

### Added

- Ledger-backed wallet import with device address verification.
- Validated-ledger order-book refresh and pending-payment recovery status.

### Security

- PIN-derived wallet secret envelopes and strict Ledger signature verification.
- Removed biometric unlock until a safe PIN-derived convenience flow is available.

### Fixed

- Wallet-list layout overflow and stale order-book loading display.

## [2.1.0] - 2026-09-07

### Added

- XRP/RLUSD market and limit trading with validated order-book display.
- Ledger signing for market orders, limit orders, and offer cancellation.
- Rich-list RPC/WSS endpoint defaults and resilient rippled response parsing.
- Reserve checks, slippage bounds, order reconciliation, and trade history.
- Editable limit rates with numeric amount entry.

## [2.0.0] - 2026-09-05

### Added

- Updated Zerp launcher icon with the complete Zerp wordmark and adaptive-icon
  safe-area padding.
- Android biometric permissions and FragmentActivity support for fingerprint /
  face unlock.

### Security

- Removed recovery-phrase clipboard copying (XRW-24).
- Replaced raw UI exception text with safe user-facing errors (XRW-25).
- Upgraded the Android local-auth implementation and retained biometric
  authentication across activity transitions.
- Added build, source, and device audit reports under `docs/audit/`.
- Added the first V2 Trade dashboard milestone: validated open-offer visibility
  for selected wallets, including watch-only accounts.

- Wallet secrets and PIN verifiers now live under runtime-derived secure
  storage key names (`KeyNames`, SHA-256 of XOR-encoded role tags) instead of
  plain `wallet_secret_` / `app_pin_hash` / `game_pin_*` literals.
  **Breaking for upgraders:** existing installs cannot read previously stored
  secrets or PINs — re-import wallets and set the PIN again. Encrypted wallet
  list exports (names + addresses only) re-import unchanged.
- Release APKs are built with Dart AOT obfuscation
  (`tool/build_release.sh` → `--obfuscate --split-debug-info`); obfuscated
  symbol maps land in `build/symbols/` for stack-trace symbolication and must
  stay private. Resolves XRW-23.
- Ledger USB Java logs are debug-only (no device names or APDU sizes in
  release logcat).
- `filterTouchesWhenObscured` on MainActivity so overlay windows cannot
  steal PIN / send taps.
- OWASP Mobile Audit report (`docs/audit/2026-09-05-owasp-mobile-audit-report.html`)
  of tree `9a743c1` plus Pixel 8 Pro checks of the installed 1.0.1 APK.
- Re-audit of the release build
  (`docs/audit/2026-09-05-reaudit-release-apk.html`, Markdown copy
  `2026-09-05-reaudit-release-apk.md`): APK verifies with the upload keystore
  under v2 signature scheme (XRW-01 resolved); XRW-21 / XRW-22 fixes verified
  on the installed binary; dynamic checks re-run (FLAG_SECURE screencaps,
  90 s auto-lock, logcat secret scan). XRW-23 resolved and device-verified in
  a follow-up pass.
- Fresh code & device audit, findings only
  (`docs/audit/2026-09-05-code-and-device-audit.html`): XRW-24 recovery
  phrase copyable to system clipboard (Low), XRW-25 raw exception text shown
  in UI errors (Informational). Everything else checked this pass was clean.
- Privacy document (`docs/privacy/privacy.md`) describing on-device storage,
  network traffic, permissions, and user controls.

## [1.0.1] - 2026-09-03

### Security

- PIN verifier is PBKDF2-SHA256 (120k iterations); legacy SHA-256 hashes
  upgrade on the next successful unlock.
- Android Auto Backup is off; Keystore `resetOnError` is false so a glitch
  cannot silently wipe seeds.
- Wallet PIN is required to send, add RLUSD, wipe, delete a wallet, or enable
  biometrics.
- `FLAG_SECURE` on PIN and send surfaces; Autofill opted out of PIN fields.
- Send shows the network fee on Review and refuses to sign if autoFill's fee
  differs (hard cap 0.1 XRP).
- Destination-tag / Disallow XRP checks, including the coffee preset path.
- Spendable XRP must cover amount plus fee; unfunded destinations need 1 XRP.
- Watcher FGS and plugin Boot/Watchdog receivers are not exported.
- Encrypted list export writes to temp and deletes the file after share.
- Ledger APDU payloads are not logged in release builds.

### Added

- Security audit report (`docs/audit/`), with Pixel 8 Pro checks of the
  release APK (signing, backup, merged manifest, FLAG_SECURE).

## [1.0.0] - 2026-09-02

### Added

- First public tag baseline of the Android-first XRPL wallet (create, import,
  send, receive, activity, PIN, optional game PIN, USB Ledger, account watcher).
- Add RLUSD trust line on wallet detail for signing and Ledger wallets (hidden
  when the line already exists).
