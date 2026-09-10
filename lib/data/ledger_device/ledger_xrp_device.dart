import 'dart:convert';
import 'dart:typed_data';

import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ledger_usb_plus/ledger_usb.dart';
import 'package:ledger_usb_plus/usb_device.dart';
import 'package:xrpl_dart/xrpl_dart.dart';

/// Ledger vendor ID (0x2c97).
const int kLedgerUsbVendorId = 0x2c97;

/// BIP44 XRP path: m/44'/144'/account'/0/0
List<int> xrpBip32Path({int accountIndex = 0}) {
  const harden = 0x80000000;
  return [44 | harden, 144 | harden, accountIndex | harden, 0, 0];
}

Uint8List pathBytes({int accountIndex = 0}) {
  final path = xrpBip32Path(accountIndex: accountIndex);
  final out = BytesBuilder();
  out.addByte(path.length);
  final bd = ByteData(4);
  for (final i in path) {
    bd.setUint32(0, i, Endian.big);
    out.add(bd.buffer.asUint8List());
  }
  return out.toBytes();
}

/// Compress any valid secp256k1 public key bytes → XRPL SigningPubKey hex.
String compressPublicKeyToXrplHex(List<int> pubRaw) {
  final secp = Secp256k1PublicKey.fromBytes(pubRaw);
  return XRPPublicKey.fromBytes(
    secp.compressed,
    algorithm: XRPKeyAlgorithm.secp256k1,
  ).toHex();
}

void _log(String message) {
  if (kDebugMode) debugPrint('[LedgerHW] $message');
}

/// APDU status word (last 2 bytes). Throws [LedgerDeviceException] when not 0x9000.
void checkApduStatus(Uint8List response, {String step = 'APDU'}) {
  if (response.length < 2) {
    throw LedgerDeviceException(
      'Empty response from Ledger during $step. '
      'Unlock the device and open the XRP app.',
      step: step,
      statusWord: 0,
    );
  }
  final sw =
      (response[response.length - 2] << 8) | response[response.length - 1];
  if (sw == 0x9000) return;

  final msg = switch (sw) {
    0x650f =>
      'Ledger connection was refused (0x650f). Unlock the device, close Ledger Live, '
          'open the XRP app until it says Application is ready, then retry.',
    0x6985 => 'Rejected on the Ledger device.',
    0x6982 => 'Ledger security status not satisfied (locked or not ready).',
    0x6a15 || 0x6e00 || 0x6d00 =>
      'Wrong app or CLA/INS not supported. Open the XRP app on the Ledger.',
    0x6807 ||
    0x6808 ||
    0x5515 => 'Ledger is locked. Unlock it and open the XRP app.',
    // XRP app: bad tx payload / parse failure (often wrong blob or oversized chunk).
    0x680b =>
      'Ledger rejected the transaction data (0x680b). '
          'Ensure the XRP app is open and try again.',
    0x6a80 => 'Incorrect data sent to Ledger (invalid transaction or path).',
    0x6a82 => 'File not found on device (is the XRP app open?).',
    0x6b00 => 'Wrong P1/P2 parameters for Ledger XRP APDU.',
    0x6700 => 'Incorrect APDU length for Ledger.',
    0x6f00 => 'Ledger technical error (try unplug/replug, reopen XRP app).',
    _ => 'Ledger returned status 0x${sw.toRadixString(16)} during $step.',
  };
  throw LedgerDeviceException(msg, step: step, statusWord: sw);
}

/// Returns true only for a canonical DER ECDSA signature.
bool isCanonicalLedgerSignature(List<int> bytes) {
  if (bytes.length < 8 || bytes[0] != 0x30 || bytes[1] != bytes.length - 2) {
    return false;
  }
  var i = 2;
  for (var integer = 0; integer < 2; integer++) {
    if (i + 2 > bytes.length || bytes[i++] != 0x02) return false;
    final length = bytes[i++];
    if (length == 0 || i + length > bytes.length) return false;
    if (bytes[i] & 0x80 != 0) return false;
    if (length > 1 && bytes[i] == 0 && bytes[i + 1] & 0x80 == 0) {
      return false;
    }
    i += length;
  }
  return i == bytes.length;
}

