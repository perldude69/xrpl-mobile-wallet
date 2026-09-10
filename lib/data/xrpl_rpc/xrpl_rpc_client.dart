import 'dart:convert';
import 'package:blockchain_utils/exception/exceptions.dart';
import 'package:http/http.dart' as http;
import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/config/network_id.dart';
import 'package:xrpl_mobile_wallet/domain/amount/xrp_amount.dart';
import 'package:xrpl_mobile_wallet/data/payments/payment_service.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/rpc_http_client.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/currency_display.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/rich_list_book_offers_request.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/rich_list_account_offers_request.dart';
import 'package:xrpl_mobile_wallet/domain/payments/batch_plan.dart';

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

class AccountReserveInfo {
  const AccountReserveInfo({
    required this.xrpBalanceDrops,
    required this.ownerCount,
    required this.baseReserveDrops,
    required this.incrementDrops,
  });

  final BigInt xrpBalanceDrops;
  final int ownerCount;
  final BigInt baseReserveDrops;
  final BigInt incrementDrops;

  BigInt get currentReserveDrops =>
      baseReserveDrops + incrementDrops * BigInt.from(ownerCount);
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

/// One validated (or still-pending) transaction, with the metadata the trade
/// reconciler needs to decide what actually happened.
///
/// [affectedNodes] is deliberately raw JSON in XRPL's own shape rather than a
/// package model: fill amounts are read from it by
/// `domain/trade/fill_parser.dart`, which is pinned to captured real metadata
/// in tests and must not move when a dependency reshapes its classes.
class LedgerTxDetail {
  const LedgerTxDetail({
    required this.hash,
    required this.transactionType,
    required this.account,
    required this.affectedNodes,
    this.ledgerIndex,
    this.validated,
    this.transactionResult,
    this.sequence,
    this.lastLedgerSequence,
    this.feeDrops,
    this.date,
  });

  final String hash;
  final String transactionType;
  final String account;

  /// `meta.AffectedNodes`, unmodified.
  final List<Map<String, dynamic>> affectedNodes;

  final int? ledgerIndex;
  final bool? validated;

  /// Engine result recorded in the validated metadata, e.g. `tesSUCCESS`.
  final String? transactionResult;

  final int? sequence;
  final int? lastLedgerSequence;
  final String? feeDrops;

  /// Ledger close time in Ripple-epoch seconds.
  final int? date;

  /// True only when the ledger has validated this transaction *and* it
  /// succeeded. Anything else — pending, failed, unknown — is not a fill.
  bool get isValidatedSuccess =>
      validated == true && transactionResult == 'tesSUCCESS';

  /// True when the ledger validated the transaction but the engine rejected
  /// it. Terminal: this transaction will never do anything.
  bool get isValidatedFailure =>
      validated == true &&
      transactionResult != null &&
      transactionResult != 'tesSUCCESS';
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
          defaultTimeout: const Duration(seconds: 30),
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

