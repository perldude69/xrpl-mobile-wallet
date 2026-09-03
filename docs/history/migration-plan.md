# Migration plan: open-source XRPL Mobile Wallet

This document is the source of truth for taking the current personal Flutter wallet and publishing it as a public, easy-to-navigate open-source project.

The app already works. This is a **behavior-preserving** re-home: same crypto, same PIN / Keystore rules, same watcher secrets boundary. What changes is public-repo hygiene, names that match what the code does, and a folder tree a new contributor can follow.

Do **not** mix a giant rename with the Android package-id cutover. The sequence below is ordered so each step is reviewable and the phone install only breaks once, on purpose.

---

## 1. Goals

1. Ship a public GitHub (or similar) repo that a stranger can clone, build, and understand.
2. Keep layered architecture (UI → Riverpod → data; domain stays pure) because that is the **security story**, not fashion.
3. Rename files, types, and folders so “ledger” is not used for both XRPL JSON-RPC and a USB Ledger device.
4. Drop personal machine paths, personal node tokens, and personal Android ids from the default tree.
5. Let you keep using your own node by **adding it in Settings**, never by committing it.

---

## 2. Decisions (locked)

| Topic | Choice |
|-------|--------|
| License | **MIT** |
| Donation | **Buy the developer a coffee** link in README + `.github/FUNDING.yml` (URL to fill in) |
| Public product name | **XRPL Mobile Wallet** |
| Dart package | Keep `xrpl_mobile_wallet` (`package:xrpl_mobile_wallet/...`) |
| Unlock-screen game title | Change to 'Zerpland'
| Android `applicationId` | **`info.richlist.wallet`** (see [§5](#5-android-applicationid)) |
| Network defaults | Public catalog only; **custom nodes** in Settings for personal RPC/WSS |

### 2.1 MIT and a coffee link

MIT does **not** restrict donations.

MIT requires only that copies of the software keep the copyright notice and the permission notice. You may:

- Put a “Buy the developer a coffee” button in the README and in Settings → About
- Use GitHub Sponsors, Ko-fi, Buy Me a Coffee, or a custom URL
- Sell binaries or accept paid support

You may **not** (under MIT) prevent someone from forking the app and adding their own donation link. That is the usual trade-off of a permissive license.

Copyright line in `LICENSE` should be your name (or “XRPL Mobile Wallet authors”) and the year of the public release. Fill this in when the LICENSE file is added.

### 2.2 Why not copyleft?

GPL-3.0 would force forks to stay GPL. That is a valid stance, but you asked about donations, not about forcing derivatives. MIT is the usual Flutter/Dart default and does not block a coffee link.

---

## 3. Non-goals (do not regress)

- Do not change BIP39 mnemonic derivation: BIP44 `m/44'/144'/0'/0/0` + **secp256k1** (must still match `xrpl.js` `Wallet.fromMnemonic`). Golden address: abandon phrase → `rHsMGQEkVNJmpGWs8XUBoTBiAAbwxZN5v3`.
- Do not change family-seed handling (`XRPPrivateKey.fromSeed`). Golden: genesis `snoPBrXtMeMyMHUVTgbuqAfg1SUTb` → `rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh`.
- Do not load mnemonics, family seeds, PINs, or raw keys in the watcher isolate (`watcher_service.dart`) or the UI-isolate watcher client.
- Do not make dice / personal-word entropy replace OS CSPRNG (`Random.secure`). Mix-in only (`EntropyMixer`).
- Do not replace Riverpod, Drift, or Material with a new framework.
- Do not rename the whole tree in one commit.
- Do not commit `*.apk`, `build/`, or node access tokens.

---

## 4. Current gaps

### 4.1 Open-source blockers

| Gap | Why it matters |
|-----|----------------|
| No `LICENSE` | A public repo without a license is *not* open source in practice. |
| No `CONTRIBUTING.md` / `SECURITY.md` / CI | Contributors and vulnerability reporters have no path. |
| `AppConstants.richListWssToken` in git | Node access credential; must not be the public default. |
| Personal `rich-list.info` as catalog #1 | Fine for you; wrong as a global default. |
| README / `AGENTS.md` use `/home/jim/flutter/bin` | Clones on other machines fail the “just follow the README” test. |
| `todo.md`, `docs/superpowers/` | Personal paths and internal agent-tooling names. |
| `applicationId` `com.jim.xrpl.xrpl_mobile_wallet` | Personal reverse-DNS; you asked to change it. |
| App chrome titled **Cicada 3301** | You want a neutral public product name. |

### 4.2 Understandability

| Current | Problem |
|---------|---------|
| `lib/data/ledger/` | This is **XRPL HTTP JSON-RPC**, not a hardware wallet. |
| `lib/data/ledger_hw/` | This **is** a USB Ledger. Two “ledger” folders. |
| `lib/core/constants.dart` | Network enum + prefs keys + WSS token + oracle address in one dump. |
| `lib/state/providers.dart` | Grab-bag of unrelated providers. |
| `WatcherBridge` | It is the UI-isolate foreground-service **client**, not a “bridge.” |
| `RobotRunnerGameScreen` | Does not match the game title users see. |
| `AmountFormat` under `data/ledger/` | Pure drop math; belongs in domain. |
| `lib/ui/wallets/` | List, create, import, receive, QR, attach-keys in one flat folder. |
| `docs/superpowers/` | Not a public design-doc layout. |

---

## 5. Android applicationId

### 5.1 Why `info.rich-list.wallet` will not build

You suggested `info.rich-list.wallet`. Android `applicationId` and Java/Kotlin package names must be reverse-DNS with **no hyphens**.

Each segment must match `[a-zA-Z][a-zA-Z0-9_]*`. `rich-list` is illegal.

**Chosen id:** `info.richlist.wallet`

Also used as:

- Gradle `namespace`
- Kotlin package directory: `android/app/src/main/kotlin/info/richlist/wallet/MainActivity.kt`

If you prefer a longer id (`info.richlist.xrplwallet`, `info.richlist.xrpl.wallet`), change it **before** PR 5. After devices install `info.richlist.wallet`, changing it again is another data-loss event.

### 5.2 This is a new app on the phone

Android Keystore and the app’s SQLite are bound to `applicationId`.

| Old | New |
|-----|-----|
| `com.jim.xrpl.xrpl_mobile_wallet` | `info.richlist.wallet` |

The new APK does **not** upgrade the old install. Both can sit on the device until you uninstall the old one.

**Cutover (already supported by encrypted export):**

1. In the **old** app: Settings → encrypted JSON export. Confirm you can open the file.
2. Install the **new** APK (`info.richlist.wallet`).
3. Set wallet PIN → import the export.
4. Check balances, a testnet send if you use testnet, watcher notifications.
5. Only then uninstall the old app.

Do not combine this cutover with a large Dart rename in the same PR.

---

## 6. Target layout

Keep the **four layers**. Rename folders so they match function. `test/` mirrors `lib/`.

```
lib/
  main.dart                         # Flutter entry; token catalog + watcher init
  app.dart                          # ProviderScope, lock gate, auto-lock
  config/                           # was lib/core/ (split constants)
    app_config.dart                 # pin min length, auto-lock seconds, notification ids
    network_id.dart                 # mainnet | testnet
    storage_keys.dart               # prefs / secure-storage *names* (never secret values)
    theme.dart
    app_exit.dart
  domain/                           # pure Dart; no I/O, no plugins
    amount/
      xrp_amount.dart               # drops ↔ XRP (was AmountFormat)
      fiat_format.dart
    wallet/
      wallet_account.dart
      wallet_color.dart
    validation/
      address_validator.dart
      secret_validator.dart
      mnemonic_grid.dart
      qr_address_parser.dart
    tokens/
      currency_display.dart
      token_registry.dart
    network/
      connection_health.dart
    oracle/
      xrp_usd_oracle.dart
  data/                             # I/O adapters
    database/                       # was data/db
      app_database.dart
      app_database.g.dart           # generated; never hand-edit
      tables.dart
    secure/                         # KeyVault, PinService, ScreenSecurity
    xrpl_rpc/                       # HTTP JSON-RPC (was data/ledger)
    ledger_device/                  # USB Ledger XRP app (was data/ledger_hw)
    endpoints/                      # public catalog + prefs + custom nodes
    watcher/                        # address-only; MUST NOT import data/secure/
    wallet/                         # generate, import, export, entropy
    payments/                       # was data/tx
    price/
    game/
  state/                            # Riverpod controllers; one concern per file
  ui/
    shell/
    wallets/
      list/
      detail/
      create/
      import/
      receive/
      attach_keys/
    send/
    activity/
    settings/
    lock/
      pin/
      runner/                       # Cicada 3301 game UI
    network/
```

Flutter entrypoints stay `lib/main.dart` and `lib/app.dart` (SDK convention). Imports stay `package:xrpl_mobile_wallet/...`.

**Watcher rule (unchanged, restated for the new tree):** anything under `lib/data/watcher/` may read public addresses and endpoint URLs only. A CI grep or a comment at the top of `watcher_service.dart` should keep forbidding `key_vault.dart` / `pin_service.dart` imports.

---

## 7. Rename map

### 7.1 Types and files

| Current path / type | Proposed | Why |
|---------------------|----------|-----|
| `lib/core/constants.dart` `AppConstants` | Split: `config/app_config.dart`, `config/storage_keys.dart`, `config/network_id.dart` | One concern per file; no secrets in “constants” |
| `lib/core/theme.dart` | `lib/config/theme.dart` | Config cluster |
| `lib/core/app_exit.dart` | `lib/config/app_exit.dart` | Same |
| `lib/data/ledger/ledger_client.dart` `LedgerClient` | `lib/data/xrpl_rpc/xrpl_rpc_client.dart` `XrplRpcClient` | Not hardware |
| `lib/data/ledger/rpc_http_service.dart` | `lib/data/xrpl_rpc/rpc_http_client.dart` | Matches folder |
| `lib/data/ledger/amount_format.dart` `AmountFormat` | `lib/domain/amount/xrp_amount.dart` `XrpAmount` | Pure math |
| `lib/domain/ledger/fiat_format.dart` `FiatFormat` | `lib/domain/amount/fiat_format.dart` | Not “ledger” |
| `lib/data/ledger_hw/xrp_ledger_apdu.dart` `XrpLedgerHardware` | `lib/data/ledger_device/ledger_xrp_device.dart` `LedgerXrpDevice` | USB device |
| `LedgerHwException` | `LedgerDeviceException` | Same |
| `lib/data/tx/payment_service.dart` `PaymentService` | `lib/data/payments/payment_service.dart` (keep type name) | Folder matches feature |
| `PaymentValidators` | keep (already descriptive) | — |
| `lib/data/watcher/watcher_bridge.dart` `WatcherBridge` | `lib/data/watcher/account_watcher.dart` `AccountWatcher` | UI-isolate FGS client |
| `lib/data/db/` | `lib/data/database/` | Readable |
| `lib/data/network/endpoint_preferences.dart` | `lib/data/endpoints/endpoint_preferences.dart` | Cluster with custom nodes |
| `lib/domain/models/wallet_account.dart` | `lib/domain/wallet/wallet_account.dart` | Feature folder |
| `lib/domain/wallets/wallet_color.dart` | `lib/domain/wallet/wallet_color.dart` | Singular `wallet/` |
| `lib/ui/lock/robot_runner_game.dart` `RobotRunnerGameScreen` | `lib/ui/lock/runner/cicada_runner_screen.dart` `CicadaRunnerScreen` | Matches game title |
| `lib/data/game/runner_scoreboard.dart` | keep `lib/data/game/` | Local top-5; no network |
| `lib/state/providers.dart` | Split next to owners, or `lib/state/app_providers.dart` | No grab-bag |
| `lib/ui/wallets/*.dart` | Subfolders in [§6](#6-target-layout) | Hierarchy = user features |

### 7.2 UI screen files (PR 8)

| Current | Proposed |
|---------|----------|
| `ui/wallets/wallet_list_screen.dart` | `ui/wallets/list/wallet_list_screen.dart` |
| `ui/wallets/wallet_detail_screen.dart` | `ui/wallets/detail/wallet_detail_screen.dart` |
| `ui/wallets/create_wallet_screen.dart` | `ui/wallets/create/create_wallet_screen.dart` |
| `ui/wallets/dice_entropy_pad.dart` | `ui/wallets/create/dice_entropy_pad.dart` |
| `ui/wallets/import_screen.dart` | `ui/wallets/import/import_screen.dart` |
| `ui/wallets/bip39_word_field.dart` | `ui/wallets/import/bip39_word_field.dart` |
| `ui/wallets/qr_scan_screen.dart` | `ui/wallets/import/qr_scan_screen.dart` |
| `ui/wallets/receive_screen.dart` | `ui/wallets/receive/receive_screen.dart` |
| `ui/wallets/attach_keys_chooser_screen.dart` | `ui/wallets/attach_keys/attach_keys_chooser_screen.dart` |
| `ui/wallets/attach_keys_entry_screen.dart` | `ui/wallets/attach_keys/attach_keys_entry_screen.dart` |
| `ui/lock/unlock_screen.dart` | `ui/lock/pin/unlock_screen.dart` |
| `ui/lock/setup_pin_screen.dart` | `ui/lock/pin/setup_pin_screen.dart` |

### 7.3 Tests (move with the code)

| Current | Proposed |
|---------|----------|
| `test/data/amount_format_test.dart` | `test/domain/amount/xrp_amount_test.dart` |
| `test/domain/fiat_format_test.dart` | `test/domain/amount/fiat_format_test.dart` |
| `test/data/ledger_account_tx_test.dart` | `test/data/xrpl_rpc/...` |
| `test/data/xrp_ledger_apdu_test.dart` | `test/data/ledger_device/...` |
| `test/data/endpoint_preferences_test.dart` | `test/data/endpoints/...` |
| `test/core/network_endpoints_test.dart` | `test/config/network_id_test.dart` |
| Other `test/data/*`, `test/domain/*` | Follow the new `lib/` path 1:1 |

### 7.4 Do **not** rename (crypto / already clear)

These names already say what they do. Renaming them risks missing a call site in signing or import:

- `WalletImporter.importMnemonic` / `deriveMnemonic` / `deriveFamilySeed` / `derive*ForAddress`
- `WalletGenerator`
- `EntropyMixer`
- `PaymentService.privateKeyFromSecret`
- `KeyVault.saveSecret` / `readSecret` / `deleteSecret`
- `PinService` wallet vs game PIN methods
- `ScreenSecurity.enable` / `disable`

If a later PR wants `XrpAmount.dropsToXrp` instead of `AmountFormat.dropsToXrp`, do it in the same PR as the file move and update every test in that PR.

---

## 8. Public repo surface

Typical Flutter + GitHub layout to add:

| File | Purpose |
|------|---------|
| `LICENSE` | MIT; copyright name/year |
| `README.md` | Product name, features, coffee link, build (`flutter` on `PATH`, no `/home/jim`), security summary, custom nodes, **package-id cutover** |
| `.github/FUNDING.yml` | `buy_me_a_coffee:` and/or `custom: ['https://...']` |
| `CONTRIBUTING.md` | `flutter analyze`, `flutter test`, Drift `build_runner`, secrets boundary, secp mnemonic rule |
| `SECURITY.md` | GitHub private vulnerability reporting; never paste a seed/PIN in an issue |
| `CODE_OF_CONDUCT.md` | Contributor Covenant |
| `CHANGELOG.md` | Keep a Changelog; starts at the first public tag |
| `.github/workflows/ci.yml` | `flutter pub get`, `analyze`, `test` on pull_request and main |
| `.github/ISSUE_TEMPLATE/` | Bug / feature templates; bug template warns “no secrets” |
| `.github/pull_request_template.md` | Checklist: tests, no secrets, derivation goldens if crypto touched |
| `NOTICE` | Vendored `packages/ledger_usb_plus` is MIT (VESPR Wallet); XRPSCAN token snapshot attribution |

Move / trim:

| Current | Action |
|---------|--------|
| `docs/superpowers/specs/*.md` | → `docs/design/` (keep content; fix internal links) |
| `docs/superpowers/plans/` | → `docs/history/` or delete once this file exists |
| `todo.md` | Do not publish (personal paths; mnemonic bug already fixed) |
| `AGENTS.md` | Keep (useful for humans and agents). Strip `/home/jim` SDK paths; keep security/crypto tables |

`packages/ledger_usb_plus/` stays a **path dependency**. Do not edit pub-cache. Keep its upstream MIT header.

---

## 9. Endpoints (product change, not just rename)

### 9.1 Today

Hardcoded failover:

1. Personal rich-list (`rpc.rich-list.info` / `wss.rich-list.info?token=…`)
2. `xrplcluster.com`
3. `mainnet.xrpl-rpc.com` (Ankr)

WSS token lives in `AppConstants.richListWssToken`.

### 9.2 Target

**Built-in public catalog** (default order):

| id | HTTP | WSS |
|----|------|-----|
| `cluster` | `https://xrplcluster.com/` | `wss://xrplcluster.com` |
| `ankr` | `https://mainnet.xrpl-rpc.com/` | `wss://mainnet.xrpl-rpc.com` |

Testnet stays Ripple altnet HTTP/WSS and is **not** user-editable.

**Custom nodes** (Settings):

- Add / edit / remove / reorder
- Fields: label, kind (`http` or `wss`), URL
- Validate scheme: `https://` for HTTP, `wss://` for WSS; reject `http://` and `ws://`
- Persist JSON in SharedPreferences (not secure storage: these are public server URLs; if a user pastes a token query param, it is their choice and stays on-device)
- Failover list = enabled built-in ∪ custom, in user order
- Empty built-in selection falls back to the **full built-in catalog**, not to custom-only (avoids locking yourself out with a typo). Custom URLs still participate when present.

**Your personal node is not in git.** After PR 3 you add locally:

- `https://rpc.rich-list.info/`
- `wss://wss.rich-list.info:443/?token=…`

Status UI continues to show **host only** (never the query string).

**Delete** `AppConstants.richListWssToken` and every test that expects it (`test/core/network_endpoints_test.dart`, `test/data/endpoint_preferences_test.dart`).

PR 2 (strip token) and PR 3 (custom nodes) should land close together so your phone is not stuck on public cluster longer than needed.

---

## 10. Branding chrome

| Surface | After |
|---------|--------|
| `MaterialApp.title` | `XRPL Mobile Wallet` |
| `android:label` | `XRPL Mobile Wallet` |
| Biometric prompt (`localizedReason`) | `Unlock XRPL Mobile Wallet` (or “Unlock wallet”) |
| Settings / README | XRPL Mobile Wallet |
| Unlock runner title screen | May stay **Cicada 3301** |
| Game PIN copy | “Opens Cicada 3301 instead of the wallet” is still accurate if the game keeps that title |

Do not search-replace “Cicada” inside the runner’s own UI if you are keeping the game name.

---

## 11. PR sequence

Each PR: `flutter analyze` + `flutter test` green. If the PR touches import/sign/derivation, golden address tests must still pass.

### PR 1 — OSS scaffolding (no behavior change)

**Intent:** Legal and social files so the repo can be public tomorrow even if code still has the old tree.

**Add:** `LICENSE`, rewrite `README.md` (neutral name, coffee placeholder, `flutter` on PATH), `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CHANGELOG.md`, `NOTICE`, `.github/FUNDING.yml`, `.github/workflows/ci.yml`, issue/PR templates.

**Do not:** change endpoints, package id, or Dart folders.

**Checklist**

- [ ] MIT text complete; copyright name confirmed
- [ ] README has coffee placeholder and no `/home/jim`
- [ ] CI runs analyze + test
- [ ] SECURITY.md says never paste seeds/PINs

### PR 2 — Strip secrets and personal defaults

**Intent:** Public clone has no node token.

**Touch:** `lib/core/constants.dart`, `lib/data/network/endpoint_preferences.dart`, endpoint tests, README watcher section.

**Behavior:** Default failover is cluster → Ankr only.

**Checklist**

- [ ] `git grep richListWssToken` empty
- [ ] `git grep rich-list` only in docs (“add your own”) and this plan
- [ ] Tests updated for two-entry catalog

### PR 3 — Custom nodes

**Intent:** You can add rich-list back on-device; any user can add a private node.

**Touch:** `EndpointPreferences` (or new `data/endpoints/`), Settings network UI, `LedgerClient.connect` / watcher WSS list builders, tests for URL validation and host-only display.

**Checklist**

- [ ] Custom HTTPS/WSS add/edit/remove/reorder
- [ ] Reject `http://` / `ws://`
- [ ] Token in WSS query not shown in status chip
- [ ] Manual: add rich-list HTTP + WSS, confirm failover

### PR 4 — Docs + branding chrome

**Intent:** Public name and public docs paths.

**Touch:** `lib/app.dart`, `AndroidManifest.xml` label, lock biometric string, Settings copy, `docs/superpowers/` → `docs/design/`, `AGENTS.md` without machine paths.

**Checklist**

- [ ] App title XRPL Mobile Wallet
- [ ] Design specs still linked from AGENTS.md / README
- [ ] Game title decision applied consistently

### PR 5 — `applicationId` `info.richlist.wallet`

**Intent:** Public Android identity. **Data-loss for the old id.** Do this when you have a fresh encrypted export.

**Touch:** `android/app/build.gradle.kts`, Kotlin `MainActivity` package + path, any `namespace` references, README cutover section, CHANGELOG warning.

**Checklist**

- [ ] Export from old app verified
- [ ] New APK installs alongside old (different id)
- [ ] Import restores wallets; send still works
- [ ] FLAG_SECURE channel still hooked
- [ ] USB Ledger permission / `usb_device_filter.xml` still works

### PR 6 — Rename RPC vs hardware Ledger

**Intent:** Kill the `data/ledger` vs `data/ledger_hw` confusion.

**Touch:** files in [§7.1](#71-types-and-files) for `XrplRpcClient`, `XrpAmount`, `LedgerXrpDevice`; all imports; matching tests.

**Checklist**

- [ ] No remaining `LedgerClient` type
- [ ] `AmountFormat` either gone or type-alias deprecated for one PR then removed
- [ ] `flutter test` including goldens

### PR 7 — Config, watcher, payments, database folders

**Intent:** Split `constants.dart`; `WatcherBridge` → `AccountWatcher`; `data/tx` → `data/payments`; `data/db` → `data/database`.

**Checklist**

- [ ] Watcher files still import no `data/secure/`
- [ ] Prefs key *strings* unchanged (or migrated) so existing installs keep PIN/network prefs **on the new applicationId** (this PR should run *after* PR 5, or prefs keys must stay identical)

### PR 8 — UI feature folders

**Intent:** `ui/wallets/` and `ui/lock/` match user-facing features ([§7.2](#72-ui-screen-files-pr-8)).

**Checklist**

- [ ] Widget tests / smoke `test/widget_test.dart` updated
- [ ] No leftover files in old flat folders

### PR 9 — Settings split (optional)

**Intent:** `settings_screen.dart` is a god file. Extract Security, Network (built-in + custom), Backup/export widgets. No logic change.

---

## 12. Risks

| Risk | Mitigation |
|------|------------|
| Package id change drops Keystore + SQLite | PR 5 isolated; README cutover; encrypted export already exists |
| Token removed before custom nodes | Land PR 2 and PR 3 adjacent |
| Hyphenated id `info.rich-list.wallet` | Will not compile; use `info.richlist.wallet` |
| Import path churn misses a signing call | PR 6/7 mechanical + full `flutter test`; do not rename `privateKeyFromSecret` |
| Watcher accidentally imports KeyVault after moves | Explicit rule + review grep in PR 7 |
| `ledger_usb_plus` license forgotten | `NOTICE` in PR 1 |

---

## 13. Success criteria

- A public clone: `flutter pub get && flutter analyze && flutter test` with Flutter on `PATH` (no personal prefixes).
- No node access token in git. `git grep` for the current token string is empty.
- A new contributor can find **send**, **account watcher**, **KeyVault**, and **USB Ledger** by folder name without reading AGENTS.md first.
- Your sideload: export old app → install `info.richlist.wallet` → import → balances and send work.
- MIT `LICENSE` + coffee link in README; CI green on the default branch.

---

## 14. Out of scope unless asked later

- Play Store listing, proper release signing, iOS polish
- DEX, NFTs, multi-sig
- Publishing `ledger_usb_plus` to pub.dev (keep path dep)
- Automatic on-device migration between `applicationId`s (Android cannot do this; export/import is the path)
- Replacing the Cicada runner with a differently named game

---

## 15. How to use this document

1. Treat PRs 1–9 as the backlog. Do not skip the secrets strip (PR 2) if the repo will be public.
2. Fill in: copyright name, Buy Me a Coffee (or similar) URL, optional applicationId tweak **before PR 5**.
3. After the tree matches [§6](#6-target-layout), update `AGENTS.md` layout section to the new paths and keep this file under `docs/history/` or leave it at the repo root until the last PR lands.

Implemented in this repo as sequential commits on `master` (source copied from `/home/jim/xrpl-mobile-wallet`).
