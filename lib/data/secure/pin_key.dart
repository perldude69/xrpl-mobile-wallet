import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// A stored KDF configuration could not be read.
class PinKdfFormatException implements Exception {
  const PinKdfFormatException(this.reason);

  /// Fixed, non-sensitive description. Never contains key material.
  final String reason;

  @override
  String toString() => 'PinKdfFormatException: $reason';
}

/// Argon2id cost and salt for turning the wallet PIN into a master key.
///
/// Persisted **once per install** rather than per wallet, because the master
/// key is derived once per unlock and then reused for every wallet (see
/// [PinMasterKey]). Storing the parameters, rather than hard-coding them at the
/// read path, is what allows the cost to be raised on a later release without
/// making existing installs unreadable.
class PinKdfParams {
  const PinKdfParams({
    required this.salt,
    this.memoryBlocks = currentMemoryBlocks,
    this.iterations = currentIterations,
    this.parallelism = currentParallelism,
  });

  /// Argon2id memory cost in 1 KiB blocks. 65536 = 64 MiB.
  ///
  /// Memory hardness is what makes a short numeric PIN expensive to attack in
  /// bulk: GPUs and ASICs gain far less against a memory-bound KDF than
  /// against PBKDF2. Measured at ~810 ms on a desktop core; a budget phone
  /// will be several times that, which is why the master key is derived **once
  /// per unlock** and cached rather than per secret read.
  static const int currentMemoryBlocks = 65536;

  /// Passes over memory.
  static const int currentIterations = 3;

  /// Lanes. Kept at 1 — parallelism helps an attacker with many cores more
  /// than it helps a phone.
  static const int currentParallelism = 1;

  static const int keyLength = 32;
  static const int saltLength = 16;

  /// Ceilings on what we will accept from stored configuration.
  ///
  /// The record is attacker-reachable once app storage is compromised, so its
  /// numbers are untrusted input: without a ceiling a doctored record could
  /// pin the app in a multi-gigabyte allocation on every unlock.
  static const int maxMemoryBlocks = 1048576; // 1 GiB
  static const int maxIterations = 16;
  static const int maxParallelism = 8;

  final List<int> salt;
  final int memoryBlocks;
  final int iterations;
  final int parallelism;

  /// Fresh parameters at today's cost, with a CSPRNG salt.
  static PinKdfParams generate() =>
      PinKdfParams(salt: _randomBytes(saltLength));

  /// True when this record is cheaper than the current standard, i.e. the
  /// master key should be re-derived and secrets re-sealed at the next
  /// opportunity.
  bool get isBelowCurrentCost =>
      memoryBlocks < currentMemoryBlocks || iterations < currentIterations;

  Map<String, dynamic> toJson() => {
    'kdf': 'argon2id',
    'm': memoryBlocks,
    't': iterations,
    'p': parallelism,
    'salt': base64Encode(salt),
  };

  String encode() => jsonEncode(toJson());

  static PinKdfParams decode(String record) {
    final Object? decoded;
    try {
      decoded = jsonDecode(record);
    } catch (_) {
      throw const PinKdfFormatException('not a valid KDF record');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const PinKdfFormatException('not a valid KDF record');
    }
    if (decoded['kdf'] != 'argon2id') {
      throw const PinKdfFormatException('unsupported key derivation');
    }
    final salt = decoded['salt'];
    if (salt is! String) {
      throw const PinKdfFormatException('missing salt');
    }
    final List<int> saltBytes;
    try {
      saltBytes = base64Decode(salt);
    } catch (_) {
      throw const PinKdfFormatException('invalid salt encoding');
    }
    if (saltBytes.length != saltLength) {
      throw const PinKdfFormatException('invalid salt length');
    }
    return PinKdfParams(
      salt: saltBytes,
      memoryBlocks: _readInt(decoded['m'], 'm', min: 8, max: maxMemoryBlocks),
      iterations: _readInt(decoded['t'], 't', min: 1, max: maxIterations),
      parallelism: _readInt(decoded['p'], 'p', min: 1, max: maxParallelism),
    );
  }

  static int _readInt(
    Object? value,
    String field, {
    required int min,
    required int max,
  }) {
    if (value is! int || value < min || value > max) {
      throw PinKdfFormatException('invalid $field parameter');
    }
    return value;
  }

  static List<int> _randomBytes(int length) {
    final rng = Random.secure();
    return List<int>.generate(length, (_) => rng.nextInt(256));
  }
}

/// The 32-byte key derived from the wallet PIN.
///
/// Held in memory only, for the duration of an unlocked session, and never
/// written anywhere. Every wallet's secret is sealed under a subkey of this
/// (see `SecretEnvelope`), so one expensive Argon2id pass covers the whole
/// session instead of one per secret read.
///
/// [destroy] overwrites the bytes we hold. That is hygiene, not a guarantee:
/// Dart cannot wipe the `String` the PIN arrived in, and the VM may have
/// copied buffers. It still shortens the window in which a heap dump is
/// useful.
class PinMasterKey {
  PinMasterKey(List<int> bytes) : _bytes = Uint8List.fromList(bytes) {
    if (bytes.length != PinKdfParams.keyLength) {
      throw ArgumentError('master key must be ${PinKdfParams.keyLength} bytes');
    }
  }

  final Uint8List _bytes;
  bool _destroyed = false;

  bool get isDestroyed => _destroyed;

  /// Raw bytes. Throws once [destroy] has been called, so a stale session
  /// cannot silently decrypt with a zeroed key.
  List<int> get bytes {
    if (_destroyed) {
      throw StateError('PinMasterKey has been destroyed');
    }
    return _bytes;
  }

  void destroy() {
    _bytes.fillRange(0, _bytes.length, 0);
    _destroyed = true;
  }
}

/// Derives [PinMasterKey] from the wallet PIN.
class PinKey {
  PinKey._();

  /// Run Argon2id over [pin] with [params].
  ///
  /// Expensive by design — hundreds of milliseconds to seconds. Call this once
  /// per unlock, hold the result for the session, and never call it on a
  /// per-transaction path.
  static Future<PinMasterKey> derive({
    required String pin,
    required PinKdfParams params,
  }) async {
    if (pin.isEmpty) {
      throw const PinKdfFormatException('empty pin');
    }
    final argon2 = Argon2id(
      memory: params.memoryBlocks,
      iterations: params.iterations,
      parallelism: params.parallelism,
      hashLength: PinKdfParams.keyLength,
    );
    final key = await argon2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: params.salt,
    );
    return PinMasterKey(await key.extractBytes());
  }
}
