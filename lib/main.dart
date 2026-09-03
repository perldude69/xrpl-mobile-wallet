import 'package:flutter/material.dart';
import 'package:xrpl_mobile_wallet/data/watcher/account_watcher.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/currency_display.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/token_registry.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // XRPSCAN token catalog for trust-line display names (offline snapshot).
  try {
    final registry = await TokenRegistry.loadFromAsset();
    CurrencyDisplay.setRegistry(registry);
  } catch (_) {
    // Tests / missing asset: ASCII hex decode still works without registry.
  }

  // Configure FGS entrypoint (no-op on desktop/web). Secrets are never loaded here.
  try {
    await AccountWatcher().initialize();
  } catch (_) {
    // Tests / unsupported platforms may fail channel setup; UI still works.
  }
  runApp(const XrplWalletApp());
}
