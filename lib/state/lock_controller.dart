import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/config/app_config.dart';
import 'package:xrpl_mobile_wallet/data/database/app_database.dart';
import 'package:xrpl_mobile_wallet/data/secure/pin_service.dart';
import 'package:xrpl_mobile_wallet/data/secure/key_vault.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';

enum LockPhase { loading, needsSetup, locked, unlocked }

/// Outcome of [LockController.unlockWithPin].
enum UnlockOutcome {
  /// Wallet unlocked (state is [LockPhase.unlocked]).
  wallet,

  /// Game PIN matched; stay locked and open the decoy game.
  game,

  /// Neither PIN matched.
  failed,
}

class LockController extends StateNotifier<LockPhase> {
  LockController(this._pin, this._vault, this._db) : super(LockPhase.loading) {
    _init();
  }

  final PinService _pin;
  final KeyVault _vault;
  final AppDatabase _db;

  Future<void> _init() async {
    state = await _pin.hasPin() ? LockPhase.locked : LockPhase.needsSetup;
  }

  Future<void> setupPin(String pin) async {
    await _pin.setPin(pin);
    await _unlockVault(pin);
    state = LockPhase.unlocked;
  }

  /// Check the wallet PIN without changing lock phase (re-auth for send/wipe).
  Future<bool> verifyWalletPin(String pin) => _pin.verifyPin(pin);

  /// Check wallet PIN, then optional game PIN.
  Future<UnlockOutcome> unlockWithPin(String pin) async {
    final result = await _pin.checkUnlockPin(pin);
    switch (result) {
      case PinCheckResult.wallet:
        try {
          await _unlockVault(pin);
        } catch (_) {
          return UnlockOutcome.failed;
        }
        state = LockPhase.unlocked;
        return UnlockOutcome.wallet;
      case PinCheckResult.game:
        return UnlockOutcome.game;
      case PinCheckResult.failed:
        return UnlockOutcome.failed;
    }
  }

  Future<bool> hasGamePin() => _pin.hasGamePin();

  /// Change wallet PIN after verifying [currentPin].
  /// Returns false if current is wrong. Throws if new PIN equals game PIN.
  Future<bool> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    if (!PinService.isPinFormatValid(newPin)) {
      throw ArgumentError(
        'PIN must be at least ${AppConfig.pinMinLength} digits',
      );
    }
    if (await _pin.verifyGamePin(newPin)) {
      throw ArgumentError('Wallet PIN must differ from the game PIN');
    }
    if (!await _pin.verifyPin(currentPin)) return false;
    final newKey = await _pin.deriveMasterKey(newPin);
    final wallets = await _db.getAllWallets();
    await _vault.rekeySecrets(
      walletIds: wallets.map((wallet) => wallet.id).toList(),
      newKey: newKey,
    );
    await _pin.setPin(newPin);
    return true;
  }

  /// Set or replace game PIN. Requires correct wallet PIN.
  Future<bool> setGamePin({
    required String walletPin,
    required String gamePin,
  }) async {
    return _pin.setGamePin(walletPin: walletPin, gamePin: gamePin);
  }

  /// Clear game PIN. Requires correct wallet PIN.
  Future<bool> clearGamePin({required String walletPin}) async {
    return _pin.clearGamePin(walletPin: walletPin);
  }

  void lock() {
    _vault.lock();
    if (state == LockPhase.unlocked) state = LockPhase.locked;
  }

  /// After wipe: no PIN remains; send user to first-run setup.
  void resetToNeedsSetup() {
    _vault.lock();
    state = LockPhase.needsSetup;
  }

  Future<void> _unlockVault(String pin) async {
    final masterKey = await _pin.deriveMasterKey(pin);
    _vault.unlock(masterKey);
  }
}

final lockControllerProvider = StateNotifierProvider<LockController, LockPhase>(
  (ref) {
    return LockController(
      ref.watch(pinServiceProvider),
      ref.watch(keyVaultProvider),
      ref.watch(databaseProvider),
    );
  },
);
