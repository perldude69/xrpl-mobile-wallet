import 'package:flutter/material.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_status.dart';

/// User-facing wording for a [TradeStatus].
///
/// The point of these strings is that they do not overclaim. "Submitted" and
/// "Resting" look similar on screen but mean very different things — one is an
/// order the ledger has confirmed, the other is an order we have not yet
/// heard back about — and the detail line says which.
String tradeStatusLabel(TradeStatus status) => switch (status) {
  TradeStatus.draft => 'Draft',
  TradeStatus.reviewing => 'In review',
  TradeStatus.awaitingApproval => 'Awaiting approval',
  TradeStatus.signing => 'Signing',
  TradeStatus.submitted => 'Submitted',
  TradeStatus.resting => 'Resting on the book',
  TradeStatus.partiallyFilled => 'Partially filled',
  TradeStatus.filled => 'Filled',
  TradeStatus.cancelled => 'Cancelled',
  TradeStatus.expired => 'Expired',
  TradeStatus.failed => 'Failed',
  TradeStatus.interrupted => 'Needs checking',
};

String tradeStatusDetail(TradeStatus status) => switch (status) {
  TradeStatus.draft => 'Not submitted.',
  TradeStatus.reviewing => 'Not submitted.',
  TradeStatus.awaitingApproval => 'Waiting for your PIN.',
  TradeStatus.signing => 'Being signed and submitted.',
  TradeStatus.submitted =>
    'Sent to the network. Not yet confirmed in a validated ledger.',
  TradeStatus.resting =>
    'Confirmed and waiting to be filled. Its funds and reserve stay locked '
        'until it fills or you cancel it.',
  TradeStatus.partiallyFilled =>
    'Part of this order has filled. The rest is still on the book.',
  TradeStatus.filled => 'Completed in full.',
  TradeStatus.cancelled => 'No longer on the book.',
  TradeStatus.expired =>
    'Never made it into a validated ledger, or passed its expiry. It cannot '
        'execute now.',
  TradeStatus.failed => 'Rejected. Nothing was traded.',
  TradeStatus.interrupted =>
    'The app stopped before recording what happened. Check your open offers '
        'and account history before placing this order again.',
};

IconData tradeStatusIcon(TradeStatus status) => switch (status) {
  TradeStatus.draft ||
  TradeStatus.reviewing ||
  TradeStatus.awaitingApproval => Icons.edit_outlined,
  TradeStatus.signing => Icons.key_outlined,
  TradeStatus.submitted => Icons.cloud_upload_outlined,
  TradeStatus.resting => Icons.hourglass_empty,
  TradeStatus.partiallyFilled => Icons.incomplete_circle,
  TradeStatus.filled => Icons.check_circle_outline,
  TradeStatus.cancelled => Icons.cancel_outlined,
  TradeStatus.expired => Icons.timer_off_outlined,
  TradeStatus.failed => Icons.error_outline,
  TradeStatus.interrupted => Icons.help_outline,
};
