# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
