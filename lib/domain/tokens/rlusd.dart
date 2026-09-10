import 'package:xrpl_mobile_wallet/config/network_id.dart';

/// Official Ripple USD (RLUSD) trust-line parameters.
///
/// Source: https://docs.ripple.com/products/stablecoin/developer-resources/rlusd-on-the-xrpl
class Rlusd {
  Rlusd._();

  /// 40-char hex currency code for `RLUSD`.
  static const currencyHex = '524C555344000000000000000000000000000000';

  /// Trust-line limit used by Ripple's published TrustSet sample.
  static const limit = '1000000000';

  static const mainnetIssuer = 'rMxCKbEDwqr76QuheSUMdEGf4B9xJ8m5De';
  static const testnetIssuer = 'rQhWct2fv4Vc4KRjRgMrxa8xPN9Zx9iLKV';

  static String issuerFor(NetworkId network) => switch (network) {
    NetworkId.mainnet => mainnetIssuer,
    NetworkId.testnet => testnetIssuer,
  };

  /// Ledger currency for RLUSD: 40-char hex, or the ASCII code some nodes return.
  static bool isCurrency(String currency) {
    final c = currency.trim().toUpperCase();
    return c == currencyHex || c == 'RLUSD';
  }

  /// True when [currency] + [issuer] is the official RLUSD line on [network].
  ///
  /// Mainnet and testnet issuers are different. A mainnet line must not count
  /// on testnet, and the reverse.
  static bool matchesLine({
    required String currency,
    String? issuer,
    required NetworkId network,
  }) {
    if (issuer == null || issuer.isEmpty) return false;
    if (!isCurrency(currency)) return false;
    return issuer.trim() == issuerFor(network);
  }

  static bool hasLine({
    required NetworkId network,
    required Iterable<({String currency, String? issuer})> lines,
  }) {
    for (final line in lines) {
      if (matchesLine(
        currency: line.currency,
        issuer: line.issuer,
        network: network,
      )) {
        return true;
      }
    }
    return false;
  }

  /// Show Add RLUSD only for wallets that can sign and do not already have the line.
  static bool shouldShowAdd({
    required bool canSign,
    required NetworkId network,
    required Iterable<({String currency, String? issuer})> lines,
  }) {
    if (!canSign) return false;
    return !hasLine(network: network, lines: lines);
  }
}
