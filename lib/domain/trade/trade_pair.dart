import 'package:xrpl_mobile_wallet/config/network_id.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/rlusd.dart';

/// One tradable asset: native XRP, or an issued currency with its issuer.
///
/// A currency code is never the sole identity of an issued asset — anyone can
/// issue `USD`. [issuer] is part of the identity and is non-null for every
/// issued asset.
class TradeAsset {
  const TradeAsset._(this.currency, this.issuer);

  /// Native XRP. No issuer.
  static const xrp = TradeAsset._('XRP', null);

  /// An issued currency. [issuer] must be a classic address.
  factory TradeAsset.issued({
    required String currency,
    required String issuer,
  }) {
    if (currency.trim().isEmpty) {
      throw ArgumentError.value(currency, 'currency', 'must not be empty');
    }
    if (issuer.trim().isEmpty) {
      throw ArgumentError.value(issuer, 'issuer', 'must not be empty');
    }
    return TradeAsset._(currency.trim(), issuer.trim());
  }

  /// `XRP` for native, otherwise the currency code or 40-char hex.
  final String currency;

  /// Counterparty issuer address; null for native XRP.
  final String? issuer;

  bool get isXrp => issuer == null;

  /// Decimal places the ledger stores for this asset.
  ///
  /// XRP is an integer number of drops (6 dp, exact). Issued amounts have no
  /// fixed scale — they carry 15 significant figures — so this is the working
  /// scale used when deriving an issued amount, before
  /// [TradeDecimal.roundToSignificantFigures] trims it.
  int get workingScale => isXrp ? xrpScale : issuedWorkingScale;

  /// Significant figures an XRPL issued-currency mantissa holds.
  static const issuedSignificantFigures = 15;

  /// XRP has exactly 6 decimal places (1 XRP = 1,000,000 drops).
  static const xrpScale = 6;

  /// Working precision for issued amounts before significant-figure rounding.
  static const issuedWorkingScale = 20;

  bool matches(String otherCurrency, String? otherIssuer) {
    if (isXrp) {
      return otherCurrency.trim().toUpperCase() == 'XRP' &&
          (otherIssuer == null || otherIssuer.trim().isEmpty);
    }
    return otherCurrency.trim() == currency && otherIssuer?.trim() == issuer;
  }

  @override
  bool operator ==(Object other) =>
      other is TradeAsset &&
      other.currency == currency &&
      other.issuer == issuer;

  @override
  int get hashCode => Object.hash(currency, issuer);

  @override
  String toString() => isXrp ? 'XRP' : '$currency.$issuer';
}

/// Which way round the trade goes, read as "…the base asset".
///
/// The base is always XRP and the quote is always RLUSD (see [TradePair]), so
/// [sell] gives up XRP for RLUSD and [buy] gives up RLUSD for XRP.
enum TradeSide {
  /// Give up base (XRP), receive quote (RLUSD).
  sell,

  /// Give up quote (RLUSD), receive base (XRP).
  buy;

  /// Storage form, matching `trade_executions.side`.
  String get storageValue => name;

  static TradeSide fromStorage(String? value) =>
      value == TradeSide.buy.name ? TradeSide.buy : TradeSide.sell;
}

/// The single pair this wallet trades: XRP ⇄ RLUSD on one network.
///
/// Deliberately not a general pair type. Trading is scoped to one book with a
/// known issuer per network, so there is no pair picker, no issuer selection
/// and no token-registry lookup in the trade path — a wrong issuer here would
/// be an unrecoverable transfer to a look-alike asset.
class TradePair {
  const TradePair._(this.network, this.base, this.quote);

  factory TradePair.forNetwork(NetworkId network) => TradePair._(
    network,
    TradeAsset.xrp,
    TradeAsset.issued(
      currency: Rlusd.currencyHex,
      issuer: Rlusd.issuerFor(network),
    ),
  );

  final NetworkId network;

  /// Always XRP. Amounts and rates are quoted per unit of base.
  final TradeAsset base;

  /// Always RLUSD for [network].
  final TradeAsset quote;

  /// The asset the account gives up for [side].
  TradeAsset given(TradeSide side) => side == TradeSide.sell ? base : quote;

  /// The asset the account receives for [side].
  TradeAsset received(TradeSide side) => side == TradeSide.sell ? quote : base;

  /// True when [currency]/[issuer] is either leg of this pair.
  bool includes(String currency, String? issuer) =>
      base.matches(currency, issuer) || quote.matches(currency, issuer);

  @override
  bool operator ==(Object other) =>
      other is TradePair && other.network == network;

  @override
  int get hashCode => network.hashCode;

  @override
  String toString() => '$base/$quote (${network.name})';
}
