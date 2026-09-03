import 'package:flutter/foundation.dart';
import 'package:ledger_usb_plus/usb.web.dart';
import 'package:ledger_usb_plus/usb_device.dart';
import 'ledger_usb_platform_interface.dart';

LedgerUsbPlatform createPlatformInstance() => WebLedgerUsb();

const _ledgerVendorId = 11415;

const _usbInterfaceDirectionIn = 'in';
const _usbInterfaceDirectionOut = 'out';

class WebLedgerUsb extends LedgerUsbPlatform {
  final List<USBDevice> _foundDevices = [];
  ({
    USBDevice device,
    int inEndpointNumber,
    int outEndpointNumber
  })? _activeDevice;

  @override
  Future<List<UsbDevice>> getDevices() async {
    try {
      final device = await usb.requestDevice(
        RequestUSBDeviceFilters.dart(
          [RequestUSBDeviceFilter(vendorId: _ledgerVendorId)],
        ),
      );

      if (device == null) {
        return [];
      }

      final devices = await usb.getDevices();

      _foundDevices
        ..clear()
        ..addAll(devices);

      return devices
          .map((e) => UsbDevice(
                manufacturerName: e.manufacturerName,
                deviceId: 0,
                vendorId: e.vendorId,
                productId: e.productId,
                productName: e.productName,
                configurationCount: 0,
                identifier: e.serialNumber,
                deviceName: e.productName,
              ))
          .toList();
    } catch (e) {
      debugPrint('Error in getDevices: $e');
      return [];
    }
  }

  @override
  Future<bool> requestPermission(UsbDevice usbDevice) async {
    return true;
  }

  @override
  Future<bool> hasPermission(UsbDevice usbDevice) async {
    return true;
  }

  @override
  Future<Map<String, dynamic>> connectionInfo() async {
    final active = _activeDevice;
    return {
      'connected': active != null,
      if (active != null) 'deviceName': active.device.productName,
    };
  }

  @override
  Future<Uint8List> exchangeApdu(
    Uint8List apdu, {
    String identifier = 'auto',
    int timeoutMs = 120000,
  }) async {
    throw UnsupportedError('exchangeApdu is Android-only in this app');
  }

  @override
  Future<bool> open(UsbDevice usbDevice) async {
    try {
      final activeDevice = _foundDevices.firstWhere(
        (e) => e.serialNumber == usbDevice.identifier,
        orElse: () => throw Exception('Device not found'),
      );

      await activeDevice.open();

      final configuration = await activeDevice.configuration;
      if (configuration == null) {
        throw Exception('No configuration found');
      }
      await activeDevice.selectConfiguration(configuration.configurationValue);

      final allInterfaces = await activeDevice.interfaces;
      if (allInterfaces.isEmpty) {
        throw Exception('No interfaces found');
      }

      List<USBInterface> eligibleInterfaces = allInterfaces
          .where(
            (e) =>
                !e.claimed &&
                e.alternate.endpoints.any(
                  (e) => e.direction == _usbInterfaceDirectionIn,
                ) &&
                e.alternate.endpoints.any(
                  (e) => e.direction == _usbInterfaceDirectionOut,
                ),
          )
          .toList(growable: false);

      if (eligibleInterfaces.isEmpty) {
        throw Exception('No eligible interfaces found');
      }

      USBInterface? claimedInterface;
      for (final interface in eligibleInterfaces) {
        if (interface.claimed) continue;

        try {
          await activeDevice.claimInterface(interface.interfaceNumber);
          claimedInterface = interface;
          break;
        } catch (e) {
          debugPrint('Error in claimInterface: $e');
          continue;
          // if (e.toString().contains('SecurityError')) {
          //   continue;
          // } else {
          //   rethrow;
          // }
        }
      }

      if (claimedInterface == null) {
        throw Exception('No eligible interface could be claimed.');
      }

      final endpoints = claimedInterface.alternate.endpoints;
      final inEndpoint = endpoints.firstWhere(
        (e) => e.direction == _usbInterfaceDirectionIn,
        orElse: () => throw Exception(
            'wtf: IN endpoint not found anymore on eligible interface'),
      );
      final outEndpoint = endpoints.firstWhere(
        (e) => e.direction == _usbInterfaceDirectionOut,
        orElse: () => throw Exception(
            'wtf: OUT endpoint not found anymore on eligible interface'),
      );

      _activeDevice = (
        device: activeDevice,
        inEndpointNumber: inEndpoint.endpointNumber,
        outEndpointNumber: outEndpoint.endpointNumber
      );
      return true;
    } catch (e) {
      debugPrint('Error in open: $e');
      return false;
    }
  }

  @override
  Future<Uint8List?> transferIn(int packetSize, int timeout) async {
    try {
      final activeDevice = _activeDevice;
      if (activeDevice == null) {
        throw Exception('No active device; use open() first');
      }
      final device = activeDevice.device;
      final endpointNumber = activeDevice.inEndpointNumber;

      if (!device.opened) {
        await device.open();
      }

      final result = await device.transferIn(endpointNumber, packetSize);
      return result.data;
    } catch (e) {
      debugPrint('Error in transferIn: $e');
      if (e.toString().contains('InvalidStateError')) {
        await _reopenDevice();
        return transferIn(packetSize, timeout);
      }
      return null;
    }
  }

  @override
  Future<int> transferOut(Uint8List data, int timeout) async {
    try {
      final activeDevice = _activeDevice;
      if (activeDevice == null) {
        throw Exception('No active device; use open() first');
      }
      final device = activeDevice.device;
      final endpointNumber = activeDevice.outEndpointNumber;

      if (!device.opened) {
        await device.open();
      }

      final result = await device.transferOut(endpointNumber, data);
      return result.bytesWritten;
    } catch (e) {
      debugPrint('Error in transferOut: $e');
      if (e.toString().contains('InvalidStateError')) {
        await _reopenDevice();
        return transferOut(data, timeout);
      }
      return -1;
    }
  }

  Future<void> _reopenDevice() async {
    final activeDevice = _activeDevice;
    if (activeDevice != null) {
      final device = activeDevice.device;
      await device.close();
      await device.open();
      await open(
        UsbDevice(
          manufacturerName: device.manufacturerName,
          deviceId: 0,
          vendorId: device.vendorId,
          productId: device.productId,
          productName: device.productName,
          configurationCount: 0,
          identifier: device.serialNumber,
          deviceName: device.productName,
        ),
      );
    }
  }

  @override
  Future<bool> close() async {
    try {
      final activeDevice = _activeDevice;
      if (activeDevice != null) {
        await activeDevice.device.close();
        _activeDevice = null;
        _foundDevices.clear();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error in close: $e');
      return false;
    }
  }
}
