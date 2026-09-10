import 'package:xrpl_dart/xrpl_dart.dart';
import 'dart:convert';
import 'package:blockchain_utils/utils/utils.dart';
import 'package:xrpl_mobile_wallet/data/payments/payment_service.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/xrpl_rpc_client.dart';
import 'package:xrpl_mobile_wallet/domain/amount/xrp_amount.dart';

class XrpEscrow {
  const XrpEscrow({
    required this.owner,
    required this.sequence,
    required this.entry,
    this.index,
  });
  final String owner;
  final int sequence;
  final Map<String, dynamic> entry;
  final String? index;

  String get id => '$owner:$sequence';
  String? get finishAfter => entry['FinishAfter']?.toString();
  String? get cancelAfter => entry['CancelAfter']?.toString();
  DateTime? get finishAfterUtc => rippleEpochToUtc(finishAfter);
  DateTime? get cancelAfterUtc => rippleEpochToUtc(cancelAfter);
  String get amountDrops => entry['Amount']?.toString() ?? '0';
  String get destination => entry['Destination']?.toString() ?? '';
  String? get destinationTag => entry['DestinationTag']?.toString();

  bool get conditional => entry['Condition'] != null;
  bool get isXrpAmount {
    final amount = entry['Amount'];
    return amount is String || amount is num;
  }

  String get amountXrp {
    if (!isXrpAmount) return amountDrops;
    try {
      return XrpAmount.dropsToXrp(amountDrops);
    } catch (_) {
      return amountDrops;
    }
  }

  /// XRPL: Finish is valid after FinishAfter and before CancelAfter.
  bool canFinishAt(DateTime nowUtc) {
    if (conditional || !isXrpAmount) return false;
    final cancel = cancelAfterUtc;
    if (cancel != null && !nowUtc.isBefore(cancel)) return false;
    final finish = finishAfterUtc;
    if (finish != null) return !nowUtc.isBefore(finish);
    return true;
  }

  /// XRPL: Cancel is valid only after CancelAfter.
  bool canCancelAt(DateTime nowUtc) {
    if (conditional || !isXrpAmount) return false;
    final cancel = cancelAfterUtc;
    return cancel != null && !nowUtc.isBefore(cancel);
  }

  String statusAt(DateTime nowUtc) {
    if (conditional) return 'Conditional escrow (not supported)';
    if (!isXrpAmount) return 'Token escrow (not supported)';
    if (canFinishAt(nowUtc)) return 'Ready to finish';
    if (canCancelAt(nowUtc)) return 'Expired · refund available';
    return 'Locked';
  }

  /// XRPL time fields are seconds since 2000-01-01 00:00:00 UTC.
  static DateTime? rippleEpochToUtc(String? value) {
    final seconds = int.tryParse(value ?? '');
    if (seconds == null) return null;
    return DateTime.utc(2000, 1, 1).add(Duration(seconds: seconds));
  }
}

class EscrowCreateRef {
  const EscrowCreateRef({
    required this.owner,
    required this.sequence,
    required this.destination,
  });
  final String owner;
  final int sequence;
  final String destination;
}

class EscrowCatalog {
  const EscrowCatalog({required this.escrows, this.hadErrors = false});
  final List<XrpEscrow> escrows;
  final bool hadErrors;
}

class EscrowService {
  EscrowService(this.rpc, {PaymentService? payments})
    : payments = payments ?? PaymentService();
  final XrplRpcClient rpc;
  final PaymentService payments;

