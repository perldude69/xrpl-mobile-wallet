# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Public-repo scaffolding: MIT license, contributing and security docs, CI.
- Settings coffee mug sends XRP to `rJTyAxvqh9UcigEfK2CTAd3ipUEvchDNzr`.
- HTML user guide at `docs/user-guide/index.html` (screenshot slots for later).

### Changed

- **Breaking (Android):** `applicationId` is now `info.richlist.wallet`. This
  does **not** upgrade an install of `com.jim.xrpl.xrpl_mobile_wallet`. Export
  from the old app, install the new APK, import, then uninstall the old app.

- Default mainnet failover is public cluster → Ankr only (no personal node token).
- Settings: add / edit / remove / reorder custom HTTPS and WSS nodes.
- Public chrome titled XRPL Mobile Wallet; unlock runner titled Zerpland.
- Rename XRPL JSON-RPC (`XrplRpcClient`) vs USB Ledger (`LedgerXrpDevice`); drop math lives in `XrpAmount`.
- Split config, rename `AccountWatcher`, and move database / payments / endpoints folders.
- Group wallet and lock screens into feature folders; runner is `ZerplandRunnerScreen`.
- Split Settings into Network, Security, and Backup widgets.
- App icon is a thick horror-style outlined Z (replaces the old Cicada moth art).

## [1.0.0] - 2026-09-02

### Added

- First public tag baseline of the Android-first XRPL wallet (create, import,
  send, receive, activity, PIN, optional game PIN, USB Ledger, account watcher).
