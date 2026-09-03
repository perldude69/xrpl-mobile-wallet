import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:xrpl_mobile_wallet/config/app_config.dart';
import 'package:xrpl_mobile_wallet/config/storage_keys.dart';

/// Result of checking an unlock PIN against wallet and optional game PIN.
enum PinCheckResult {
  /// Matches the wallet unlock PIN.
  wallet,

  /// Matches the optional game PIN (opens decoy game; stay locked).
  game,

  /// Matches neither (or no PINs configured).
  failed,
}

class PinService {
  PinService({FlutterSecureStorage? storage})
      : _kv = _FlutterSecureKv(storage ?? const FlutterSecureStorage());

  /// In-memory store for unit tests (no platform channels).
  PinService.memory([Map<String, String>? map]) : _kv = _MapKv(map ?? {});

  final _PinKv _kv;

  static bool isPinFormatValid(String pin) =>
      pin.length >= AppConfig.pinMinLength && RegExp(r'^\d+$').hasMatch(pin);

  static String hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  static String generateSalt() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64UrlEncode(bytes);
  }

  Future<bool> hasPin() async {
    final h = await _kv.read(StorageKeys.pinHash);
    return h != null && h.isNotEmpty;
  }

  Future<bool> hasGamePin() async {
    final h = await _kv.read(StorageKeys.gamePinHash);
    return h != null && h.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    if (!isPinFormatValid(pin)) {
      throw ArgumentError(
          'PIN must be at least ${AppConfig.pinMinLength} digits');
    }
    if (await verifyGamePin(pin)) {
      throw ArgumentError('Wallet PIN must differ from the game PIN');
    }
    final salt = generateSalt();
    final hash = hashPin(pin, salt);
    await _kv.write(StorageKeys.pinSalt, salt);
    await _kv.write(StorageKeys.pinHash, hash);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _kv.read(StorageKeys.pinSalt);
    final expected = await _kv.read(StorageKeys.pinHash);
    if (salt == null || expected == null) return false;
    return hashPin(pin, salt) == expected;
  }

  /// Verify [currentPin], then replace with [newPin]. Returns false if current
  /// is wrong. Throws if [newPin] matches the game PIN.
  Future<bool> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    if (!await verifyPin(currentPin)) return false;
    await setPin(newPin);
    return true;
  }

  Future<void> clearPin() async {
    await _kv.delete(StorageKeys.pinHash);
    await _kv.delete(StorageKeys.pinSalt);
  }

  /// Set or replace the game PIN. Requires a correct [walletPin].
  /// Returns false if [walletPin] is wrong.
  /// Throws [ArgumentError] if [gamePin] is invalid or equals the wallet PIN.
  Future<bool> setGamePin({
    required String walletPin,
    required String gamePin,
  }) async {
    if (!await verifyPin(walletPin)) return false;
    if (!isPinFormatValid(gamePin)) {
      throw ArgumentError(
          'Game PIN must be at least ${AppConfig.pinMinLength} digits');
    }
    if (gamePin == walletPin || await verifyPin(gamePin)) {
      throw ArgumentError('Game PIN must differ from the wallet PIN');
    }
    final salt = generateSalt();
    final hash = hashPin(gamePin, salt);
    await _kv.write(StorageKeys.gamePinSalt, salt);
    await _kv.write(StorageKeys.gamePinHash, hash);
    return true;
  }

  Future<bool> verifyGamePin(String pin) async {
    final salt = await _kv.read(StorageKeys.gamePinSalt);
    final expected = await _kv.read(StorageKeys.gamePinHash);
    if (salt == null || expected == null) return false;
    return hashPin(pin, salt) == expected;
  }

  /// Change game PIN after verifying wallet PIN. Returns false if wallet PIN
  /// is wrong. Throws if new game PIN is invalid or equals wallet PIN.
  Future<bool> changeGamePin({
    required String walletPin,
    required String newGamePin,
  }) async {
    return setGamePin(walletPin: walletPin, gamePin: newGamePin);
  }

  /// Clear game PIN after verifying wallet PIN. Returns false if wallet PIN
  /// is wrong.
  Future<bool> clearGamePin({required String walletPin}) async {
    if (!await verifyPin(walletPin)) return false;
    await _kv.delete(StorageKeys.gamePinHash);
    await _kv.delete(StorageKeys.gamePinSalt);
    return true;
  }

  /// Classify an unlock attempt. Wallet PIN takes precedence if both matched
  /// (they must not be equal when set).
  Future<PinCheckResult> checkUnlockPin(String pin) async {
    if (await verifyPin(pin)) return PinCheckResult.wallet;
    if (await verifyGamePin(pin)) return PinCheckResult.game;
    return PinCheckResult.failed;
  }
}

// ---------------------------------------------------------------------------
// Storage backends (secure storage vs in-memory for tests)
// ---------------------------------------------------------------------------

abstract class _PinKv {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _FlutterSecureKv implements _PinKv {
  _FlutterSecureKv(this._storage);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class _MapKv implements _PinKv {
  _MapKv(this._map);
  final Map<String, String> _map;

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async => _map[key] = value;

  @override
  Future<void> delete(String key) async => _map.remove(key);
}
