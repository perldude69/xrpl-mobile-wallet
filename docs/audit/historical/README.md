# Security audits

Open the HTML report in a browser (GitHub does not render it inline):

- [2026-09-05-code-and-device-audit.html](2026-09-05-code-and-device-audit.html) — fresh code + device pass, findings only: XRW-24 (phrase clipboard copy, Low), XRW-25 (raw exception passthrough, Informational).
- [2026-09-05-reaudit-release-apk.html](2026-09-05-reaudit-release-apk.html) — re-audit of v1.0.1 (build 2): release APK now v2-signed with the upload keystore (XRW-01 resolved), XRW-21/22 resolved, dynamic checks (FLAG_SECURE, auto-lock, logcat scan) re-verified on the Pixel 8 Pro. Markdown copy: [2026-09-05-reaudit-release-apk.md](2026-09-05-reaudit-release-apk.md).
- [2026-09-05-owasp-mobile-audit-report.html](2026-09-05-owasp-mobile-audit-report.html) — OWASP Mobile Audit (CWE + Mobile Top 10 2016, MASVS v2 labels) of the current tree plus Pixel 8 Pro checks of the installed release APK.
- [2026-09-03-security-audit-report.html](2026-09-03-security-audit-report.html) — earlier source audit plus Pixel 8 Pro packaging / FLAG_SECURE checks.

Status after the 2026-09-05 re-audit: **no High/Medium findings remain.** XRW-01 (debug-signed APK), XRW-21 (Ledger Java logs), XRW-22 (obscured-touch filter) and XRW-23 (obfuscated snapshot + derived storage key names) are resolved and verified on the installed binary. XRW-02 and XRW-19 remain open as accepted informational items.

Evidence screenshots: [evidence/](evidence/).

Related: [../privacy/privacy.md](../privacy/privacy.md) — what the app stores, sends, and never collects.

Evidence screenshots: [evidence/](evidence/).
