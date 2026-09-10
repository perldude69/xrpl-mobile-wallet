import 'package:flutter/material.dart';

/// Deterministic accent color from a classic address (and optional override).
class WalletColor {
  WalletColor._();

  /// Preset palette for manual selection (metals, gems, sea — works on dark UI).
  static const presets = <Color>[
    Color(0xFFC9A227), // brass
    Color(0xFF1AA6B8), // lagoon
    Color(0xFFC14B3A), // rum
    Color(0xFF2E7D4F), // bottle
    Color(0xFF5C6BC0), // deep water
    Color(0xFF7E57C2), // amethyst
    Color(0xFFEC407A), // ruby
    Color(0xFFFFA726), // doubloon
    Color(0xFF66BB6A), // foam
    Color(0xFF8D6E63), // oak
    Color(0xFF78909C), // pewter
    Color(0xFFE6D5B0), // sail canvas
  ];

  /// Resolve display color: explicit ARGB override, else hash of [address].
  static Color resolve(String address, {int? accentArgb}) {
    if (accentArgb != null) {
      return Color(accentArgb);
    }
    return fromAddress(address);
  }

  /// Stable HSL color derived from classic address characters.
  static Color fromAddress(String address) {
    final s = address.trim();
    if (s.isEmpty) return presets.first;
    // FNV-1a style hash over code units
    var h = 2166136261;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 16777619) & 0xFFFFFFFF;
    }
    final hue = (h % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.55, 0.48).toColor();
  }
}
