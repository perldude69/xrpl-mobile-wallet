import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xrpl_mobile_wallet/config/storage_keys.dart';
import 'package:xrpl_mobile_wallet/data/secure/pin_service.dart';
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
  LockController(this._pin) : super(LockPhase.loading) {
    _init();
  }

  final PinService _pin;
  final _auth = LocalAuthentication();

  Future<void> _init() async {
    state = await _pin.hasPin() ? LockPhase.locked : LockPhase.needsSetup;
  }

  Future<void> setupPin(String pin) async {
    await _pin.setPin(pin);
    state = LockPhase.unlocked;
  }

  /// Check wallet PIN, then optional game PIN.
  Future<UnlockOutcome> unlockWithPin(String pin) async {
    final result = await _pin.checkUnlockPin(pin);
    switch (result) {
      case PinCheckResult.wallet:
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
    return _pin.changePin(currentPin: currentPin, newPin: newPin);
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

  Future<bool> isBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageKeys.biometricsEnabled) ?? false;
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.biometricsEnabled, enabled);
  }

  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlockWithBiometrics() async {
    if (!await isBiometricsEnabled()) return false;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock XRPL Mobile Wallet',
        biometricOnly: true,
      );
      if (ok) state = LockPhase.unlocked;
      return ok;
    } catch (_) {
      return false;
    }
  }

  void lock() {
    if (state == LockPhase.unlocked) state = LockPhase.locked;
  }

  /// After wipe: no PIN remains; send user to first-run setup.
  void resetToNeedsSetup() {
    state = LockPhase.needsSetup;
  }
}

final lockControllerProvider =
    StateNotifierProvider<LockController, LockPhase>((ref) {
  return LockController(ref.watch(pinServiceProvider));
});
