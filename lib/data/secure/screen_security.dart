import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform helpers for sensitive screens (recovery phrase, import secrets).
///
/// On Android, toggles [WindowManager.LayoutParams.FLAG_SECURE] so the system
/// blocks screenshots and recent-app previews of the secure surface.
class ScreenSecurity {
  ScreenSecurity._();

  static const _channel = MethodChannel('xrpl_mobile_wallet/screen_security');

  /// Nested enable/disable (PIN dialog over Send, etc.) must not clear the
  /// flag while an outer secret surface is still open.
  static int _holds = 0;

  /// Enable secure surface (no screenshots / recents capture) when supported.
  static Future<void> enable() async {
    _holds++;
    if (_holds == 1) await _setSecure(true);
  }

  /// Restore normal capture behavior when the last secure surface closes.
  static Future<void> disable() async {
    if (_holds <= 0) {
      _holds = 0;
      return;
    }
    _holds--;
    if (_holds == 0) await _setSecure(false);
  }

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
