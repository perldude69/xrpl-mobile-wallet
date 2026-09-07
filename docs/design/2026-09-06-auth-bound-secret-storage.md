# Making the PIN a real cryptographic factor

Status: **P1 shipped; P2–P6 not started** · 2026-09-06
Related: `AGENTS.md` §Security, `lib/data/secure/`, `lib/state/lock_controller.dart`

Goal: the wallet PIN must **cryptographically** protect stored seeds. Today it
is only a UI gate — anything running as `info.richlist.wallet` can ask the
Keystore to unwrap and read every seed without knowing the PIN.

Target is **Google Play**, with third-party users holding real funds. Sideload
is only for development. That constraint drives every decision below, and it
**reversed my first recommendation** — see §3.

---

## 1. Where we are today (verified in source, not assumed)

`KeyVault` stores the **raw 24-word phrase, verbatim** (`WalletImporter`
returns `secret: trimmed`) via `flutter_secure_storage` 10.3.1 with
`AndroidOptions(resetOnError: false)` — i.e. plugin defaults:

| Layer | Reality |
|---|---|
| Value | `AES/GCM/NoPadding`, random IV, 128-bit tag |
| Data key | **16 bytes — AES-128** (`StorageCipherImplementationGCM.java:18`) |
| Key wrapping | RSA-OAEP (SHA-256/MGF1) keypair in `AndroidKeyStore`, **no auth requirement** |
| At rest | Wrapped key + ciphertext in a private SharedPreferences XML |
| Key names | SHA-256 of XOR-encoded role tags (XRW-23) — obfuscates *names* only |
| Backup | `android:allowBackup="false"` |
| PIN | `PinService` PBKDF2-hashes it **for comparison only**; derives no key |

Effective `minSdk` is **24**, confirmed in the merged manifest of the shipped
APK, pinned by `local_auth_android` (24), `flutter_local_notifications` (24)
and the vendored `ledger_usb_plus` (24).

---

## 2. The trap in `AndroidOptions.biometric`

`KeyCipherImplementationAES23.generateSymmetricKey()` hardcodes
`setInvalidatedByBiometricEnrollment(true)`. It is not an option we can pass.

An auth-bound Keystore key is permanently destroyed when the user **enrolls a
new fingerprint or face**, or **removes the screen lock**. Both are routine.

For one developer who knows to keep paper backups, that is a caveat. For a Play
release it is a defect that will cost strangers their money: users enroll
fingerprints constantly, most will not have written down 24 words, and the app
has **no in-app seed backup** — `wallet_export.dart` is explicitly "never
includes seeds, mnemonics, or private keys."

**"Add a fingerprint → wallet gone" cannot ship to Play.**

---

## 3. The revision: don't auth-bind the seed at all

My earlier recommendation put the seed behind an auth-bound Keystore key. That
was wrong for this audience, and the fix is a clean separation:

> The invalidation hazard comes **only** from auth-binding. Keys created
> *without* `setUserAuthenticationRequired(true)` are **not** invalidated by
> biometric enrollment or by removing the screen lock. So keep the seed's
> storage key non-auth-bound, and put the PIN into the cryptography instead.

That closes the actual gap (root can read seeds without the PIN) **without**
introducing a way to lose funds.

### Target architecture

**Layer 1 — the real protection. `Argon2id(PIN, salt)` → AES-256-GCM envelope
around the phrase.**
Device-independent and durable. Survives biometric enrollment, screen-lock
removal, OS upgrade, Keystore reset. Pure Dart, therefore unit-testable with
vectors. `Argon2id` is already available — `cryptography` 2.9.0 is in the tree.

**Layer 2 — defence in depth. Store that envelope in `flutter_secure_storage`,
keeping today's non-auth-bound Keystore config.**
Exfiltrating the app's data directory yields only ciphertext, and the RSA key
never leaves the TEE. No invalidation risk, because nothing here is auth-bound.

