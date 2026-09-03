import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:xrpl_mobile_wallet/domain/validation/qr_address_parser.dart';

/// Full-screen camera scanner that returns a classic XRPL address via [Navigator.pop].
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _handled = false;
  String? _lastError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final address = QrAddressParser.extractClassicAddress(raw);
      if (address != null) {
        _handled = true;
        Navigator.of(context).pop(address);
        return;
      }
    }
    // Invalid codes: soft feedback without stopping the scanner.
    if (capture.barcodes.isNotEmpty && mounted) {
      setState(() => _lastError = 'No valid XRPL address in this QR code');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraOk = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan address'),
        actions: [
          if (cameraOk)
            IconButton(
              tooltip: 'Toggle torch',
              icon: const Icon(Icons.flash_on),
              onPressed: () => _controller.toggleTorch(),
            ),
        ],
      ),
      body: !cameraOk
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Camera scanning is only available on Android and iOS devices.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Camera error: ${error.errorCode.name}\n\n'
                          'Grant camera permission in system settings to scan QR codes.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    color: Colors.black54,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Point the camera at a wallet address QR code',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        if (_lastError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _lastError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
