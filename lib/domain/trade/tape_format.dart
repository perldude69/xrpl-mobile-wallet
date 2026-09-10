import 'package:xrpl_mobile_wallet/domain/trade/order_book.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';

/// Display-only rounding for the order-book tape. Never use the result as a
/// quote or an `OfferCreate` rate.
String formatTapeDecimal(TradeDecimal value, {int figures = 5}) {
  if (value.isZero) return '0';
  final rounded = value
      .roundToSignificantFigures(figures, roundUp: false)
      .normalized;
  final negative = rounded.isNegative;
  final digits = rounded.unscaled.abs().toString();
  final leadingFracZeros = rounded.scale - digits.length;
  if (leadingFracZeros >= 3) {
    final exp = digits.length - 1 - rounded.scale;
    final mantissa = digits.length == 1
        ? digits
        : '${digits[0]}.${digits.substring(1)}';
    return '${negative ? '-' : ''}${mantissa}e$exp';
  }
  return rounded.toString();
}

/// Bid-side share of base-asset depth, in thousandths (0–1000), for layout
/// flex only. Not a tradable quantity.
int tapeBidVolumeShareThousandths(BookSnapshot snapshot) {
  var bid = TradeDecimal.zero;
  var ask = TradeDecimal.zero;
  for (final level in snapshot.bids) {
    bid += level.baseAmount;
  }
  for (final level in snapshot.asks) {
    ask += level.baseAmount;
  }
  final total = bid + ask;
  if (total.isZero) return 500;
  if (bid.isZero) return 0;
  if (ask.isZero) return 1000;
  return bid
      .divide(total, scale: 3, roundUp: false)
      .withScale(3, roundUp: false)
      .unscaled
      .toInt();
}
