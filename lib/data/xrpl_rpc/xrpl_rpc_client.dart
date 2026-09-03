import 'package:blockchain_utils/exception/exceptions.dart';
import 'package:http/http.dart' as http;
import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/config/network_id.dart';
import 'package:xrpl_mobile_wallet/domain/amount/xrp_amount.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/rpc_http_client.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/currency_display.dart';

/// A single balance entry (native XRP or issued IOU).
class LedgerBalance {
  const LedgerBalance({
    required this.currency,
    required this.value,
    this.issuer,
  });

  /// `XRP` for native, otherwise currency code / hex.
  final String currency;

  /// Decimal amount string (XRP already converted from drops).
  final String value;

  /// Counterparty issuer address; null for native XRP.
  final String? issuer;

  Map<String, dynamic> toMap() => {
        'currency': currency,
        'value': value,
        if (issuer != null) 'issuer': issuer,
      };
}

/// Lightweight account transaction summary for UI / caching.
class LedgerTxSummary {
  const LedgerTxSummary({
    required this.hash,
    required this.ledgerIndex,
    required this.transactionType,
    required this.account,
    this.destination,
    this.amountSummary,
    this.date,
    this.validated,
  });

  final String hash;
  final int? ledgerIndex;
  final String transactionType;
  final String account;
  final String? destination;
  final String? amountSummary;
  final int? date;
  final bool? validated;

  Map<String, dynamic> toMap() => {
        'hash': hash,
        'ledgerIndex': ledgerIndex,
        'transactionType': transactionType,
        'account': account,
        'destination': destination,
        'amountSummary': amountSummary,
        'date': date,
        'validated': validated,
      };
}

/// Read-only XRPL ledger client over JSON-RPC HTTP.
class XrplRpcClient {
  XRPProvider? _rpc;
  http.Client? _httpClient;
  NetworkId? _network;
  String? _activeHttpUrl;

  bool get isConnected => _rpc != null;
  NetworkId? get network => _network;
  XRPProvider? get provider => _rpc;

  /// Full HTTP JSON-RPC URL currently in use, or null when disconnected.
  String? get activeHttpUrl => _activeHttpUrl;

  /// Host of [activeHttpUrl] for compact UI (e.g. `xrplcluster.com`).
  String? get activeHttpHost {
    final url = _activeHttpUrl;
    if (url == null) return null;
    return Uri.tryParse(url)?.host ?? url;
  }

  /// Connected RPC provider, or throws if [connect] has not succeeded.
  XRPProvider requireProvider() => _requireRpc();

  /// Connect (or reconnect) to [network].
  ///
  /// [httpUrls] overrides the default catalog order (user prefs). When omitted,
  /// uses [NetworkId.httpEndpoints].
  ///
  /// When [httpClient] is omitted (production), probes each URL with
  /// `server_info` and keeps the first that responds. When a client is
  /// injected (unit tests), uses the first URL without probing so mocks only
  /// need to handle the methods under test.
  Future<void> connect(
    NetworkId network, {
    http.Client? httpClient,
    List<String>? httpUrls,
  }) async {
    await disconnect();
    final ownedClient = httpClient == null;
    final client = httpClient ?? http.Client();
    final candidates = (httpUrls != null && httpUrls.isNotEmpty)
        ? httpUrls
        : network.httpEndpoints;

    if (!ownedClient) {
      final url = candidates.first;
      final service = RpcHttpClient(url, client);
      _httpClient = client;
      _rpc = XRPProvider(service);
      _network = network;
      _activeHttpUrl = url;
      return;
    }

    Object? lastError;
    for (final url in candidates) {
      try {
        final service = RpcHttpClient(
          url,
          client,
          defaultTimeout: const Duration(seconds: 12),
        );
        final rpc = XRPProvider(service);
        await rpc.request(XRPRequestServerInfo());
        _httpClient = client;
        _rpc = rpc;
        _network = network;
        _activeHttpUrl = url;
        return;
      } catch (e) {
        lastError = e;
      }
    }

    client.close();
    throw StateError(
      'No reachable HTTP RPC for ${network.name}'
      '${lastError == null ? '' : ': $lastError'}',
    );
  }

  /// Tear down HTTP resources.
  Future<void> disconnect() async {
    _httpClient?.close();
    _httpClient = null;
    _rpc = null;
    _network = null;
    _activeHttpUrl = null;
  }

