import 'package:xrpl_mobile_wallet/data/database/app_database.dart';
import 'package:xrpl_mobile_wallet/data/trade/trade_repository.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/xrpl_rpc_client.dart';
import 'package:xrpl_mobile_wallet/domain/trade/fill_parser.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_pair.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_rate.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_status.dart';

/// What one execution row was resolved to in a reconciliation pass.
class TradeReconcileOutcome {
  const TradeReconcileOutcome({
    required this.executionId,
    required this.from,
    required this.to,
    this.note,
  });

  final String executionId;
  final TradeStatus from;
  final TradeStatus to;

  /// Fixed slug describing why, never raw exception text.
  final String? note;

  bool get changed => from != to;

  @override
  String toString() =>
      '$executionId: ${from.name} → ${to.name}${note == null ? '' : ' ($note)'}';
}

/// Resolves every non-terminal trade row against the ledger.
///
/// This is what makes the trade feature honest. Without it, a submitted order
/// sits at "submitted" forever and the app cannot answer the only question
/// that matters — *did it fill?* Every status this writes is backed by
/// something the ledger actually said.
///
/// Three rules it does not bend:
///
/// 1. **Never blind-retry.** An ambiguous submission stays [TradeStatus.submitted]
///    until a validated transaction or the `LastLedgerSequence` rule proves
///    otherwise. Re-submitting an order that might already be resting is how
///    an account ends up filled twice.
/// 2. **`LastLedgerSequence` is the only proof of death.** Past that ledger
///    with nothing validated, a transaction can never be applied, so it is
///    safe to call [TradeStatus.expired]. Nothing else is.
/// 3. **Fills come from validated metadata only** — see [FillParser]. Never a
///    client-side subtraction.
///
/// **Must run in the UI process**, kicked from `LockLifecycle`. Not in the
/// watcher isolate: a second [AppDatabase] on the same file corrupts it, and
/// the watcher is address-only by design. Not from the Trade screen either —
/// an order placed and then backgrounded has to resolve without anyone
/// looking at it.
class TradeReconciler {
  TradeReconciler({
    required AppDatabase database,
    required TradeRepository repository,
    required XrplRpcClient client,
  }) : _db = database,
       _repository = repository,
       _client = client;

  final AppDatabase _db;
  final TradeRepository _repository;
  final XrplRpcClient _client;

  bool _running = false;

  /// How far back to look for a stranger's transaction that crossed one of our
  /// resting offers. Generous: reconciliation is idempotent, so re-reading the
  /// same range costs nothing but a request.
  static const accountTxLookback = 100;

  /// Reconcile every non-terminal row on the connected network.
  ///
  /// Returns the rows whose status changed. Never throws: a pass that cannot
  /// reach the network, or that trips on one malformed row, must leave the
  /// remaining rows exactly as they were rather than take the app down on
  /// resume.
  Future<List<TradeReconcileOutcome>> reconcileAll() async {
    if (_running) return const [];
    _running = true;
    try {
      if (!_client.isConnected) return const [];
      final network = _client.network;
      if (network == null) return const [];

      final rows = await _repository.activeExecutions();
      if (rows.isEmpty) return const [];

      final int currentLedgerIndex;
      try {
        currentLedgerIndex = await _client.fetchCurrentLedgerIndex();
      } catch (_) {
        // No ledger index means the LastLedgerSequence rule cannot be applied,
        // and every other decision depends on it. Leave everything alone.
        return const [];
      }

      final addresses = {
        for (final wallet in await _db.getAllWallets())
          wallet.id: wallet.address,
      };

      final outcomes = <TradeReconcileOutcome>[];
      for (final row in rows) {
        // Only reconcile rows belonging to the network we are actually talking
        // to. A mainnet row must never be resolved against testnet answers.
        if (row.network != network.name) continue;
        final address = addresses[row.walletId];
        if (address == null) continue;
        try {
          final outcome = await _reconcile(
            row,
            address: address,
            currentLedgerIndex: currentLedgerIndex,
          );
          if (outcome != null && outcome.changed) outcomes.add(outcome);
        } catch (_) {
          // One unreadable row must not abandon the rest of the pass. The row
          // keeps its current status and is retried next time.
          continue;
        }
      }
      return outcomes;
    } finally {
      _running = false;
    }
  }

