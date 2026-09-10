import 'package:flutter/material.dart';

/// Comic pirate palette. Display type is Pirata One; body stays the platform
/// UI font so amounts, addresses, and errors stay readable.
class PiratePalette {
  PiratePalette._();

  static const nightSea = Color(0xFF0B1C24);
  static const lagoon = Color(0xFF14323C);
  static const brass = Color(0xFFC9A227);
  static const canvas = Color(0xFFE6D5B0);
  static const foam = Color(0xFF8FCB7A);
  static const rum = Color(0xFFC14B3A);
  static const teal = Color(0xFF1AA6B8);
  static const ink = Color(0xFF1A1208);
  static const scrim = Color(0xCC0B1C24);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: PiratePalette.brass,
    onPrimary: PiratePalette.ink,
    secondary: PiratePalette.teal,
    onSecondary: PiratePalette.ink,
    error: PiratePalette.rum,
    onError: Colors.white,
    surface: Color(0xE614323C),
    onSurface: PiratePalette.canvas,
    onSurfaceVariant: Color(0xFFC4B496),
    primaryContainer: Color(0xCC1A3A44),
    onPrimaryContainer: PiratePalette.canvas,
    secondaryContainer: Color(0xCC2A2418),
    onSecondaryContainer: PiratePalette.canvas,
    outline: Color(0xFF8A7A58),
    surfaceContainerHighest: Color(0xCC1C333C),
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
  );

  final text = base.textTheme.apply(
    bodyColor: PiratePalette.canvas,
    displayColor: PiratePalette.canvas,
  );

  TextStyle pirata(double size, {FontWeight weight = FontWeight.w400}) =>
      TextStyle(
        fontFamily: 'PirataOne',
        fontSize: size,
        fontWeight: weight,
        color: PiratePalette.canvas,
        height: 1.1,
      );

  return base.copyWith(
    textTheme: text.copyWith(
      headlineLarge: pirata(32),
      headlineMedium: pirata(28),
      headlineSmall: pirata(24),
      titleLarge: pirata(22),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: PiratePalette.nightSea.withValues(alpha: 0.72),
      foregroundColor: PiratePalette.canvas,
      titleTextStyle: pirata(26),
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: PiratePalette.nightSea.withValues(alpha: 0.92),
      indicatorColor: PiratePalette.brass.withValues(alpha: 0.28),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? PiratePalette.brass : PiratePalette.canvas,
        );
      }),
    ),
    cardTheme: CardThemeData(
      color: PiratePalette.lagoon.withValues(alpha: 0.82),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: PiratePalette.brass.withValues(alpha: 0.35)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: PiratePalette.brass.withValues(alpha: 0.22),
      space: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: PiratePalette.lagoon,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: PiratePalette.brass.withValues(alpha: 0.4)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: PiratePalette.lagoon,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PiratePalette.brass,
        foregroundColor: PiratePalette.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PiratePalette.canvas,
        side: const BorderSide(color: PiratePalette.brass),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: PiratePalette.brass,
      foregroundColor: PiratePalette.ink,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: PiratePalette.brass,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: PiratePalette.ink,
      contentTextStyle: TextStyle(color: PiratePalette.canvas),
    ),
  );
}