**Layer 3 — biometric as convenience only, never as custody.**
A *separate* auth-bound Keystore entry caches the Argon2id-derived key so a
fingerprint can substitute for typing the PIN. If it is invalidated, the user
is asked for their PIN and it is transparently re-created. **Losing layer 3
loses a convenience, never a seed.**

Net effect against the original complaint: root or malware now needs the device
Keystore **and** the PIN. It cannot read a seed by replaying a Keystore unwrap.

### Bonus this unlocks

The envelope is portable ciphertext, so a genuine **encrypted seed backup /
restore** becomes possible later — the thing that actually protects Play users
from losing a phone. Out of scope here, but the format should not preclude it.

---

## 4. Decisions

| # | Decision | Call |
|---|---|---|
| D1 | Protection model | **Three layers above.** Seed never held hostage by an auth-bound key. |
| D2 | Require a device screen lock? | Refuse to create/import a **signing** wallet when `KeyguardManager.isDeviceSecure()` is false, with an explanation. Watch-only stays allowed. |
| D3 | `minSdk` 24 → 28 | **Yes** — your call, taken. Drops Android 7.0/7.1/8.0/8.1, all unpatched by Google since ~2021. Gains StrongBox and `setUnlockedDeviceRequired` for layer 3. |
| D4 | Biometric strength | `biometricOrDeviceCredential`, so Class-2-face-only devices still work. |
| D5 | Prompt frequency | Once per unlocked session, lazily on first secret access — not at app start, not per read. |
| D6 | Minimum PIN | **Raised 6 → 8 digits** for new PINs (done). Layer 1 rests on PIN entropy; 6 digits is 10⁶. |

### Why PIN length now matters more than it did

Once the seed's confidentiality depends on `Argon2id(PIN)`, PIN entropy is a
real security parameter rather than a lockout threshold. An attacker who
defeats layer 2 gets an offline brute-force target.

- 6 digits = 10⁶. High-cost Argon2id (64 MiB, t=3 as shipped) makes each guess
  expensive and is GPU-hostile, but 10⁶ is a small space.
- 8 digits = 10⁸, i.e. ~100× the work for two more keystrokes.

Existing PINs are not force-migrated; the new minimum applies to newly set
PINs, with a prompt suggesting an upgrade. Argon2id parameters must be tuned on
a low-end device, not the Pixel — target roughly 500 ms–1 s on weak hardware,
and the parameters live in the per-install `PinKdfParams` record so they can be
raised later without making existing installs unreadable.

---

## 5. Migration

No compatibility burden — no wallet holds real funds yet. Clean break, done
deliberately:

1. Bump `storageNamespace` (e.g. `zerp.v2`) → fresh Keystore aliases and prefs.
2. One-shot wipe of the old namespace on first run of the new build, then send
   the user to first-run setup.
3. `migrateOnAlgorithmChange: false`, `resetOnError: false` — failures must be
   loud and explained, never a silent seed deletion.
4. Any wallet row whose secret cannot be decrypted becomes **watch-only with a
   "keys unavailable" banner**, offering the existing *Attach keys* flow or
   delete. Label, address and accent survive; only the secret is gone.

Step 4 is permanent infrastructure, not migration scaffolding — it is also the
recovery path if layer 2 ever fails.

---

## 6. Play Store work this implies (separate track)

Flagging so it is not discovered late. `AGENTS.md` has been updated: the header
and the product-scope section now state that Play is the goal, and that no
design may carry a "user loses their funds" failure mode.

- **Financial-services / crypto declaration** in Play Console for a
  non-custodial wallet.
- **Data safety form** — accurate now that we can say seeds never leave the
  device and there is no backend.
- **Privacy policy URL** — mandatory.
- **Target API** — 36 already satisfies Play's rolling requirement.
- **Play App Signing** — upload keystore already configured via
  `android/key.properties`.
- **Pre-launch report** runs on real devices; expect biometric and USB paths to
  be exercised.
- Sideload builds stay `tool/build_release.sh`; Play needs an App Bundle.

---

## 7. Related

Hardware second factor (YubiKey) is explored separately in
`docs/design/2026-09-06-yubikey-exploration.md`. It plugs into
`PinKey.derive` as an extra input to the same master key, so it is additive —
but it must come after P2/P3, or the same code gets rewired twice.

