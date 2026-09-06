import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Runtime-derived secure-storage key names (XRW-23).
///
/// Release binaries must not carry plain `wallet_secret_` / `app_pin_hash` /
/// `game_pin_*` literals in the Dart snapshot: those names would tell an
/// analyst exactly where wallet secrets and PIN verifiers live. Instead the
/// names are SHA-256 derivations of XOR-encoded role tags, so
/// `strings libapp.so` shows only opaque bytes. The derivation is
/// deterministic — every install computes the same names for the same inputs.
///
/// This obfuscates *names*, not values: the secrets themselves are protected
/// by Android Keystore via `flutter_secure_storage`. Changing these tags
/// changes where data is stored (old entries become unreachable — re-import
/// or wipe instead of renaming casually).
class KeyNames {
  KeyNames._();

  /// XOR mask for the role tags below. Trivial obfuscation: the goal is to
  /// keep structured key names out of the snapshot, not to hide a secret.
  static const List<int> _mask = <int>[
    0x5a, 0xc3, 0x77, 0x1e, 0x9b, 0xf4, 0x2d, 0x68, //
  ];

  // XOR-encoded role tags ("wallet-secret", "pin-hash", "pin-salt",
  // "game-pin-hash", "game-pin-salt").
  static const List<int> _walletTag = <int>[
    0x2d, 0xa2, 0x1b, 0x72, 0xfe, 0x80, 0x00, 0x1b, 0x3f, 0xa0, 0x05, 0x7b, 0xef, //
  ];
  static const List<int> _pinHashTag = <int>[
    0x2a, 0xaa, 0x19, 0x33, 0xf3, 0x95, 0x5e, 0x00, //
  ];
  static const List<int> _pinSaltTag = <int>[
    0x2a, 0xaa, 0x19, 0x33, 0xe8, 0x95, 0x41, 0x1c, //
  ];
  static const List<int> _gamePinHashTag = <int>[
    0x3d, 0xa2, 0x1a, 0x7b, 0xb6, 0x84, 0x44, 0x06, 0x77, 0xab, 0x16, 0x6d, 0xf3, //
  ];
  static const List<int> _gamePinSaltTag = <int>[
    0x3d, 0xa2, 0x1a, 0x7b, 0xb6, 0x84, 0x44, 0x06, 0x77, 0xb0, 0x16, 0x72, 0xef, //
  ];

  /// Secure-storage key for wallet [walletId]'s secret (mnemonic / seed).
  static String walletSecret(String walletId) => _name(_decode(_walletTag), walletId);

  static String get pinHash => _name(_decode(_pinHashTag));
  static String get pinSalt => _name(_decode(_pinSaltTag));
  static String get gamePinHash => _name(_decode(_gamePinHashTag));
  static String get gamePinSalt => _name(_decode(_gamePinSaltTag));

  static String _decode(List<int> encoded) {
    final out = List<int>.generate(
      encoded.length,
      (i) => encoded[i] ^ _mask[i % _mask.length],
    );
    return utf8.decode(out);
  }

  static String _name(String tag, [String? id]) {
    final parts = <String>[tag, ?id];
    final digest = sha256.convert(utf8.encode(parts.join('\x1f')));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}
