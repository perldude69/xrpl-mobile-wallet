import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Wallets, Balances, CachedTxs, AppSettingsRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

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

  Future<List<CachedTx>> getAllCachedTxs() =>
      (select(cachedTxs)
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

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
