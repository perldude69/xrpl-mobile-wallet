import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Domain-separated mixing of OS CSPRNG entropy with user ritual contributions.
///
/// Security model (aligns with "always ride the OS RNG"):
/// - [osEntropy32] is **always** 32 bytes from a cryptographically secure RNG
///   ([Random.secure] → OS CSPRNG on mobile).
/// - Dice / swipe / typed word are **additional** inputs only; they never replace
///   the OS pool. A weak word or few rolls cannot produce a weak wallet.
/// - Final BIP39 entropy is `SHA-256(domain ‖ 0x00 ‖ os ‖ 0x00 ‖ ritualHash)`.
class EntropyMixer {
  EntropyMixer._();

  /// Versioned domain separation string (do not change without a new version).
  static const String domain = 'xrpl-mobile-wallet/v1/entropy';

  /// BIP39 24-word entropy length in bytes.
  static const int entropyBytes = 32;

  /// Minimum motion score (0–100) required before leaving the dice step.
  static const double minMotionScore = 80;

  /// Rough minimum word strength (0–100) before mixing.
  static const double minWordStrength = 35;

  /// Fill [length] bytes from [random] (defaults to [Random.secure]).
  static Uint8List osEntropy([int length = entropyBytes, Random? random]) {
    if (length <= 0) {
      throw ArgumentError.value(length, 'length', 'must be positive');
    }
    final rng = random ?? Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => rng.nextInt(256)));
  }

  /// Hash UTF-8 bytes of [word] (empty word still yields a defined hash).
  static Uint8List hashWord(String word) {
    return Uint8List.fromList(sha256.convert(utf8.encode(word)).bytes);
  }

  /// Canonical encoding of dice / swipe ritual data, then SHA-256.
  static Uint8List hashRitualPayload(RitualEntropyInput input) {
    final payload = utf8.encode(input.canonicalJson);
    return Uint8List.fromList(sha256.convert(payload).bytes);
  }

  /// Mix OS entropy with ritual contributions → 32-byte BIP39 entropy.
  ///
  /// [osBytes] must be exactly [entropyBytes] from a CSPRNG.
  static Uint8List mix({
    required Uint8List osBytes,
    required RitualEntropyInput ritual,
  }) {
    if (osBytes.length != entropyBytes) {
      throw ArgumentError(
        'osBytes must be $entropyBytes bytes, got ${osBytes.length}',
      );
    }
    final ritualHash = hashRitualPayload(ritual);
    final wordHash = hashWord(ritual.personalWord);

    final builder = BytesBuilder(copy: false);
    builder.add(utf8.encode(domain));
    builder.addByte(0);
    builder.add(osBytes);
    builder.addByte(0);
    builder.add(utf8.encode('ritual'));
    builder.addByte(0);
    builder.add(ritualHash);
    builder.addByte(0);
    builder.add(utf8.encode('word'));
    builder.addByte(0);
    builder.add(wordHash);

    return Uint8List.fromList(sha256.convert(builder.toBytes()).bytes);
  }

  /// Heuristic strength of a personal contribution (0–100). Not cryptographic.
  ///
  /// Rewards length, multiple tokens, character-class diversity, and variety.
  /// Long lowercase prose used to cap near ~60 because length was hard-capped
  /// at 40 points and bonuses required digits/symbols/mixed case.
  static double wordStrength(String word) {
    if (word.isEmpty) return 0;
    final trimmed = word.trim();
    if (trimmed.isEmpty) return 0;

    var score = 0.0;

    // Length: strong early, then diminishing — still grows past “pages of text”.
    // ~20 chars → ~35, ~40 → ~50, ~80 → ~60, ~160+ → ~70
    final len = trimmed.length;
    score += (40 * (1 - exp(-len / 28))).clamp(0, 40);
    if (len > 40) {
      score += ((len - 40) / 8).clamp(0, 15); // up to +15 for long input
    }

    // Token count (words / chunks)
    final tokens = trimmed
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.length >= 2) score += 8;
    if (tokens.length >= 4) score += 6;
    if (tokens.length >= 8) score += 6;

    // Character-class diversity
    final hasLower = RegExp(r'[a-z]').hasMatch(trimmed);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(trimmed);
    final hasDigit = RegExp(r'\d').hasMatch(trimmed);
    final hasSymbol = RegExp(r'[^A-Za-z0-9\s]').hasMatch(trimmed);
    var classes = 0;
    if (hasLower) classes++;
    if (hasUpper) classes++;
    if (hasDigit) classes++;
    if (hasSymbol) classes++;
    score += classes * 6; // up to 24

    // Unique-character ratio (penalize "aaaa aaa aaa")
    final unique = trimmed.replaceAll(RegExp(r'\s'), '').split('').toSet().length;
    final nonSpace = trimmed.replaceAll(RegExp(r'\s'), '').length;
    if (nonSpace > 0) {
      final variety = unique / nonSpace;
      score += (variety * 12).clamp(0, 12);
    }

    // Single short lowercase token is weak.
    if (RegExp(r'^[a-z]{1,8}$').hasMatch(trimmed)) {
      score = score.clamp(0, 25);
    }

    return score.clamp(0, 100);
  }
}

/// One swipe/roll sample collected during the dice ritual.
class DiceRollSample {
  const DiceRollSample({
    required this.pathLength,
    required this.durationMs,
    required this.speedAvg,
    required this.faces,
    required this.pathPoints,
    required this.timestampMs,
  });

  final double pathLength;
  final int durationMs;
  final double speedAvg;

  /// Final face values (1–6) for each die after this roll.
  final List<int> faces;

  /// Sparse path samples: [x, y, tMs] triples (capped by the pad).
  final List<List<int>> pathPoints;
  final int timestampMs;

  Map<String, Object?> toJson() => {
        'pathLength': pathLength,
        'durationMs': durationMs,
        'speedAvg': speedAvg,
        'faces': faces,
        'pathPoints': pathPoints,
        'timestampMs': timestampMs,
      };
}

/// User contributions folded into [EntropyMixer.mix].
class RitualEntropyInput {
  const RitualEntropyInput({
    required this.rolls,
    required this.personalWord,
    required this.motionScore,
  });

  final List<DiceRollSample> rolls;
  final String personalWord;
  final double motionScore;

  /// Stable JSON used for hashing (field order fixed).
  String get canonicalJson {
    // Manual encoding keeps key order stable without dart:convert map quirks.
    final rollsJson = rolls.map((r) {
      final pts = r.pathPoints
          .map((p) => '[${p.join(',')}]')
          .join(',');
      return '{'
          '"pathLength":${r.pathLength},'
          '"durationMs":${r.durationMs},'
          '"speedAvg":${r.speedAvg},'
          '"faces":[${r.faces.join(',')}],'
          '"pathPoints":[$pts],'
          '"timestampMs":${r.timestampMs}'
          '}';
    }).join(',');
    // Escape word for JSON string
    final escaped = jsonEncode(personalWord);
    return '{'
        '"v":1,'
        '"motionScore":$motionScore,'
        '"word":$escaped,'
        '"rolls":[$rollsJson]'
        '}';
  }
}
