import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/data/payments/payment_service.dart';
import 'package:xrpl_mobile_wallet/domain/amount/xrp_amount.dart';
import 'package:xrpl_mobile_wallet/domain/payments/batch_plan.dart';

/// Builds and submits a single-account XRP [Batch] (All or nothing).
///
/// Inner Payments are unsigned (`Fee` 0, `tfInnerBatchTxn`). The outer Batch
/// is signed through [PaymentService.signAndSubmitTransaction].
class BatchService {
  BatchService(this._payments);

  final PaymentService _payments;

  /// Inner Payments + outer Batch. Sequences and the outer fee are filled by
  /// [XRPHelper.autoFill] at submit time.
  static Batch buildXrpAllOrNothing({
    required String fromAddress,
    required String publicKeyHex,
    required List<BatchPaymentLeg> legs,
  }) {
    final countErr = BatchValidators.validateLegCount(legs.length);
    if (countErr != null) throw ArgumentError(countErr);
    for (final leg in legs) {
      final err = BatchValidators.validateLeg(
        fromAddress: fromAddress,
        leg: leg,
      );
      if (err != null) throw ArgumentError(err);
    }

    final inners = [
      for (final leg in legs)
        Payment(
          amount: XRPAmount(
            BigInt.parse(XrpAmount.xrpToDrops(leg.amountXrp.trim())),
          ),
          destination: leg.destination.trim(),
          destinationTag: leg.destinationTag,
          account: fromAddress,
          flags: [TransactionFlag.innerBatchTxn.id],
          fee: BigInt.zero,
        ),
    ];

    return Batch(
      account: fromAddress,
      rawTransactions: inners,
      flags: [BatchFlag.tfAllOrNothing.value],
      signer: XRPLSignature.signer(publicKeyHex),
    );
  }

  Future<PaymentSubmitResult> submitXrpAllOrNothing({
    required String walletId,
    required String network,
    required String secret,
    required String fromAddress,
    required List<BatchPaymentLeg> legs,
    required XRPProvider rpc,
    String? expectedFeeDrops,
  }) {
    return _payments.signAndSubmitTransaction(
      walletId: walletId,
      network: network,
      secret: secret,
      fromAddress: fromAddress,
      rpc: rpc,
      expectedFeeDrops: expectedFeeDrops,
      build: (pubHex) => buildXrpAllOrNothing(
        fromAddress: fromAddress,
        publicKeyHex: pubHex,
        legs: legs,
      ),
    );
  }
}
