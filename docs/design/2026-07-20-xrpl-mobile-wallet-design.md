# XRPL Mobile Wallet Manager — Design

**Status:** Approved by user (2026-07-20)  
**Codename / path (suggested):** `~/xrpl-mobile-wallet`  
**Approach:** Pure Flutter + `xrpl_dart` + Android foreground service watcher

---

## 1. Summary

A **personal, sideloadable Android wallet manager** for the XRP Ledger that:

- Imports **signing** wallets (24-word BIP39 or classic family seed `s...`)
- Adds **watch-only** wallets (classic address `r...`)
- Shows **XRP + IOU** balances and history
- **Sends** XRP and held IOUs (sign on-device)
- Runs a **background watcher** that notifies on validated account activity
- Supports **Mainnet + Testnet**
- Ships as a **sideload APK** first; iOS later; no Play Store requirement for v1

**Non-goals (v1):** generate-new wallet, DEX, NFTs, hardware Ledger, cloud backup, multi-sig UX, remote push server, iOS release.

---

## 2. Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Platform | Flutter, Android-first | Cross-platform later; Flutter already installed |
| XRPL stack | `xrpl_dart` + `blockchain_utils` | Native Dart sign/RPC/WSS; no dual JS runtime |
| Architecture | Local-first + FGS watcher | Full control; mirrors desktop watcher without a backend |
| Secrets boundary | UI process only; watcher address-only | Limits blast radius if service is compromised |
| Distribution | Personal sideload | Fast iteration; fewer store constraints |
| Assets | XRP + IOUs held | Useful portfolio without DEX complexity |
| Networks | Mainnet + Testnet | Safe testing + real funds |
| Onboarding | Import only (no generate) | User already has keys; simpler security UX |
| Auth | Required PIN + optional biometrics | At-rest protection beyond phone lock |

**Rejected:** Flutter+JS bridge (heavier, harder to secure); pure poll-only watcher (worse UX than subscribe); generate-wallet in v1 (user preference).

---

## 3. System Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Flutter UI (Material 3)                                │
│  Wallets · Activity · Settings + Import/Send/Receive    │
└───────────────┬───────────────────────────┬─────────────┘
                │                           │
                ▼                           ▼
┌───────────────────────────┐   ┌───────────────────────────┐
│  Domain                   │   │  Watcher bridge           │
│  KeyVault · WalletRepo    │   │  address set · start/stop │
│  XrplRpcClient · TxService │   │  notification routing     │
└─────────────┬─────────────┘   └─────────────┬─────────────┘
              │                               │
              ▼                               ▼
┌───────────────────────────┐   ┌───────────────────────────┐
│  xrpl_dart                │   │  Android Foreground Svc   │
│  flutter_secure_storage   │   │  WSS subscribe (public)   │
│  SQLite (metadata)        │   │  local notifications      │
└─────────────┬─────────────┘   └─────────────┬─────────────┘
              └───────────────┬───────────────┘
                              ▼
                    XRPL Mainnet / Testnet WSS
