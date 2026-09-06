import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:xrpl_mobile_wallet/data/secure/key_names.dart';
import 'package:xrpl_mobile_wallet/data/secure/secure_storage.dart';

class KeyVault {
  KeyVault({FlutterSecureStorage? storage})
      : _storage = storage ?? kAppSecureStorage;

  final FlutterSecureStorage _storage;

  String _key(String walletId) => KeyNames.walletSecret(walletId);

  Future<void> saveSecret(String walletId, String secret) async {
    await _storage.write(key: _key(walletId), value: secret);
  }

  Future<String?> readSecret(String walletId) async {
    return _storage.read(key: _key(walletId));
  }

  Future<void> deleteSecret(String walletId) async {
    await _storage.delete(key: _key(walletId));
  }

  Future<void> deleteAllSecrets() async {
    await _storage.deleteAll();
  }
}
