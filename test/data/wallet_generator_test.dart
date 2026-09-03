import 'dart:math';
import 'dart:typed_data';

import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/data/wallet/entropy_mixer.dart';
import 'package:xrpl_mobile_wallet/data/wallet/wallet_generator.dart';
import 'package:xrpl_mobile_wallet/data/wallet/wallet_importer.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';
import 'package:xrpl_mobile_wallet/domain/validation/address_validator.dart';

void main() {
  group('WalletGenerator', () {
    test('generateMnemonic24 returns 24 BIP39 words', () {
      final gen = WalletGenerator(random: Random(1));
      final phrase = gen.generateMnemonic24();
      final words = phrase.split(' ');
      expect(words, hasLength(24));
      final phrase2 = gen.generateMnemonic24();
      expect(phrase2.split(' '), hasLength(24));
      expect(phrase2, isNot(equals(phrase)));
    });

    test('generateMnemonic24 from fixed entropy is deterministic BIP39', () {
      final gen = WalletGenerator(random: Random(0));
      final entropy = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
      final a = gen.generateMnemonic24(entropy32: entropy);
      final b = gen.generateMnemonic24(entropy32: entropy);
      expect(a, b);
      expect(a.split(' '), hasLength(24));
      // Round-trip: same entropy via blockchain_utils encoder
      final expected =
          Bip39MnemonicGenerator(Bip39Languages.english).fromEntropy(entropy);
      expect(a, expected.toStr());
    });

    test('generateMnemonic24 rejects wrong entropy length', () {
      final gen = WalletGenerator();
      expect(
        () => gen.generateMnemonic24(entropy32: Uint8List(16)),
        throwsArgumentError,
      );
    });

    test('generateMnemonic24FromRitual produces valid 24-word mnemonic', () {
      final gen = WalletGenerator(random: Random(99));
      final ritual = RitualEntropyInput(
        motionScore: 95,
        personalWord: 'unit-test-ritual-word-42!',
        rolls: [
          DiceRollSample(
            pathLength: 200,
            durationMs: 500,
            speedAvg: 0.8,
            faces: [2, 5, 1, 6, 3],
            pathPoints: [
              [1, 2, 3],
              [4, 5, 6],
            ],
            timestampMs: 12345,
          ),
        ],
      );
      final phrase = gen.generateMnemonic24FromRitual(ritual);
      expect(phrase.split(' '), hasLength(24));
      // Different OS draws → different phrases for same ritual
      final phrase2 = gen.generateMnemonic24FromRitual(ritual);
      expect(phrase2, isNot(equals(phrase)));
    });

    test('createFromMnemonic matches importMnemonic derivation', () {
      final gen = WalletGenerator(random: Random(3));
      final phrase = gen.generateMnemonic24();
      final created = gen.createFromMnemonic(
        phrase,
        label: 'New',
        network: NetworkId.testnet,
      );
      final imported = WalletImporter().importMnemonic(
        phrase,
        label: 'New',
        network: NetworkId.testnet,
      );
      expect(created.account.address, imported.account.address);
      expect(AddressValidator.isValidClassic(created.account.address), isTrue);
      expect(created.account.kind, WalletKind.signing);
      expect(created.account.importMethod, ImportMethod.mnemonic);
      expect(created.secret, phrase);
    });

    test('buildQuiz produces distinct indices with correct answer in choices', () {
      final gen = WalletGenerator(random: Random(42));
      const phrase =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      final quiz = gen.buildQuiz(phrase: phrase, count: 3, choicesPerQuestion: 3);
      expect(quiz, hasLength(3));
      final indices = quiz.map((q) => q.wordIndex).toSet();
      expect(indices, hasLength(3));
      final words = phrase.split(' ');
      for (final item in quiz) {
        expect(item.correctWord, words[item.wordIndex]);
        expect(item.choices, contains(item.correctWord));
        expect(item.choices.toSet(), hasLength(item.choices.length));
        expect(item.choices, hasLength(3));
        expect(item.displayPosition, item.wordIndex + 1);
      }
    });
  });
}