```

| Process | Holds secrets? | Role |
|---------|----------------|------|
| Flutter UI | Yes | Import, display, sign, submit |
| Watcher FGS | **No** | Subscribe to addresses; local notify |

---

## 4. Data Model & Storage

### Account kinds

- **`signing`** — secret in Keystore; can send  
- **`watch_only`** — address only; no send  

### Entities

- **WalletAccount:** id, label, address, kind, preferredNetwork, importMethod (`mnemonic` | `family_seed` | `address_only`), createdAt, sortOrder  
- **SecretRecord:** walletId → mnemonic or family seed (**secure storage only**)  
- **CachedBalance:** walletId, currency, issuer?, value, updatedAt  
- **CachedTx:** hash, walletId, summary fields, date  
- **AppSettings:** active network, server URLs, PIN/biometrics flags, watcher enabled  

### Storage split

| Store | Data |
|-------|------|
| `flutter_secure_storage` | Secrets, PIN verifier |
| SQLite | Accounts, caches, non-secret settings |
| Prefs | Theme, last selected wallet id |

### Import rules

- BIP39 12 or 24 words (emphasize 24)  
- Family seed `s...`  
- Watch-only classic `r...` with checksum  
- Reject duplicate address  

### Network UX

- Global active network (Mainnet / Testnet)  
- Per-account preferred network + badge  
- Warning before send if active ≠ preferred  
- Watcher follows **active network only** (v1)

---

## 5. Screens & Flows

**Tabs:** Wallets | Activity | Settings  

**Flows:**

1. First launch → set PIN → optional biometrics → empty CTAs (Import / Watch)  
2. Import secret → validate → label → save → balances + watcher update  
3. Watch address → label → save  
4. Detail → balances (XRP + IOUs), Receive QR, Send (signing only), history  
5. Send → unlock → asset → destination (+ tag) → amount → **review** → sign/submit  
6. Activity → cross-wallet feed; notification taps deep-link here  
7. Settings → network, watcher, security, wipe all  

**No** create/generate wallet in v1. Never re-show seed after import.

---

## 6. Security

- PIN required (min 6); salted verifier; auto-lock on resume/timeout  
- Biometrics optional unlock only  
- Secrets: Keystore-backed; clear text controllers after import; ephemeral load for sign  
- `FLAG_SECURE` on import screens  
- Watcher never receives secrets  
- No cloud seed backup; no secret logging  
- Permissions: Internet, notifications, FGS, biometrics — nothing else  

---

## 7. Watcher & Notifications

- Sticky FGS: “XRPL Watcher: N accounts · network · connected/reconnecting”  
- Subscribe `accounts: [...]` on active network WSS  
- Notify on validated txs; dedupe by hash  
- Body from public ledger data (e.g. received amount)  
- Toggle in Settings; best-effort under OEM battery limits  
- **No** Firebase; local notifications only  

Parity target: desktop `~/mon/xrpl-watcher` behavior, mobile-shaped.

---

## 8. Packages (planned)

- `xrpl_dart`, `blockchain_utils`  
- `flutter_secure_storage`, `local_auth`  
- `drift` or `sqflite`  
- `flutter_local_notifications` + Android FGS plugin/pattern  
- State management: Riverpod or Bloc (choose at scaffold)  
- QR: `qr_flutter`  

Reuse **concepts** from `~/codebaseOne` (import, multi-wallet, network), not the Electron runtime.

---

## 9. PR Plan

| PR | Title | Delivers | Depends |
|----|-------|----------|---------|
| 1 | Scaffold & shell | Flutter app, theme, bottom nav, deps, network URLs | — |
| 2 | Storage & app lock | Secure storage, SQLite, PIN/biometrics, wipe | 1 |
| 3 | Ledger read client | Connect, balances, lines, tx history cache | 1–2 |
| 4 | Import & wallet list | Mnemonic/seed/watch import, detail, receive QR | 2–3 |
| 5 | Send payment | XRP + IOU Payment, review, submit | 4 |
| 6 | Activity feed | Cross-wallet history UI | 3–4 |
| 7 | Watcher FGS | Subscribe, notifications, settings toggle | 4 (parallel OK with 5–6) |
| 8 | Hardening & APK | Redaction, empty states, release signing, README | 5–7 |

**First useful path:** 1 → 2 → 3 → 4 → 5, then 6–8.

### Testing

- Unit: validation, formatting, dedupe  
- Integration: Testnet only  
- Manual: import testnet account, send, background notification  
- No mainnet secrets in repo/CI  

### v1 success criteria

1. Import signing + watch-only  
2. XRP + IOU balances on Mainnet/Testnet  
3. Send with review/confirm  
4. Background notify on validated activity  
5. Sideload APK on personal Android device  

---

## 10. Open Questions (resolved)

| Question | Resolution |
|----------|------------|
| Full wallet vs monitor-first? | Full wallet |
| Distribution? | Personal sideload |
| Assets? | XRP + IOUs |
| Networks? | Mainnet + Testnet |
| Stack? | Flutter |
| Architecture? | A + watcher in v1 (C) |
| Generate wallet? | No — import only |
| Watcher timing? | In v1 after core import path |

## 11. Open Questions (optional later)

- Custom WSS URL in settings (easy add; not required for first APK)  
- Exact FGS service type string for target Android API  
- Riverpod vs Bloc  
- Project directory name/location  

---

## 12. Next Steps After Plan Approval

1. Write durable spec copy under project `docs/` when repo is created  
2. Produce detailed implementation plan (writing-plans) for PR1+  
3. Scaffold Flutter project and execute PR plan  

---

*Design brainstormed and approved interactively; ready for implementation planning.*
