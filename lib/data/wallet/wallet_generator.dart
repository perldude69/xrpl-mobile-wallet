import 'dart:math';
import 'dart:typed_data';

import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:xrpl_mobile_wallet/config/network_id.dart';
import 'package:xrpl_mobile_wallet/data/wallet/entropy_mixer.dart';
import 'package:xrpl_mobile_wallet/data/wallet/wallet_importer.dart';

/// One backup-quiz challenge: "what is word N?" with multiple choices.
class MnemonicQuizItem {
  const MnemonicQuizItem({
    required this.wordIndex,
    required this.correctWord,
    required this.choices,
  });

  /// 0-based index into the mnemonic word list.
  final int wordIndex;

  final String correctWord;

  /// Shuffled options including [correctWord] (typically 3 total).
  final List<String> choices;

  /// 1-based position for UI ("Word 7").
  int get displayPosition => wordIndex + 1;
}

/// Generates BIP39 recovery phrases and XRPL wallets from them.
///
/// Entropy path (deliberately avoids package Fortuna for seed material):
/// 1. [Random.secure] → 32 OS CSPRNG bytes, and/or
/// 2. [EntropyMixer.mix] of those bytes with the user dice/word ritual
/// 3. [Bip39MnemonicGenerator.fromEntropy] → 24 English words
/// 4. Same BIP44 + secp256k1 derivation as [WalletImporter.importMnemonic]
class WalletGenerator {
  WalletGenerator({
    WalletImporter? importer,
    Random? random,
  })  : _importer = importer ?? WalletImporter(),
        _random = random ?? Random.secure();

  final WalletImporter _importer;
  final Random _random;

  /// 32 cryptographically secure random bytes (OS CSPRNG via [Random.secure]).
  Uint8List osEntropy32() => EntropyMixer.osEntropy(EntropyMixer.entropyBytes, _random);

  /// Generate a fresh English BIP39 **24-word** mnemonic from 256-bit entropy.
  ///
  /// When [entropy32] is omitted, fills 32 bytes from [Random.secure] directly
  /// (no intermediate package PRNG). When provided, must be exactly 32 bytes
  /// (typically from [EntropyMixer.mix]).
  String generateMnemonic24({List<int>? entropy32}) {
    final bytes = entropy32 ?? osEntropy32();
    if (bytes.length != EntropyMixer.entropyBytes) {
      throw ArgumentError(
        'entropy32 must be ${EntropyMixer.entropyBytes} bytes, got ${bytes.length}',
      );
    }
    final mnemonic = Bip39MnemonicGenerator(Bip39Languages.english)
        .fromEntropy(bytes);
    return mnemonic.toStr();
  }

  /// Mix OS + ritual → BIP39 24-word phrase.
  ///
  /// Always includes a full 32-byte OS CSPRNG contribution.
  String generateMnemonic24FromRitual(RitualEntropyInput ritual) {
    final os = osEntropy32();
    final mixed = EntropyMixer.mix(osBytes: os, ritual: ritual);
    return generateMnemonic24(entropy32: mixed);
  }

  /// Derive a signing wallet from [phrase] (same rules as import).
  ImportResult createFromMnemonic(
    String phrase, {
    required String label,
    required NetworkId network,
  }) {
    return _importer.importMnemonic(
      phrase,
      label: label,
      network: network,
    );
  }

  /// Build [count] random-position quiz items for backup verification.
  ///
  /// Each item has [choicesPerQuestion] options (1 correct + distractors from
  /// the BIP39 English word list, never colliding with the correct word).
  List<MnemonicQuizItem> buildQuiz({
    required String phrase,
    int count = 3,
    int choicesPerQuestion = 3,
  }) {
    final words = phrase.trim().split(RegExp(r'\s+'));
    if (words.length < count) {
      throw ArgumentError('Mnemonic too short for a $count-question quiz');
    }
    if (choicesPerQuestion < 2) {
      throw ArgumentError('choicesPerQuestion must be at least 2');
    }

    final wordList = Bip39Languages.english.wordList;
    final indices = List<int>.generate(words.length, (i) => i)..shuffle(_random);
    final selected = indices.take(count).toList()..sort();

    return selected.map((wordIndex) {
      final correct = words[wordIndex];
      final choices = <String>{correct};
      // Prefer distractors that appear elsewhere in the phrase, then word list.
      final phrasePool = words.where((w) => w != correct).toList()..shuffle(_random);
      for (final w in phrasePool) {
        if (choices.length >= choicesPerQuestion) break;
        choices.add(w);
      }
      while (choices.length < choicesPerQuestion) {
        final decoy = wordList[_random.nextInt(wordList.length)];
        if (decoy != correct) choices.add(decoy);
      }
      final optionList = choices.toList()..shuffle(_random);
      return MnemonicQuizItem(
        wordIndex: wordIndex,
        correctWord: correct,
        choices: optionList,
      );
    }).toList();
  }
}
