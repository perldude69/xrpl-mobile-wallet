import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/data/payments/batch_service.dart';
import 'package:xrpl_mobile_wallet/domain/payments/batch_plan.dart';

const _from = 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh';
const _a = 'rHsMGQEkVNJmpGWs8XUBoTBiAAbwxZN5v3';
const _b = 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe';

BatchPaymentLeg _leg(String dest, String amount, {bool unfunded = false}) {
  return BatchPaymentLeg(
    destination: dest,
    amountXrp: amount,
    destUnfunded: unfunded,
  );
}

void main() {
  group('BatchAmendment.isEnabled', () {
    test('matches name or amendment id with enabled true', () {
      expect(BatchAmendment.isEnabled(const {}), isFalse);
      expect(
        BatchAmendment.isEnabled({
          BatchAmendment.name: {'enabled': false},
        }),
        isFalse,
      );
      expect(
        BatchAmendment.isEnabled({
          BatchAmendment.name: {'enabled': true},
        }),
        isTrue,
      );
      expect(
        BatchAmendment.isEnabled({
          BatchAmendment.id: {'enabled': true},
        }),
        isTrue,
      );
    });
  });

  group('BatchValidators', () {
    test('leg count is 2–8', () {
      expect(BatchValidators.validateLegCount(1), isNotNull);
      expect(BatchValidators.validateLegCount(2), isNull);
      expect(BatchValidators.validateLegCount(8), isNull);
      expect(BatchValidators.validateLegCount(9), isNotNull);
    });

    test('rejects self and invalid destinations', () {
      expect(
        BatchValidators.validateDestination(
          destination: _from,
          fromAddress: _from,
        ),
        isNotNull,
      );
      expect(
        BatchValidators.validateDestination(
          destination: 'not-an-address',
          fromAddress: _from,
        ),
        isNotNull,
      );
      expect(
        BatchValidators.validateDestination(
          destination: _a,
          fromAddress: _from,
        ),
        isNull,
      );
    });

    test('duplicate destinations are detected but allowed', () {
      expect(
        BatchValidators.hasDuplicateDestinations([
          _leg(_a, '1'),
          _leg(_a, '2'),
        ]),
        isTrue,
      );
      expect(
        BatchValidators.hasDuplicateDestinations([
          _leg(_a, '1'),
          _leg(_b, '2'),
        ]),
        isFalse,
      );
    });

    test('outer fee is 2*base plus one base per inner', () {
      expect(
        BatchValidators.estimateOuterFeeDrops(
          baseFeeDrops: BigInt.from(10),
          innerCount: 2,
        ),
        BigInt.from(40),
      );
      expect(
        BatchValidators.estimateOuterFeeDrops(
          baseFeeDrops: BigInt.from(10),
          innerCount: 8,
        ),
        BigInt.from(100),
      );
    });

    test('spendable sums all legs plus fee', () {
      final legs = [_leg(_a, '1'), _leg(_b, '2')];
      expect(
        BatchValidators.validateSpendable(
          legs: legs,
          availableXrp: '3.00001',
          feeDrops: '10',
        ),
        isNull,
      );
      expect(
        BatchValidators.validateSpendable(
          legs: legs,
          availableXrp: '3',
          feeDrops: '10',
        ),
        isNotNull,
      );
    });

    test('unfunded dest still needs account-create reserve per leg', () {
      expect(
        BatchValidators.validateSpendable(
          legs: [_leg(_a, '0.5', unfunded: true), _leg(_b, '1')],
          availableXrp: '20',
          feeDrops: '10',
        ),
        isNotNull,
      );
    });

    test('maps batch engine codes', () {
      expect(
        BatchValidators.userFacingEngineResult('temDISABLED'),
        contains('not enabled'),
      );
      expect(BatchValidators.userFacingEngineResult('tesSUCCESS'), isNull);
    });
  });

  group('BatchService.buildXrpAllOrNothing', () {
    test('inners have tfInnerBatchTxn, fee 0, empty signing key', () {
      final batch = BatchService.buildXrpAllOrNothing(
        fromAddress: _from,
        publicKeyHex: '02' + ('11' * 32),
        legs: [_leg(_a, '1'), _leg(_b, '2')],
      );

      expect(batch.transactionType, SubmittableTransactionType.batch);
      expect(batch.flags, [BatchFlag.tfAllOrNothing.value]);
      expect(batch.rawTransactions, hasLength(2));
      expect(batch.batchSigners, isNull);

      for (final inner in batch.rawTransactions) {
        expect(inner, isA<Payment>());
        expect(inner.fee, BigInt.zero);
        expect(inner.flags, contains(TransactionFlag.innerBatchTxn.id));
        expect(inner.signer, isNull);
        expect(inner.lastLedgerSequence, isNull);
        final json = inner.toJson();
        expect(json['fee'], '0');
        expect(json['signing_pub_key'], '');
        expect(json['txn_signature'], isNull);
        expect(json['flags'] & TransactionFlag.innerBatchTxn.id, isNonZero);
      }

      final outer = batch.toJson();
      expect(outer['transaction_type'], 'Batch');
      expect(outer['flags'] & BatchFlag.tfAllOrNothing.value, isNonZero);
      expect(outer['raw_transactions'], hasLength(2));
    });

    test('refuses a single inner', () {
      expect(
        () => BatchService.buildXrpAllOrNothing(
          fromAddress: _from,
          publicKeyHex: '02' + ('11' * 32),
          legs: [_leg(_a, '1')],
        ),
        throwsArgumentError,
      );
    });
  });
}
