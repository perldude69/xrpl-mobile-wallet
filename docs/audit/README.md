# Security audits

Open the HTML report in a browser (GitHub does not render it inline):

- [2026-09-03-security-audit-report.html](2026-09-03-security-audit-report.html) — source audit plus Pixel 8 Pro release-APK checks (signing, backup, merged manifest, FLAG_SECURE, exported components).

One High finding remains open and was confirmed on the installed APK: release is signed with the Android debug key (XRW-01), deferred to store signing. XRW-15, XRW-16, XRW-17, XRW-18, and XRW-20 are resolved.

Evidence screenshots: [evidence/](evidence/).
