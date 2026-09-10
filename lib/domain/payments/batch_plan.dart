import 'package:xrpl_mobile_wallet/config/app_config.dart';
import 'package:xrpl_mobile_wallet/domain/amount/xrp_amount.dart';
import 'package:xrpl_mobile_wallet/domain/validation/address_validator.dart';

/// XLS-56 batch modes. Slice 1 only submits [allOrNothing].
enum BatchMode { allOrNothing, onlyOne, untilFailure, independent }

/// One XRP Payment inner transaction in a single-account batch.
class BatchPaymentLeg {
  const BatchPaymentLeg({
    required this.destination,
    required this.amountXrp,
    this.destinationTag,
    this.destUnfunded = false,
  });

  final String destination;
  final String amountXrp;
  final int? destinationTag;
  final bool destUnfunded;
}

/// Amendment identifiers for BatchV1_1 (original `Batch` is obsolete).
abstract final class BatchAmendment {
  static const name = 'BatchV1_1';
  static const id =
      '9F287AED3CDB50A7BD1ACEC24296A30C9B5230CCD136219317AC790E3B884377';

  /// True when the `feature` RPC result shows BatchV1_1 enabled on this node.
  static bool isEnabled(Map<String, dynamic> featureResult) {
    for (final key in [name, id]) {
      final raw = featureResult[key];
      if (raw is Map) {
        final enabled = raw['enabled'];
        if (enabled == true) return true;
      }
    }
    return false;
  }
}

/// Pure checks for a single-account XRP multi-payment batch (2–8 inners).
abstract final class BatchValidators {
  static const minLegs = 2;
  static const maxLegs = 8;

  static String? validateLegCount(int count) {
    if (count < minLegs) {
      return 'A batch needs at least $minLegs payments';
    }
    if (count > maxLegs) {
      return 'A batch can include at most $maxLegs payments';
    }
    return null;
  }

  /// Error for one destination, or null if it may be added.
  static String? validateDestination({
    required String destination,
    required String fromAddress,
  }) {
    final dest = destination.trim();
    if (!AddressValidator.isValidClassic(dest)) {
      return 'Enter a valid XRPL classic address';
    }
    if (dest == fromAddress) {
      return 'Destination cannot be the same as this wallet';
    }
    return null;
  }

  static String? validateLeg({
    required String fromAddress,
    required BatchPaymentLeg leg,
  }) {
    final destErr = validateDestination(
      destination: leg.destination,
      fromAddress: fromAddress,
    );
    if (destErr != null) return destErr;
    return _validatePositiveXrp(leg.amountXrp);
  }

  static String? _validatePositiveXrp(String amount) {
    final trimmed = amount.trim();
    if (trimmed.isEmpty) return 'Enter an amount';
    try {
      final drops = XrpAmount.xrpToDrops(trimmed);
      if (BigInt.parse(drops) <= BigInt.zero) {
        return 'Amount must be greater than zero';
      }
      return null;
    } on FormatException catch (e) {
      return e.message;
    } catch (_) {
      return 'Invalid XRP amount';
    }
  }

  /// True when two legs share the same classic address (allowed, warn in UI).
  static bool hasDuplicateDestinations(Iterable<BatchPaymentLeg> legs) {
    final seen = <String>{};
    for (final leg in legs) {
      final dest = leg.destination.trim();
      if (!seen.add(dest)) return true;
    }
    return false;
  }

  /// Outer fee in drops for [innerCount] simple Payments:
  /// `2 * base + innerCount * base` (xrpl_dart / XLS-56, single signature).
  static BigInt estimateOuterFeeDrops({
    required BigInt baseFeeDrops,
    required int innerCount,
  }) {
    return baseFeeDrops * BigInt.from(2 + innerCount);
  }

  static String? validateSpendable({
    required List<BatchPaymentLeg> legs,
    required String availableXrp,
    required String feeDrops,
    BigInt? accountReserveDrops,
  }) {
    final countErr = validateLegCount(legs.length);
    if (countErr != null) return countErr;
    final feeErr = _validateFeeDrops(feeDrops);
    if (feeErr != null) return feeErr;

    BigInt total = BigInt.zero;
    for (final leg in legs) {
      final amountErr = _validatePositiveXrp(leg.amountXrp);
      if (amountErr != null) return amountErr;
      total += BigInt.parse(XrpAmount.xrpToDrops(leg.amountXrp.trim()));
    }

    final BigInt bal;
    try {
      bal = BigInt.parse(XrpAmount.xrpToDrops(availableXrp.trim()));
    } catch (_) {
      return 'Available balance is invalid';
    }
    final fee = BigInt.parse(feeDrops.trim());
    if (total + fee > bal) {
      return 'Total amount plus network fee exceeds available balance';
    }

    final reserve =
        accountReserveDrops ?? BigInt.from(AppConfig.accountCreateReserveDrops);
    for (final leg in legs) {
      if (!leg.destUnfunded) continue;
      final send = BigInt.parse(XrpAmount.xrpToDrops(leg.amountXrp.trim()));
      if (send < reserve) {
        return 'Unfunded destination ${leg.destination} needs at least '
            '${XrpAmount.dropsToXrp(reserve.toString())} XRP';
      }
    }
    return null;
  }

  static String? _validateFeeDrops(String? feeDrops) {
    if (feeDrops == null || feeDrops.trim().isEmpty) {
      return 'Network fee is missing; refusing to sign';
    }
    final BigInt fee;
    try {
      fee = BigInt.parse(feeDrops.trim());
    } catch (_) {
      return 'Network fee is invalid; refusing to sign';
    }
    if (fee <= BigInt.zero) {
      return 'Network fee is invalid; refusing to sign';
    }
    final max = BigInt.from(AppConfig.maxFeeDrops);
    if (fee > max) {
      return 'Network fee is ${XrpAmount.dropsToXrp(fee.toString())} XRP '
          '(max ${XrpAmount.dropsToXrp(max.toString())} XRP). Refusing to sign.';
    }
    return null;
  }

  static String? userFacingEngineResult(String engineResult) {
    return switch (engineResult) {
      'temDISABLED' ||
      'tecDISABLED' => 'Batch transactions are not enabled on this network yet',
      'temARRAY_EMPTY' => 'A batch needs at least two payments',
      'temARRAY_TOO_LARGE' => 'A batch can include at most eight payments',
      'temINVALID_FLAG' => 'This batch used an invalid mode or inner flag',
      'temBAD_FEE' => 'Inner batch payments must not include a fee',
      'temBAD_SIGNATURE' ||
      'temBAD_REGKEY' => 'Inner batch payments must not be signed separately',
      'temINVALID_INNER_BATCH' => 'This batch contains an unsupported payment',
      'temREDUNDANT' => 'This batch contains a duplicate payment',
      _ => null,
    };
  }
}
