import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform helpers for sensitive screens (recovery phrase, import secrets).
///
/// On Android, toggles [WindowManager.LayoutParams.FLAG_SECURE] so the system
/// blocks screenshots and recent-app previews of the secure surface.
class ScreenSecurity {
  ScreenSecurity._();

  static const _channel = MethodChannel('xrpl_mobile_wallet/screen_security');

  /// Enable secure surface (no screenshots / recents capture) when supported.
  static Future<void> enable() => _setSecure(true);

  /// Restore normal capture behavior.
  static Future<void> disable() => _setSecure(false);

  static Future<void> _setSecure(bool secure) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } on MissingPluginException {
      // Desktop / tests without the channel.
    } on PlatformException {
      // Best-effort; never block wallet UX on this.
    }
  }
}