  Future<TradeReconcileOutcome?> _reconcile(
    TradeExecution row, {
    required String address,
    required int currentLedgerIndex,
  }) async {
    final from = TradeStatus.fromStorage(row.status);
    if (from.isTerminal) return null;

    final txHash = row.txHash;
    if (txHash == null || txHash.isEmpty) {
      // Approved and possibly submitted, but we never learned a hash — the
      // process died between signing and recording it. There is nothing to
      // look up and nothing safe to assume, so park it for the user rather
      // than guess or resubmit.
      if (from == TradeStatus.interrupted) return null;
      await _repository.markStatus(
        row.id,
        TradeStatus.interrupted,
        errorSlug: 'no-tx-hash',
        lastLedgerIndex: currentLedgerIndex,
      );
      return TradeReconcileOutcome(
        executionId: row.id,
        from: from,
        to: TradeStatus.interrupted,
        note: 'no-tx-hash',
      );
    }

    final detail = await _client.fetchTransaction(txHash);

    if (detail == null) {
      final lls = row.lastLedgerSequence;
      if (lls != null && currentLedgerIndex > lls) {
        // Rule 2: past LastLedgerSequence and still not in a validated ledger.
        // This transaction can never be applied — definitively dead, and safe
        // to place a replacement order by hand.
        await _repository.markStatus(
          row.id,
          TradeStatus.expired,
          errorSlug: 'lls-expired',
          lastLedgerIndex: currentLedgerIndex,
        );
        return TradeReconcileOutcome(
          executionId: row.id,
          from: from,
          to: TradeStatus.expired,
          note: 'lls-expired',
        );
      }
      // Still genuinely unknown. Rule 1: leave it alone.
      await _repository.noteReconciledAt(row.id, currentLedgerIndex);
      return null;
    }

    if (detail.isValidatedFailure) {
      await _repository.markStatus(
        row.id,
        TradeStatus.failed,
        errorSlug: 'engine:${detail.transactionResult}',
        lastLedgerIndex: currentLedgerIndex,
      );
      return TradeReconcileOutcome(
        executionId: row.id,
        from: from,
        to: TradeStatus.failed,
        note: 'engine:${detail.transactionResult}',
      );
    }

    if (!detail.isValidatedSuccess) {
      // Found, but not validated yet. Not a fill, not a failure.
      await _repository.noteReconciledAt(row.id, currentLedgerIndex);
      return null;
    }

    return _applyValidatedOffer(
      row,
      address: address,
      detail: detail,
      from: from,
      currentLedgerIndex: currentLedgerIndex,
    );
  }

  /// Resolve a row whose `OfferCreate` is validated and successful.
  Future<TradeReconcileOutcome> _applyValidatedOffer(
    TradeExecution row, {
    required String address,
    required LedgerTxDetail detail,
    required TradeStatus from,
    required int currentLedgerIndex,
  }) async {
    final given = _asset(row.baseCurrency, row.baseIssuer);
    final received = _asset(row.quoteCurrency, row.quoteIssuer);

    await _recordFillFrom(
      detail,
      executionId: row.id,
      address: address,
      given: given,
      received: received,
    );

    // Did any of the order rest on the book?
    var offerSequence =
        row.offerSequence ??
        FillParser.createdOfferSequence(
          affectedNodes: detail.affectedNodes,
          account: address,
        );

    if (offerSequence != null) {
      final resolved = await _resolveRestingOffer(
        row,
        address: address,
        given: given,
        received: received,
        offerSequence: offerSequence,
        currentLedgerIndex: currentLedgerIndex,
      );
      if (resolved != null) {
        return TradeReconcileOutcome(
          executionId: row.id,
          from: from,
          to: resolved.status,
          note: resolved.note,
        );
      }
    }

    // Nothing rests: the order is finished, one way or another.
    final filled = await _repository.filledBaseTotal(row.id);
    final target = TradeDecimal.tryParse(row.targetAmount);
    final complete = target == null || filled >= target;
    final status = complete ? TradeStatus.filled : TradeStatus.cancelled;
    await _repository.markStatus(
      row.id,
      status,
      // A validated OfferCreate that left nothing on the book and filled less
      // than the target had its remainder killed — an IOC/FOK order, or an
      // offer the ledger could not keep. Recorded rather than dressed up as a
      // clean fill.
      errorSlug: complete ? null : 'remainder-killed',
      offerSequence: offerSequence,
      lastLedgerIndex: currentLedgerIndex,
    );
    return TradeReconcileOutcome(
      executionId: row.id,
      from: from,
      to: status,
      note: complete ? null : 'remainder-killed',
    );
  }

