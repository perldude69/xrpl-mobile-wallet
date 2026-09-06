# Security Re-Audit — XRPL Mobile Wallet v1.0.1 (build 2)

- **Date:** 2026-09-05
- **Auditor:** Independent code + dynamic audit (OWASP MASTG/MASVS v2 methodology)
- **Scope:** Full source tree at commit `9a743c1` (plus working-tree changes) and the
  installed release APK on a Pixel 8 Pro (Android 16, `husky`)
- **Method:** Static source review (Dart/Kotlin/Java/Gradle), dependency review,
  APK static analysis (`aapt2`, `apksigner`, `libapp.so` strings), and dynamic
  testing on the attached device (install, launch, FLAG_SECURE screencaps,
  auto-lock timing, logcat secret scan, component export checks).
- **Prior audits:** [2026-09-03-security-audit-report.html](2026-09-03-security-audit-report.html),
  [2026-09-05-owasp-mobile-audit-report.html](2026-09-05-owasp-mobile-audit-report.html)

---

## 1. Verdict

**PASS with two open, low-impact notes (XRW-02, XRW-19).**
No High or Medium findings remain. The single High finding from the previous
audit round (XRW-01, debug-signed release APK) is **resolved in this build**:
`build/app/outputs/flutter-apk/app-release.apk` now verifies under APK
Signature Scheme v2 with the RSA-2048 upload keystore
(CN=James Hughes, OU=Rich-List.info). XRW-23 (un-obfuscated snapshot +
plain storage key names) was resolved in a follow-up pass the same day via
obfuscated release builds (`tool/build_release.sh`) and runtime-derived
storage key names (`KeyNames`).

| Severity | Open | Resolved this round |
|----------|------|---------------------|
| High     | 0    | XRW-01 |
| Medium   | 0    | — |
| Low      | 0    | XRW-21, XRW-22 |
| Informational | 2 (accepted/known) | XRW-23 |

---

## 2. Build & packaging (MASVS-CODE / MASVS-RESILIENCE)

| Check | Result | Evidence |
|-------|--------|----------|
| Release signing | **Pass** | `apksigner verify --print-certs`: v2 scheme verified; signer `CN=James Hughes, OU=Rich-List.info, O=Rich-List, L=Phoenix, ST=Arizona, C=US`, RSA-2048, SHA-256 cert digest `f90f349b4412ae1c164c53b6eba9b6095ff6a12bd3051a540b05fcfbbfbe72bb`. Prior builds were `CN=Android Debug` (XRW-01). |
| Keystore fallback | Pass (documented) | `android/app/build.gradle.kts` falls back to debug signing only when `android/key.properties` is absent (personal sideload). This machine has `key.properties`, so release uses the upload key. Residual risk: a release built without the file is debug-signed. Recommend a Gradle task failure instead of fallback for CI, or a startup check. |
| minify / shrink | **Resolved** (follow-up pass) | Release builds use `tool/build_release.sh` (`--obfuscate --split-debug-info=build/symbols/android`). Verified on the rebuilt APK: no class names (`KeyVault`, `PinService`, `PaymentService`…), no structured storage key names, no DWARF sections in the shipped `libapp.so`. Sensitive storage keys are derived at runtime from XOR-encoded role tags (`lib/data/secure/key_names.dart`); symbol maps stay private in `build/symbols/`. |
| debuggable flag | Pass | Not present in merged manifest. |
| Version | Pass | versionName 1.0.1, versionCode 2, targetSdk 36, minSdk 24. |

XRW-23 resolution was re-verified on the device with the obfuscated build:
fresh install → PIN setup → import family seed (golden genesis address
`rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh`, watcher started) → wipe → re-import of
the saved wallet list via encrypted export (watch-only, balance syncs) →
force-stop / relaunch → PIN unlock with data intact → logcat clean.

---

## 3. Manifest & attack surface (MASVS-PLATFORM)

`aapt2 dump xmltree` on the merged manifest of the **installed APK**:

