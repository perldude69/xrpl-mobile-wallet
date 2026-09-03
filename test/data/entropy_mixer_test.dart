import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/data/wallet/entropy_mixer.dart';

void main() {
  group('EntropyMixer', () {
    test('osEntropy returns requested length', () {
      final a = EntropyMixer.osEntropy(32, Random(1));
      final b = EntropyMixer.osEntropy(32, Random(1));
      expect(a, hasLength(32));
      expect(b, hasLength(32));
      // Same seed → same bytes for deterministic Random
      expect(a, b);
    });

    test('osEntropy differs across secure draws (Random.secure)', () {
      final a = EntropyMixer.osEntropy();
      final b = EntropyMixer.osEntropy();
      expect(a, hasLength(32));
      expect(b, hasLength(32));
      // Extremely unlikely to collide
      expect(a, isNot(equals(b)));
    });

    test('mix is deterministic for fixed inputs', () {
      final os = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final ritual = RitualEntropyInput(
        motionScore: 90,
        personalWord: 'purple-toaster-7',
        rolls: [
          DiceRollSample(
            pathLength: 120,
            durationMs: 400,
            speedAvg: 0.5,
            faces: [1, 2, 3, 4, 5],
            pathPoints: [
              [10, 20, 1],
              [30, 40, 2],
            ],
            timestampMs: 1000,
          ),
        ],
      );
      final once = EntropyMixer.mix(osBytes: os, ritual: ritual);
      final twice = EntropyMixer.mix(osBytes: os, ritual: ritual);
      expect(once, hasLength(32));
      expect(once, twice);
    });

    test('mix changes when OS bytes change', () {
      final os1 = Uint8List.fromList(List<int>.filled(32, 1));
      final os2 = Uint8List.fromList(List<int>.filled(32, 2));
      final ritual = RitualEntropyInput(
        motionScore: 80,
        personalWord: 'x',
        rolls: const [],
      );
      final a = EntropyMixer.mix(osBytes: os1, ritual: ritual);
      final b = EntropyMixer.mix(osBytes: os2, ritual: ritual);
      expect(a, isNot(equals(b)));
    });

    test('mix changes when word changes', () {
      final os = Uint8List.fromList(List<int>.filled(32, 7));
      RitualEntropyInput ritual(String w) => RitualEntropyInput(
            motionScore: 80,
            personalWord: w,
            rolls: const [],
          );
      final a = EntropyMixer.mix(osBytes: os, ritual: ritual('alpha'));
      final b = EntropyMixer.mix(osBytes: os, ritual: ritual('beta'));
      expect(a, isNot(equals(b)));
    });

    test('mix rejects wrong OS length', () {
      expect(
        () => EntropyMixer.mix(
          osBytes: Uint8List(16),
          ritual: const RitualEntropyInput(
            motionScore: 0,
            personalWord: '',
            rolls: [],
          ),
        ),
        throwsArgumentError,
      );
    });

    test('wordStrength ranks stronger phrases higher', () {
      expect(EntropyMixer.wordStrength('cat'), lessThan(30));
      expect(
        EntropyMixer.wordStrength('purple-toaster-7!moth'),
        greaterThan(EntropyMixer.wordStrength('cat')),
      );
      expect(
        EntropyMixer.wordStrength('purple-toaster-7!moth'),
        greaterThanOrEqualTo(EntropyMixer.minWordStrength),
      );
    });

    test('wordStrength rewards long multi-word input past 70', () {
      // Old heuristic capped ~60 for lowercase prose (length hard-capped at 40).
      const prose =
          'the quick brown fox jumps over the lazy dog again and again '
          'with more words to fill the page for the entropy ritual';
      final score = EntropyMixer.wordStrength(prose);
      expect(score, greaterThan(70));
      // Diversity pushes higher even with fewer words
      final strong = EntropyMixer.wordStrength(
        'Purple-toaster 7! moth Nebula-42 lake more words here for length XX',
      );
      expect(strong, greaterThan(75));
    });

    test('canonicalJson is stable', () {
      final r = RitualEntropyInput(
        motionScore: 81.5,
        personalWord: 'hi "there"',
        rolls: [
          DiceRollSample(
            pathLength: 1.5,
            durationMs: 10,
            speedAvg: 0.1,
            faces: [6, 1],
            pathPoints: [
              [0, 0, 0],
            ],
            timestampMs: 42,
          ),
        ],
      );
      expect(r.canonicalJson, r.canonicalJson);
      expect(r.canonicalJson, contains('hi \\"there\\"'));
    });
  });
}
