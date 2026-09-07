import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/data/database/app_database.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_status.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  TradeExecutionsCompanion execution(String id, TradeStatus status) =>
      TradeExecutionsCompanion.insert(
        id: id,
        walletId: 'w1',
        network: 'mainnet',
        side: 'sell',
        baseCurrency: 'XRP',
        quoteCurrency: '524C555344000000000000000000000000000000',
        quoteIssuer: const Value('rMxCKbEDwqr76QuheSUMdEGf4B9xJ8m5De'),
        targetAmount: '10',
        orderType: 'limit',
        status: status.storageValue,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  test('schemaVersion is 4', () {
    expect(db.schemaVersion, 5);
  });

  test('getActiveTradeExecutions returns only non-terminal rows', () async {
    await db.upsertTradeExecution(execution('a', TradeStatus.submitted));
    await db.upsertTradeExecution(execution('b', TradeStatus.partiallyFilled));
    await db.upsertTradeExecution(execution('c', TradeStatus.interrupted));
    await db.upsertTradeExecution(execution('d', TradeStatus.filled));
    await db.upsertTradeExecution(execution('e', TradeStatus.cancelled));
    await db.upsertTradeExecution(execution('f', TradeStatus.expired));
    await db.upsertTradeExecution(execution('g', TradeStatus.failed));

    final active = await db.getActiveTradeExecutions();
    expect(active.map((e) => e.id).toSet(), {'a', 'b', 'c'});
  });

  test(
    'updateTradeExecutionStatus moves a row out of the active set',
    () async {
      await db.upsertTradeExecution(execution('a', TradeStatus.submitted));
      expect((await db.getActiveTradeExecutions()).length, 1);

      await db.updateTradeExecutionStatus(
        'a',
        status: TradeStatus.filled.storageValue,
      );
      expect(await db.getActiveTradeExecutions(), isEmpty);
    },
  );

  test('getTradeExecutionsForWallet scopes by wallet', () async {
    await db.upsertTradeExecution(execution('a', TradeStatus.submitted));
    await db.upsertTradeExecution(
      execution(
        'b',
        TradeStatus.submitted,
      ).copyWith(walletId: const Value('w2')),
    );
    final rows = await db.getTradeExecutionsForWallet('w1');
    expect(rows.map((e) => e.id), ['a']);
  });

  group('trade fills', () {
    TradeFillsCompanion fill(String txHash, int ledgerIndex) =>
        TradeFillsCompanion.insert(
          executionId: 'a',
          txHash: txHash,
          ledgerIndex: ledgerIndex,
          filledBase: '4',
          filledQuote: '2',
          rate: '0.5',
          date: DateTime.now(),
        );

    test('one execution holds many fills, ordered by ledger index', () async {
      await db.upsertTradeExecution(
        execution('a', TradeStatus.partiallyFilled),
      );
      await db.upsertTradeFill(fill('TX_C', 300));
      await db.upsertTradeFill(fill('TX_A', 100));
      await db.upsertTradeFill(fill('TX_B', 200));

      final fills = await db.getTradeFills('a');
      expect(fills.map((f) => f.txHash), ['TX_A', 'TX_B', 'TX_C']);
    });

    test('replaying the same fill does not double-count', () async {
      await db.upsertTradeExecution(
        execution('a', TradeStatus.partiallyFilled),
      );
      await db.upsertTradeFill(fill('TX_A', 100));
      await db.upsertTradeFill(fill('TX_A', 100));
      await db.upsertTradeFill(fill('TX_A', 100));

      expect((await db.getTradeFills('a')).length, 1);
    });
  });
}
