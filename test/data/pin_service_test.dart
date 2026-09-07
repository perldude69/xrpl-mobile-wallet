import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/config/storage_keys.dart';
import 'package:xrpl_mobile_wallet/data/secure/pin_service.dart';

void main() {
  test('same pin+salt produces same hash', () async {
    final salt = PinService.generateSalt();
    final a = await PinService.hashPin('123456', salt);
    final b = await PinService.hashPin('123456', salt);
    expect(a, equals(b));
    expect(PinService.isLegacyPinHash(a), isFalse);
  });

  test('different pins differ', () async {
    final salt = PinService.generateSalt();
    final a = await PinService.hashPin('123456', salt);
    final b = await PinService.hashPin('654321', salt);
    expect(a, isNot(equals(b)));
  });

  test('min length enforced at 8 digits', () {
    // The PIN is a cryptographic factor (it derives the seed-sealing key), so
    // this floor is a security parameter. 6 and 7 digits must be refused.
    expect(PinService.isPinFormatValid('1234567'), isFalse);
    expect(PinService.isPinFormatValid('123456'), isFalse);
    expect(PinService.isPinFormatValid('12345678'), isTrue);
    expect(PinService.isPinFormatValid('123456789'), isTrue);
    // Digits only.
    expect(PinService.isPinFormatValid('1234567a'), isFalse);
  });

  test('verifyPin does not enforce the minimum', () async {
    // An install that set a 6-digit PIN before the floor moved must still be
    // able to unlock; it is upgraded when the user next changes it. Raising
    // the minimum must never lock somebody out of their own wallet.
    final salt = PinService.generateSalt();
    final existing = PinService.memory({
      StorageKeys.pinSalt: salt,
      StorageKeys.pinHash: await PinService.hashPin('123456', salt),
    });
    expect(await existing.verifyPin('123456'), isTrue);
    expect(await existing.verifyPin('654321'), isFalse);

    // But changing to another short PIN is refused.
    await expectLater(
      existing.changePin(currentPin: '123456', newPin: '654321'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('legacy sha256 verifier upgrades on successful unlock', () async {
    const walletPin = '11111111';
    const salt = 'legacy-salt-value';
    final map = {
      StorageKeys.pinSalt: salt,
      StorageKeys.pinHash: PinService.hashPinLegacy(walletPin, salt),
    };
    final migrated = PinService.memory(map);
    expect(PinService.isLegacyPinHash(map[StorageKeys.pinHash]!), isTrue);
    expect(await migrated.verifyPin(walletPin), isTrue);
    expect(await migrated.verifyPin(walletPin), isTrue);
    expect(PinService.isLegacyPinHash(map[StorageKeys.pinHash]!), isFalse);
    expect(await migrated.verifyPin('00000000'), isFalse);
  });

  test('hashEquals is length-sensitive', () {
    expect(PinService.hashEquals('abcd', 'abcd'), isTrue);
    expect(PinService.hashEquals('abcd', 'abce'), isFalse);
    expect(PinService.hashEquals('abc', 'abcd'), isFalse);
  });

  group('game PIN', () {
    late PinService pin;

    setUp(() {
      pin = PinService.memory();
    });

    test('checkUnlockPin: wallet, game, failed', () async {
      await pin.setPin('11111111');
      final setOk = await pin.setGamePin(
        walletPin: '11111111',
        gamePin: '22222222',
      );
      expect(setOk, isTrue);
      expect(await pin.hasGamePin(), isTrue);

      expect(await pin.checkUnlockPin('11111111'), PinCheckResult.wallet);
      expect(await pin.checkUnlockPin('22222222'), PinCheckResult.game);
      expect(await pin.checkUnlockPin('99999999'), PinCheckResult.failed);
    });

    test('game PIN must differ from wallet PIN', () async {
      await pin.setPin('11111111');
      await expectLater(
        pin.setGamePin(walletPin: '11111111', gamePin: '11111111'),
        throwsA(isA<ArgumentError>()),
      );
      expect(await pin.hasGamePin(), isFalse);
    });

    test('setGamePin rejects wrong wallet PIN', () async {
      await pin.setPin('11111111');
      final ok = await pin.setGamePin(
        walletPin: '00000000',
        gamePin: '22222222',
      );
      expect(ok, isFalse);
      expect(await pin.hasGamePin(), isFalse);
    });

    test('clearGamePin requires wallet PIN and removes hash', () async {
      await pin.setPin('11111111');
      await pin.setGamePin(walletPin: '11111111', gamePin: '22222222');
      expect(await pin.hasGamePin(), isTrue);

      expect(await pin.clearGamePin(walletPin: '00000000'), isFalse);
      expect(await pin.hasGamePin(), isTrue);

      expect(await pin.clearGamePin(walletPin: '11111111'), isTrue);
      expect(await pin.hasGamePin(), isFalse);
      expect(await pin.checkUnlockPin('22222222'), PinCheckResult.failed);
    });

    test('change wallet PIN rejects if equals game PIN', () async {
      await pin.setPin('11111111');
      await pin.setGamePin(walletPin: '11111111', gamePin: '22222222');
      await expectLater(
        pin.changePin(currentPin: '11111111', newPin: '22222222'),
        throwsA(isA<ArgumentError>()),
      );
      // Wallet PIN unchanged.
      expect(await pin.verifyPin('11111111'), isTrue);
    });

    test('change wallet PIN succeeds when different from game PIN', () async {
      await pin.setPin('11111111');
      await pin.setGamePin(walletPin: '11111111', gamePin: '22222222');
      final ok = await pin.changePin(
        currentPin: '11111111',
        newPin: '33333333',
      );
      expect(ok, isTrue);
      expect(await pin.verifyPin('33333333'), isTrue);
      expect(await pin.checkUnlockPin('22222222'), PinCheckResult.game);
    });

    test('wallet PIN takes precedence if both somehow match', () async {
      // Can only happen if storage was corrupted; verify order is wallet first.
      await pin.setPin('11111111');
      expect(await pin.checkUnlockPin('11111111'), PinCheckResult.wallet);
    });
  });
}
