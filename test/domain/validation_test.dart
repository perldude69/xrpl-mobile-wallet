import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/config/app_config.dart';
import 'package:xrpl_mobile_wallet/domain/validation/address_validator.dart';
import 'package:xrpl_mobile_wallet/domain/validation/secret_validator.dart';

void main() {
  group('AddressValidator', () {
    test('accepts a known-valid classic address format', () {
      // Well-formed classic address (checksum validated by implementation)
      const addr = 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh';
      expect(AddressValidator.isValidClassic(addr), isTrue);
    });

    test('coffee tip address is a valid classic address', () {
      expect(AddressValidator.isValidClassic(AppConfig.coffeeAddress), isTrue);
    });

    test('rejects empty and garbage', () {
      expect(AddressValidator.isValidClassic(''), isFalse);
      expect(AddressValidator.isValidClassic('not-an-address'), isFalse);
      expect(AddressValidator.isValidClassic('sNoValidAddressHere'), isFalse);
    });
  });

  group('SecretValidator', () {
    test('detects family seed prefix', () {
      expect(SecretValidator.looksLikeFamilySeed('snoPBrXtMeMyMHUVTgbuqAfg1SUTb'), isTrue);
      expect(SecretValidator.looksLikeFamilySeed('hello world'), isFalse);
    });

    test('detects mnemonic by word count', () {
      final words12 = List.filled(12, 'abandon').join(' ');
      final words24 = List.filled(24, 'abandon').join(' ');
      expect(SecretValidator.looksLikeMnemonic(words12), isTrue);
      expect(SecretValidator.looksLikeMnemonic(words24), isTrue);
      expect(SecretValidator.looksLikeMnemonic('only three words'), isFalse);
    });
  });
}
