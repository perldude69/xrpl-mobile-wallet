import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_pair.dart';

/// Which way a ledger entry changed in a transaction's metadata.
enum LedgerNodeChange { created, modified, deleted }

/// What actually moved in and out of one account in one validated
/// transaction.
///
/// Signed from that account's point of view: negative is given up, positive is
/// received.
class AccountBalanceDeltas {
  const AccountBalanceDeltas({required this.base, required this.quote});

  final TradeDecimal base;
  final TradeDecimal quote;

  bool get isEmpty => base.isZero && quote.isZero;

  @override
  String toString() => 'base $base / quote $quote';
}

/// How one specific offer owned by the account changed.
class OfferNodeOutcome {
  const OfferNodeOutcome({
    required this.change,
    required this.sequence,
    this.remainingGets,
    this.remainingPays,
    this.consumedGets,
    this.consumedPays,
  });

  final LedgerNodeChange change;
  final int sequence;

  /// `TakerGets` / `TakerPays` still on the book after this transaction.
  /// Zero-ish on a full consumption; the whole unfilled amount on a cancel.
  final TradeDecimal? remainingGets;
  final TradeDecimal? remainingPays;

  /// How much of each side this transaction took, when the metadata carried a
  /// previous value to subtract from. Null when it did not — a created or
  /// cancelled offer consumes nothing.
  final TradeDecimal? consumedGets;
  final TradeDecimal? consumedPays;

  /// True when the offer is no longer on the book after this transaction.
  bool get isGone => change == LedgerNodeChange.deleted;

  /// True when the offer still rests and can still be filled or cancelled.
  bool get isResting => change != LedgerNodeChange.deleted;
}

/// Reads validated transaction metadata.
///
/// Works on **raw JSON maps** in XRPL's own `AffectedNodes` shape rather than
/// on a package's model classes: this is the one place where a dependency
/// upgrade silently reshaping a field would corrupt recorded fill history, and
/// raw maps can be pinned to captured real-world metadata in tests.
///
/// Fill amounts are always read from here, never computed by subtracting a
/// client-side estimate — issued-currency arithmetic drifts, and a drifting
/// filled total is exactly the lie this module exists to prevent.
///
/// Pure: no I/O, no Flutter.
class FillParser {
  FillParser._();

  static const _accountRoot = 'AccountRoot';
  static const _rippleState = 'RippleState';
  static const _offer = 'Offer';

  /// Net movement of [base] and [quote] for [account] across [affectedNodes].
  ///
  /// [feeDropsPaidByAccount] is added back to the XRP side. The transaction
  /// fee is burnt from the submitter's balance in the same metadata, and
  /// counting it as part of the trade would understate every XRP fill by the
  /// fee. Pass it only when [account] actually submitted the transaction; pass
  /// null when reading someone else's transaction that crossed our offer.
  static AccountBalanceDeltas balanceDeltas({
    required List<Map<String, dynamic>> affectedNodes,
    required String account,
    required TradeAsset base,
    required TradeAsset quote,
    String? feeDropsPaidByAccount,
  }) {
    var baseDelta = TradeDecimal.zero;
    var quoteDelta = TradeDecimal.zero;

    for (final node in affectedNodes) {
      final entry = _entry(node);
      if (entry == null) continue;

      switch (entry.ledgerEntryType) {
        case _accountRoot:
          final owner = _string(entry.after, 'Account');
          if (owner != account) continue;
          final delta = _xrpDelta(entry);
          if (delta == null) continue;
          if (base.isXrp) baseDelta += delta;
          if (quote.isXrp) quoteDelta += delta;

        case _rippleState:
          final delta = _rippleStateDelta(entry, account);
          if (delta == null) continue;
          final currency = _string(
            _amountMap(entry.after, 'Balance'),
            'currency',
          );
          if (currency == null) continue;
          if (!base.isXrp && base.currency == currency) {
            baseDelta += delta;
          } else if (!quote.isXrp && quote.currency == currency) {
            quoteDelta += delta;
          }
      }
    }

    final fee = TradeDecimal.tryParse(feeDropsPaidByAccount);
    if (fee != null && !fee.isZero) {
      final feeXrp = TradeDecimal.fromUnscaled(
        fee.unscaled,
        TradeAsset.xrpScale,
      );
      if (base.isXrp) baseDelta += feeXrp;
      if (quote.isXrp) quoteDelta += feeXrp;
    }

    return AccountBalanceDeltas(base: baseDelta, quote: quoteDelta);
  }

  /// The change to [account]'s offer with [sequence], if this transaction
  /// touched it.
  ///
  /// Matches on account **and** sequence together. An offer sequence is only
  /// unique per account, so matching on sequence alone would happily pick up a
  /// stranger's offer out of the same metadata.
  static OfferNodeOutcome? offerOutcome({
    required List<Map<String, dynamic>> affectedNodes,
    required String account,
    required int sequence,
  }) {
    for (final node in affectedNodes) {
      final entry = _entry(node);
      if (entry == null || entry.ledgerEntryType != _offer) continue;
      if (_string(entry.after, 'Account') != account) continue;
      if (_int(entry.after, 'Sequence') != sequence) continue;

      final finalGets = _amount(entry.after, 'TakerGets');
      final finalPays = _amount(entry.after, 'TakerPays');
      final previousGets = _amount(entry.before, 'TakerGets');
      final previousPays = _amount(entry.before, 'TakerPays');

      return OfferNodeOutcome(
        change: entry.change,
        sequence: sequence,
        remainingGets: finalGets,
        remainingPays: finalPays,
        consumedGets: (previousGets != null && finalGets != null)
            ? previousGets - finalGets
            : null,
        consumedPays: (previousPays != null && finalPays != null)
            ? previousPays - finalPays
            : null,
      );
    }
    return null;
  }