  Future<List<XrpEscrow>> list(String address) async {
    final result = await rpc.requestJson('account_objects', {
      'account': address,
      'ledger_index': 'validated',
      'type': 'escrow',
    });
    if (_rpcFailed(result)) return const [];
    return ((result['account_objects'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where(
          (e) => e['OwnerNode'] != null || e['LedgerEntryType'] == 'Escrow',
        )
        .map(
          (e) => XrpEscrow(
            owner: e['Account']?.toString() ?? address,
            sequence: int.tryParse(e['Sequence']?.toString() ?? '') ?? -1,
            index: e['index']?.toString(),
            entry: e,
          ),
        )
        .where((e) => e.sequence >= 0)
        .toList();
  }

  /// Owned objects plus still-open incoming escrows found in recent
  /// `account_tx` history. Incoming lookup is best-effort: older creates that
  /// have fallen out of history can still be opened via [inspect].
  Future<EscrowCatalog> listVisible(Iterable<String> addresses) async {
    final local = addresses.where((a) => a.trim().isNotEmpty).toSet();
    var hadErrors = false;
    final byId = <String, XrpEscrow>{};

    Future<void> collect(Future<List<XrpEscrow>> Function(String) load) async {
      for (final address in local) {
        try {
          for (final escrow in await load(address)) {
            byId[escrow.id] = escrow;
          }
        } catch (_) {
          hadErrors = true;
        }
      }
    }

    await collect(list);
    await collect(listIncoming);
    return EscrowCatalog(
      escrows: byId.values.toList()..sort((a, b) => a.id.compareTo(b.id)),
      hadErrors: hadErrors,
    );
  }

  Future<List<XrpEscrow>> listIncoming(String destination) async {
    final refs = await _incomingCreateRefs(destination);
    if (refs.isEmpty) return const [];
    final sequencesByOwner = <String, Set<int>>{};
    for (final ref in refs) {
      if (ref.owner == destination) continue;
      sequencesByOwner.putIfAbsent(ref.owner, () => {}).add(ref.sequence);
    }
    final found = <XrpEscrow>[];
    for (final entry in sequencesByOwner.entries) {
      try {
        final listed = await list(entry.key);
        found.addAll(
          listed.where(
            (e) =>
                e.destination == destination &&
                entry.value.contains(e.sequence),
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return found;
  }

  Future<XrpEscrow?> inspect({
    required String owner,
    required int sequence,
  }) async {
    final listed = await list(owner);
    final found = listed.where((e) => e.sequence == sequence).firstOrNull;
    if (found?.index == null) return null;
    final result = await rpc.requestJson('ledger_entry', {
      'ledger_index': 'validated',
      'index': found!.index,
    });
    if (_rpcFailed(result)) return null;
    final e = result['node'] ?? result['node_binary'];
    if (e is! Map || e['LedgerEntryType'] != 'Escrow') return null;
    return XrpEscrow(
      owner: owner,
      sequence: sequence,
      index: found.index,
      entry: Map<String, dynamic>.from(e),
    );
  }

  Future<PaymentSubmitResult> finish({
    required XrpEscrow escrow,
    required String feeAccount,
    required String secret,
    required XRPProvider provider,
    required String walletId,
    required String network,
    String? memo,
    String? expectedFeeDrops,
  }) => payments.signAndSubmitTransaction(
    walletId: walletId,
    network: network,
    secret: secret,
    fromAddress: feeAccount,
    rpc: provider,
    expectedFeeDrops: expectedFeeDrops,
    build: (pub) => EscrowFinish(
      account: feeAccount,
      owner: escrow.owner,
      offerSequence: escrow.sequence,
      signer: XRPLSignature.signer(pub),
      memos: _memo(memo),
    ),
  );

  Future<PaymentSubmitResult> cancel({
    required XrpEscrow escrow,
    required String feeAccount,
    required String secret,
    required XRPProvider provider,
    required String walletId,
    required String network,
    String? memo,
    String? expectedFeeDrops,
  }) => payments.signAndSubmitTransaction(
    walletId: walletId,
    network: network,
    secret: secret,
    fromAddress: feeAccount,
    rpc: provider,
    expectedFeeDrops: expectedFeeDrops,
    build: (pub) => EscrowCancel(
      account: feeAccount,
      owner: escrow.owner,
      offerSequence: escrow.sequence,
      signer: XRPLSignature.signer(pub),
      memos: _memo(memo),
    ),
  );

  Future<PaymentSubmitResult> finishWithLedger({
    required XrpEscrow escrow,
    required String feeAccount,
    required String walletId,
    required String network,
    required XRPProvider provider,
    required String publicKeyHex,
    required Future<String> Function(List<int>) signTransactionBlob,
    String? memo,
    String? expectedFeeDrops,
  }) => payments.signAndSubmitWithLedgerKeys(
    walletId: walletId,
    network: network,
    fromAddress: feeAccount,
    rpc: provider,
    publicKeyHex: publicKeyHex,
    signTransactionBlob: signTransactionBlob,
    expectedFeeDrops: expectedFeeDrops,
    build: (pub) => EscrowFinish(
      account: feeAccount,
      owner: escrow.owner,
      offerSequence: escrow.sequence,
      signer: XRPLSignature.signer(pub),
      memos: _memo(memo),
    ),
  );

  Future<PaymentSubmitResult> cancelWithLedger({
    required XrpEscrow escrow,
    required String feeAccount,
    required String walletId,
    required String network,
    required XRPProvider provider,
    required String publicKeyHex,
    required Future<String> Function(List<int>) signTransactionBlob,
    String? memo,
    String? expectedFeeDrops,
  }) => payments.signAndSubmitWithLedgerKeys(
    walletId: walletId,
    network: network,
    fromAddress: feeAccount,
    rpc: provider,
    publicKeyHex: publicKeyHex,
    signTransactionBlob: signTransactionBlob,
    expectedFeeDrops: expectedFeeDrops,
    build: (pub) => EscrowCancel(
      account: feeAccount,
      owner: escrow.owner,
      offerSequence: escrow.sequence,
      signer: XRPLSignature.signer(pub),
      memos: _memo(memo),
    ),
  );

  Future<List<EscrowCreateRef>> _incomingCreateRefs(String destination) async {
    final refs = <EscrowCreateRef>[];
    dynamic marker;
    for (var page = 0; page < 3; page++) {
      final params = <String, dynamic>{
        'account': destination,
        'ledger_index_min': -1,
        'ledger_index_max': -1,
        'limit': 200,
        'forward': false,
      };
      if (marker != null) params['marker'] = marker;
      final Map<String, dynamic> result;
      try {
        result = await rpc.requestJson('account_tx', params);
      } catch (_) {
        break;
      }
      if (_rpcFailed(result)) break;
      refs.addAll(
        escrowCreatesFromAccountTx(
          result,
        ).where((ref) => ref.destination == destination),
      );
      marker = result['marker'];
      if (marker == null) break;
    }
    return refs;
  }

  /// Pulls successful `EscrowCreate` owner/sequence/destination tuples out of
  /// an `account_tx` result. Accepts both `tx` and `tx_json` shapes.
  static List<EscrowCreateRef> escrowCreatesFromAccountTx(
    Map<String, dynamic> result,
  ) {
    final rows = result['transactions'];
    if (rows is! List) return const [];
    final refs = <EscrowCreateRef>[];
    for (final row in rows) {
      if (row is! Map) continue;
      if (!_isTesSuccess(row)) continue;
      final tx = _transactionMap(row);
      if (tx == null) continue;
      if (tx['TransactionType']?.toString() != 'EscrowCreate') continue;
      final owner = tx['Account']?.toString() ?? '';
      final destination = tx['Destination']?.toString() ?? '';
      final sequence = int.tryParse(tx['Sequence']?.toString() ?? '') ?? -1;
      if (owner.isEmpty || destination.isEmpty || sequence < 0) continue;
      refs.add(
        EscrowCreateRef(
          owner: owner,
          sequence: sequence,
          destination: destination,
        ),
      );
    }
    return refs;
  }

  static bool _rpcFailed(Map<String, dynamic> result) =>
      result['error'] != null || result['status'] == 'error';

  static bool _isTesSuccess(Map<dynamic, dynamic> row) {
    final meta = row['meta'] ?? row['Meta'];
    if (meta is Map) {
      final code = meta['TransactionResult'] ?? meta['transactionResult'];
      if (code != null) return code.toString() == 'tesSUCCESS';
    }
    return true;
  }

  static Map<String, dynamic>? _transactionMap(Map<dynamic, dynamic> row) {
    for (final key in const ['tx', 'tx_json', 'transaction']) {
      final value = row[key];
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        final nested = map['transaction'];
        if (nested is Map && nested['TransactionType'] != null) {
          return Map<String, dynamic>.from(nested);
        }
        if (map['TransactionType'] != null) return map;
      }
    }
    if (row['TransactionType'] != null) {
      return Map<String, dynamic>.from(row);
    }
    return null;
  }

  static List<XRPLMemo>? _memo(String? text) {
    final value = text?.trim();
    return value == null || value.isEmpty
        ? null
        : [XRPLMemo(memoData: BytesUtils.toHexString(utf8.encode(value)))];
  }
}