/// Verify a Ledger signature against the exact STObject sent to the device.
bool verifyLedgerSignature({
  required String publicKeyHex,
  required List<int> transactionBlob,
  required List<int> derSignature,
}) {
  if (!isCanonicalLedgerSignature(derSignature)) return false;
  try {
    // Ledger receives the raw STObject, but XRPL transaction signatures are
    // verified over the STX\0-prefixed signing payload.
    final signingPayload = <int>[0x53, 0x54, 0x58, 0x00, ...transactionBlob];
    final verifier = XrpVerifier.fromKeyBytes(
      BytesUtils.fromHexString(publicKeyHex),
      EllipticCurveTypes.secp256k1,
    );
    return verifier.verify(signingPayload, derSignature);
  } catch (_) {
    return false;
  }
}

Uint8List apduPayload(Uint8List response) {
  if (response.length < 2) return response;
  return response.sublist(0, response.length - 2);
}

/// Typed failure from our Ledger helper (includes step for logs/UI).
class LedgerDeviceException implements Exception {
  LedgerDeviceException(
    this.message, {
    required this.step,
    this.statusWord,
    this.cause,
  });

  final String message;
  final String step;
  final int? statusWord;
  final Object? cause;

  @override
  String toString() {
    final sw = statusWord == null
        ? ''
        : ' sw=0x${statusWord!.toRadixString(16)}';
    return 'LedgerDeviceException($step$sw): $message';
  }
}

/// Live USB session to a Ledger (uses ledger_usb_plus directly).
///
/// Mirrors codebaseOne desktop flow (`@ledgerhq/hw-transport-node-hid`):
/// open a session, exchange APDUs on the same handle, close when done.
/// Native side holds a process-wide singleton so the watcher Flutter engine
/// cannot wipe the UI session.
class LedgerUsbSession {
  LedgerUsbSession._(this._usb, this.device);

  final LedgerUsb _usb;
  final UsbDevice device;

  /// Per bulk transfer. Signing waits for user to click buttons on device.
  static const int _ioTimeoutMs = 120000;

  /// Open first Ledger USB device (vendor 0x2c97).
  ///
  /// Important: unlock the Ledger and open the **XRP app before** connecting.
  /// Switching apps can re-enumerate USB and drop the session.
  static Future<LedgerUsbSession> open() async {
    final usb = LedgerUsb();
    try {
      try {
        await usb.close();
      } catch (_) {}

      var device = await _requireLedgerDevice(usb);

      _log(
        'Requesting USB permission for ${device.productName} '
        '(id=${device.identifier} pid=0x${device.productId.toRadixString(16)})…',
      );
      var granted = await usb.requestPermission(device);
      _log('Permission callback granted=$granted');

      // Re-list after the dialog: the device name key can change, and the XRP
      // app must already be open so the HID interface is the one we claim.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      device = await _requireLedgerDevice(usb);

      final hasPerm = await usb.hasPermission(device);
      _log('hasPermission(after dialog)=$hasPerm');
      if (!hasPerm && !granted) {
        // One more prompt in case the first dialog was dismissed/lost.
        granted = await usb.requestPermission(device);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        device = await _requireLedgerDevice(usb);
        final again = await usb.hasPermission(device);
        _log('permission retry callback=$granted hasPermission=$again');
        if (!again) {
          throw LedgerDeviceException(
            'USB access not granted. Unplug and replug the Ledger, open the '
            'XRP app, then tap Allow on the system dialog.',
            step: 'requestPermission',
          );
        }
      }

      _log('Opening USB session for ${device.identifier}…');
      try {
        // Prefer auto-resolve on native side if the bus path is stale.
        final opened = await usb.open(device);
        _log('Open result=$opened');
        if (!opened) {
          throw LedgerDeviceException(
            'Could not open Ledger USB. Close Ledger Live, open the XRP app, '
            'unplug/replug, and try again.',
            step: 'open',
          );
        }
      } on PlatformException catch (e) {
        _log('open PlatformException code=${e.code} msg=${e.message}');
        throw LedgerDeviceException(
          _platformMessage(e),
          step: 'open',
          cause: e,
        );
      }

      final info = await usb.connectionInfo();
      _log('connectionInfo=$info');
      final connected = info['connected'] == true;
      if (!connected) {
        throw LedgerDeviceException(
          'USB open reported success but the session is not connected. '
          'Open the XRP app on the Ledger first, then retry.',
          step: 'open',
        );
      }

      return LedgerUsbSession._(usb, device);
    } on LedgerDeviceException {
      rethrow;
    } on PlatformException catch (e, st) {
      _log(
        'PlatformException during open: code=${e.code} message=${e.message}\n$st',
      );
      throw LedgerDeviceException(_platformMessage(e), step: 'open', cause: e);
    } catch (e, st) {
      _log('Unexpected open error: $e\n$st');
      throw LedgerDeviceException(
        'Failed to connect to Ledger: $e',
        step: 'open',
        cause: e,
      );
    }
  }

