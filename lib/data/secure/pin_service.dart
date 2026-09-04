import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:xrpl_mobile_wallet/config/app_config.dart';
import 'package:xrpl_mobile_wallet/config/storage_keys.dart';
import 'package:xrpl_mobile_wallet/data/secure/secure_storage.dart';

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
      : _kv = _FlutterSecureKv(storage ?? kAppSecureStorage);

  /// In-memory store for unit tests (no platform channels).
  PinService.memory([Map<String, String>? map]) : _kv = _MapKv(map ?? {});

  final _PinKv _kv;

  static bool isPinFormatValid(String pin) =>
      pin.length >= AppConfig.pinMinLength && RegExp(r'^\d+$').hasMatch(pin);

  /// PBKDF2-SHA256 PIN verifier (same KDF family as [WalletExport]).
  static Future<String> hashPin(
    String pin,
    String salt, {
    int iterations = AppConfig.pinPbkdf2Iterations,
  }) async {
    final saltBytes = base64Url.decode(salt);
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: saltBytes,
    );
    final bytes = await key.extractBytes();
    return base64UrlEncode(bytes);
  }

  /// Pre-PBKDF2 verifier: `sha256('$salt:$pin')` hex. Kept to migrate
  /// existing installs on the next successful unlock.
  static String hashPinLegacy(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return crypto.sha256.convert(bytes).toString();
  }

  static bool isLegacyPinHash(String hash) =>
      RegExp(r'^[0-9a-f]{64}$').hasMatch(hash);

  static String generateSalt() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// Constant-time equality for equal-length strings; length mismatch is false.
  static bool hashEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
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
    await _writeVerifier(
      pin: pin,
      saltKey: StorageKeys.pinSalt,
      hashKey: StorageKeys.pinHash,
    );
  }

  Future<bool> verifyPin(String pin) async {
    return _verifyAndMaybeUpgrade(
      pin: pin,
      saltKey: StorageKeys.pinSalt,
      hashKey: StorageKeys.pinHash,
    );
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
    await _writeVerifier(
      pin: gamePin,
      saltKey: StorageKeys.gamePinSalt,
      hashKey: StorageKeys.gamePinHash,
    );
    return true;
  }

  Future<bool> verifyGamePin(String pin) async {
    return _verifyAndMaybeUpgrade(
      pin: pin,
      saltKey: StorageKeys.gamePinSalt,
      hashKey: StorageKeys.gamePinHash,
    );
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

  /// Delete wallet and game PIN verifiers (full wipe). Does not require the PIN.
  Future<void> wipePins() async {
    await _kv.delete(StorageKeys.pinHash);
    await _kv.delete(StorageKeys.pinSalt);
    await _kv.delete(StorageKeys.gamePinHash);
    await _kv.delete(StorageKeys.gamePinSalt);
  }

  /// Classify an unlock attempt. Wallet PIN takes precedence if both matched
  /// (they must not be equal when set).
  Future<PinCheckResult> checkUnlockPin(String pin) async {
    if (await verifyPin(pin)) return PinCheckResult.wallet;
    if (await verifyGamePin(pin)) return PinCheckResult.game;
    return PinCheckResult.failed;
  }

  Future<void> _writeVerifier({
    required String pin,
    required String saltKey,
    required String hashKey,
  }) async {
    final salt = generateSalt();
    final hash = await hashPin(pin, salt);
    await _kv.write(saltKey, salt);
    await _kv.write(hashKey, hash);
  }

  Future<bool> _verifyAndMaybeUpgrade({
    required String pin,
    required String saltKey,
    required String hashKey,
  }) async {
    final salt = await _kv.read(saltKey);
    final expected = await _kv.read(hashKey);
    if (salt == null || expected == null) return false;

    if (isLegacyPinHash(expected)) {
      if (!hashEquals(hashPinLegacy(pin, salt), expected)) return false;
      await _writeVerifier(pin: pin, saltKey: saltKey, hashKey: hashKey);
      return true;
    }

    final computed = await hashPin(pin, salt);
    return hashEquals(computed, expected);
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
