/// Heuristic detection of secret import formats (family seed vs mnemonic).
class SecretValidator {
  static bool looksLikeFamilySeed(String input) {
    final s = input.trim();
    return s.startsWith('s') && !s.contains(' ') && s.length >= 20;
  }

  static bool looksLikeMnemonic(String input) {
    final parts = input.trim().split(RegExp(r'\s+'));
    return parts.length == 12 || parts.length == 24;
  }
}
