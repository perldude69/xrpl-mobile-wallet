import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:xrpl_mobile_wallet/data/secure/key_names.dart';
import 'package:xrpl_mobile_wallet/data/secure/secure_storage.dart';
import 'package:xrpl_mobile_wallet/data/secure/pin_key.dart';
import 'package:xrpl_mobile_wallet/data/secure/secret_envelope.dart';

class KeyVault {
  KeyVault({FlutterSecureStorage? storage})
    : _storage = storage ?? kAppSecureStorage;

  final FlutterSecureStorage _storage;
  PinMasterKey? _masterKey;

  String _key(String walletId) => KeyNames.walletSecret(walletId);

  void unlock(PinMasterKey masterKey) {
    _masterKey?.destroy();
    _masterKey = masterKey;
  }

  void lock() {
    _masterKey?.destroy();
    _masterKey = null;
  }

  Future<void> saveSecret(String walletId, String secret) async {
    final key = _masterKey;
    if (key == null || key.isDestroyed) {
      throw StateError(
        'Wallet keys are unavailable; unlock with the wallet PIN',
      );
    }
    final envelope = await SecretEnvelope.seal(
      secret: secret,
      masterKey: key,
      contextId: walletId,
    );
    await _storage.write(key: _key(walletId), value: envelope);
  }

  Future<String?> readSecret(String walletId) async {
    final key = _masterKey;
    if (key == null || key.isDestroyed) {
      throw StateError(
        'Wallet keys are unavailable; unlock with the wallet PIN',
      );
    }
    final stored = await _storage.read(key: _key(walletId));
    if (stored == null) return null;
    if (SecretEnvelope.looksLikeEnvelope(stored)) {
      return SecretEnvelope.open(
        envelope: stored,
        masterKey: key,
        contextId: walletId,
      );
    }
    // One-time migration for wallets written by the old plaintext vault.
    final envelope = await SecretEnvelope.seal(
      secret: stored,
      masterKey: key,
      contextId: walletId,
    );
    await _storage.write(key: _key(walletId), value: envelope);
    return stored;
  }

  Future<void> deleteSecret(String walletId) async {
    await _storage.delete(key: _key(walletId));
  }

  /// Re-seal wallet secrets during a wallet PIN change.
  Future<void> rekeySecrets({
    required List<String> walletIds,
    required PinMasterKey newKey,
  }) async {
    final oldKey = _masterKey;
    if (oldKey == null || oldKey.isDestroyed) {
      throw StateError(
        'Wallet keys are unavailable; unlock with the wallet PIN',
      );
    }
    final migrated = <String, String>{};
    for (final walletId in walletIds) {
      final stored = await _storage.read(key: _key(walletId));
      if (stored == null) continue;
      final secret = SecretEnvelope.looksLikeEnvelope(stored)
          ? await SecretEnvelope.open(
              envelope: stored,
              masterKey: oldKey,
              contextId: walletId,
            )
          : stored;
      migrated[walletId] = await SecretEnvelope.seal(
        secret: secret,
        masterKey: newKey,
        contextId: walletId,
      );
    }
    for (final entry in migrated.entries) {
      await _storage.write(key: _key(entry.key), value: entry.value);
    }
    unlock(newKey);
  }

  Future<void> deleteAllSecrets() async {
    await _storage.deleteAll();
    lock();
  }
}