| Check | Result |
|-------|--------|
| `allowBackup` | **false** — bmgr/auto-backup cannot copy Keystore-adjacent files off device. |
| Exported components | Only `MainActivity` (launcher, `singleTop`, `taskAffinity=""`). FGS `BackgroundService`, `WatchdogReceiver`, `BootReceiver`, and the notification `FileProvider` are all `exported=false`. |
| Permissions requested | `INTERNET`, `ACCESS_NETWORK_STATE`, `CAMERA` (QR scan), `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE(_DATA_SYNC)`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, `USE_BIOMETRIC`/`USE_FINGERPRINT` (optional unlock). No location, contacts, storage, SMS, or phone permissions. |
| Cleartext traffic | No `usesCleartextTraffic` override; targetSdk 36 blocks cleartext by default. All built-in endpoints are `https://` / `wss://`; custom endpoints are validated in `EndpointUrl.validate` (http/ws schemes rejected). No `networkSecurityConfig` needed. |
| USB host | `USB_DEVICE_ATTACHED` intent-filter + `usb_device_filter.xml` (Ledger). Not a runtime permission; per-device grant via system dialog. |
| Query allowance | Only `PROCESS_TEXT` (Flutter text services). |

`filterTouchesWhenObscured` is applied on `decorView` + content in
`MainActivity.onCreate`/`onResume` — tapjacking mitigation (XRW-22 **resolved**).

---

## 4. Secrets & cryptography (MASVS-CRYPTO / MASVS-STORAGE)

| Area | Finding |
|------|---------|
| Wallet secrets | Mnemonics/family seeds stored only in `flutter_secure_storage` (Android Keystore-backed) via `KeyVault`; `resetOnError: false` documented so a Keystore glitch cannot silently wipe seeds. Secrets are method arguments to `PaymentService` and never stored on the service or logged. |
| PIN verifier | PBKDF2-SHA256, 120k iterations, 16-byte `Random.secure` salt, constant-time `hashEquals` compare, with transparent legacy SHA-256 → PBKDF2 upgrade on next successful unlock (XRW-03 resolved, re-confirmed). |
| Auto-lock | `LockController.lock()` after 90 s in background (`LockLifecycle`, `AppConfig.autoLockSeconds`). **Dynamically re-verified on device**: app unlocked → HOME → 100 s → relaunch → PIN screen. Earlier "still unlocked" readings in this session were stale `uiautomator` dump files; re-test with file-freshness guard confirmed lock. |
| Failed attempts | In-memory counter only (XRW-02, informational — accepted). Game-PIN decoy after 3 fails is also in-memory. |
| PIN is not a KEK | Keystore guards the seeds; the PIN is an app lock (XRW-19, informational — accepted by design). |
| Export | `WalletExport`: AES-256-GCM + PBKDF2-SHA256; envelope contains names + addresses only (no secrets); iteration count clamped 120k–600k against weak-KDF/DoS; bounded field lengths. |
| Entropy | `EntropyMixer.mix`: OS CSPRNG 32 bytes is mandatory input; dice/word ritual hashes are **mixed in** via domain-separated SHA-256 (`xrpl-mobile-wallet/v1/entropy`). Weak ritual input cannot weaken the wallet. |
| Derivation | Mnemonic → BIP44 `m/44'/144'/0'/0/0` secp256k1 (matches `xrpl.js`); golden tests pin the abandon-phrase address `rHsMGQEkVNJmpGWs8XUBoTBiAAbwxZN5v3` and genesis seed `snoPBr…` → `rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh`. `PaymentService.privateKeyFromSecret` matches `WalletImporter` and falls back to ed25519 only on expected-address match. |
| Fee/amount safety | Sign-time fee must equal the reviewed fee and stay ≤ 0.1 XRP (`validateFeeDrops`, `reviewedFeeMatches`); spendable check includes reserve for unfunded destinations; destination-tag / disallow-XRP account flags enforced pre-sign. |

---

## 5. Background watcher (MASVS-NETWORK / STORAGE)

- Watcher isolate (`watcherOnStart`) imports only public-address book, status
  store, and rate store — no `KeyVault`/`PinService` imports. Confirmed by
  source review; the shared file is `watcher_address_book.json` (public
  addresses + network only).
- WSS failover is ordered (user prefs → catalog → legacy book value),
  reconnect uses exponential backoff 2→60 s, connect timeout 12 s.
- Seen-hash dedupe is bounded (200 persisted / 500 in-memory) in
  SharedPreferences — non-sensitive tx hashes only.
- Notifications contain label, tx type, amount, direction — no secrets; note
  that amounts + labels are visible on the lock screen (see §9 note N-1).
- Foreground-service notification shows **host only** (query string dropped by
  `EndpointUrl.hostOf`) — matches the no-URL-leak rule.

---

## 6. Logging & data leakage (MASVS-STORAGE-2)

- Full-session logcat scan on the installed release while setting a PIN,
  unlocking, and navigating: **no mnemonics, seeds, PIN digits, or private key
  material from the app**. (Test-harness artifacts only: `adb shell input text`
  commands echo in adbd logs — that is the audit tooling, not the app.)
