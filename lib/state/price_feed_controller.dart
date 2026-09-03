import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xrpl_mobile_wallet/config/app_config.dart';
import 'package:xrpl_mobile_wallet/config/storage_keys.dart';
import 'package:xrpl_mobile_wallet/data/oracle/xrp_usd_rate_store.dart';
import 'package:xrpl_mobile_wallet/domain/oracle/xrp_usd_oracle.dart';
import 'package:xrpl_mobile_wallet/state/network_controller.dart';
// NetworkId via constants.dart

/// Live + cached XRP→USD rate for portfolio display.
class PriceFeedState {
  const PriceFeedState({
    this.usdPerXrp,
    this.updatedAt,
    this.displayFiat = false,
    this.live = false,
  });

  final double? usdPerXrp;
  final DateTime? updatedAt;

  /// When true, portfolio shows USD totals; when false, XRP.
  final bool displayFiat;

  /// True if quote came from a stream/bootstrap in this session (not only disk).
  final bool live;

  bool get hasRate =>
      usdPerXrp != null && usdPerXrp!.isFinite && usdPerXrp! > 0;

  PriceFeedState copyWith({
    double? usdPerXrp,
    DateTime? updatedAt,
    bool? displayFiat,
    bool? live,
  }) {
    return PriceFeedState(
      usdPerXrp: usdPerXrp ?? this.usdPerXrp,
      updatedAt: updatedAt ?? this.updatedAt,
      displayFiat: displayFiat ?? this.displayFiat,
      live: live ?? this.live,
    );
  }
}

class PriceFeedController extends StateNotifier<PriceFeedState> {
  PriceFeedController(this._network) : super(const PriceFeedState()) {
    _init();
  }

  final NetworkController _network;
  final _store = XrpUsdRateStore();
  Timer? _poll;
  http.Client? _http;

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final fiat = prefs.getBool(StorageKeys.displayFiat) ?? false;
    final cached = await _store.load();
    state = PriceFeedState(
      usdPerXrp: cached?.usdPerXrp,
      updatedAt: cached?.at,
      displayFiat: fiat,
      live: false,
    );
    await bootstrapFromRpc();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_reloadFromStore());
    });
  }

  Future<void> _reloadFromStore() async {
    final cached = await _store.load();
    if (cached == null || !cached.isPositive) return;
    final prev = state.usdPerXrp;
    final prevAt = state.updatedAt;
    if (prev == cached.usdPerXrp &&
        prevAt?.millisecondsSinceEpoch ==
            cached.at.millisecondsSinceEpoch) {
      return;
    }
    state = state.copyWith(
      usdPerXrp: cached.usdPerXrp,
      updatedAt: cached.at,
      live: true,
    );
  }

  /// Fetch latest oracle TrustSet via JSON-RPC (mainnet only).
  Future<void> bootstrapFromRpc() async {
    if (_network.state.network != NetworkId.mainnet) return;
    final base = _network.state.activeNodeUrl ??
        NetworkId.mainnet.defaultHttp;
    try {
      _http ??= http.Client();
      final res = await _http!
          .post(
            Uri.parse(base),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'method': 'account_tx',
              'params': [
                {
                  'account': AppConfig.xrpUsdOracleAddress,
                  'ledger_index_min': -1,
                  'ledger_index_max': -1,
                  'limit': 1,
                  'binary': false,
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body);
      if (body is! Map) return;
      final result = body['result'];
      if (result is! Map) return;
      final txs = result['transactions'];
      if (txs is! List || txs.isEmpty) return;
      final first = txs.first;
      if (first is! Map) return;
      final quote = XrpUsdOracle.parseAccountTxItem(
        Map<String, dynamic>.from(first),
      );
      if (quote == null || !quote.isPositive) return;
      await _store.save(quote);
      state = state.copyWith(
        usdPerXrp: quote.usdPerXrp,
        updatedAt: quote.at,
        live: true,
      );
    } catch (_) {
      // Keep cached rate.
    }
  }

  Future<void> setDisplayFiat(bool fiat) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.displayFiat, fiat);
    state = state.copyWith(displayFiat: fiat);
  }

  void toggleDisplayFiat() {
    unawaited(setDisplayFiat(!state.displayFiat));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _http?.close();
    super.dispose();
  }
}

final priceFeedControllerProvider =
    StateNotifierProvider<PriceFeedController, PriceFeedState>((ref) {
  return PriceFeedController(ref.watch(networkControllerProvider.notifier));
});
