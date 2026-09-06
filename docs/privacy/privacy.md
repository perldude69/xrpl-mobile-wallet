# Privacy — XRPL Mobile Wallet (Zerpland)

**Applies to:** XRPL Mobile Wallet v1.0.1+ (Android, package `info.richlist.wallet`)
**Last updated:** 2026-09-05
**Summary:** The wallet is **local-first**. It has **no accounts, no servers,
no analytics, no ads, and no tracking**. Your secrets never leave the device
except as signed transactions. Public XRP Ledger data (your addresses) is sent
to the XRPL nodes you choose, over TLS, because that is how the ledger works.

---

## 1. What the app collects

**Nothing is collected by the developer.** The app has no backend, no crash
reporter, no analytics SDK, no advertising SDK, and no device identifiers.
There is no remote endpoint under the developer's control that receives data
from the app. (The optional "buy the developer a coffee" action in Settings is
a normal on-ledger XRP payment that **you** initiate and sign — it sends XRP
to a fixed public address and nothing else.)

## 2. Data stored on the device

All data lives in the app's private storage (`/data/user/0/info.richlist.wallet/`).

| Data | Where | Encrypted? | Contents |
|------|-------|------------|----------|
| Wallet secrets (mnemonic / family seed) | `flutter_secure_storage` → Android Keystore | Keystore-backed | One entry per signing wallet (`wallet_secret_<id>`). Never written to SQLite, prefs, files, or logs. |
| Wallet PIN verifier | `flutter_secure_storage` | Keystore-backed | PBKDF2-SHA256 hash + random salt (`app_pin_hash`, `app_pin_salt`) — never the PIN itself. |
| Game PIN verifier (optional decoy) | `flutter_secure_storage` | Keystore-backed | Same scheme (`game_pin_hash`, `game_pin_salt`). |
| Wallet metadata | SQLite (Drift) | No (public data) | Wallet label, public `r…` address, accent color, watch-only flag, Ledger flag + account index. |
| Watcher address book | App file `watcher_address_book.json` | No (public data) | Public addresses + network only. Written for the background watcher isolate; **no secrets ever enter the watcher**. |
| Watcher status / seen tx hashes / last XRP-USD rate | SharedPreferences | No (public data) | Connection phase, endpoint host, recent tx hashes (dedupe), last cached XRP/USD rate. |
| Export files | Only where you save them | Password-encrypted | Wallet **names + addresses only**; AES-256-GCM + PBKDF2 (120k iterations). Never contains seeds or private keys. Temporary export files are deleted after share. |
| Token label catalog | Bundled APK asset | n/a | Offline XRPSCAN snapshot for token display names. Not user data. |
| Zerpland runner scores | SharedPreferences | No | Local top-5 game scores only. Not synced anywhere. |

Backups of the app's data are **disabled** (`android:allowBackup="false"`).
Removing the app deletes all of the above. **There is no cloud copy — if you
uninstall without your recovery phrase, the wallet is unrecoverable.**

## 3. Data that leaves the device

The app talks only to **XRP Ledger nodes** (yours or public ones you pick):

| What | Where | When | Protection |
|------|-------|------|------------|
| Your public addresses (subscribe to account activity) | XRPL WSS nodes | While the background watcher is enabled | TLS (`wss://`); ws:// rejected |
| Address / account_info / fee / account_lines queries; signed transactions | XRPL HTTPS JSON-RPC nodes | When you view balances or send | TLS (`https://`); http:// rejected |
| Signed payment blobs | The same nodes | On send / RLUSD trust-line opt-in | HTTPS; the unsigned transaction and your key never leave the device |
| XRP/USD rate | Public oracle account `rXUMMaPpZqPutoRszR29jtC8amWq3APkx` via the subscribed WSS stream | Passive (mainnet watcher only) | TLS |

Default mainnet endpoints (you can enable/disable per endpoint or add your own
in Settings → Endpoint settings): `xrplcluster.com`, `mainnet.xrpl-rpc.com`
(Ankr). Testnet is fixed to Ripple altnet nodes. **Choosing a third-party node
means that operator sees the queries you send it** — this is inherent to
ledger access; the wallet sends it nothing beyond what XRPL clients normally
send (public addresses, tx blobs, standard RPC parameters). Custom endpoints
must be https/wss.

Note: like any blockchain, **transactions and balances are public on the
XRPL**. Anything you do on-ledger is linkable to your address by anyone.
The wallet cannot change that; it only avoids adding identifying metadata
(no UTM-like tags, no app fingerprint fields in transactions).

## 4. Android permissions and why

| Permission | Why |
|------------|-----|
| `INTERNET`, `ACCESS_NETWORK_STATE` | Talk to XRPL nodes; connection-status chip. |
| `CAMERA` | Scan XRPL address QR codes (import / send). Only used on the scan screen; no photos are saved. |
| `POST_NOTIFICATIONS` | Optional watcher alerts (received/sent activity) and watcher status. You can deny; the wallet still works. |
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_DATA_SYNC`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED` | The background watcher foreground service (address-only) and restart on reboot. |
| `USE_BIOMETRIC` | Optional fingerprint unlock. Biometric data is handled by Android; the app never sees or stores it. |
| USB host (`USB_DEVICE_ATTACHED`) | Ledger device support. Access is granted per-device by a system dialog; no location or storage permission is used. |

**Not requested:** location, contacts, microphone, storage/media, phone,
SMS, advertising ID.

## 5. Screenshots / recents

Secret surfaces (PIN setup, unlock, recovery phrase, entropy ritual, import)
set Android's `FLAG_SECURE`, so the app is excluded from screenshots and the
recents-app preview on those screens.

## 6. Third-party software

Dependencies are open-source pub.dev/Flutter plugins (list in `pubspec.yaml`):
XRPL/crypto (`xrpl_dart`, `blockchain_utils`, `cryptography`, `crypto`),
storage (Drift/SQLite, flutter_secure_storage, shared_preferences),
UI/util (Riverpod, qr_flutter, mobile_scanner, share_plus, file_selector,
intl), services (flutter_background_service, flutter_local_notifications,
local_auth), and the vendored `ledger_usb_plus` plugin (patched copy in this
repository). None of them ship telemetry to their vendors through this app.
The Drift generated code and the Flutter engine are the only compiled
third-party code besides AndroidX.

## 7. Notifications & lock-screen exposure

Watcher notifications contain the wallet label, transaction type, amount, and
direction. Android may display these on the lock screen according to **your**
system notification settings. If you prefer not to expose amounts there,
disable lock-screen notifications for the app in Android settings, or disable
the watcher.

## 8. Your controls

- **Wipe everything:** Settings → Security → wipe (requires wallet PIN)
  deletes secrets, PIN verifiers, metadata, watcher book, and scores.
- **Export (public data only):** password-encrypted JSON with names +
  addresses; secrets are never exported by the app.
- **Endpoint choice:** enable/disable built-ins, add your own node — including
  one you run yourself.
- **Watcher on/off:** background watcher can be disabled entirely in Settings.
- **Uninstall:** removes all app data (no server-side copies exist).

## 9. Contact

This is a personal, sideloaded project (not a Play Store product). Questions:
see `SECURITY.md` and `README.md` in the repository root.
