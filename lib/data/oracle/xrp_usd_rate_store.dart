import 'package:shared_preferences/shared_preferences.dart';
import 'package:xrpl_mobile_wallet/config/storage_keys.dart';
import 'package:xrpl_mobile_wallet/domain/oracle/xrp_usd_oracle.dart';

/// Persist last-known XRP→USD quote for UI (written by watcher + bootstrap).
class XrpUsdRateStore {
  XrpUsdRateStore({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> save(XrpUsdQuote quote) async {
    if (!quote.isPositive) return;
    final p = await _ensure();
    await p.setDouble(StorageKeys.xrpUsdRate, quote.usdPerXrp);
    await p.setInt(
      StorageKeys.xrpUsdRateAt,
      quote.at.toUtc().millisecondsSinceEpoch,
    );
  }

  /// Last saved quote, or null if never stored.
  Future<XrpUsdQuote?> load() async {
    final p = await _ensure();
    final rate = p.getDouble(StorageKeys.xrpUsdRate);
    if (rate == null || !rate.isFinite || rate <= 0) return null;
    final ms = p.getInt(StorageKeys.xrpUsdRateAt);
    final at = ms == null
        ? DateTime.now().toUtc()
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return XrpUsdQuote(usdPerXrp: rate, at: at);
  }
}