  XRPProvider _requireRpc() {
    final rpc = _rpc;
    if (rpc == null) {
      throw StateError('XrplRpcClient is not connected. Call connect() first.');
    }
    return rpc;
  }

  /// Fetch XRP + IOU balances for [address].
  ///
  /// Unfunded accounts (`actNotFound`) map to a zero XRP balance and no lines
  /// without throwing.
  Future<List<LedgerBalance>> fetchBalances(String address) async {
    final rpc = _requireRpc();

    String xrpValue = '0';
    try {
      final info = await rpc.request(XRPRequestAccountInfo(account: address));
      xrpValue = XrpAmount.dropsToXrp(info.accountData.balance);
    } on RPCError catch (e) {
      if (!_isAccountNotFound(e)) rethrow;
      // Unfunded account: treat as zero XRP and skip lines.
      return const [
        LedgerBalance(currency: 'XRP', value: '0'),
      ];
    }

    final balances = <LedgerBalance>[
      LedgerBalance(currency: 'XRP', value: xrpValue),
    ];

    try {
      final lines =
          await rpc.request(XRPRequestAccountLines(account: address));
      for (final line in lines.lines) {
        balances.add(
          LedgerBalance(
            currency: line.currency,
            issuer: line.account,
            value: line.balance,
          ),
        );
      }
    } on RPCError catch (e) {
      if (!_isAccountNotFound(e)) rethrow;
      // Account may have been deleted between calls; keep XRP only.
    }

    return balances;
  }

  /// Fetch recent transactions for [address] as compact summaries.
  ///
  /// Unfunded accounts (`actNotFound`) return an empty list.
  ///
  /// Note: [XRPRequestAccountTx] defaults `ledgerIndex` to `validated`, which
  /// makes public rippled nodes search **only the latest ledger** and return
  /// an empty `transactions` array. We clear that and use the full available
  /// range (`ledger_index_min/max = -1`) so history actually loads.
  Future<List<LedgerTxSummary>> fetchAccountTx(
    String address, {
    int limit = 20,
  }) async {
    final rpc = _requireRpc();
    try {
      final result = await rpc.request(
        XRPRequestAccountTx(
          account: address,
          limit: limit,
          ledgerIndex: null,
          ledgerIndexMin: -1,
          ledgerIndexMax: -1,
        ),
      );
      return result.transactions
          .map(_summarizeTx)
          .whereType<LedgerTxSummary>()
          .toList();
    } on RPCError catch (e) {
      if (_isAccountNotFound(e)) return const [];
      rethrow;
    }
  }

  LedgerTxSummary? _summarizeTx(AccountTxTransactionResult tx) {
    final txJson = tx.txJson;
    final hash = tx.hash ?? txJson?.hash;
    if (hash == null) return null;

    final transaction = txJson?.transaction;
    final type = transaction?.transactionType.value ?? 'Unknown';
    final account = transaction?.account ?? '';

    String? destination;
    String? amountSummary;
    if (transaction is Payment) {
      destination = transaction.destination;
      amountSummary = _formatAmount(transaction.amount);
    }

    return LedgerTxSummary(
      hash: hash,
      ledgerIndex: tx.ledgerIndex ?? txJson?.ledgerIndex,
      transactionType: type,
      account: account,
      destination: destination,
      amountSummary: amountSummary,
      date: txJson?.date,
      validated: tx.validated,
    );
  }

  String _formatAmount(BaseAmount amount) {
    if (amount is XRPAmount) {
      return '${XrpAmount.dropsToXrp(amount.value.toString())} XRP';
    }
    if (amount is IssuedCurrencyAmount) {
      final symbol = CurrencyDisplay.symbol(
        amount.currency,
        issuer: amount.issuer,
      );
      return '${amount.value} $symbol';
    }
    return amount.toJson().toString();
  }

  /// XRPL `actNotFound` means the classic address has never been funded.
  static bool _isAccountNotFound(RPCError error) {
    if (error.message == 'actNotFound') return true;
    final payload = error.jsonRpcErrpr;
    if (payload != null) {
      final code = payload['error']?.toString();
      if (code == 'actNotFound') return true;
    }
    // Some nodes surface the error only in toString / nested request.
    return error.toString().contains('actNotFound');
  }
}
