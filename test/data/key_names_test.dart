import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/data/secure/key_names.dart';

void main() {
  group('KeyNames', () {
    test('derived names are stable and non-empty', () {
      expect(KeyNames.walletSecret('w1'), KeyNames.walletSecret('w1'));
      expect(KeyNames.pinHash, isNotEmpty);
      expect(KeyNames.pinSalt, isNotEmpty);
      expect(KeyNames.gamePinHash, isNotEmpty);
      expect(KeyNames.gamePinSalt, isNotEmpty);
    });

    test('per-wallet secret keys differ per wallet id', () {
      expect(KeyNames.walletSecret('w1'), isNot(KeyNames.walletSecret('w2')));
    });

    test('roles never collide', () {
      final names = <String>{
        KeyNames.pinHash,
        KeyNames.pinSalt,
        KeyNames.gamePinHash,
        KeyNames.gamePinSalt,
        KeyNames.walletSecret('w1'),
      };
      expect(names.length, 5);
    });

    test('names are base64url without padding or structured literals', () {
      for (final n in <String>[
        KeyNames.pinHash,
        KeyNames.pinSalt,
        KeyNames.gamePinHash,
        KeyNames.gamePinSalt,
        KeyNames.walletSecret('w1'),
      ]) {
        expect(n, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
        expect(n.contains('pin'), isFalse);
        expect(n.contains('secret'), isFalse);
      }
    });
  });
}