  /// Sequence of the offer [account] created in this transaction, if any.
  ///
  /// An `OfferCreate` that crosses completely creates no offer node at all —
  /// a null here means nothing rests on the book, not that parsing failed.
  static int? createdOfferSequence({
    required List<Map<String, dynamic>> affectedNodes,
    required String account,
  }) {
    for (final node in affectedNodes) {
      final entry = _entry(node);
      if (entry == null || entry.ledgerEntryType != _offer) continue;
      if (entry.change != LedgerNodeChange.created) continue;
      if (_string(entry.after, 'Account') != account) continue;
      final sequence = _int(entry.after, 'Sequence');
      if (sequence != null) return sequence;
    }
    return null;
  }

  /// Parse an XRPL amount field: a drops string for XRP, or a
  /// `{currency, issuer, value}` object for an issued amount.
  ///
  /// Returns null for a missing or unparseable field rather than throwing —
  /// metadata legitimately omits fields, and a single unreadable node must not
  /// abandon the rest of a reconciliation pass.
  static TradeDecimal? parseAmount(Object? value) {
    if (value is String) {
      final drops = TradeDecimal.tryParse(value);
      if (drops == null) return null;
      return TradeDecimal.fromUnscaled(drops.unscaled, TradeAsset.xrpScale);
    }
    if (value is Map) {
      return TradeDecimal.tryParse(value['value']?.toString());
    }
    return null;
  }

  // --- node plumbing -------------------------------------------------------

  static _Entry? _entry(Map<String, dynamic> node) {
    for (final change in LedgerNodeChange.values) {
      final key = switch (change) {
        LedgerNodeChange.created => 'CreatedNode',
        LedgerNodeChange.modified => 'ModifiedNode',
        LedgerNodeChange.deleted => 'DeletedNode',
      };
      final data = node[key];
      if (data is! Map) continue;
      final type = data['LedgerEntryType'];
      if (type is! String) continue;
      return _Entry(
        change: change,
        ledgerEntryType: type,
        after: _fields(
          data[change == LedgerNodeChange.created
              ? 'NewFields'
              : 'FinalFields'],
        ),
        before: _fields(data['PreviousFields']),
      );
    }
    return null;
  }

  static Map<String, dynamic>? _fields(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  /// XRP delta for an AccountRoot node, in XRP (not drops).
  static TradeDecimal? _xrpDelta(_Entry entry) {
    final after = parseAmount(entry.after?['Balance']);
    if (after == null) return null;
    if (entry.change == LedgerNodeChange.created) return after;
    final before = parseAmount(entry.before?['Balance']);
    // A ModifiedNode with no PreviousFields.Balance did not move XRP.
    if (before == null) return null;
    return after - before;
  }

  /// Issued-currency delta for a RippleState node, signed for [account].
  ///
  /// A trust line's `Balance` is always written from the **low** account's
  /// point of view, so it must be negated when our account is the high side.
  /// Getting this backwards turns every buy into a sell in the fill history.
  static TradeDecimal? _rippleStateDelta(_Entry entry, String account) {
    final fields = entry.after ?? entry.before;
    if (fields == null) return null;
    final low = _string(_amountMap(fields, 'LowLimit'), 'issuer');
    final high = _string(_amountMap(fields, 'HighLimit'), 'issuer');

    final bool negate;
    if (low == account) {
      negate = false;
    } else if (high == account) {
      negate = true;
    } else {
      return null;
    }

    final after = parseAmount(entry.after?['Balance']);
    final before = parseAmount(entry.before?['Balance']);
    final TradeDecimal delta;
    if (entry.change == LedgerNodeChange.created) {
      if (after == null) return null;
      delta = after;
    } else if (entry.change == LedgerNodeChange.deleted) {
      if (before == null) return null;
      delta = (after ?? TradeDecimal.zero) - before;
    } else {
      if (after == null || before == null) return null;
      delta = after - before;
    }
    return negate ? -delta : delta;
  }

  static TradeDecimal? _amount(Map<String, dynamic>? fields, String key) =>
      fields == null ? null : parseAmount(fields[key]);

  static Map<String, dynamic>? _amountMap(
    Map<String, dynamic>? fields,
    String key,
  ) {
    final value = fields?[key];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  static String? _string(Map<String, dynamic>? fields, String key) {
    final value = fields?[key];
    return value is String ? value : null;
  }

  static int? _int(Map<String, dynamic>? fields, String key) {
    final value = fields?[key];
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class _Entry {
  const _Entry({
    required this.change,
    required this.ledgerEntryType,
    required this.after,
    required this.before,
  });

  final LedgerNodeChange change;
  final String ledgerEntryType;

  /// `NewFields` for a created node, `FinalFields` otherwise.
  final Map<String, dynamic>? after;

  /// `PreviousFields`, when present.
  final Map<String, dynamic>? before;
}
