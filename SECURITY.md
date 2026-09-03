# Security Policy

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security problems.

Use [GitHub private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability) on this repository.

If that is unavailable, contact the maintainer privately. Wait for acknowledgement before discussing details in public.

## Never paste secrets

Do **not** include any of the following in issues, pull requests, emails, or screenshots:

- BIP39 mnemonics / recovery phrases
- Family seeds (`s…`)
- Wallet PINs or game PINs
- Private keys or Keystore material
- Node access tokens (including WSS `?token=` query strings)

If you accidentally posted a secret, treat it as compromised: move funds, rotate the node token, and change PINs.

## Scope notes

- Secrets live in Android Keystore via `KeyVault` / `PinService`. The background watcher isolate must never import those modules.
- New wallet entropy always includes OS CSPRNG (`Random.secure`). Dice / personal-word input is mix-in only.
- Status UI must show endpoint **host only**, never a URL query string.
