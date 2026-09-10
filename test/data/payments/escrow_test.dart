import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/data/payments/escrow_service.dart';
import 'package:xrpl_mobile_wallet/data/payments/payment_service.dart';

int _ripple(DateTime utc) => utc.difference(DateTime.utc(2000, 1, 1)).inSeconds;

XrpEscrow _escrow({
  DateTime? finish,
  DateTime? cancel,
  Object? amount = '1000000',
  String? condition,
  String destination = 'rHsMGQEkVNJmpGWs8XUBoTBiAAbwxZN5v3',
}) {
  final finishRipple = finish == null ? null : _ripple(finish);
  final cancelRipple = cancel == null ? null : _ripple(cancel);
  return XrpEscrow(
    owner: 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh',
    sequence: 1,
    entry: {
      'FinishAfter': ?finishRipple,
      'CancelAfter': ?cancelRipple,
      'Condition': ?condition,
      'Amount': amount,
      'Destination': destination,
    },
  );
}

void main() {
  test('escrow requires future finish before cancel', () {
    final now = DateTime.now().toUtc();
    expect(
      PaymentService.validateEscrowTimes(
        now.add(const Duration(minutes: 1)),
        now,
      ),
      isNotNull,
    );
    expect(
      PaymentService.validateEscrowTimes(
        now.add(const Duration(hours: 1)),
        now.add(const Duration(hours: 2)),
      ),
      isNull,
    );
  });

  test('escrow ledger times convert from ripple epoch', () {
    const finishAfter = 746496000; // 2023-08-28 00:00:00 UTC
    const cancelAfter = 746582400; // 2023-08-29 00:00:00 UTC
    final escrow = XrpEscrow(
      owner: 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh',
      sequence: 1,
      entry: const {
        'FinishAfter': finishAfter,
        'CancelAfter': cancelAfter,
        'Amount': '1000000',
        'Destination': 'rHsMGQEkVNJmpGWs8XUBoTBiAAbwxZN5v3',
      },
    );
    expect(escrow.finishAfterUtc, DateTime.utc(2023, 8, 28));
    expect(escrow.cancelAfterUtc, DateTime.utc(2023, 8, 29));
    expect(escrow.amountXrp, '1');
  });

  test('finish is only valid after FinishAfter and before CancelAfter', () {
    final finish = DateTime.utc(2024, 1, 10);
    final cancel = DateTime.utc(2024, 1, 20);
    final escrow = _escrow(finish: finish, cancel: cancel);

    expect(escrow.canFinishAt(DateTime.utc(2024, 1, 9)), isFalse);
    expect(escrow.canCancelAt(DateTime.utc(2024, 1, 9)), isFalse);
    expect(escrow.statusAt(DateTime.utc(2024, 1, 9)), 'Locked');

    expect(escrow.canFinishAt(DateTime.utc(2024, 1, 10)), isTrue);
    expect(escrow.canCancelAt(DateTime.utc(2024, 1, 10)), isFalse);
    expect(escrow.statusAt(DateTime.utc(2024, 1, 10)), 'Ready to finish');

    expect(escrow.canFinishAt(DateTime.utc(2024, 1, 20)), isFalse);
    expect(escrow.canCancelAt(DateTime.utc(2024, 1, 20)), isTrue);
    expect(
      escrow.statusAt(DateTime.utc(2024, 1, 20)),
      'Expired · refund available',
    );
  });

  test('conditional and token escrows cannot be finished or cancelled', () {
    final now = DateTime.utc(2024, 2, 1);
    final timed = DateTime.utc(2024, 1, 1);
    final conditional = _escrow(
      finish: timed,
      cancel: timed.add(const Duration(days: 1)),
      condition: 'A025...',
    );
    final token = _escrow(
      finish: timed,
      cancel: timed.add(const Duration(days: 1)),
      amount: {'currency': 'USD', 'issuer': 'rIssuer', 'value': '1'},
    );
    expect(conditional.canFinishAt(now), isFalse);
    expect(conditional.canCancelAt(now), isFalse);
    expect(conditional.statusAt(now), 'Conditional escrow (not supported)');
    expect(token.canFinishAt(now), isFalse);
    expect(token.isXrpAmount, isFalse);
    expect(token.statusAt(now), 'Token escrow (not supported)');
  });

  test('parses EscrowCreate refs from account_tx tx and tx_json shapes', () {
    const owner = 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh';
    const dest = 'rHsMGQEkVNJmpGWs8XUBoTBiAAbwxZN5v3';
    final result = {
      'transactions': [
        {
          'meta': {'TransactionResult': 'tesSUCCESS'},
          'tx': {
            'TransactionType': 'EscrowCreate',
            'Account': owner,
            'Destination': dest,
            'Sequence': 7,
          },
        },
        {
          'meta': {'TransactionResult': 'tesSUCCESS'},
          'tx_json': {
            'TransactionType': 'EscrowCreate',
            'Account': owner,
            'Destination': dest,
            'Sequence': 8,
          },
        },
        {
          'meta': {'TransactionResult': 'tecNO_DST'},
          'tx': {
            'TransactionType': 'EscrowCreate',
            'Account': owner,
            'Destination': dest,
            'Sequence': 9,
          },
        },
        {
          'tx': {
            'TransactionType': 'Payment',
            'Account': owner,
            'Destination': dest,
            'Sequence': 10,
          },
        },
      ],
    };
    final refs = EscrowService.escrowCreatesFromAccountTx(result);
    expect(refs.map((r) => r.sequence).toList(), [7, 8]);
    expect(refs.first.owner, owner);
    expect(refs.first.destination, dest);
  });

  test('escrow create spendable includes fee and extra owner reserve', () {
    expect(
      PaymentService.validateEscrowCreateSpendable(
        amountXrp: '10',
        balanceDrops: BigInt.from(20000000), // 20 XRP
        currentReserveDrops: BigInt.from(1000000), // 1 XRP
        reserveIncrementDrops: BigInt.from(200000), // 0.2 XRP
        feeDrops: '12',
        destUnfunded: false,
      ),
      isNull,
    );
    expect(
      PaymentService.validateEscrowCreateSpendable(
        amountXrp: '19',
        balanceDrops: BigInt.from(20000000),
        currentReserveDrops: BigInt.from(1000000),
        reserveIncrementDrops: BigInt.from(200000),
        feeDrops: '12',
        destUnfunded: false,
      ),
      isNotNull,
    );
    expect(
      PaymentService.validateEscrowCreateSpendable(
        amountXrp: '0.5',
        balanceDrops: BigInt.from(20000000),
        currentReserveDrops: BigInt.from(1000000),
        reserveIncrementDrops: BigInt.from(200000),
        feeDrops: '12',
        destUnfunded: true,
      ),
      isNotNull,
    );
  });
}