  /// Follow an offer that rested on the book after its `OfferCreate`.
  ///
  /// Returns null when the offer is gone and the caller should close the row
  /// out normally.
  Future<({TradeStatus status, String? note})?> _resolveRestingOffer(
    TradeExecution row, {
    required String address,
    required TradeAsset given,
    required TradeAsset received,
    required int offerSequence,
    required int currentLedgerIndex,
  }) async {
    final offers = await _client.fetchAccountOffers(address);
    final onBook = offers.any((offer) => offer.seq == offerSequence);

    if (onBook) {
      final filled = await _repository.filledBaseTotal(row.id);
      final status = filled.isPositive
          ? TradeStatus.partiallyFilled
          : TradeStatus.resting;
      await _repository.markStatus(
        row.id,
        status,
        offerSequence: offerSequence,
        lastLedgerIndex: currentLedgerIndex,
      );
      return (status: status, note: null);
    }

    // The offer has left the book. Somebody's transaction consumed it, or it
    // was cancelled or expired — and the transaction that did it is not one we
    // sent, so it can only be found by looking at what touched the account.
    final cancelled = await _sweepAccountTx(
      row,
      address: address,
      given: given,
      received: received,
      offerSequence: offerSequence,
    );

    final filled = await _repository.filledBaseTotal(row.id);
    final target = TradeDecimal.tryParse(row.targetAmount);

    final TradeStatus status;
    final String? note;
    if (target != null && filled >= target) {
      status = TradeStatus.filled;
      note = null;
    } else if (cancelled) {
      status = TradeStatus.cancelled;
      note = null;
    } else if (row.expiration != null &&
        DateTime.now().isAfter(row.expiration!)) {
      status = TradeStatus.expired;
      note = null;
    } else {
      // Off the book, under target, and we found no cancellation. It is over
      // either way; the slug records that the ending was inferred rather than
      // read directly, so the history does not overstate what is known.
      status = TradeStatus.cancelled;
      note = 'left-book';
    }

    await _repository.markStatus(
      row.id,
      status,
      errorSlug: note,
      offerSequence: offerSequence,
      lastLedgerIndex: currentLedgerIndex,
    );
    return (status: status, note: note);
  }

  /// Scan recent account transactions for anything that touched our offer.
  ///
  /// Records every fill it finds. Returns true when one of them was our own
  /// `OfferCancel` for this offer.
  Future<bool> _sweepAccountTx(
    TradeExecution row, {
    required String address,
    required TradeAsset given,
    required TradeAsset received,
    required int offerSequence,
  }) async {
    final history = await _client.fetchAccountTxDetails(
      address,
      limit: accountTxLookback,
    );
    var cancelled = false;

    for (final detail in history) {
      if (!detail.isValidatedSuccess) continue;
      final outcome = FillParser.offerOutcome(
        affectedNodes: detail.affectedNodes,
        account: address,
        sequence: offerSequence,
      );
      if (outcome == null) continue;

      if (detail.transactionType == 'OfferCancel' &&
          detail.account == address) {
        cancelled = true;
        continue;
      }

      await _recordFillFrom(
        detail,
        executionId: row.id,
        address: address,
        given: given,
        received: received,
        // Only our own submission pays the fee out of our balance; a
        // stranger's transaction that crossed our offer did not.
        accountPaidFee: detail.account == address,
      );
    }
    return cancelled;
  }

  /// Read the amounts that moved for [address] and store them as a fill.
  ///
  /// Skipped silently when nothing moved — an `OfferCreate` that rested
  /// without crossing anything is not a zero-sized fill, it is no fill.
  Future<void> _recordFillFrom(
    LedgerTxDetail detail, {
    required String executionId,
    required String address,
    required TradeAsset given,
    required TradeAsset received,
    bool accountPaidFee = true,
  }) async {
    final ledgerIndex = detail.ledgerIndex;
    if (ledgerIndex == null) return;

    final deltas = FillParser.balanceDeltas(
      affectedNodes: detail.affectedNodes,
      account: address,
      base: given,
      quote: received,
      feeDropsPaidByAccount: accountPaidFee && detail.account == address
          ? detail.feeDrops
          : null,
    );

    // Magnitudes: the direction is already fixed by the row's side, and
    // `filled_amount` is compared against `target_amount`, which is positive.
    final filledGiven = deltas.base.isNegative ? -deltas.base : deltas.base;
    final filledReceived = deltas.quote.isNegative
        ? -deltas.quote
        : deltas.quote;
    if (filledGiven.isZero) return;

    final rate = TradeRates.executedRate(
      baseAmount: filledGiven,
      quoteAmount: filledReceived,
    );
    if (rate == null) return;

    await _repository.recordFill(
      executionId: executionId,
      txHash: detail.hash,
      ledgerIndex: ledgerIndex,
      filledBase: filledGiven,
      filledQuote: filledReceived,
      rate: rate,
      feeDrops: detail.account == address ? detail.feeDrops : null,
      date: _rippleEpoch(detail.date),
    );
  }

  static TradeAsset _asset(String currency, String? issuer) =>
      (issuer == null || issuer.isEmpty)
      ? TradeAsset.xrp
      : TradeAsset.issued(currency: currency, issuer: issuer);

  /// XRPL ledger "date" is seconds since 2000-01-01 UTC.
  static DateTime _rippleEpoch(int? seconds) => seconds == null
      ? DateTime.now().toUtc()
      : DateTime.utc(2000, 1, 1).add(Duration(seconds: seconds));
}
