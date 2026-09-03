import 'package:flutter/material.dart';

/// Deterministic accent color from a classic address (and optional override).
class WalletColor {
  WalletColor._();

  /// Preset palette for manual selection (Material-ish, works on dark UI).
  static const presets = <Color>[
    Color(0xFF00A3BF), // teal
    Color(0xFF26A69A),
    Color(0xFF5C6BC0),
    Color(0xFF7E57C2),
    Color(0xFFEC407A),
    Color(0xFFEF5350),
    Color(0xFFFFA726),
    Color(0xFFFFEE58),
    Color(0xFF66BB6A),
    Color(0xFF8D6E63),
    Color(0xFF78909C),
    Color(0xFFE0E0E0),
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
