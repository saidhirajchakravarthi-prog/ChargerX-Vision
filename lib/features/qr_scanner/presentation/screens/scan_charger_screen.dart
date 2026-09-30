import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../chargers/domain/models/charger_model.dart';
import '../../../chargers/presentation/providers/selected_charger_provider.dart';
import 'package:go_router/go_router.dart';

class ScanChargerScreen extends ConsumerStatefulWidget {
  const ScanChargerScreen({super.key});

  @override
  ConsumerState<ScanChargerScreen> createState() => _ScanChargerScreenState();
}

class _ScanChargerScreenState extends ConsumerState<ScanChargerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;
  ChargerModel? _identifiedCharger;
  String? _errorMessage;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) {
      _showError('Empty or unreadable QR code. Please try again.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final parsedCharger = ChargerModel.fromQrString(rawValue);

    if (parsedCharger.isRecognized) {
      setState(() {
        _identifiedCharger = parsedCharger;
      });
    } else {
      setState(() {
        _identifiedCharger = parsedCharger;
        _errorMessage = 'Charger not identified. Unknown QR format.';
      });
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _isProcessing = false;
    });
  }

  void _resetScanner() {
    setState(() {
      _isProcessing = false;
      _identifiedCharger = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Charger'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: _identifiedCharger != null
          ? _buildResultView()
          : _buildScannerView(),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _onDetect,
          errorBuilder: (context, error) {
            String errorText;
            switch (error.errorCode) {
              case MobileScannerErrorCode.permissionDenied:
                errorText =
                    'Camera permission denied. Please enable it in settings.';
                break;
              case MobileScannerErrorCode.unsupported:
                errorText = 'Camera not supported on this device.';
                break;
              default:
                errorText =
                    'Camera error: ${error.errorDetails?.message ?? "Unknown error"}';
                break;
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  errorText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            );
          },
        ),
        // Scanner overlay
        Container(
          decoration: ShapeDecoration(
            shape: QrScannerOverlayShape(
              borderColor: Theme.of(context).primaryColor,
              borderRadius: 12,
              borderLength: 32,
              borderWidth: 8,
              cutOutSize: 250,
            ),
          ),
        ),
        if (_errorMessage != null)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.red.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResultView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            _identifiedCharger!.isRecognized
                ? Icons.check_circle_outline
                : Icons.help_outline,
            size: 64,
            color: _identifiedCharger!.isRecognized
                ? Colors.green
                : Colors.orange,
          ),
          const SizedBox(height: 16),
          Text(
            _identifiedCharger!.isRecognized
                ? 'Charger Identified'
                : 'Charger Not Identified',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 32),
          _buildDetailRow('Manufacturer', _identifiedCharger!.manufacturer),
          _buildDetailRow('Model', _identifiedCharger!.model),
          _buildDetailRow('Type', _identifiedCharger!.type),
          _buildDetailRow('Serial Number', _identifiedCharger!.serialNumber),
          const Divider(height: 32),
          _buildDetailRow('Raw QR Data', _identifiedCharger!.rawQrIdentifier),
          const Spacer(),
          FilledButton.icon(
            onPressed: () {
              if (_identifiedCharger!.isRecognized) {
                ref
                    .read(selectedChargerProvider.notifier)
                    .selectCharger(_identifiedCharger);
                context.go('/digital-twin', extra: _identifiedCharger);
              } else {
                _resetScanner();
              }
            },
            icon: Icon(
              _identifiedCharger!.isRecognized
                  ? Icons.arrow_forward
                  : Icons.refresh,
            ),
            label: Text(
              _identifiedCharger!.isRecognized
                  ? 'View Digital Twin'
                  : 'Try Again',
            ),
          ),
          if (_identifiedCharger!.isRecognized) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _resetScanner,
              child: const Text('Scan Another Charger'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value?.isNotEmpty == true ? value! : 'Not available',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.blue,
    this.borderWidth = 3.0,
    this.overlayColor = 150,
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10.0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path path = Path()..addRect(rect);
    rect = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );
    path.addRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(borderRadius),
        topRight: Radius.circular(borderRadius),
        bottomLeft: Radius.circular(borderRadius),
        bottomRight: Radius.circular(borderRadius),
      ),
    );
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withAlpha(overlayColor.toInt())
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );

    canvas.drawPath(
      Path()
        ..addRect(rect)
        ..addRRect(
          RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
        )
        ..fillType = PathFillType.evenOdd,
      backgroundPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
      boxPaint,
    );

    // Draw corners
    final cornerPath = Path();

    // Top left
    cornerPath.moveTo(cutOutRect.left, cutOutRect.top + borderLength);
    cornerPath.lineTo(cutOutRect.left, cutOutRect.top + borderRadius);
    cornerPath.arcToPoint(
      Offset(cutOutRect.left + borderRadius, cutOutRect.top),
      radius: Radius.circular(borderRadius),
    );
    cornerPath.lineTo(cutOutRect.left + borderLength, cutOutRect.top);

    // Top right
    cornerPath.moveTo(cutOutRect.right - borderLength, cutOutRect.top);
    cornerPath.lineTo(cutOutRect.right - borderRadius, cutOutRect.top);
    cornerPath.arcToPoint(
      Offset(cutOutRect.right, cutOutRect.top + borderRadius),
      radius: Radius.circular(borderRadius),
    );
    cornerPath.lineTo(cutOutRect.right, cutOutRect.top + borderLength);

    // Bottom right
    cornerPath.moveTo(cutOutRect.right, cutOutRect.bottom - borderLength);
    cornerPath.lineTo(cutOutRect.right, cutOutRect.bottom - borderRadius);
    cornerPath.arcToPoint(
      Offset(cutOutRect.right - borderRadius, cutOutRect.bottom),
      radius: Radius.circular(borderRadius),
    );
    cornerPath.lineTo(cutOutRect.right - borderLength, cutOutRect.bottom);

    // Bottom left
    cornerPath.moveTo(cutOutRect.left + borderLength, cutOutRect.bottom);
    cornerPath.lineTo(cutOutRect.left + borderRadius, cutOutRect.bottom);
    cornerPath.arcToPoint(
      Offset(cutOutRect.left, cutOutRect.bottom - borderRadius),
      radius: Radius.circular(borderRadius),
    );
    cornerPath.lineTo(cutOutRect.left, cutOutRect.bottom - borderLength);

    canvas.drawPath(cornerPath, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
      borderRadius: borderRadius * t,
      borderLength: borderLength * t,
      cutOutSize: cutOutSize * t,
    );
  }
}