  /// Raw validated JSON-RPC for ledger object methods not modelled by xrpl_dart.
  Future<Map<String, dynamic>> requestJson(
    String method,
    Map<String, dynamic> params,
  ) async {
    final client = _httpClient;
    final url = _activeHttpUrl;
    if (client == null || url == null) throw StateError('RPC is not connected');
    final response = await client.post(
      Uri.parse(url),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'method': method,
        'params': [params],
      }),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['status'] == 'error') {
      throw StateError('Ledger request failed');
    }
    return Map<String, dynamic>.from(body['result'] as Map);
  }

  /// Whether the connected node has enabled [BatchAmendment.name] (BatchV1_1).
  ///
  /// False on RPC errors so the UI stays hidden rather than offering a submit
  /// that the ledger will reject with `temDISABLED`.
  Future<bool> batchAmendmentEnabled() async {
    try {
      final result = await requestJson('feature', const {});
      if (BatchAmendment.isEnabled(result)) return true;
      final named = result[BatchAmendment.name];
      if (named is Map && named['enabled'] == true) return true;
    } catch (_) {}
    try {
      final result = await requestJson('feature', {
        'feature': BatchAmendment.name,
      });
      if (result['enabled'] == true) return true;
      return BatchAmendment.isEnabled(result);
    } catch (_) {
      return false;
    }
  }

  /// Minimum open-ledger fee in drops (same [XrplFeeType.minimum] autoFill uses).
  Future<BigInt> fetchMinimumFeeDrops() async {
    final rpc = _requireRpc();
    final result = await rpc.request(XRPRequestFee());
    return result.getFeeType(type: XrplFeeType.minimum);
  }

  /// Owner-reserve increment in drops (per owned ledger object, e.g. a resting
  /// offer), from the validated ledger in `server_info`. `null` if the server
  /// did not report it.
  Future<BigInt?> fetchOwnerReserveIncrementDrops() async {
    final rpc = _requireRpc();
    final result = await rpc.request(XRPRequestServerInfo());
    final incXrp = result.info.validatedLedger?.reserveIncXrp;
    if (incXrp == null) return null;
    return BigInt.from((incXrp * 1000000).round());
  }

  Future<AccountReserveInfo> fetchAccountReserveInfo(String address) async {
    final rpc = _requireRpc();
    final info = await rpc.request(XRPRequestAccountInfo(account: address));
    final server = await rpc.request(XRPRequestServerInfo());
    final ledger = server.info.validatedLedger;
    if (ledger == null) {
      throw const FormatException('Reserve data unavailable.');
    }
    return AccountReserveInfo(
      xrpBalanceDrops: BigInt.parse(info.accountData.balance),
      ownerCount: info.accountData.ownerCount,
      baseReserveDrops: BigInt.from((ledger.reserveBaseXrp * 1000000).round()),
      incrementDrops: BigInt.from((ledger.reserveIncXrp * 1000000).round()),
    );
  }

  /// Fetch validated offers currently owned by [address].
  Future<List<AccountOffer>> fetchAccountOffers(String address) async {
    final result = await _requireRpc().request(
      RichListAccountOffersRequest(account: address, limit: 200),
    );
    final rows = result['offers'] as List? ?? const [];
    return [
      for (final raw in rows)
        AccountOffer.fromJson({
          'flags': raw['Flags'] ?? raw['flags'] ?? 0,
          'seq': raw['Sequence'] ?? raw['seq'],
          'taker_gets': raw['TakerGets'] ?? raw['taker_gets'],
          'taker_pays': raw['TakerPays'] ?? raw['taker_pays'],
          'quality': raw['quality'] ?? '',
          'expiration': raw['Expiration'] ?? raw['expiration'],
        }),
    ];
  }

  /// Fetch one validated side of an order book. The caller supplies the
  /// currency descriptors because `book_offers` treats XRP as native currency
  /// and issued assets as `{currency, issuer}` objects.
  Future<Map<String, dynamic>> fetchBookOffers({
    required BaseCurrency takerGets,
    required BaseCurrency takerPays,
    int limit = 20,
  }) async {
    return _requireRpc().request(
      RichListBookOffersRequest(
        takerGets: takerGets.toJson(),
        takerPays: takerPays.toJson(),
        limit: limit,
      ),
    );
  }

  /// Index of the ledger currently being built.
  ///
  /// The reconciler compares this against a transaction's
  /// `LastLedgerSequence`: once the network is past that ledger and the
  /// transaction is still not in a validated one, it can never be validated,
  /// which is the only safe basis for calling a submission definitively dead.
  Future<int> fetchCurrentLedgerIndex() async {
    final rpc = _requireRpc();
    return rpc.request(XRPRequestLedgerCurrent());
  }

  Future<int> fetchValidatedLedgerIndex() async {
    final ledger = (await _requireRpc().request(
      XRPRequestServerInfo(),
    )).info.validatedLedger;
    if (ledger == null) {
      throw const FormatException('Validated ledger unavailable.');
    }
    return ledger.seq;
  }

  /// Look up one transaction by [hash].
  ///
  /// Returns null when the node does not know the transaction (`txnNotFound`).
  /// That is genuinely ambiguous — the transaction may simply not have reached
  /// this node yet — so callers must not read it as failure on its own; pair
  /// it with the `LastLedgerSequence` rule.
  Future<LedgerTxDetail?> fetchTransaction(String hash) async {
    final rpc = _requireRpc();
    try {
      final result = await rpc.request(XRPRequestTx(transaction: hash));
      final meta = result.meta ?? result.metaBlob;
      final tx = result.txJson;
      return LedgerTxDetail(
        hash: result.hash,
        transactionType: tx.transactionType.value,
        account: tx.account,
        affectedNodes: [
          for (final node in meta?.affectedNodes ?? const [])
            Map<String, dynamic>.from(node.toJson()),
        ],
        ledgerIndex: result.ledgerIndex,
        validated: result.validated,
        transactionResult: meta?.transactionResult,
        sequence: tx.sequence,
        lastLedgerSequence: tx.lastLedgerSequence,
        feeDrops: tx.fee?.toString(),
        date: result.date,
      );
    } on RPCError catch (e) {
      if (_isTransactionNotFound(e)) return null;
      rethrow;
    }
  }

  /// Recent transactions affecting [address], **with their metadata**.
  ///
  /// `account_tx` includes transactions that merely touched the account, which
  /// is exactly what is needed to find a stranger's transaction that crossed
  /// one of our resting offers — that fill appears in no transaction we sent.
  ///
  /// Unfunded accounts return an empty list.
  Future<List<LedgerTxDetail>> fetchAccountTxDetails(
    String address, {
    int limit = 50,
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
      final details = <LedgerTxDetail>[];
      for (final entry in result.transactions) {
        final txJson = entry.txJson;
        final transaction = txJson?.transaction;
        final hash = entry.hash ?? txJson?.hash;
        if (transaction == null || hash == null) continue;
        details.add(
          LedgerTxDetail(
            hash: hash,
            transactionType: transaction.transactionType.value,
            account: transaction.account,
            affectedNodes: [
              for (final node in entry.meta?.affectedNodes ?? const [])
                Map<String, dynamic>.from(node.toJson()),
            ],
            ledgerIndex: entry.ledgerIndex ?? txJson?.ledgerIndex,
            validated: entry.validated,
            transactionResult: entry.meta?.transactionResult,
            sequence: transaction.sequence,
            lastLedgerSequence: transaction.lastLedgerSequence,
            feeDrops: transaction.fee?.toString(),
            date: txJson?.date,
          ),
        );
      }
      return details;
    } on RPCError catch (e) {
      if (_isAccountNotFound(e)) return const [];
      rethrow;
    }
  }

  /// Destination flags that affect send safety. Unfunded accounts are allowed.
  Future<DestinationAccountPolicy> fetchDestinationPolicy(
    String address,
  ) async {
    final rpc = _requireRpc();
    try {
      final info = await rpc.request(XRPRequestAccountInfo(account: address));
      final decoded = info.accountFlags;
      if (decoded != null) {
        return DestinationAccountPolicy(
          exists: true,
          requireDestinationTag: decoded.requireDestinationTag,
          disallowIncomingXrp: decoded.disallowIncomingXRP,
        );
      }
      return DestinationAccountPolicy.fromFlags(info.accountData.flags);
    } on RPCError catch (e) {
      if (_isAccountNotFound(e)) return DestinationAccountPolicy.unfunded;
      rethrow;
    }
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
      return const [LedgerBalance(currency: 'XRP', value: '0')];
    }

    final balances = <LedgerBalance>[
      LedgerBalance(currency: 'XRP', value: xrpValue),
    ];

    try {
      final lines = await rpc.request(XRPRequestAccountLines(account: address));
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

  /// XRPL `txnNotFound` means this node has no record of the transaction —
  /// which covers both "never submitted" and "not here yet".
  static bool _isTransactionNotFound(RPCError error) =>
      _hasErrorCode(error, 'txnNotFound');

  /// XRPL `actNotFound` means the classic address has never been funded.
  static bool _isAccountNotFound(RPCError error) =>
      _hasErrorCode(error, 'actNotFound');

  /// Public rippled nodes report error codes inconsistently — as the message,
  /// in the JSON-RPC error payload, or only in the rendered string.
  static bool _hasErrorCode(RPCError error, String code) {
    if (error.message == code) return true;
    final payload = error.jsonRpcErrpr;
    if (payload != null && payload['error']?.toString() == code) return true;
    // Some nodes surface the error only in toString / nested request.
    return error.toString().contains(code);
  }
}
