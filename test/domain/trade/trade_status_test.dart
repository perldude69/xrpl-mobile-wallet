import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_status.dart';

void main() {
  test('terminal states are exactly filled/cancelled/expired/failed', () {
    expect(TradeStatus.terminalValues, [
      'filled',
      'cancelled',
      'expired',
      'failed',
    ]);
  });

  test('in-flight states need reconciliation', () {
    for (final s in [
      TradeStatus.draft,
      TradeStatus.reviewing,
      TradeStatus.awaitingApproval,
      TradeStatus.signing,
      TradeStatus.submitted,
      TradeStatus.resting,
      TradeStatus.partiallyFilled,
      TradeStatus.interrupted,
    ]) {
      expect(s.needsReconciliation, isTrue, reason: s.name);
      expect(s.isTerminal, isFalse, reason: s.name);
    }
  });

  test('resting is distinct from submitted', () {
    // "Submitted" means we do not know whether it landed; "resting" means the
    // ledger confirmed it and it is waiting to fill. Collapsing the two is the
    // dishonesty reconciliation exists to remove.
    expect(TradeStatus.resting, isNot(TradeStatus.submitted));
    expect(TradeStatus.resting.storageValue, 'resting');
    expect(TradeStatus.fromStorage('resting'), TradeStatus.resting);
    expect(TradeStatus.resting.isTerminal, isFalse);
  });

  test('storage form is the enum name, never the index', () {
    expect(TradeStatus.partiallyFilled.storageValue, 'partiallyFilled');
    expect(
      TradeStatus.fromStorage('partiallyFilled'),
      TradeStatus.partiallyFilled,
    );
  });

  test('unknown or null persisted values reconcile rather than look done', () {
    expect(TradeStatus.fromStorage(null), TradeStatus.interrupted);
    expect(TradeStatus.fromStorage('completed'), TradeStatus.interrupted);
    expect(TradeStatus.fromStorage(''), TradeStatus.interrupted);
    expect(TradeStatus.fromStorage('3'), TradeStatus.interrupted);
    expect(TradeStatus.fromStorage('completed').isTerminal, isFalse);
  });
}
