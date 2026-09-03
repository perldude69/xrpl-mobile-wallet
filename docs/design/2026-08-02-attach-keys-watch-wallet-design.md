# Attach Keys to Watch-Only Wallet — Design

**Status:** Implemented (2026-08-02)  
**App:** XRPL Mobile Wallet / BG123  
**Related:** `docs/design/2026-07-20-xrpl-mobile-wallet-design.md`

---

## 1. Summary

Allow the user to **add signing keys** to an existing **watch-only** wallet without creating a second account. After a successful attach, the same `walletId` becomes `signing`, secrets land in KeyVault, and **Send** becomes available. Balances, history, label, and classic address are unchanged.

---

## 2. Goals / Non-goals

### Goals

- Upgrade watch-only → signing **in place** when the entered secret derives to that wallet’s classic address.
- Support three entry modes: paste phrase, 24-cell grid phrase, family seed.
- Grid is **8 rows × 3 columns**, numbered 1–24, with English BIP39 autocomplete.
- Accept **12 or 24** words when the filled set is unambiguous; reject other counts.
- On address mismatch: **error only** — no KeyVault write, no kind change, no new wallet.

### Non-goals

- Creating a new wallet when the secret does not match.
- Changing the stored classic address to match a different secret.
- Removing keys / downgrading signing → watch-only (unless requested later).
- Multi-language BIP39 (English only, same as create/import today).
- Hardware wallets or QR of full mnemonics.

---

## 3. User flow

```
Wallet detail (kind = watchOnly)
  → primary or secondary action: "Add keys"
  → Chooser screen / sheet:
       1. Paste recovery phrase
       2. Enter phrase (grid)
       3. Family seed
  → Entry screen (screenshot protection on)
  → User submits
  → Derive address; compare to wallet.address
       match    → persist secret + flip to signing → pop to detail (Signing chip, Send visible)
       mismatch → show standard warning; stay on entry screen
       invalid  → show validation error; stay on entry screen
```

Signing wallets do not show “Add keys”.

---

## 4. Entry modes

### 4.1 Chooser

Present three options (list tiles or large buttons). No secret fields on the chooser itself.

| Option | Next UI |
|--------|---------|
| Paste recovery phrase | Single multi-line (or single-line) secret field, obscure optional |
| Enter phrase (grid) | 8×3 numbered cells |
| Family seed | Single field for `s…` seed |

### 4.2 Paste recovery phrase

- User pastes or types whitespace-separated words.
- Normalize: trim, collapse internal whitespace to single spaces, lowercase for BIP39 matching as needed by existing import helpers.
- Word count must be **12 or 24**; otherwise error: enter 12 or 24 words.
- Proceed to derive + address check (section 5).

### 4.3 Grid (8×3)

- Always render **24** cells in **8 rows × 3 columns**.
- Each cell shows its index **1–24** before/while empty (label or prefix), so position is always clear.
- English BIP39 **autocomplete** / suggestions from `Bip39Languages.english.wordList` (already used in create flow).
- Optional polish (recommended if low cost): pasting a full phrase into cell 1 (or a toolbar “Paste phrase”) splits and fills cells 1–N.
- On submit, collect non-empty cells:

| Filled cells | Interpretation |
|--------------|----------------|
| Exactly **24**, all positions 1–24 non-empty | 24-word mnemonic |
| Exactly **12**, and they are **positions 1–12** (13–24 empty) | 12-word mnemonic |
| Any other pattern (count 0–11, 13–23, gaps, or 12 words not in 1–12) | Error: enter 12 or 24 words (do not invent a phrase) |

- Join accepted words in index order → same derive + address check as paste.

### 4.4 Family seed

- Single text field; validate with existing `SecretValidator.looksLikeFamilySeed` / `WalletImporter.importFamilySeed` rules.
- Derive via `XRPPrivateKey.fromSeed` path already used for import.
- Address must match; same error policy.

---

## 5. Crypto and persistence

### 5.1 Derivation (must stay consistent with import)

| Secret | Algorithm |
|--------|-----------|
| BIP39 12/24 | BIP44 `m/44'/144'/0'/0/0` + **secp256k1** (`WalletImporter.importMnemonic`) |
| Family seed | Existing `importFamilySeed` / `XRPPrivateKey.fromSeed` |

Reuse importer derivation; do not reimplement curves or paths.

### 5.2 Address match (hard gate)

```
derivedAddress == wallet.address  (classic r…)
```

