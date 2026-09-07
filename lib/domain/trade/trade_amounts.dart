import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/domain/amount/xrp_amount.dart';

/// Amount helpers for one side of an XRPL offer.
///
/// Pure: no I/O, no Flutter. This is the seed of `domain/trade/`; the rate,
/// slippage and `tfSell` logic (R2) lands beside it.
class TradeAmounts {
  TradeAmounts._();

  /// Build an XRPL [BaseAmount] for one side of an offer.
  ///
  /// `XRP` (any case) is converted from decimal XRP to integer drops and throws
  /// [FormatException] on sub-drop precision — it is never silently truncated.
  /// Anything else is an issued amount carrying its issuer explicitly; a
  /// currency code alias is never the sole identity of an asset.
  static BaseAmount offerAmount(String value, String currency, String issuer) {
    if (currency.trim().toUpperCase() == 'XRP') {
      return XRPAmount(BigInt.parse(XrpAmount.xrpToDrops(value.trim())));
    }
    return IssuedCurrencyAmount(
      value: value.trim(),
      currency: currency.trim(),
      issuer: issuer.trim(),
    );
  }

  /// Human-readable rendering of an offer side, for review and list rows.
  static String describe(BaseAmount amount) {
    final json = amount.toJson();
    if (json is Map) {
      return '${json['value']} ${json['currency']}';
    }
    return '${XrpAmount.dropsToXrp(json.toString())} XRP';
  }
}