## 8. Test matrix

Layers 2 and 3 are Keystore behaviour and cannot be unit-tested. Layer 1 can be
and must be.

| # | Scenario | Expected |
|---|---|---|
| 1 | Argon2id envelope round-trip, known vectors | Deterministic, exact |
| 2 | Wrong PIN | Authentication failure, never garbage plaintext |
| 3 | Tampered ciphertext / salt / params | GCM tag rejects |
| 4 | Envelope parameters upgraded | Old envelopes still open |
| 5 | Pixel 8 Pro, fingerprint enrolled | Biometric unlock works |
| 6 | **Enroll a new fingerprint after storing a seed** | Layer 3 invalidated → PIN prompt → re-armed. **Seed intact.** |
| 7 | **Remove screen lock after storing a seed** | Same as 6 |
| 8 | No screen lock at all | Signing-wallet creation blocked with reason; watch-only works |
| 9 | Class-2 face-only device | Works via device credential |
| 10 | API 28 emulator | Works (proves the new floor) |
| 11 | Low-end device | Argon2id cost tuned to ≤1 s |
| 12 | Non-StrongBox device | TEE fallback |
| 13 | Background mid-prompt | No stuck state |
| 14 | Trade reconciler on resume | Unaffected — public ledger data only, never `KeyVault` |
| 15 | Watcher isolate | Unaffected — address-only by design |

6 and 7 are the ones that used to lose money and now must not.

---

## 9. Phases

Nothing is wired yet: `KeyVault` still stores plaintext, so the app behaves
exactly as before and the suite is green (364 tests). P2/P3 are the change of
behaviour.

- **P1 — DONE.** Split into two pieces rather than one, because a single
  Argon2id-per-read would have put ~1 s on every send and trade signature:
  - `lib/data/secure/pin_key.dart` — `PinKdfParams` (cost + per-install salt,
    validated against ceilings because the record is attacker-reachable),
    `PinKey.derive` (Argon2id 64 MiB / t=3 / p=1 → 32-byte master key), and
    `PinMasterKey` (memory-only, `destroy()` zeroes and blocks further use).
  - `lib/data/secure/secret_envelope.dart` — AES-256-GCM under an HKDF-SHA256
    subkey of the master key, with the wallet id as both HKDF `info` and GCM
    associated data, so an envelope cannot be replayed into another wallet's
    slot. Microseconds per seal/open.
  - 58 tests across the two: round trip, wrong key, wallet binding, tampering
    (flipped ciphertext, swapped nonce/mac/ct, truncated tag), malformed
    records, hostile cost parameters, destroyed-key use, and one full-cost
    end-to-end pass each.
  - `AppConfig.pinMinLength` 6 → **8**, enforced only when *setting* a PIN;
    `verifyPin` deliberately does not enforce it, so raising the floor cannot
    lock anyone out of an existing wallet (pinned by a test).
  - Measured Argon2id on a desktop core: 16 MiB 274 ms, 32 MiB 401 ms,
    **64 MiB 814 ms**. A budget phone will be several times that — hence
    derive-once-per-unlock, and re-measure on real low-end hardware before
    release.
- **P2 — `KeyVault` rework** *(next)*: store envelopes instead of raw phrases; explicit
  `SecretUnavailable` result rather than a bare null; new storage namespace;
  one-shot wipe.
- **P3 — call sites**: import, create, attach-keys, send, trade signing and
  export all need the PIN at the point of secret access. This is the invasive
  phase and touches every money path.
- **P4 — app-level gates**: device-secure check, recovery-phrase confirmation,
  "keys unavailable" state.
- **P5 — layer 3 biometric convenience**, auth-bound with graceful
  re-arming.
- **P6 — `minSdk` 28**, PIN minimum 8, `AGENTS.md` update, full matrix run.

P3 is where regressions would hurt; it deserves its own review pass against the
`flutter analyze` + `flutter test` gate before anything is installed.