- Case-sensitive classic address compare as stored (same string form as importer produces).
- **Mismatch:** user-visible error, e.g. “This secret does not match this wallet’s address.” No side effects.
- **Match:** continue to persist.

### 5.3 Persist (in place)

On success, for existing `walletId`:

1. `KeyVault.saveSecret(walletId, secret)` — store normalized mnemonic string or family seed string (same material shape as import).
2. Update SQLite wallet row:
   - `kind` → `signing`
   - `importMethod` → `mnemonic` or `familySeed` (replace `addressOnly`)
3. Reload list state so UI shows Signing and Send.
4. Watcher address book: no address change required; optional re-sync is fine but not required for correctness.

Do **not** create a new UUID/account. Do **not** change `address`, `label`, balances, or cached txs.

### 5.4 Idempotency / edge cases

- If wallet is no longer watch-only when submit runs: error or pop (stale UI).
- If secret already exists in KeyVault for that id (should not for watch-only): overwrite only after successful match is acceptable; prefer asserting watch-only before write.
- Duplicate address among other wallets: attach still allowed for this row; do not create a second row.

---

## 6. UI placement

- **Wallet detail** (`WalletDetailScreen`) when `!account.canSign`:
  - Show **Add keys** (e.g. `FilledButton` or tonal button in the action row with Receive; Send remains hidden until upgrade).
  - Optional overflow menu item “Add keys” for the same route.
- After success: snackbar or brief confirmation; detail rebuilds with Signing chip and Send.

### Security UX (parity with import)

- Enable `ScreenSecurity` while entry screens are mounted; disable on dispose.
- Scrub text controllers on dispose (overwrite-then-clear pattern from `ImportScreen`).
- Prefer obscuring family seed; phrase grid may show words while typing (autocomplete needs visibility) — acceptable on a secured screen.

---

## 7. Architecture / code touchpoints

Suggested shape (implementation plan may refine names):

| Piece | Role |
|-------|------|
| UI chooser + entry screens under `lib/ui/wallets/` | Navigation and input only |
| Shared BIP39 autocomplete widget (grid cells) | Reuse word list from `blockchain_utils` |
| Domain/data: thin helper e.g. `attachSecret` or methods on `WalletImporter` | Derive from secret without allocating a new account id; return derived address + normalized secret + method |
| `WalletListController.attachKeys(walletId, …)` | Load account, require watchOnly, verify address, KeyVault + DB update, reload |

Avoid teaching the watcher about secrets. Avoid putting KeyVault in UI beyond calling the controller.

---

## 8. Errors (user-facing)

| Condition | Message intent |
|-----------|----------------|
| Not 12 or 24 words / invalid grid fill | Enter 12 or 24 recovery words |
| Invalid BIP39 / checksum | Invalid recovery phrase |
| Invalid family seed format | Invalid family seed |
| Derived address ≠ wallet | This secret does not match this wallet’s address |
| Wallet missing / not watch-only | Wallet not found / already has keys |

Tone: clear, non-leaky (do not show the derived other address unless useful for support; default is mismatch only).

---

## 9. Testing

Unit / widget tests:

1. **Match (24):** known phrase → address A; watch row with A → attach succeeds; kind signing; secret readable from vault mock.
2. **Match (12):** valid 12-word vector if available, or generator path; same in-place upgrade.
3. **Mismatch:** valid phrase for address B, watch is A → error; DB/kind unchanged; no vault write.
4. **Grid fill rules:** 1–12 only accepted as 12; 1–11 rejected; gap rejected; full 24 accepted.
5. **Family seed match/mismatch** using existing genesis/known vectors where applicable.
6. Golden continuity: abandon 24-word still maps to `rHsMGQEkVNJmpGWs8XUBoTBiAAbwxZN5v3` when used as attach secret for that address.

---

## 10. Decisions log

| Decision | Choice |
|----------|--------|
| Mismatch behavior | Error only; no new wallet |
| Entry chooser | Paste phrase \| Grid \| Family seed |
| Grid layout | 8×3, numbers 1–24 always visible |
| Autocomplete | English BIP39 word list |
| Partial phrase | 12 words only if cells 1–12 filled and 13–24 empty |
| Address change | Never |
| Wallet id | Preserved |

---

## 11. Open implementation details (non-blocking)

- Exact navigation: full-screen routes vs modal bottom sheet for chooser (prefer full-screen for screenshot security consistency with import).
- Whether paste-into-grid is v1 or follow-up (nice-to-have).
- Button label copy: “Add keys” vs “Unlock sending” (prefer **Add keys**).
