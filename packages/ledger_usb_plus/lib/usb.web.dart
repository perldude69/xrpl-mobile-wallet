// ignore_for_file: prefer_void_to_null, unnecessary_library_name

@JS("window.navigator")
library usb;

import 'dart:js_interop';
import 'dart:typed_data';

@JS()
external WebUSB get usb;

extension type WebUSB._(JSObject o) implements JSObject {
  @JS('getDevices')
  external JSPromise<JSArray<USBDevice>> _getDevices();

  @JS('requestDevice')
  external JSPromise<USBDevice?> _requestDevice(
    RequestUSBDeviceFilters filters,
  );

  Future<List<USBDevice>> getDevices() async {
    final jsDevices = await _getDevices().toDart;
    return jsDevices.toDart;
  }

  Future<USBDevice?> requestDevice(RequestUSBDeviceFilters filters) async {
    final device = await _requestDevice(filters).toDart;
    return device;
  }
}

extension type USBDevice._(JSObject o) implements JSObject {
  @JS('open')
  external JSPromise<Null> _open();

  @JS('selectConfiguration')
  external JSPromise<Null> _selectConfiguration(int configurationValue);

  @JS('claimInterface')
  external JSPromise<Null> _claimInterface(int interfaceNumber);

  @JS('transferIn')
  external JSPromise<USBInTransferResult> _transferIn(
    int endpointNumber,
    int packetSize,
  );

  @JS('transferOut')
  external JSPromise<USBOutTransferResult> _transferOut(
    int endpointNumber,
    JSUint8Array data,
  );

  @JS('close')
  external JSPromise<JSAny> _close();

  external String get manufacturerName;
  external String get productName;
  external String get serialNumber;
  external int get vendorId;
  external int get productId;

  external bool get opened;

  @JS('configuration')
  external USBConfiguration? get _configuration;

  Future<void> open() async {
    try {
      if (!opened) {
        await _open().toDart;
      }
    } catch (e) {
      throw Exception('Failed to open device: $e');
    }
  }

  Future<void> selectConfiguration(int configurationValue) async {
    await _selectConfiguration(configurationValue).toDart;
  }

  Future<void> claimInterface(int interfaceNumber) async {
    await _claimInterface(interfaceNumber).toDart;
  }

  Future<USBInTransferResult> transferIn(
    int endpointNumber,
    int packetSize,
  ) async {
    if (!opened) {
      throw Exception('Device is not open');
    }
    try {
      final result = await _transferIn(endpointNumber, packetSize).toDart;
      return result;
    } catch (e) {
      throw Exception('TransferIn failed: $e');
    }
  }

  Future<USBOutTransferResult> transferOut(
    int endpointNumber,
    Uint8List data,
  ) async {
    if (!opened) {
      throw Exception('Device is not open');
    }
    try {
      final result = await _transferOut(endpointNumber, data.toJS).toDart;
      return result;
    } catch (e) {
      throw Exception('TransferOut failed: $e');
    }
  }

  Future<void> close() async {
    if (opened) {
      await _close().toDart;
    }
  }
}

extension type USBInTransferResult._(JSObject o) implements JSObject {
  @JS('data')
  external JSDataView? get _data;
  external String get status;

  Uint8List? get data {
    final jsData = _data;
    if (jsData == null) {
      return null;
    }
    return jsData.toDart.buffer.asUint8List();
  }
}

extension type USBOutTransferResult._(JSObject o) implements JSObject {
  external int get bytesWritten;
  external String get status;
}

extension type RequestUSBDeviceFilters._(JSObject o) implements JSObject {
  external JSArray<RequestUSBDeviceFilter> filters;

  external RequestUSBDeviceFilters.js({
    required JSArray<RequestUSBDeviceFilter> filters,
  });

  static RequestUSBDeviceFilters dart(List<RequestUSBDeviceFilter> filters) =>
      RequestUSBDeviceFilters.js(filters: filters.toJS);
}

extension type RequestUSBDeviceFilter._(JSObject o) implements JSObject {
  external int? get vendorId;
  external int? get productId;
  external String? get classCode;
  external String? get subclassCode;
  external String? get protocolCode;
  external String? get serialNumber;

  external RequestUSBDeviceFilter({
    int? vendorId,
    int? productId,
    String? classCode,
    String? subclassCode,
    String? protocolCode,
    String? serialNumber,
  });
}

extension USBDeviceExtension on USBDevice {
  Future<USBConfiguration?> get configuration async => _configuration;

  Future<List<USBInterface>> get interfaces async {
    final config = await configuration;
    final jsInterfaces = config?.interfaces.toDart;
    if (jsInterfaces == null) {
      return [];
    }
    return jsInterfaces;
  }
}

extension type USBConfiguration._(JSObject o) implements JSObject {
  external String? get configurationName;
  external int get configurationValue;
  external JSArray<USBInterface> get interfaces;
}

extension type USBInterface._(JSObject o) implements JSObject {
  external int get interfaceNumber;
  external String? get interfaceName;
  external int get interfaceClass;
  external int get interfaceSubclass;
  external int get interfaceProtocol;
  external bool get claimed;
  external USBAlternateInterface get alternate;
}

extension type USBAlternateInterface._(JSObject o) implements JSObject {
  external int get alternateSetting;
  @JS('endpoints')
  external JSArray<USBEndpoint> get _endpoints;

  List<USBEndpoint> get endpoints => _endpoints.toDart;
}

extension type USBEndpoint._(JSObject o) implements JSObject {
  external int get endpointNumber;
  external String get direction;
  external String get type;
  external int get packetSize;
}
