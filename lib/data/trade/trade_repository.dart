import 'package:drift/drift.dart' show Value;
import 'package:xrpl_mobile_wallet/data/database/app_database.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_pair.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_status.dart';

/// The only place that reads or writes the trade tables.
///
/// Everything above this (controller, reconciler, UI) speaks in domain types
/// and never sees a Drift companion. Keeping the write paths in one file is
/// what makes the "`filled_amount` is the sum of validated fills, never a
/// client-side subtraction" rule enforceable rather than aspirational.
///
/// Holds no secrets: trade rows are public metadata — addresses, amounts,
/// hashes, and a fixed error slug. Nothing here may ever carry key material or
/// raw exception text.
class TradeRepository {
  TradeRepository(this._db);

  final AppDatabase _db;

  /// Persist a freshly signed order.
  ///
  /// Called **after** the PIN has been verified, never before: an abandoned
  /// draft must not leave a row behind claiming an order exists (XRW-31).
  /// The row starts at [TradeStatus.signing] because that is the truth at this
  /// point — approved and being submitted, outcome unknown.
  /// [given] / [received] are the assets as actually traded, not as inferred
  /// from a pair: the row must record what was signed, so a future
  /// reconciliation reads back the same two assets that moved.
  Future<void> createSigningExecution({
    required String id,
    required String walletId,
    required String network,
    required TradeAsset given,
    required TradeAsset received,
    required TradeSide side,
    required String targetAmount,
    required String orderType,
    DateTime? expiration,
  }) async {
    final now = DateTime.now();
    final base = given;
    final quote = received;
    await _db.upsertTradeExecution(
      TradeExecutionsCompanion.insert(
        id: id,
        walletId: walletId,
        network: network,
        side: side.storageValue,
        baseCurrency: base.currency,
        baseIssuer: Value(base.issuer),
        quoteCurrency: quote.currency,
        quoteIssuer: Value(quote.issuer),
        targetAmount: targetAmount,
        orderType: orderType,
        status: TradeStatus.signing.storageValue,
        expiration: Value(expiration),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Record that a transaction reached a node.
  ///
  /// [lastLedgerSequence] is the whole basis of the later "definitively
  /// failed" decision, so it is stored at submit time rather than looked up
  /// afterwards — by the time a submission looks stuck, the transaction that
  /// would have told us is the one we cannot find.
  Future<void> markSubmitted(
    String id, {
    required String txHash,
    int? lastLedgerSequence,
  }) => _db.updateTradeExecutionProgress(
    id,
    status: TradeStatus.submitted.storageValue,
    txHash: txHash,
    lastLedgerSequence: lastLedgerSequence,
    clearLastError: true,
  );

  Future<void> markStatus(
    String id,
    TradeStatus status, {
    String? errorSlug,
    int? offerSequence,
    int? lastLedgerIndex,
  }) => _db.updateTradeExecutionProgress(
    id,
    status: status.storageValue,
    lastError: errorSlug,
    clearLastError: errorSlug == null,
    offerSequence: offerSequence,
    lastLedgerIndex: lastLedgerIndex,
  );

  Future<void> noteReconciledAt(String id, int ledgerIndex) =>
      _db.updateTradeExecutionProgress(id, lastLedgerIndex: ledgerIndex);

  Future<TradeExecution?> execution(String id) => _db.getTradeExecution(id);

  /// Every row the reconciler still owes an answer on, across all wallets.
  Future<List<TradeExecution>> activeExecutions() =>
      _db.getActiveTradeExecutions();

  Future<List<TradeExecution>> executionsForWallet(String walletId) =>
      _db.getTradeExecutionsForWallet(walletId);

  Future<List<TradeFill>> fills(String executionId) =>
      _db.getTradeFills(executionId);

  /// Record one validated fill and refresh the execution's filled total.
  ///
  /// Idempotent: the fill's primary key is (executionId, txHash), and the
  /// total is recomputed by **summing the stored fills** rather than adding to
  /// a running figure. Replaying the same ledger range therefore cannot
  /// double-count, which is what lets reconciliation run on every resume
  /// without keeping a high-water mark it might get wrong.
  Future<void> recordFill({
    required String executionId,
    required String txHash,
    required int ledgerIndex,
    required TradeDecimal filledBase,
    required TradeDecimal filledQuote,
    required TradeDecimal rate,
    String? feeDrops,
    required DateTime date,
  }) async {
    await _db.upsertTradeFill(
      TradeFillsCompanion.insert(
        executionId: executionId,
        txHash: txHash,
        ledgerIndex: ledgerIndex,
        filledBase: filledBase.toString(),
        filledQuote: filledQuote.toString(),
        rate: rate.toString(),
        feeDrops: Value(feeDrops),
        date: date,
      ),
    );
    await _db.updateTradeExecutionProgress(
      executionId,
      filledAmount: (await filledBaseTotal(executionId)).toString(),
    );
  }

  /// Sum of every recorded fill's base amount, as an exact decimal.
  Future<TradeDecimal> filledBaseTotal(String executionId) async {
    var total = TradeDecimal.zero;
    for (final fill in await _db.getTradeFills(executionId)) {
      final value = TradeDecimal.tryParse(fill.filledBase);
      if (value != null) total += value;
    }
    return total;
  }
}
