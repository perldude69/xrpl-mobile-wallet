import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/domain/validation/mnemonic_grid.dart';

void main() {
  List<String> cells(List<String> filled) {
    return List<String>.generate(
      MnemonicGrid.slotCount,
      (i) => i < filled.length ? filled[i] : '',
    );
  }

  group('MnemonicGrid.phraseFromCells', () {
    test('accepts full 24 words', () {
      final words = List<String>.generate(24, (i) => 'word$i');
      expect(MnemonicGrid.phraseFromCells(words), words.join(' '));
    });

    test('accepts first 12 only', () {
      final twelve = List<String>.generate(12, (i) => 'w$i');
      expect(
        MnemonicGrid.phraseFromCells(cells(twelve)),
        twelve.join(' '),
      );
    });

    test('rejects 11 words', () {
      expect(
        () => MnemonicGrid.phraseFromCells(
          cells(List.generate(11, (i) => 'w$i')),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('12 or 24'),
          ),
        ),
      );
    });

    test('rejects 12 words not in positions 1–12', () {
      final c = List<String>.filled(24, '');
      for (var i = 12; i < 24; i++) {
        c[i] = 'w$i';
      }
      expect(
        () => MnemonicGrid.phraseFromCells(c),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects gap in first twelve', () {
      final c = cells(List.generate(12, (i) => 'w$i'));
      c[5] = '';
      expect(
        () => MnemonicGrid.phraseFromCells(c),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('normalizes case and trim', () {
      final c = cells(List.generate(12, (i) => ' W$i '));
      expect(
        MnemonicGrid.phraseFromCells(c),
        List.generate(12, (i) => 'w$i').join(' '),
      );
    });
  });

  group('MnemonicGrid.splitPaste', () {
    test('splits and lowercases', () {
      expect(
        MnemonicGrid.splitPaste('  Alpha Beta  Gamma '),
        ['alpha', 'beta', 'gamma'],
      );
    });
  });
}
