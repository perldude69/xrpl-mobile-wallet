# Widgetbook (layout sandbox)

Local catalog for experimenting with XRPL Mobile Wallet layouts.
**Not included in the Play / release APK.**

```bash
cd widgetbook
flutter pub get
flutter run -d chrome          # or a device id
```

Knobs (right panel) change padding-like structure: watch-only, Testnet card, tile aspect, bid/ask/AMM.

Winning layouts still have to be copied into `lib/ui/` in the parent app.
