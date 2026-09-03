import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const seed = Color(0xFF00A3BF); // XRPL-adjacent teal
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(centerTitle: false),
  );
}
