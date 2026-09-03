import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/data/payments/payment_service.dart';

void main() {
  group('PaymentValidators.validateXrpAmount', () {
    test('accepts positive XRP with up to 6 decimals', () {
      expect(PaymentValidators.validateXrpAmount('1'), isNull);
      expect(PaymentValidators.validateXrpAmount('0.000001'), isNull);
      expect(PaymentValidators.validateXrpAmount('12.5'), isNull);
    });

    test('rejects empty, zero, and too many decimals', () {
      expect(PaymentValidators.validateXrpAmount(''), isNotNull);
      expect(PaymentValidators.validateXrpAmount('0'), isNotNull);
      expect(PaymentValidators.validateXrpAmount('0.0'), isNotNull);
      expect(PaymentValidators.validateXrpAmount('1.0000001'), isNotNull);
      expect(PaymentValidators.validateXrpAmount('abc'), isNotNull);
    });
  });

  group('PaymentValidators.validateIouAmount', () {
    test('accepts positive decimals', () {
      expect(PaymentValidators.validateIouAmount('1'), isNull);
      expect(PaymentValidators.validateIouAmount('0.5'), isNull);
      expect(PaymentValidators.validateIouAmount('80.585677899'), isNull);
    });

    test('rejects empty and zero', () {
      expect(PaymentValidators.validateIouAmount(''), isNotNull);
      expect(PaymentValidators.validateIouAmount('0'), isNotNull);
      expect(PaymentValidators.validateIouAmount('0.00'), isNotNull);
      expect(PaymentValidators.validateIouAmount('-1'), isNotNull);
      expect(PaymentValidators.validateIouAmount('1.2.3'), isNotNull);
    });
  });

  group('PaymentValidators.parseDestinationTag', () {
    test('empty is null', () {
      expect(PaymentValidators.parseDestinationTag(''), isNull);
      expect(PaymentValidators.parseDestinationTag('  '), isNull);
    });

    test('parses valid tags', () {
      expect(PaymentValidators.parseDestinationTag('0'), 0);
      expect(PaymentValidators.parseDestinationTag('25'), 25);
      expect(PaymentValidators.parseDestinationTag('4294967295'), 4294967295);
    });

    test('rejects non-numeric and out of range', () {
      expect(
        () => PaymentValidators.parseDestinationTag('abc'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => PaymentValidators.parseDestinationTag('4294967296'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('PaymentValidators.compareDecimal', () {
    test('orders amounts', () {
      expect(PaymentValidators.compareDecimal('1', '2'), lessThan(0));
      expect(PaymentValidators.compareDecimal('2', '1'), greaterThan(0));
      expect(PaymentValidators.compareDecimal('1.50', '1.5'), 0);
      expect(PaymentValidators.compareDecimal('0.1', '0.01'), greaterThan(0));
    });
  });

  group('PaymentService.privateKeyFromSecret', () {
    test('family seed derives known genesis address', () {
      final pk = PaymentService.privateKeyFromSecret(
        'snoPBrXtMeMyMHUVTgbuqAfg1SUTb',
        expectedAddress: 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh',
      );
      expect(
        pk.getPublic().toClassicAddress().address,
        'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh',
      );
    });

    test('mismatched expected address throws', () {
      expect(
        () => PaymentService.privateKeyFromSecret(
          'snoPBrXtMeMyMHUVTgbuqAfg1SUTb',
          expectedAddress: 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('mnemonic derives xrpl.js secp256k1 classic address', () {
      const phrase =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      const expectedAddress = 'rHsMGQEkVNJmpGWs8XUBoTBiAAbwxZN5v3';
      final pk = PaymentService.privateKeyFromSecret(phrase);
      final addr = pk.getPublic().toClassicAddress().address;
      expect(addr, expectedAddress);
    });

    test('mnemonic with legacy ed25519 expectedAddress still signs', () {
      // Address produced by the old ed25519-first import path for abandon*.
      const phrase =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      const legacyEd25519Address = 'rBo2fTwPahuUDZR5EzT4yGgpnqUjLUuutC';
      final pk = PaymentService.privateKeyFromSecret(
        phrase,
        expectedAddress: legacyEd25519Address,
      );
      expect(
        pk.getPublic().toClassicAddress().address,
        legacyEd25519Address,
      );
    });
  });
}
