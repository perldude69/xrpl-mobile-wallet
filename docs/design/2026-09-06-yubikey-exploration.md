# YubiKey — exploration

Status: **exploration, nothing built** · 2026-09-06
Related: `docs/design/2026-09-06-auth-bound-secret-storage.md`, `lib/data/secure/`

---

## 1. What a YubiKey cannot do here

Worth clearing first, because it is the intuitive expectation and it is wrong:

- **It cannot hold an XRPL seed or sign XRPL transactions**, not usefully.
  There is no XRP applet. PIV only does RSA and NIST curves (P-256/P-384) —
  not secp256k1, and not ed25519 in the form XRPL wants. The YubiKey 5 OpenPGP
  applet *does* support secp256k1 ECDSA, so in theory a transaction hash could
  be signed there, but it would mean hand-rolling XRPL signing over OpenPGP
  APDUs with no key-derivation path (`m/44'/144'/…`) and no on-device display
  of what is being signed.
- **That role is already filled.** `lib/data/ledger_device/` does hardware
  signing properly, with a real XRP app and an on-device confirmation screen.
  A YubiKey would be a worse Ledger.

So: not a signer.

## 2. What it is genuinely good for here

**A second factor on the at-rest encryption.** This lands exactly on the
weakness we just accepted: seed confidentiality now rests on
`Argon2id(PIN)`, and an 8-digit PIN is only 10⁸. Add a YubiKey factor and the
stored bytes cannot be decrypted at all without the physical key present —
brute-forcing the PIN offline stops being a path.

**The architecture already accommodates it.** `PinKey.derive()` produces a
`PinMasterKey`, and `SecretEnvelope` seals under HKDF subkeys of that master
key. A hardware factor is just another input to that one derivation:

```
masterKey = HKDF(
    ikm  : Argon2id(PIN, salt) || hardwareSecret,
    info : "zerp.master.v2",
)
```

Nothing in `SecretEnvelope` or the call sites changes. That was a happy
accident of splitting the KDF out, but it does mean this is additive rather
than a rewrite.

### Which YubiKey mechanism

| Mechanism | Fit | Notes |
|---|---|---|
| **HMAC-SHA1 challenge-response** (OTP applet, slot 2) | **Best** | Send a 64-byte challenge, get a 20-byte HMAC. Deterministic, so the same salt always yields the same secret. This is how KeePassXC and VeraCrypt use a YubiKey. Requires programming a shared secret into the key once (Yubico Authenticator does it). USB **and** NFC. |
| **FIDO2 `hmac-secret`** | Good, more modern | Derives a per-credential symmetric secret from a salt; no shared secret to program. CTAP2 over USB/NFC. More protocol surface to get right. |
| **PIV** | Workable | Wrap the master key with an on-card RSA/ECC key. Adds a PIV PIN and touch policy. Heavier. |
| **OATH / OTP codes** | **No** | A 6-digit TOTP cannot contribute key material. It would be theatre. |

Recommendation: **HMAC-SHA1 challenge-response**. It is deterministic, well
understood, works over both transports, and 20 bytes of HMAC output is ample
as one HKDF input.

## 3. The hazard, and it is the same one as before

**A lost YubiKey means unreadable seeds.** This is the `setInvalidatedBy­Biometric­Enrollment`
problem wearing a different hat, and the same rule from `AGENTS.md` applies:
*no design may have a "user loses their funds" failure mode.*

So it must be:

- **Opt-in**, off by default, and clearly explained.
- **Enrolled in pairs** — the flow should require registering a *second*
  YubiKey (Yubico's own guidance, and the reason they sell them in twos), or an
  explicit acknowledgement that the recovery phrase is the only fallback.
- Backed by the same **"keys unavailable"** state already planned, so a missing
  key produces "insert your security key" and not a crash.

A neat property of the HMAC approach: because the hardware secret is a *KDF
input* rather than a wrapping key, a user can disable the factor by re-sealing
every envelope under a PIN-only master key — provided they can currently
unlock. So there is a clean opt-out path while the key still exists.

## 4. Android and Play reality

- **Transports:** USB-C/OTG and NFC both work. USB needs the same
  `UsbManager.requestPermission` dance already solved for Ledger
  (`usb_device_filter.xml`); NFC needs `android.permission.NFC` and an
  intent filter.
- **Not universal:** plenty of Android phones have no NFC, and OTG support is
  uneven on budget hardware. Another reason this is an optional power-user
  feature, never a requirement.
- **Play:** no policy obstacle. It is a hardware-token integration, not a
  crypto-custody claim.

## 5. Integration options

There is **no mature Flutter YubiKey plugin**. Two viable routes:

**(a) NFC-only, raw APDUs via `flutter_nfc_kit`.** No native code at all —
select the OTP applet and issue the challenge-response APDU directly. Cheapest
way to prove the mechanism and the UX. NFC only.

**(b) Vendor `yubikit-android` behind a platform channel.** Yubico's official
Kotlin/Java SDK; covers USB and NFC properly. There is precedent in this repo —
`packages/ledger_usb_plus` is already a vendored, locally patched plugin — so
the pattern is established. Materially more work.

Suggested order: spike **(a)** to validate that challenge-response over NFC
gives a stable secret and that the unlock UX is tolerable, then decide whether
USB support justifies **(b)**.

## 6. Where this sits in the queue

It should come **after** the current side quest is finished and on a device.
The reasons are ordering, not enthusiasm:

1. The PIN envelope (P1, done) and its wiring (P2–P4, not started) are what
   actually close the reported gap. YubiKey deepens the same defence; it does
   not substitute for it.
2. The master-key indirection it plugs into only exists once P2/P3 land.
3. It changes the master-key derivation, so doing it mid-rewire means changing
   the same code twice.

Rough shape when it does come up:

- **Y0** — spike (a): NFC challenge-response, print the derived secret, confirm
  determinism across taps and across a re-tap after reboot.
- **Y1** — `HardwareFactor` abstraction feeding `PinKey.derive`, with
  PIN-only as the default implementation.
- **Y2** — enrollment UX: register key, require a second key or an explicit
  acknowledgement, and a disable/re-seal path.
- **Y3** — USB via (b), if wanted.

## 7. Open questions

1. NFC-only first, or hold out for USB too? (NFC is far less work and your
   Pixel 8 Pro has it.)
2. Require a second registered key at enrollment, or accept an explicit
   "my recovery phrase is my only backup" confirmation?
3. Is this a power-user setting, or something you would want prominent? It
   changes how much UX work Y2 is.