  static Future<UsbDevice> _requireLedgerDevice(LedgerUsb usb) async {
    final all = await usb.listDevices();
    _log('USB devices seen: ${all.length}');
    for (final d in all) {
      _log(
        '  id=${d.identifier} vid=0x${d.vendorId.toRadixString(16)} '
        'pid=0x${d.productId.toRadixString(16)} name=${d.productName}',
      );
    }
    final ledgers = all
        .where((d) => d.vendorId == kLedgerUsbVendorId)
        .toList(growable: false);
    if (ledgers.isEmpty) {
      throw LedgerDeviceException(
        all.isEmpty
            ? 'No USB devices found. Use a data-capable OTG cable, unlock '
                  'the Ledger, and open the XRP app before sending.'
            : 'USB device(s) found but none are Ledger (vendor 0x2c97). '
                  'Check the OTG cable and that the Ledger is unlocked.',
        step: 'listDevices',
      );
    }
    return ledgers.first;
  }

  Future<void> close() async {
    try {
      await _usb.close();
      _log('USB closed');
    } catch (e) {
      _log('USB close error (ignored): $e');
    }
  }

  /// Exchange one APDU; returns full response including SW1SW2.
  ///
  /// Uses native atomic [LedgerUsb.exchangeApdu] (same model as codebaseOne
  /// `TransportNodeHid.exchange`): one process-wide session, auto-reopen if
  /// the background Flutter engine wiped a per-engine manager.
  Future<Uint8List> exchange(
    Uint8List apdu, {
    required String step,
    int timeoutMs = _ioTimeoutMs,
  }) async {
    _log('$step → APDU (${apdu.length}b)');
    try {
      // Re-check session before exchange (debug visibility).
      final before = await _usb.connectionInfo();
      _log('$step connectionInfo before exchange: $before');

      final result = await _usb.exchangeApdu(
        apdu,
        identifier: device.identifier.isEmpty ? 'auto' : device.identifier,
        timeoutMs: timeoutMs,
      );
      _log('$step ← ${result.length}b');
      checkApduStatus(result, step: step);
      return result;
    } on LedgerDeviceException {
      rethrow;
    } on PlatformException catch (e, st) {
      _log('PlatformException during $step: ${e.code} ${e.message}\n$st');
      throw LedgerDeviceException(_platformMessage(e), step: step, cause: e);
    } catch (e, st) {
      _log('Error during $step: $e\n$st');
      throw LedgerDeviceException(
        'Ledger $step failed: $e',
        step: step,
        cause: e,
      );
    }
  }

