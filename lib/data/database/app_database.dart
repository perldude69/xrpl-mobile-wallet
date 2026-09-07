import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_status.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Wallets,
    Balances,
    CachedTxs,
    AppSettingsRows,
    TradeExecutions,
    TradeFills,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(wallets, wallets.accentColor);
      }
      if (from < 3) {
        await m.addColumn(wallets, wallets.useLedger);
        await m.addColumn(wallets, wallets.ledgerAccountIndex);
      }
      if (from < 4) {
        await m.createTable(tradeExecutions);
        await m.createTable(tradeFills);
      }
    },
  );

  Future<List<Wallet>> getAllWallets() =>
      (select(wallets)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();

  Future<Wallet?> getWalletById(String id) =>
      (select(wallets)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertWallet(WalletsCompanion row) =>
      into(wallets).insertOnConflictUpdate(row);

  Future<void> updateWalletLabel(String id, String label) async {
    await (update(wallets)..where((t) => t.id.equals(id))).write(
      WalletsCompanion(label: Value(label)),
    );
  }

  Future<void> updateWalletAccentColor(String id, int? accentArgb) async {
    await (update(wallets)..where((t) => t.id.equals(id))).write(
      WalletsCompanion(accentColor: Value(accentArgb)),
    );
  }

  Future<void> updateWalletLedger({
    required String id,
    required bool useLedger,
    int ledgerAccountIndex = 0,
  }) async {
    await (update(wallets)..where((t) => t.id.equals(id))).write(
      WalletsCompanion(
        useLedger: Value(useLedger),
        ledgerAccountIndex: Value(ledgerAccountIndex),
      ),
    );
  }

  Future<void> deleteWalletById(String id) =>
      (delete(wallets)..where((t) => t.id.equals(id))).go();

  Future<void> deleteWalletCascade(String id) async {
    await (delete(balances)..where((t) => t.walletId.equals(id))).go();
    await (delete(cachedTxs)..where((t) => t.walletId.equals(id))).go();
    // Trade rows too: a non-terminal execution belonging to a deleted wallet
    // would otherwise be reconciled forever against an address the app no
    // longer holds.
    final executions = await getTradeExecutionsForWallet(id);
    for (final execution in executions) {
      await (delete(
        tradeFills,
      )..where((t) => t.executionId.equals(execution.id))).go();
    }
    await (delete(tradeExecutions)..where((t) => t.walletId.equals(id))).go();
    await deleteWalletById(id);
  }

  Future<List<Balance>> getBalancesForWallet(String walletId) =>
      (select(balances)..where((t) => t.walletId.equals(walletId))).get();

  Future<void> upsertBalance(BalancesCompanion row) =>
      into(balances).insertOnConflictUpdate(row);

  Future<void> replaceBalances(
    String walletId,
    List<BalancesCompanion> rows,
  ) async {
    await (delete(balances)..where((t) => t.walletId.equals(walletId))).go();
    for (final row in rows) {
      await into(balances).insert(row);
    }
  }

  Future<void> upsertCachedTx(CachedTxsCompanion row) =>
      into(cachedTxs).insertOnConflictUpdate(row);

  Future<void> upsertCachedTxs(List<CachedTxsCompanion> rows) async {
    for (final row in rows) {
      await into(cachedTxs).insertOnConflictUpdate(row);
    }
  }

  Future<void> upsertTradeExecution(TradeExecutionsCompanion row) =>
      into(tradeExecutions).insertOnConflictUpdate(row);

  Future<void> updateTradeExecutionStatus(
    String id, {
    required String status,
    String? lastError,
  }) async {
    await (update(tradeExecutions)..where((t) => t.id.equals(id))).write(
      TradeExecutionsCompanion(
        status: Value(status),
        lastError: Value(lastError),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<TradeExecution?> getTradeExecution(String id) => (select(
    tradeExecutions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Record what the ledger said about an execution.
  ///
  /// Every field is optional and only written when supplied, so a
  /// reconciliation pass that learns one fact (a tx hash, say) cannot blank
  /// out the others. [clearLastError] is explicit for the same reason: `null`
  /// means "unchanged" here, never "clear it".
  Future<void> updateTradeExecutionProgress(
    String id, {
    String? status,
    String? lastError,
    bool clearLastError = false,
    String? txHash,
    int? offerSequence,
    int? lastLedgerSequence,
    int? lastLedgerIndex,
    String? filledAmount,
  }) async {
    await (update(tradeExecutions)..where((t) => t.id.equals(id))).write(
      TradeExecutionsCompanion(
        status: status == null ? const Value.absent() : Value(status),
        lastError: clearLastError
            ? const Value(null)
            : (lastError == null ? const Value.absent() : Value(lastError)),
        txHash: txHash == null ? const Value.absent() : Value(txHash),
        offerSequence: offerSequence == null
            ? const Value.absent()
            : Value(offerSequence),
        lastLedgerSequence: lastLedgerSequence == null
            ? const Value.absent()
            : Value(lastLedgerSequence),
        lastLedgerIndex: lastLedgerIndex == null
            ? const Value.absent()
            : Value(lastLedgerIndex),
        filledAmount: filledAmount == null
            ? const Value.absent()
            : Value(filledAmount),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Rows the reconciler must resolve against the ledger (everything not in a
  /// terminal [TradeStatus]).
  Future<List<TradeExecution>> getActiveTradeExecutions() =>
      (select(tradeExecutions)
            ..where((t) => t.status.isNotIn(TradeStatus.terminalValues))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  Future<List<TradeExecution>> getTradeExecutionsForWallet(String walletId) =>
      (select(tradeExecutions)
            ..where((t) => t.walletId.equals(walletId))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  /// Insert a validated fill. Idempotent on (executionId, txHash) so replaying
  /// reconciliation over the same ledger range cannot double-count.
  Future<void> upsertTradeFill(TradeFillsCompanion row) =>
      into(tradeFills).insertOnConflictUpdate(row);

  Future<List<TradeFill>> getTradeFills(String executionId) =>
      (select(tradeFills)
            ..where((t) => t.executionId.equals(executionId))
            ..orderBy([(t) => OrderingTerm.asc(t.ledgerIndex)]))
          .get();

  Future<List<CachedTx>> getAllCachedTxs() =>
      (select(cachedTxs)..orderBy([(t) => OrderingTerm.desc(t.date)])).get();

  Future<List<CachedTx>> getCachedTxsForWallet(String walletId) =>
      (select(cachedTxs)
            ..where((t) => t.walletId.equals(walletId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<void> wipeAll() async {
    await delete(cachedTxs).go();
    await delete(balances).go();
    await delete(wallets).go();
    await delete(appSettingsRows).go();
  }
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'xrpl_wallet.sqlite'));
    return NativeDatabase(file);
  });
}
