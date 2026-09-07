import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/data/secure/pin_key.dart';
import 'package:xrpl_mobile_wallet/data/secure/secret_envelope.dart';

/// The envelope is the only thing standing between a stolen app data directory
/// and a user's funds, so every branch is pinned here.
///
/// The expensive Argon2id step lives in [PinKey] and is tested separately;
/// these tests use fixed master-key bytes so they run in microseconds.
void main() {
  // Golden 24-word phrase used across the crypto tests.
  const phrase =
      'abandon abandon abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon abandon abandon abandon abandon art';
  const walletId = 'wallet-1';

  /// Stand-ins for the output of [PinKey.derive]: two distinct keys model
  /// "right PIN" and "wrong PIN" without paying for Argon2id.
  PinMasterKey rightKey() => PinMasterKey(List<int>.generate(32, (i) => i));
  PinMasterKey wrongKey() =>
      PinMasterKey(List<int>.generate(32, (i) => 255 - i));

  Future<String> seal({
    String secret = phrase,
    PinMasterKey? key,
    String contextId = walletId,
  }) => SecretEnvelope.seal(
    secret: secret,
    masterKey: key ?? rightKey(),
    contextId: contextId,
  );

  Future<String> open(
    String envelope, {
    PinMasterKey? key,
    String contextId = walletId,
  }) => SecretEnvelope.open(
    envelope: envelope,
    masterKey: key ?? rightKey(),
    contextId: contextId,
  );

  group('round trip', () {
    test('a sealed phrase comes back byte-identical', () async {
      expect(await open(await seal()), phrase);
    });

    test('a family seed round-trips too', () async {
      const secret = 'snoPBrXtMeMyMHUVTgbuqAfg1SUTb';
      expect(await open(await seal(secret: secret)), secret);
    });

    test('the plaintext never appears in the envelope', () async {
      final envelope = await seal();
      expect(envelope.contains('abandon'), isFalse);
      expect(envelope.contains('art'), isFalse);
    });

    test('sealing twice gives different bytes (fresh nonce)', () async {
      final a = await seal();
      final b = await seal();
      expect(a, isNot(b));
      expect(jsonDecode(a)['nonce'], isNot(jsonDecode(b)['nonce']));
      expect(await open(a), phrase);
      expect(await open(b), phrase);
    });

    test('a long secret at the size limit still works', () async {
      final secret = 'x' * SecretEnvelope.maxPlaintextBytes;
      expect(await open(await seal(secret: secret)), secret);
    });
  });

  group('wrong credentials', () {
    test('a wrong master key fails, never returns plaintext', () async {
      await expectLater(
        open(await seal(), key: wrongKey()),
        throwsA(isA<SecretEnvelopeAuthException>()),
      );
    });

    test('a master key differing in one byte fails', () async {
      final almost = PinMasterKey(
        List<int>.generate(32, (i) => i == 31 ? 99 : i),
      );
      await expectLater(
        open(await seal(), key: almost),
        throwsA(isA<SecretEnvelopeAuthException>()),
      );
    });

    test('an empty secret is refused at seal', () async {
      await expectLater(
        seal(secret: ''),
        throwsA(isA<SecretEnvelopeFormatException>()),
      );
    });

    test('an empty context id is refused at seal', () async {
      await expectLater(
        seal(contextId: ''),
        throwsA(isA<SecretEnvelopeFormatException>()),
      );
    });

    test('an over-long secret is refused at seal', () async {
      await expectLater(
        seal(secret: 'x' * (SecretEnvelope.maxPlaintextBytes + 1)),
        throwsA(isA<SecretEnvelopeFormatException>()),
      );
    });

    test('a destroyed master key cannot be used', () async {
      final key = rightKey()..destroy();
      expect(key.isDestroyed, isTrue);
      await expectLater(
        seal(key: key),
        throwsA(isA<StateError>()),
        reason: 'a locked session must not silently encrypt with zeroes',
      );
    });
  });

  group('wallet binding', () {
    test('an envelope will not open under another wallet id', () async {
      await expectLater(
        open(await seal(contextId: 'wallet-1'), contextId: 'wallet-2'),
        throwsA(isA<SecretEnvelopeAuthException>()),
        reason: 'a stolen envelope must not be replayable into another slot',
      );
    });

    test('the matching id opens it', () async {
      expect(
        await open(await seal(contextId: 'wallet-2'), contextId: 'wallet-2'),
        phrase,
      );
    });

    test('each wallet gets a different subkey from one master key', () async {
      // Same secret, same master key, different wallet: the ciphertexts must
      // not be interchangeable.
      final a = await seal(contextId: 'wallet-a');
      await expectLater(
        open(a, contextId: 'wallet-b'),
        throwsA(isA<SecretEnvelopeAuthException>()),
      );
    });
  });

  group('tampering', () {
    Future<Map<String, dynamic>> sealedMap() async =>
        jsonDecode(await seal()) as Map<String, dynamic>;

    Future<void> expectRejected(Map<String, dynamic> doc) => expectLater(
      open(jsonEncode(doc)),
      throwsA(
        anyOf(
          isA<SecretEnvelopeAuthException>(),
          isA<SecretEnvelopeFormatException>(),
        ),
      ),
    );

    test('a flipped ciphertext byte is caught by the GCM tag', () async {
      final doc = await sealedMap();
      final ct = base64Decode(doc['ct'] as String);
      ct[0] ^= 0x01;
      doc['ct'] = base64Encode(ct);
      await expectRejected(doc);
    });

    test('a swapped nonce is caught', () async {
      final doc = await sealedMap();
      doc['nonce'] = (await sealedMap())['nonce'];
      await expectRejected(doc);
    });

    test('a swapped mac is caught', () async {
      final doc = await sealedMap();
      doc['mac'] = (await sealedMap())['mac'];
      await expectRejected(doc);
    });

    test('a truncated mac is caught', () async {
      final doc = await sealedMap();
      doc['mac'] = base64Encode(
        base64Decode(doc['mac'] as String).sublist(0, 12),
      );
      await expectRejected(doc);
    });

    test('a ciphertext from another envelope is caught', () async {
      final doc = await sealedMap();
      doc['ct'] = (await sealedMap())['ct'];
      await expectRejected(doc);
    });
  });

  group('malformed records', () {
    Future<void> expectFormatError(String envelope) => expectLater(
      open(envelope),
      throwsA(isA<SecretEnvelopeFormatException>()),
    );

    test('not JSON', () => expectFormatError('not an envelope'));
    test('empty string', () => expectFormatError(''));
    test('a JSON array', () => expectFormatError('[]'));
    test('a bare number', () => expectFormatError('42'));

    test('unknown version', () async {
      final doc = jsonDecode(await seal()) as Map<String, dynamic>;
      doc['v'] = 99;
      await expectFormatError(jsonEncode(doc));
    });

    test('unknown algorithm', () async {
      final doc = jsonDecode(await seal()) as Map<String, dynamic>;
      doc['alg'] = 'rot13';
      await expectFormatError(jsonEncode(doc));
    });

    test('missing fields', () async {
      for (final field in ['nonce', 'mac', 'ct', 'v', 'alg']) {
        final doc = jsonDecode(await seal()) as Map<String, dynamic>;
        doc.remove(field);
        await expectFormatError(jsonEncode(doc));
      }
    });

    test('non-base64 field', () async {
      final doc = jsonDecode(await seal()) as Map<String, dynamic>;
      doc['ct'] = 'not base64 !!!';
      await expectFormatError(jsonEncode(doc));
    });

    test('a nonce of implausible length', () async {
      final doc = jsonDecode(await seal()) as Map<String, dynamic>;
      doc['nonce'] = base64Encode(List<int>.filled(4, 0));
      await expectFormatError(jsonEncode(doc));
    });

    test('an oversized ciphertext is refused before decrypting', () async {
      // Untrusted input once app storage is compromised — must not become a
      // memory-exhaustion lever.
      final doc = jsonDecode(await seal()) as Map<String, dynamic>;
      doc['ct'] = base64Encode(
        List<int>.filled(SecretEnvelope.maxPlaintextBytes + 1, 0),
      );
      await expectFormatError(jsonEncode(doc));
    });
  });

  group('looksLikeEnvelope', () {
    test('recognises our own output', () async {
      expect(SecretEnvelope.looksLikeEnvelope(await seal()), isTrue);
    });

    test('rejects a legacy plaintext mnemonic', () {
      expect(SecretEnvelope.looksLikeEnvelope(phrase), isFalse);
    });

    test('rejects a legacy family seed', () {
      expect(
        SecretEnvelope.looksLikeEnvelope('snoPBrXtMeMyMHUVTgbuqAfg1SUTb'),
        isFalse,
      );
    });

    test('rejects unrelated JSON', () {
      expect(SecretEnvelope.looksLikeEnvelope('{"a":1}'), isFalse);
    });

    test('rejects an empty string', () {
      expect(SecretEnvelope.looksLikeEnvelope(''), isFalse);
    });
  });

  test('the algorithm identity is not changed casually', () {
    // Changing either would make every stored secret unreadable.
    expect(SecretEnvelope.version, 1);
    expect(SecretEnvelope.algorithmName, 'a256gcm-hkdf');
  });
}
