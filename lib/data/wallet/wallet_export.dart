import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:intl/intl.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';

/// One public wallet entry for export/import (no credentials).
class ExportedWalletEntry {
  const ExportedWalletEntry({required this.name, required this.address});

  final String name;
  final String address;
}

/// Password-encrypted export of wallet names + addresses only.
///
/// **Security:** Never includes seeds, mnemonics, or private keys.
/// Outer JSON is generic (no product/ledger branding). Filename should be
/// `yyyyMMdd_HHmmss.json` only.
class WalletExport {
  WalletExport._();

  static const int version = 1;
  static const int pbkdf2Iterations = 120000;
  static const int minPbkdf2Iterations = pbkdf2Iterations;
  static const int maxPbkdf2Iterations = 600000;
  static const int saltLength = 16;
  static const int minPasswordLength = 6;

  /// Build encrypted export document as a JSON map.
  ///
  /// Plaintext is AES-256-GCM sealed; only `name` + `address` lists are inside.
  static Future<Map<String, dynamic>> encryptExport({
    required List<WalletAccount> wallets,
    required String password,
  }) async {
    _requirePassword(password);

    final plain = {
      'items': [
        for (final w in wallets)
          {
            'n': w.label,
            'a': w.address,
          },
      ],
    };
    final plainBytes = utf8.encode(jsonEncode(plain));

    final salt = _randomBytes(saltLength);
    final secretKey = await _deriveKey(password, salt);
    final algorithm = AesGcm.with256bits();
    final secretBox = await algorithm.encrypt(
      plainBytes,
      secretKey: secretKey,
    );

    // Generic envelope — no product or ledger identifiers in cleartext.
    return {
      'v': version,
      'kdf': 'pbkdf2-sha256',
      'iter': pbkdf2Iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'ct': base64Encode(secretBox.cipherText),
    };
  }

  /// Decrypt an export document and return public entries.
  static Future<List<ExportedWalletEntry>> decryptExport({
    required Map<String, dynamic> document,
    required String password,
  }) async {
    _requirePassword(password);

    final v = document['v'];
    if (v != version && v != 1) {
      throw ArgumentError('Unsupported export version: $v');
    }
    if (document['kdf'] != 'pbkdf2-sha256') {
      throw ArgumentError('Unsupported key derivation');
    }
    final iter = _readIterations(document['iter']);
    final salt = _decodeExact('salt', document['salt'], saltLength);
    final nonce = _decodeBounded('nonce', document['nonce'], min: 8, max: 16);
    final macBytes = _decodeBounded('mac', document['mac'], min: 12, max: 32);
    final ct = _decodeBounded('ct', document['ct'], min: 1, max: 1024 * 1024);

    final secretKey = await _deriveKey(password, salt, iterations: iter);
    final algorithm = AesGcm.with256bits();
    final secretBox = SecretBox(
      ct,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final List<int> plainBytes;
    try {
      plainBytes = await algorithm.decrypt(secretBox, secretKey: secretKey);
    } catch (_) {
      throw ArgumentError('Wrong password or corrupted file');
    }

    final decoded = jsonDecode(utf8.decode(plainBytes));
    if (decoded is! Map<String, dynamic>) {
      throw ArgumentError('Invalid export payload');
    }
    final items = decoded['items'];
    if (items is! List) {
      throw ArgumentError('Invalid export payload (missing items)');
    }

    final out = <ExportedWalletEntry>[];
    for (final item in items) {
      if (item is! Map) continue;
      final name = (item['n'] ?? item['name'] ?? '').toString().trim();
      final address = (item['a'] ?? item['address'] ?? '').toString().trim();
      if (name.isEmpty || address.isEmpty) continue;
      out.add(ExportedWalletEntry(name: name, address: address));
    }
    return out;
  }

  /// Suggested export filename: `yyyyMMdd_HHmmss.json` (no product branding).
  static String suggestedFileName([DateTime? now]) {
    final t = now ?? DateTime.now();
    return '${DateFormat('yyyyMMdd_HHmmss').format(t)}.json';
  }

  static Future<SecretKey> _deriveKey(
    String password,
    List<int> salt, {
    int iterations = pbkdf2Iterations,
  }) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  static void _requirePassword(String password) {
    if (password.length < minPasswordLength) {
      throw ArgumentError(
        'Password must be at least $minPasswordLength characters',
      );
    }
  }

  /// Rejects attacker-controlled iteration counts (1 = weak KDF, huge = freeze).
  static int _readIterations(Object? raw) {
    final int iter;
    if (raw == null) {
      iter = pbkdf2Iterations;
    } else if (raw is int) {
      iter = raw;
    } else if (raw is num) {
      iter = raw.toInt();
    } else {
      throw ArgumentError('Unsupported key derivation parameters');
    }
    if (iter < minPbkdf2Iterations || iter > maxPbkdf2Iterations) {
      throw ArgumentError('Unsupported key derivation parameters');
    }
    return iter;
  }

  static List<int> _decodeExact(String field, Object? raw, int length) {
    final bytes = _decodeBounded(field, raw, min: length, max: length);
    return bytes;
  }

  static List<int> _decodeBounded(
    String field,
    Object? raw, {
    required int min,
    required int max,
  }) {
    if (raw is! String || raw.isEmpty) {
      throw ArgumentError('Invalid export $field');
    }
    final List<int> bytes;
    try {
      bytes = base64Decode(raw);
    } catch (_) {
      throw ArgumentError('Invalid export $field');
    }
    if (bytes.length < min || bytes.length > max) {
      throw ArgumentError('Invalid export $field');
    }
    return bytes;
  }

  static Uint8List _randomBytes(int length) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => r.nextInt(256)));
  }
}
