import 'package:xrpl_dart/xrpl_dart.dart';

/// Validates XRPL classic addresses with real Base58 checksum checks via xrpl_dart.
class AddressValidator {
  static bool isValidClassic(String address) {
    final s = address.trim();
    if (s.isEmpty) return false;
    try {
      XRPClassicAddress(s);
      return true;
    } catch (_) {
      return false;
    }
  }
}
