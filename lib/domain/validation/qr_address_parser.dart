import 'package:xrpl_mobile_wallet/domain/validation/address_validator.dart';

/// Extracts a classic XRPL address from QR / clipboard-style payloads.
class QrAddressParser {
  QrAddressParser._();

  /// Classic addresses start with `r` and use Base58 alphabet (no 0,O,I,l).
  static final _classicCandidate = RegExp(r'r[1-9A-HJ-NP-Za-km-z]{24,34}');

  /// Returns a validated classic address, or null if none found.
  static String? extractClassicAddress(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    // Bare address
    if (AddressValidator.isValidClassic(text)) {
      return text;
    }

    // Query params on any URI shape
    final uri = Uri.tryParse(text);
    if (uri != null) {
      for (final key in const ['address', 'to', 'account', 'destination']) {
        final v = uri.queryParameters[key];
        if (v != null && AddressValidator.isValidClassic(v.trim())) {
          return v.trim();
        }
      }
    }

    // Strip common schemes then scan for classic address tokens
    var scan = text;
    for (final prefix in const ['xrpl:', 'ripple:', 'xrp:']) {
      if (scan.toLowerCase().startsWith(prefix)) {
        scan = scan.substring(prefix.length);
        // Drop optional leading //
        if (scan.startsWith('//')) scan = scan.substring(2);
        break;
      }
    }

    // Path-only after scheme strip (e.g. rXXX?dt=1)
    final q = scan.indexOf('?');
    if (q >= 0) {
      final pathOnly = scan.substring(0, q);
      if (AddressValidator.isValidClassic(pathOnly)) return pathOnly;
    } else if (AddressValidator.isValidClassic(scan)) {
      return scan;
    }

    return _firstValidCandidate(text) ?? _firstValidCandidate(scan);
  }

  static String? _firstValidCandidate(String text) {
    for (final match in _classicCandidate.allMatches(text)) {
      final candidate = match.group(0)!;
      if (AddressValidator.isValidClassic(candidate)) {
        return candidate;
      }
    }
    return null;
  }
}
