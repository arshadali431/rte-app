import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/permission_handler.dart';
import '../../services/firestore_service.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.trim().isNotEmpty) {
        _processQrCode(code);
        return;
      }
    }
  }

  Future<void> _processQrCode(String code) async {
    if (_isProcessing) return;
    if (mounted) setState(() => _isProcessing = true);

    try {
      final decoded = jsonDecode(code);
      if (decoded is! Map<String, dynamic>) {
        _showError('This QR code is not a valid application code.');
        return;
      }

      final rawTokenId = decoded['tokenId'];
      final tokenId = rawTokenId is String ? rawTokenId.trim() : null;

      if (tokenId == null || tokenId.isEmpty) {
        _showError('Invalid QR code. Token ID is missing.');
        return;
      }

      final token = await FirestoreService().getTokenById(tokenId);
      if (token == null) {
        _showError('Token not found. Please scan a valid application QR code.');
        return;
      }

      if (mounted) {
        await context.push('/office/token-detail', extra: token);
      }
    } on FormatException {
      _showError('Unable to read this QR code. Try another code.');
    } catch (e, stackTrace) {
      debugPrint('QR scan failed: $e\n$stackTrace');
      _showError('Could not open the application. Please try again.');
    } finally {
      // Brief cooldown prevents the same on-camera code being processed repeatedly.
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;

    final granted = await AppPermissions.requestPhotos();
    if (!mounted) return;

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Photo library access is required to scan an image.',
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => AppPermissions.showSettingsDialog(),
          ),
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final barcodeCapture = await _controller.analyzeImage(image.path);
      if (barcodeCapture == null || barcodeCapture.barcodes.isEmpty) {
        _showError('No QR code detected in this image.');
        return;
      }

      final code = barcodeCapture.barcodes
          .map((barcode) => barcode.rawValue)
          .whereType<String>()
          .firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');

      if (code.isEmpty) {
        _showError('No readable QR code found in this image.');
        return;
      }

      // Release the gallery processing lock before handing off to the shared handler.
      if (mounted) setState(() => _isProcessing = false);
      await _processQrCode(code);
    } catch (e, stackTrace) {
      debugPrint('QR gallery analysis failed: $e\n$stackTrace');
      _showError('Could not scan this image. Please try another one.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.outfit(fontSize: 13),
          ),
          backgroundColor: const Color(0xFF8B3030),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  void _closeScanner() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/office/dashboard');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Live camera preview.
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Subtle edge shading keeps controls readable without dimming
          // the whole camera preview too heavily.
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x99000000),
                      Color(0x11000000),
                      Color(0x11000000),
                      Color(0xCC000000),
                    ],
                    stops: [0.0, 0.24, 0.58, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Top bar.
          Positioned(
            top: topInset + 12,
            left: 20,
            right: 20,
            child: Row(
              children: [
                _buildControlButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Close scanner',
                  onTap: _closeScanner,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan QR Code',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Open an application instantly',
                        style: GoogleFonts.outfit(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _buildControlButton(
                  icon: Icons.flash_on_rounded,
                  tooltip: 'Toggle flashlight',
                  onTap: () => _controller.toggleTorch(),
                ),
              ],
            ),
          ),

          // Simple scan frame.
          Center(
            child: SizedBox(
              width: 258,
              height: 258,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.24),
                        width: 1,
                      ),
                    ),
                  ),
                  _buildCorner(Alignment.topLeft, 0),
                  _buildCorner(Alignment.topRight, 1.5708),
                  _buildCorner(Alignment.bottomLeft, -1.5708),
                  _buildCorner(Alignment.bottomRight, 3.1416),
                ],
              ),
            ),
          ),

          // Bottom guidance and gallery action.
          Positioned(
            left: 24,
            right: 24,
            bottom: bottomInset + 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.center_focus_strong_rounded,
                      size: 17,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Align the QR code within the frame',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: Colors.white.withOpacity(0.92),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 20),
                    label: Text(
                      'Choose from gallery',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF00796B),
                      disabledForegroundColor: Colors.white54,
                      side: BorderSide(
                        color: const Color(0xFF4DB6AC).withOpacity(0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.55),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF102F2B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            color: Color(0xFF4DB6AC),
                            strokeWidth: 2.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Checking QR code…',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withOpacity(0.38),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }

  Widget _buildCorner(Alignment alignment, double angle) {
    return Align(
      alignment: alignment,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFF4DB6AC), width: 4),
              left: BorderSide(color: Color(0xFF4DB6AC), width: 4),
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}
