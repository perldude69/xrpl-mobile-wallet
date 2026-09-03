import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/config/network_id.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/rlusd.dart';

void main() {
  const hex = '524C555344000000000000000000000000000000';

  test('currency hex and issuers match Ripple docs', () {
    expect(Rlusd.currencyHex, hex);
    expect(Rlusd.limit, '1000000000');
    expect(Rlusd.issuerFor(NetworkId.mainnet), Rlusd.mainnetIssuer);
    expect(Rlusd.issuerFor(NetworkId.testnet), Rlusd.testnetIssuer);
    expect(Rlusd.mainnetIssuer, 'rMxCKbEDwqr76QuheSUMdEGf4B9xJ8m5De');
    expect(Rlusd.testnetIssuer, 'rQhWct2fv4Vc4KRjRgMrxa8xPN9Zx9iLKV');
  });

  group('matchesLine', () {
    test('mainnet official line', () {
      expect(
        Rlusd.matchesLine(
          currency: hex,
          issuer: Rlusd.mainnetIssuer,
          network: NetworkId.mainnet,
        ),
        isTrue,
      );
    });

    test('hex is case-insensitive', () {
      expect(
        Rlusd.matchesLine(
          currency: hex.toLowerCase(),
          issuer: Rlusd.mainnetIssuer,
          network: NetworkId.mainnet,
        ),
        isTrue,
      );
    });

    test('rejects wrong issuer, XRP, and other hex', () {
      expect(
        Rlusd.matchesLine(
          currency: hex,
          issuer: Rlusd.testnetIssuer,
          network: NetworkId.mainnet,
        ),
        isFalse,
      );
      expect(
        Rlusd.matchesLine(
          currency: 'XRP',
          issuer: null,
          network: NetworkId.mainnet,
        ),
        isFalse,
      );
      expect(
        Rlusd.matchesLine(
          currency: 'USD',
          issuer: Rlusd.mainnetIssuer,
          network: NetworkId.mainnet,
        ),
        isFalse,
      );
    });
  });

  group('shouldShowAdd', () {
    final empty = <({String currency, String? issuer})>[];
    final xrpOnly = [(currency: 'XRP', issuer: null)];
    final rlusdMainnet = [
      (currency: 'XRP', issuer: null),
      (currency: hex, issuer: Rlusd.mainnetIssuer),
    ];

    test('watch-only without Ledger is hidden', () {
      expect(
        Rlusd.shouldShowAdd(
          canSign: false,
          network: NetworkId.mainnet,
          lines: empty,
        ),
        isFalse,
      );
    });

    test('canSign without the line is shown', () {
      expect(
        Rlusd.shouldShowAdd(
          canSign: true,
          network: NetworkId.mainnet,
          lines: xrpOnly,
        ),
        isTrue,
      );
    });

    test('canSign with existing line is hidden', () {
      expect(
        Rlusd.shouldShowAdd(
          canSign: true,
          network: NetworkId.mainnet,
          lines: rlusdMainnet,
        ),
        isFalse,
      );
    });

    test('mainnet line does not hide the testnet action', () {
      expect(
        Rlusd.shouldShowAdd(
          canSign: true,
          network: NetworkId.testnet,
          lines: rlusdMainnet,
        ),
        isTrue,
      );
    });
  });
}
