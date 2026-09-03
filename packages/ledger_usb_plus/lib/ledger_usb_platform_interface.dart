import 'dart:typed_data';
import 'package:ledger_usb_plus/usb_device.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ledger_usb_method_channel.dart'
    if (dart.library.html) 'web_ledger_usb.dart'
    if (dart.library.js) 'web_ledger_usb.dart'
    if (dart.library.js_interop) 'web_ledger_usb.dart';

abstract class LedgerUsbPlatform extends PlatformInterface {
  /// Constructs a LedgerUsbPlatform.
  LedgerUsbPlatform() : super(token: _token);

  static final Object _token = Object();

  static LedgerUsbPlatform _instance = createPlatformInstance();

  /// The default instance of [LedgerUsbPlatform] to use.
  ///
  /// Defaults to [MethodChannelLedgerUsb] or [WebLedgerUsb] if running on web.
  static LedgerUsbPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [LedgerUsbPlatform] when
  /// they register themselves.
  static set instance(LedgerUsbPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<List<UsbDevice>> getDevices();

  Future<bool> requestPermission(UsbDevice usbDevice);

  Future<bool> hasPermission(UsbDevice usbDevice);

  Future<bool> open(UsbDevice usbDevice);

  Future<Uint8List?> transferIn(int packetSize, int timeout);

  Future<int> transferOut(Uint8List data, int timeout);

  Future<bool> close();

  Future<Map<String, dynamic>> connectionInfo();

  /// Atomic HID-framed APDU exchange (preferred over transferIn/Out).
  Future<Uint8List> exchangeApdu(
    Uint8List apdu, {
    String identifier = 'auto',
    int timeoutMs = 120000,
  });
}
