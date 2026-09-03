import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/currency_display.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/token_registry.dart';

void main() {
  const rlusdHex = '524C555344000000000000000000000000000000';
  const rlusdIssuer = 'rMxCKbEDwqr76QuheSUMdEGf4B9xJ8m5De';
  const soloHex = '534F4C4F00000000000000000000000000000000';

  setUp(() {
    CurrencyDisplay.setRegistry(
      TokenRegistry.fromJsonString('''
{
  "source": "test",
  "entries": [
    {
      "currency": "$rlusdHex",
      "issuer": "$rlusdIssuer",
      "code": "RLUSD",
      "name": "Ripple USD"
    },
    {
      "currency": "$soloHex",
      "issuer": "rsoLo2S1kiGeCcn6hCUXVrCpGMWLrRrLZz",
      "code": "SOLO",
      "name": "SOLO"
    },
    {
      "currency": "BTC",
      "issuer": "rchGBxcD1A1C2tdxF6papQYZ8kjRKMYcL",
      "code": "BTC",
      "name": "Bitcoin"
    }
  ]
}
'''),
    );
  });

  group('CurrencyDisplay with XRPSCAN registry', () {
    test('RLUSD hex + issuer → symbol RLUSD and name Ripple USD', () {
      expect(
        CurrencyDisplay.symbol(rlusdHex, issuer: rlusdIssuer),
        'RLUSD',
      );
      expect(
        CurrencyDisplay.name(rlusdHex, issuer: rlusdIssuer),
        'Ripple USD',
      );
      expect(
        CurrencyDisplay.title(rlusdHex, issuer: rlusdIssuer),
        'Ripple USD (RLUSD)',
      );
    });

    test('RLUSD hex without issuer still resolves via currency map', () {
      expect(CurrencyDisplay.symbol(rlusdHex), 'RLUSD');
      expect(CurrencyDisplay.name(rlusdHex), 'Ripple USD');
    });

    test('3-char BTC maps to Bitcoin name', () {
      expect(CurrencyDisplay.symbol('BTC'), 'BTC');
      expect(
        CurrencyDisplay.name(
          'BTC',
          issuer: 'rchGBxcD1A1C2tdxF6papQYZ8kjRKMYcL',
        ),
        'Bitcoin',
      );
    });

    test('XRP is identity', () {
      expect(CurrencyDisplay.symbol('XRP'), 'XRP');
      expect(CurrencyDisplay.name('XRP'), 'XRP');
    });

    test('standard 3-char without registry entry passes through', () {
      expect(CurrencyDisplay.symbol('USD'), 'USD');
      expect(CurrencyDisplay.name('USD'), 'USD');
    });
  });

  group('ASCII hex decode fallback', () {
    test('decodes RLUSD without registry', () {
      CurrencyDisplay.setRegistry(TokenRegistry.empty());
      expect(CurrencyDisplay.decodeHexCurrency(rlusdHex), 'RLUSD');
      expect(CurrencyDisplay.symbol(rlusdHex), 'RLUSD');
    });

    test('decodes SOLO hex', () {
      CurrencyDisplay.setRegistry(TokenRegistry.empty());
      expect(CurrencyDisplay.decodeHexCurrency(soloHex), 'SOLO');
    });

    test('lowercase hex accepted', () {
      CurrencyDisplay.setRegistry(TokenRegistry.empty());
      expect(
        CurrencyDisplay.decodeHexCurrency(rlusdHex.toLowerCase()),
        'RLUSD',
      );
    });

    test('non-printable / empty hex does not crash', () {
      CurrencyDisplay.setRegistry(TokenRegistry.empty());
      expect(
        CurrencyDisplay.decodeHexCurrency(
          'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
        ),
        isNull,
      );
      // Still returns a non-empty display string
      expect(
        CurrencyDisplay.symbol(
          'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
        ),
        isNotEmpty,
      );
    });
  });
}
