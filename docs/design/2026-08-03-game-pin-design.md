# Game PIN (duress decoy) — Design

**Date:** 2026-08-03  
**App:** XRPL Mobile Wallet (unlock runner: **Zerpland**)  
**Status:** Implemented

## Goal

Allow the user to configure an optional **second PIN** (the **game PIN**). Entering it on the unlock screen opens **Zerpland** (endless runner) instead of the wallet, while remaining locked. Useful under duress: the user can give a PIN that appears to “unlock” something without revealing wallet data.

UI wording stays neutral (**Game PIN** / Zerpland) — no “duress” or “panic” language.

## Behavior

| Input | Result |
|-------|--------|
| Correct **wallet PIN** | Unlock wallet (`LockPhase.unlocked`) |
| Correct **game PIN** (if set) | Full-screen Zerpland; stay `locked`; closing game returns to Unlock |
| Wrong PIN | Same “Incorrect PIN” message either way |
| **No game PIN** | After **3** failed attempts → Zerpland (legacy decoy) |
| **Game PIN set** | 3-fail decoy **disabled**; only the game PIN opens the game |
| Biometrics | Unlocks wallet only (unchanged) |

### Rules

- Game PIN is optional.
- Same format as wallet PIN: ≥ `AppConfig.pinMinLength` (6) digits.
- Must **differ** from the current wallet PIN when setting or changing either PIN.
- Changing wallet PIN to equal the game PIN is **rejected** (user picks a different wallet PIN).
- Wipe all local data clears both PINs (`KeyVault.deleteAllSecrets` → secure storage `deleteAll`).
- Set / change / clear game PIN always require the **wallet PIN**.

## Settings UX (Security)

Tile: **Game PIN**

- Not set: subtitle “A second PIN that opens Zerpland instead of the wallet” → set dialog (wallet PIN + game PIN + confirm).
- Set: subtitle “Configured · opens Zerpland” → Change or Clear.
  - Clear: confirm with wallet PIN; restores 3-fail decoy.

## Storage

| Key | Purpose |
|-----|---------|
| `app_pin_hash` / `app_pin_salt` | Wallet PIN (existing) |
| `game_pin_hash` / `game_pin_salt` | Optional game PIN |

Same SHA-256(`salt:pin`) scheme as the wallet PIN. Separate salt per PIN.

## Architecture

```
UnlockScreen
  → LockController.unlockWithPin → PinService.checkUnlockPin
       wallet → LockPhase.unlocked
       game   → push ZerplandRunnerScreen (stay locked)
       failed → incorrect; optional 3-fail decoy if !hasGamePin

Settings
  → LockController.setGamePin / clearGamePin / hasGamePin
       → PinService (secure storage)
```

### Touch points

| File | Change |
|------|--------|
| `lib/config/storage_keys.dart` | Game PIN storage keys |
| `lib/data/secure/pin_service.dart` | Game PIN CRUD, `PinCheckResult`, `checkUnlockPin` |
| `lib/state/lock_controller.dart` | `UnlockOutcome`, unlock/set/clear APIs |
| `lib/ui/lock/pin/unlock_screen.dart` | Branch on outcome; gate 3-fail on `!hasGamePin` |
| `lib/ui/settings/settings_screen.dart` | Game PIN tile + dialogs |
| `test/data/pin_service_test.dart` | Memory-backed coverage |

## Out of scope

- Fake balances / decoy wallets
- First-run requirement for a game PIN
- Hiding Zerpland existence from Settings (soft deniability only)
- Timing-attack hardening beyond equal-length wrong-path messaging

## Security notes

- Game PIN never unlocks secrets; KeyVault is not read for game path.
- Unlock screen does not reveal whether a game PIN exists (failed attempts look the same; only the 3-fail path differs, and only when no game PIN is set).
- Watcher / FGS remain address-only; unchanged.
