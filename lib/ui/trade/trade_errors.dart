import 'dart:async';

import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/data/payments/payment_service.dart';

// The matching persisted slugs live in `data/trade/trade_error_slug.dart`:
// wording here is presentation and may be reworded freely, slugs there are
// already in the database and may not.

/// Fixed, user-safe text for a failed trade action.
///
/// Never interpolates exception text into the UI (XRW-26): dependency
/// exceptions can change wording between versions and could one day carry
/// caller input. `PaymentOperationException.stage` is one of our own fixed
/// constants, so it is safe to surface.
String tradeFailureMessage(Object error) {
  if (error is PaymentOperationException) {
    return 'The order failed during ${error.stage}.';
  }
  if (error is RPCError) {
    return 'The network rejected the transaction.';
  }
  if (error is BaseXRPLPluginException) {
    return 'The transaction could not be built.';
  }
  if (error is ArgumentError) {
    return 'The order did not pass its safety checks.';
  }
  if (error is TimeoutException) {
    return 'The network did not respond in time.';
  }
  if (error is StateError) {
    return 'No signing key is available for this wallet.';
  }
  return 'The order could not be completed.';
}
