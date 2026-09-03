import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/ui/shell/main_shell.dart';

void main() {
  testWidgets('shell shows Wallets tab', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MainShell()),
      ),
    );
    expect(find.text('Wallets'), findsWidgets);
  });

  testWidgets('settings tab shows a coffee mug', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MainShell()),
      ),
    );
    await tester.tap(find.text('Settings').last);
    await tester.pump();
    expect(find.byIcon(Icons.coffee), findsWidgets);
  });
}
