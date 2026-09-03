import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/domain/validation/qr_address_parser.dart';

void main() {
  const genesis = 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh';

  group('QrAddressParser.extractClassicAddress', () {
    test('accepts bare classic address', () {
      expect(QrAddressParser.extractClassicAddress(genesis), genesis);
      expect(
        QrAddressParser.extractClassicAddress('  $genesis  '),
        genesis,
      );
    });

    test('accepts xrpl: and ripple: schemes', () {
      expect(
        QrAddressParser.extractClassicAddress('xrpl:$genesis'),
        genesis,
      );
      expect(
        QrAddressParser.extractClassicAddress('ripple:$genesis'),
        genesis,
      );
    });

    test('accepts address in query params', () {
      expect(
        QrAddressParser.extractClassicAddress(
          'https://example.com/pay?address=$genesis',
        ),
        genesis,
      );
      expect(
        QrAddressParser.extractClassicAddress(
          'xrpl:$genesis?dt=123',
        ),
        genesis,
      );
    });

    test('finds address embedded in surrounding text', () {
      expect(
        QrAddressParser.extractClassicAddress('Send to $genesis please'),
        genesis,
      );
    });

    test('rejects empty and garbage', () {
      expect(QrAddressParser.extractClassicAddress(''), isNull);
      expect(QrAddressParser.extractClassicAddress('not-an-address'), isNull);
      expect(
        QrAddressParser.extractClassicAddress('snoPBrXtMeMyMHUVTgbuqAfg1SUTb'),
        isNull,
      );
    });
  });
}
