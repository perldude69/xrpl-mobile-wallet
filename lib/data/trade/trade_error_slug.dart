import 'dart:async';

import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/data/payments/payment_service.dart';

/// Short, non-sensitive category slug persisted to
/// `trade_executions.last_error` instead of raw exception text (XRW-28).
///
/// Lives in the data layer because it is *persistence*, not presentation: the
/// reconciler and the trade controller both write it, and neither may reach up
/// into `ui/` for it. The user-facing wording lives separately in
/// `ui/trade/trade_errors.dart` and can be reworded without changing what is
/// already in the database.
///
/// Every branch returns a fixed constant. `PaymentOperationException.stage` is
/// one of our own literals, so it is safe to embed; nothing else derived from
/// an exception's own message ever is.
String tradeErrorCategory(Object error) {
  if (error is PaymentOperationException) return 'stage:${error.stage}';
  if (error is RPCError) return 'submit-rejected';
  if (error is BaseXRPLPluginException) return 'build-failed';
  if (error is ArgumentError) return 'validation';
  if (error is TimeoutException) return 'network-timeout';
  if (error is StateError) return 'no-signing-key';
  return 'unknown';
}
