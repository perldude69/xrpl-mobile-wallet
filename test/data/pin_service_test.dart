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

  test('min length enforced', () {
    expect(PinService.isPinFormatValid('12345'), isFalse);
    expect(PinService.isPinFormatValid('123456'), isTrue);
  });

  test('legacy sha256 verifier upgrades on successful unlock', () async {
    const walletPin = '111111';
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
    expect(await migrated.verifyPin('000000'), isFalse);
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
      await pin.setPin('111111');
      final setOk =
          await pin.setGamePin(walletPin: '111111', gamePin: '222222');
      expect(setOk, isTrue);
      expect(await pin.hasGamePin(), isTrue);

      expect(await pin.checkUnlockPin('111111'), PinCheckResult.wallet);
      expect(await pin.checkUnlockPin('222222'), PinCheckResult.game);
      expect(await pin.checkUnlockPin('999999'), PinCheckResult.failed);
    });

    test('game PIN must differ from wallet PIN', () async {
      await pin.setPin('111111');
      await expectLater(
        pin.setGamePin(walletPin: '111111', gamePin: '111111'),
        throwsA(isA<ArgumentError>()),
      );
      expect(await pin.hasGamePin(), isFalse);
    });

    test('setGamePin rejects wrong wallet PIN', () async {
      await pin.setPin('111111');
      final ok = await pin.setGamePin(walletPin: '000000', gamePin: '222222');
      expect(ok, isFalse);
      expect(await pin.hasGamePin(), isFalse);
    });

    test('clearGamePin requires wallet PIN and removes hash', () async {
      await pin.setPin('111111');
      await pin.setGamePin(walletPin: '111111', gamePin: '222222');
      expect(await pin.hasGamePin(), isTrue);

      expect(await pin.clearGamePin(walletPin: '000000'), isFalse);
      expect(await pin.hasGamePin(), isTrue);

      expect(await pin.clearGamePin(walletPin: '111111'), isTrue);
      expect(await pin.hasGamePin(), isFalse);
      expect(await pin.checkUnlockPin('222222'), PinCheckResult.failed);
    });

    test('change wallet PIN rejects if equals game PIN', () async {
      await pin.setPin('111111');
      await pin.setGamePin(walletPin: '111111', gamePin: '222222');
      await expectLater(
        pin.changePin(currentPin: '111111', newPin: '222222'),
        throwsA(isA<ArgumentError>()),
      );
      // Wallet PIN unchanged.
      expect(await pin.verifyPin('111111'), isTrue);
    });

    test('change wallet PIN succeeds when different from game PIN', () async {
      await pin.setPin('111111');
      await pin.setGamePin(walletPin: '111111', gamePin: '222222');
      final ok = await pin.changePin(currentPin: '111111', newPin: '333333');
      expect(ok, isTrue);
      expect(await pin.verifyPin('333333'), isTrue);
      expect(await pin.checkUnlockPin('222222'), PinCheckResult.game);
    });

    test('wallet PIN takes precedence if both somehow match', () async {
      // Can only happen if storage was corrupted; verify order is wallet first.
      await pin.setPin('111111');
      expect(await pin.checkUnlockPin('111111'), PinCheckResult.wallet);
    });
  });
}
