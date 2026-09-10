import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/ui/theme/pirate_icon.dart';

void main() {
  testWidgets('every pirate glyph paints', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Wrap(
          children: [
            for (final glyph in PirateGlyph.values)
              PirateIcon(glyph: glyph, size: 32),
          ],
        ),
      ),
    );
    expect(find.byType(PirateIcon), findsNWidgets(PirateGlyph.values.length));
  });
}
