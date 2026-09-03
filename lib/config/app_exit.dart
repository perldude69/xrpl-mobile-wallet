import 'package:flutter/services.dart';

/// Leave the process (Android: finish activity; returns to home screen).
///
/// Prefer this over `exit(0)` so the OS can clean up Flutter/engine state.
Future<void> exitApplication() async {
  await SystemNavigator.pop();
}