  static String _platformMessage(PlatformException e) {
    final code = e.code;
    final msg = (e.message ?? '').trim();
    final lower = msg.toLowerCase();
    if (lower.contains('connectionlost') || lower.contains('disconnect')) {
      return 'USB connection lost. Keep the XRP app open, unplug/replug, retry.';
    }
    // Native "Not connected" means claim/open never stuck — not a missing
    // AndroidManifest permission.
    if (lower.contains('not connected')) {
      return msg.isNotEmpty
          ? msg
          : 'USB session not open. Open the XRP app on the Ledger, grant the '
                'system USB dialog, then retry.';
    }
    if (lower.contains('permission')) {
      return msg.isNotEmpty
          ? msg
          : 'USB permission denied. Unplug/replug and tap Allow.';
    }
    if (lower.contains('endpoint') || lower.contains('interface')) {
      return msg.isNotEmpty
          ? msg
          : 'Could not claim Ledger USB interface. Close Ledger Live and retry.';
    }
    if (msg.isEmpty) {
      return 'USB error (code $code). Unplug/replug and open the XRP app.';
    }
    // Prefer the native message — it is written for the user.
    return msg;
  }
}

/// High-level XRP Ledger hardware helper (USB).
class LedgerXrpDevice {
  /// List Ledger USB devices (vendor-filtered).
  static Future<List<UsbDevice>> listUsbDevices() async {
    try {
      final all = await LedgerUsb().listDevices();
      return all.where((d) => d.vendorId == kLedgerUsbVendorId).toList();
    } catch (e) {
      _log('listUsbDevices failed: $e');
      return const [];
    }
  }

  /// Open USB session (permission + claim interface).
  static Future<LedgerUsbSession> connectUsb() => LedgerUsbSession.open();

  static Future<({String address, String publicKeyHex})> getAddress(
    LedgerUsbSession session, {
    int accountIndex = 0,
    bool display = false,
  }) async {
    final path = pathBytes(accountIndex: accountIndex);
    final apdu = BytesBuilder()
      ..addByte(0xE0)
      ..addByte(0x02)
      ..addByte(display ? 0x01 : 0x00)
      ..addByte(0x40) // secp256k1
      ..addByte(path.length)
      ..add(path);

    final raw = await session.exchange(
      apdu.toBytes(),
      step: 'getAddress',
      // Display on device needs user to confirm.
      timeoutMs: display ? 120000 : 15000,
    );
    final data = apduPayload(raw);
    if (data.length < 2) {
      throw LedgerDeviceException(
        'Truncated getAddress payload (${data.length} bytes).',
        step: 'getAddress',
      );
    }
    var offset = 0;
    final pubLen = data[offset++];
    if (offset + pubLen + 1 > data.length) {
      throw LedgerDeviceException(
        'Truncated public key in getAddress (pubLen=$pubLen, total=${data.length}).',
        step: 'getAddress',
      );
    }
    final pubRaw = data.sublist(offset, offset + pubLen);
    offset += pubLen;
    final addrLen = data[offset++];
    if (offset + addrLen > data.length) {
      throw LedgerDeviceException(
        'Truncated address in getAddress (addrLen=$addrLen).',
        step: 'getAddress',
      );
    }
    final address = utf8.decode(data.sublist(offset, offset + addrLen));
    final publicKeyHex = compressPublicKeyToXrplHex(pubRaw);
    _log('getAddress → $address');
    return (address: address, publicKeyHex: publicKeyHex);
  }

