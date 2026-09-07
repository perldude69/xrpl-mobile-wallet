import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:xrpl_mobile_wallet/data/secure/pin_key.dart';

/// The envelope could not be read at all — malformed JSON, unknown version, or
/// a field of the wrong shape.
///
/// Distinct from [SecretEnvelopeAuthException] because the two mean different
/// things to the user: this one is a corrupt record, that one is usually a
/// mistyped PIN.
class SecretEnvelopeFormatException implements Exception {
  const SecretEnvelopeFormatException(this.reason);

  /// Fixed, non-sensitive description. Never contains envelope contents.
  final String reason;

  @override
  String toString() => 'SecretEnvelopeFormatException: $reason';
}

/// Authentication failed: wrong PIN, wrong wallet, or altered bytes.
///
/// AES-GCM cannot distinguish those — a wrong key and a flipped ciphertext bit
/// both fail the tag — and the caller must not pretend otherwise.
class SecretEnvelopeAuthException implements Exception {
  const SecretEnvelopeAuthException();

  @override
  String toString() => 'SecretEnvelopeAuthException';
}

/// A seed phrase sealed under a subkey of the PIN-derived master key.
///
/// This is what makes the PIN a **cryptographic** factor rather than a UI
/// gate. Before this existed, anything running as the app could ask the
/// Keystore to unwrap and read every seed without knowing the PIN; now the
/// stored bytes are useless without it.
///
/// **Deliberately not bound to any Keystore or device key.** An auth-bound
/// Keystore key is destroyed when the user enrolls a new fingerprint or removes
/// their screen lock, which would take their funds with it. This envelope
/// survives all of that; Keystore is a second, independent layer applied where
/// the envelope is *stored*, and biometrics are only ever a convenience over
/// the top. See `docs/design/2026-09-06-auth-bound-secret-storage.md`.
///
/// **Why a master key and not the PIN directly.** Argon2id costs the better
/// part of a second on a phone. Running it per secret read would put that on
/// every send and every trade signature. Instead [PinKey] runs once per unlock
/// and each wallet gets a cheap HKDF subkey from the result, so sealing and
/// opening here are microseconds.
///
/// Format (compact JSON, no product or ledger identifiers in cleartext):
///
/// ```json
/// {"v":1,"alg":"a256gcm-hkdf","nonce":"…","mac":"…","ct":"…"}
/// ```
class SecretEnvelope {
  SecretEnvelope._();

  static const int version = 1;
  static const String algorithmName = 'a256gcm-hkdf';

  /// Longest plaintext we will unseal. A 24-word mnemonic is ~250 bytes.
  static const int maxPlaintextBytes = 4096;

  /// Seal [secret] for the wallet identified by [contextId].
  ///
  /// [contextId] separates wallets two ways: it is HKDF `info`, so every
  /// wallet gets a different subkey, and it is AES-GCM associated data, so a
  /// stolen envelope cannot be replayed into another wallet's slot.
  static Future<String> seal({
    required String secret,
    required PinMasterKey masterKey,
    required String contextId,
  }) async {
    if (secret.isEmpty) {
      throw const SecretEnvelopeFormatException('empty secret');
    }
    if (contextId.isEmpty) {
      throw const SecretEnvelopeFormatException('empty context id');
    }
    final plain = utf8.encode(secret);
    if (plain.length > maxPlaintextBytes) {
      throw const SecretEnvelopeFormatException('secret is too long');
    }

    final subkey = await _subkey(masterKey, contextId);
    final box = await AesGcm.with256bits().encrypt(
      plain,
      secretKey: subkey,
      aad: _aad(contextId),
    );

    return jsonEncode({
      'v': version,
      'alg': algorithmName,
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'ct': base64Encode(box.cipherText),
    });
  }

  /// Open an envelope produced by [seal].
  ///
  /// Throws [SecretEnvelopeFormatException] if the record is unreadable, and
  /// [SecretEnvelopeAuthException] if the master key is wrong (i.e. wrong PIN),
  /// the wallet id does not match, or the bytes were altered. Neither carries
  /// any part of the secret, the PIN, or the key.
  static Future<String> open({
    required String envelope,
    required PinMasterKey masterKey,
    required String contextId,
  }) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(envelope);
    } catch (_) {
      throw const SecretEnvelopeFormatException('not a valid envelope');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const SecretEnvelopeFormatException('not a valid envelope');
    }
    if (decoded['v'] != version) {
      throw const SecretEnvelopeFormatException('unsupported envelope version');
    }
    if (decoded['alg'] != algorithmName) {
      throw const SecretEnvelopeFormatException('unsupported algorithm');
    }

    final nonce = _decodeBounded('nonce', decoded['nonce'], min: 8, max: 16);
    final mac = _decodeBounded('mac', decoded['mac'], min: 12, max: 32);
    final ct = _decodeBounded(
      'ct',
      decoded['ct'],
      min: 1,
      max: maxPlaintextBytes,
    );

    final subkey = await _subkey(masterKey, contextId);
    final List<int> plain;
    try {
      plain = await AesGcm.with256bits().decrypt(
        SecretBox(ct, nonce: nonce, mac: Mac(mac)),
        secretKey: subkey,
        aad: _aad(contextId),
      );
    } catch (_) {
      // Wrong PIN, wrong wallet, or tampering — indistinguishable, by design.
      throw const SecretEnvelopeAuthException();
    }

    try {
      return utf8.decode(plain);
    } catch (_) {
      throw const SecretEnvelopeFormatException('secret is not valid text');
    }
  }

  /// True when [value] is one of our envelopes rather than a legacy plaintext
  /// secret. Used only to detect un-migrated storage.
  static bool looksLikeEnvelope(String value) {
    final trimmed = value.trimLeft();
    if (!trimmed.startsWith('{')) return false;
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map && decoded['alg'] == algorithmName;
    } catch (_) {
      return false;
    }
  }

  /// Per-wallet subkey. HKDF is cheap, so this runs on every seal and open.
  static Future<SecretKey> _subkey(
    PinMasterKey masterKey,
    String contextId,
  ) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: SecretKey(masterKey.bytes),
      info: _aad(contextId),
    );
  }

  /// Domain separation string, used both as HKDF `info` and as GCM associated
  /// data.
  static List<int> _aad(String contextId) =>
      utf8.encode('zerp.secret.v$version|$contextId');

  static List<int> randomBytes(int length) {
    final rng = Random.secure();
    return List<int>.generate(length, (_) => rng.nextInt(256));
  }

  static List<int> _decodeBounded(
    String field,
    Object? value, {
    required int min,
    required int max,
  }) {
    if (value is! String) {
      throw SecretEnvelopeFormatException('missing $field');
    }
    final List<int> bytes;
    try {
      bytes = base64Decode(value);
    } catch (_) {
      throw SecretEnvelopeFormatException('invalid $field encoding');
    }
    if (bytes.length < min || bytes.length > max) {
      throw SecretEnvelopeFormatException('invalid $field length');
    }
    return bytes;
  }
}