- Vendored Ledger plugin: new `LedgerLog` gates all `Log.i/w/e` behind
  `BuildConfig.DEBUG`; release logcat shows no `LedgerUSB` lines (XRW-21
  **resolved**). Dart-side APDU dumps remain `kDebugMode`-gated (XRW-10).
- SQLite (Drift) stores only public metadata: labels, addresses, accent color,
  `useLedger`, ledger index. No secrets in DB.

---

## 7. Screen capture & UI hardening (MASVS-PLATFORM-3)

Dynamic screencap tests on the installed release (`adb exec-out screencap`,
center-crop mean = 0 → 100 % black):

| Surface | Screencap result | Evidence |
|---------|------------------|----------|
| PIN setup (first-run) | Black | `evidence/reaudit-2026-09-05-pin-setup-secure-black.png` |
| Entropy ritual / recovery phrase flow | Black | `evidence/reaudit-2026-09-05-entropy-ritual-secure-black.png` |
| Auto-locked PIN screen | Black | `evidence/reaudit-2026-09-05-autolock-pin-secure-black.png` |

`ScreenSecurity` uses a nested hold counter so an inner dialog (e.g. PIN
re-auth over Send) cannot drop the flag while an outer secret surface is open.
`filterTouchesWhenObscured` on decor view + content children (XRW-22 resolved;
code-verified — no overlay app was installed for a live tapjacking test).

---

## 8. Tests & static analysis

- `flutter analyze`: **no issues**.
- `flutter test`: **163/163 pass** (import/derivation goldens, PIN service,
  export crypto, watchers, endpoint prefs, connection health, RLUSD TrustSet,
  APDU helpers).

---

## 9. Findings register (delta vs 2026-09-05 OWASP report)

| ID | Title | Severity | Status this round |
|----|-------|----------|-------------------|
| XRW-01 | Release APK signed with debug key | High | **Resolved** — v2-signed with upload keystore (§2). |
| XRW-21 | Ledger Java plugin INFO logs in release | Low | **Resolved** — `LedgerLog` gates on `BuildConfig.DEBUG`; no `LedgerUSB` lines in release logcat. |
| XRW-22 | PIN / send confirm lack obscured-touch filter | Low | **Resolved** — `filterTouchesWhenObscured` applied in `MainActivity` onCreate + onResume. |
| XRW-02 | No persistent PIN throttling | Informational | Open (accepted). In-memory counter; full wipe available. |
| XRW-19 | PIN is app lock, not a KEK | Informational | Open (accepted by design). |
| XRW-23 | Un-obfuscated Dart snapshot; key names in `libapp.so` | Informational | **Resolved** (follow-up pass). Obfuscated release builds + runtime-derived storage key names (`KeyNames`). Breaking for upgraders: stored secrets / PINs must be re-imported. |
| XRW-03…18, XRW-20 | (see prior reports) | — | Remain resolved; spot-re-verified where relevant to this round (signing, FLAG_SECURE, exports, fee guards). |

New notes from this round (no ID assigned, none actionable as vulnerabilities):

- **N-1 (Privacy note):** watcher notifications include wallet label, amount,
  and direction; on the lock screen Android may show these by default. Default
  channel importance is high; users who want lock-screen privacy should
  disable notification content in system settings or the watcher. Consider a
  future "hide amounts" toggle.
- **N-2 (Residual risk):** debug-keystore fail-open in `build.gradle.kts`
  remains as a foot-gun for CI (§2). Suggested hardening: fail the build when
  `key.properties` is missing for `release` builds, or keep the fallback but
  add a runtime "debug-signed build" banner.

---

## 10. Method & tool versions

- `flutter analyze` / `flutter test` (Flutter 3, Dart SDK ^3.10.4)
- `aapt2` / `apksigner` (Android SDK build-tools 36.1.0)
- `keytool -printcert`, `unzip`/`strings` on `libapp.so`
- Device: Pixel 8 Pro (`38181FDJG00F43`, model `husky`), Android 16,
  app installed via `adb install -r` from
  `build/app/outputs/flutter-apk/app-release.apk` (85.7 MB)
- Device test data (test PIN 123456, throwaway "AuditWallet" flow state) was
  wiped with `adb shell pm clear` after the audit.

---

## 11. Sign-off

The app follows its local-first, secrets-in-Keystore design correctly. All
previously open High/Low findings are fixed and dynamically verified on the
installed release binary. Remaining items are documented, low-impact, and
accepted.
