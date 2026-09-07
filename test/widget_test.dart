import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/data/database/app_database.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';
import 'package:xrpl_mobile_wallet/ui/shell/main_shell.dart';

void main() {
  // One in-memory database shared by both tests. Without an override each test
  // builds its own on-disk AppDatabase against the same executor, which Drift
  // warns about ("created the database class AppDatabase multiple times").
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget harness() => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: const MaterialApp(home: MainShell()),
  );

  testWidgets('shell shows Wallets tab', (tester) async {
    await tester.pumpWidget(harness());
    expect(find.text('Wallets'), findsWidgets);
  });

  testWidgets('settings tab shows a coffee mug', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('Settings').last);
    await tester.pump();
    expect(find.byIcon(Icons.coffee), findsWidgets);
  });
}