  /// Sign a serialized XRPL transaction STObject (no TxnSignature).
  ///
  /// [txBlob] must be the same bytes as xrpl.js `encode(prepared)` with
  /// SigningPubKey set — **not** the STX\\0 software signing prefix.
  /// Chunking matches `@ledgerhq/hw-app-xrp` (150-byte APDU data).
  /// Returns DER signature bytes (no SW).
  static Future<Uint8List> signTransaction(
    LedgerUsbSession session,
    List<int> txBlob, {
    int accountIndex = 0,
  }) async {
    final path = pathBytes(accountIndex: accountIndex);
    final tx = Uint8List.fromList(txBlob);
    // Official hw-app-xrp: first chunk data max = 150 - 1 - pathComponents*4
    // which equals 150 - pathBytes.length; later chunks max 150.
    const maxData = 150;
    final firstTxCap = maxData - path.length;
    if (firstTxCap <= 0) {
      throw LedgerDeviceException(
        'Invalid path encoding for Ledger sign',
        step: 'sign',
      );
    }

    var offset = 0;
    final firstLen = tx.length < firstTxCap ? tx.length : firstTxCap;
    final firstData = Uint8List(path.length + firstLen)
      ..setAll(0, path)
      ..setAll(path.length, tx.sublist(0, firstLen));
    offset = firstLen;
    final isOnly = offset >= tx.length;

    Future<Uint8List> sendChunk(int p1, Uint8List data, String label) async {
      if (data.length > maxData) {
        throw LedgerDeviceException(
          'Ledger sign chunk too large (${data.length} > $maxData)',
          step: label,
        );
      }
      final apdu = BytesBuilder()
        ..addByte(0xE0)
        ..addByte(0x04)
        ..addByte(p1)
        ..addByte(0x40) // secp256k1
        ..addByte(data.length)
        ..add(data);
      final raw = await session.exchange(
        apdu.toBytes(),
        step: label,
        // User must review + approve on device for the final chunk.
        timeoutMs: 180000,
      );
      return apduPayload(raw);
    }

    // P1: bit0x80 = more data follows; bit0x01 = not first (same as hw-app-xrp).
    if (isOnly) {
      final payload = await sendChunk(0x00, firstData, 'sign(only)');
      return _requireSignature(payload);
    }

    await sendChunk(0x80, firstData, 'sign(first)');
    while (offset < tx.length) {
      final remaining = tx.length - offset;
      final take = remaining > maxData ? maxData : remaining;
      final chunk = tx.sublist(offset, offset + take);
      offset += take;
      final isLast = offset >= tx.length;
      final payload = await sendChunk(
        isLast ? 0x01 : 0x81,
        Uint8List.fromList(chunk),
        isLast ? 'sign(last)' : 'sign(mid)',
      );
      if (isLast) return _requireSignature(payload);
    }
    throw LedgerDeviceException(
      'Ledger sign produced no signature',
      step: 'sign',
    );
  }

  static Uint8List _requireSignature(Uint8List payload) {
    if (!isCanonicalLedgerSignature(payload)) {
      throw LedgerDeviceException(
        'Malformed Ledger signature (approve the transaction on the device).',
        step: 'sign',
      );
    }
    return payload;
  }

  /// Ledger XRP returns a strict DER ECDSA signature: SEQUENCE(INTEGER r,
  /// INTEGER s). Reject alternate encodings before they reach transaction
  /// serialization.

  /// Map failures to short user-facing copy (keeps step detail when useful).
  static String userFacingError(Object error) {
    if (error is LedgerDeviceException) {
      return error.message;
    }
    if (error is PlatformException) {
      return LedgerUsbSession._platformMessage(error);
    }
    if (error is StateError) {
      return error.message;
    }
    final s = error.toString();
    final cleaned = s
        .replaceFirst(RegExp(r'^Bad state:\s*'), '')
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^StateError:\s*'), '')
        .replaceFirst(RegExp(r'^LedgerDeviceException\([^)]*\):\s*'), '');
    if (s.contains('DeviceNotConnectedException') ||
        s.contains('ConnectionLostException')) {
      return 'USB session dropped. Unplug/replug Ledger, unlock, open XRP app, retry. '
          'Detail: $cleaned';
    }
    return cleaned;
  }
}
