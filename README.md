# XRPL Mobile Wallet

Android-first, local-first wallet for the XRP Ledger. Secrets stay on the
device (Android Keystore). The background watcher process never holds keys.

If this project is useful, send a little XRP from **Settings → coffee mug**
to `rJTyAxvqh9UcigEfK2CTAd3ipUEvchDNzr`.

## User guide

A step-by-step HTML guide for new users (with screenshot slots) lives at
[docs/user-guide/index.html](docs/user-guide/index.html). Open it in a browser.

## Features

- Create a BIP39 24-word wallet (OS CSPRNG plus optional dice / personal-word mix-in)
- Import mnemonic, family seed, or watch-only address (QR for watch-only)
- Attach keys to a watch-only wallet in place when the secret matches that address
- XRP + IOU balances and history, with a portfolio XRP total
- Trust-line token names from a bundled [XRPSCAN tokens](https://xrpscan.com/tokens) snapshot
- Send XRP and held IOUs with a review step (software keys or USB Ledger)
- PIN lock, optional biometrics, optional game PIN
- Background account watcher with local notifications
- Encrypted JSON export/import of the public wallet list (names + addresses)

## Build / run

Install [Flutter](https://docs.flutter.dev/get-started/install) and keep
`flutter` on your `PATH`. No machine-specific SDK prefixes.

```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --release
```

APK path: `build/app/outputs/flutter-apk/app-release.apk`

Play Store bundle:

```bash
flutter build appbundle --release
```

AAB path: `build/app/outputs/bundle/release/app-release.aab`

Release signing uses `android/key.properties` (gitignored) and the upload
keystore. Without that file, release falls back to the debug key for personal
sideload. GitHub APKs were debug-signed; a Play install cannot upgrade those
in place (different cert, same `applicationId`).

## Security

- PIN required; secrets in Android Keystore via `flutter_secure_storage`
- Optional **Game PIN** (Settings → Security): a second PIN that opens the
  unlock-screen runner instead of the wallet (the wallet stays locked)
- Watcher process never holds keys
- Create wallet: dice + personal-word ritual mixed with **OS CSPRNG**
  (`Random.secure`) via domain-separated SHA-256 → BIP39 24-word
- Attach keys: derived address must equal the watch wallet; mismatch is
  rejected with no KeyVault write
- Never paste a seed, PIN, or node token into a GitHub issue — see
  [SECURITY.md](SECURITY.md)

## Watcher

Disable battery optimization for reliable background alerts on some OEMs.

Mainnet HTTP JSON-RPC and watcher WSS endpoints are chosen in
**Settings → Network**. Built-in public catalog (default order):

| id | HTTP | WSS |
|----|------|-----|
| `cluster` | `https://xrplcluster.com/` | `wss://xrplcluster.com` |
| `ankr` | `https://mainnet.xrpl-rpc.com/` | `wss://mainnet.xrpl-rpc.com` |

Add your own HTTPS / WSS node in Settings (for example a private RPC). Do not
commit node access tokens. Status UI shows **host only**, never a query string.

## Token names

Display names for issued currencies come from
`assets/tokens/xrpscan_tokens.json`, with hex→ASCII decode as offline fallback.
Regenerate with:

```bash
python3 tool/fetch_xrpscan_tokens.py
```

See [NOTICE](NOTICE) for XRPSCAN attribution.

## Android package id cutover

The public Android `applicationId` is `info.richlist.wallet`. That is a **new
app** on the phone relative to older personal ids. Keystore and SQLite do not
migrate automatically.

1. In the old app: Settings → encrypted JSON export. Confirm you can open the file.
2. Install the new APK.
3. Set wallet PIN → import the export.
4. Check balances, a testnet send if you use testnet, watcher notifications.
5. Only then uninstall the old app.

## Design docs

- [Wallet design](docs/design/2026-07-20-xrpl-mobile-wallet-design.md)
- [Attach keys](docs/design/2026-08-02-attach-keys-watch-wallet-design.md)
- [Game PIN](docs/design/2026-08-03-game-pin-design.md)

## License

[MIT](LICENSE). Vendored USB Ledger plugin and token snapshot credits are in
[NOTICE](NOTICE).
