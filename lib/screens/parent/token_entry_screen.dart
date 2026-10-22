import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/permission_handler.dart';
import '../../core/maintenance_mixin.dart';
import '../../widgets/no_internet_banner.dart';
import '../../widgets/privacy_policy_link.dart';

class TokenEntryScreen extends StatefulWidget {
  const TokenEntryScreen({super.key});

  @override
  State<TokenEntryScreen> createState() => _TokenEntryScreenState();
}

class _TokenEntryScreenState extends State<TokenEntryScreen>
    with MaintenanceWatcher {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    startMaintenanceWatch();
    // Auto open scan options after screen renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showScanOptions();
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(fontSize: 14),
        ),
        backgroundColor: const Color(0xFFB3261E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showScanOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF102F2B),
      barrierColor: Colors.black.withOpacity(0.55),
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.24),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Choose a scan method',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Scan the QR code printed on your RTE token.',
                style: GoogleFonts.outfit(
                  color: Colors.white.withOpacity(0.62),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              _buildScanOption(
                icon: Icons.camera_alt_rounded,
                title: 'Scan with camera',
                //subtitle: 'Point your camera at the QR code',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openCameraScanner();
                },
              ),
              const SizedBox(height: 10),
              _buildScanOption(
                icon: Icons.photo_library_outlined,
                title: 'Choose from gallery',
                //subtitle: 'Use a QR code image saved on your phone',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _scanFromGallery();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanOption({
    required IconData icon,
    required String title,
    //required String subtitle,
    required VoidCallback onTap,
  }) {
    const accent = Color(0xFF4DB6AC);

    return Material(
      color: Colors.white.withOpacity(0.045),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // const SizedBox(height: 3),
                    // Text(
                    //   subtitle,
                    //   style: GoogleFonts.outfit(
                    //     color: Colors.white.withOpacity(0.58),
                    //     fontSize: 12,
                    //   ),
                    // ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.45),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCameraScanner() async {
    final granted = await AppPermissions.requestCamera();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Camera permission is required to scan QR codes.'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => AppPermissions.showSettingsDialog(),
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
        const _TokenQrScanner(),
        transitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
            child: child,
          );
        },
      ),
    ).then((result) {
      if (result == 'gallery') {
        _scanFromGallery();
      } else {
        _processQrResult(result);
      }
    });
  }

  Future<void> _scanFromGallery() async {
    final granted = await AppPermissions.requestPhotos();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Photo library access is required to scan images.'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => AppPermissions.showSettingsDialog(),
            ),
          ),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    if (!mounted) return;
    setState(() => _isLoading = true);
    MobileScannerController? controller;

    try {
      controller = MobileScannerController();
      final BarcodeCapture? capture = await controller.analyzeImage(image.path);

      if (capture != null && capture.barcodes.isNotEmpty) {
        final code = capture.barcodes.first.rawValue;
        if (code != null) {
          try {
            final Map<String, dynamic> data = jsonDecode(code);
            await _processQrResult(data);
            return;
          } catch (_) {
            _showError('This image does not contain a valid token QR code.');
          }
        } else {
          _showError('No readable QR code found. Try another image.');
        }
      } else {
        _showError('No QR code found in this image. Try another image.');
      }
    } catch (e, stackTrace) {
      debugPrint('Gallery QR scan failed: $e\n$stackTrace');
      _showError('Could not scan this image. Please try again.');
    } finally {
      await controller?.dispose();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processQrResult(dynamic result) async {
    if (result != null && result is Map<String, dynamic>) {
      final String? tokenId = result['tokenId'];
      final int? tokenNumber = result['tokenNumber'];

      if (tokenId != null && tokenNumber != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token_id', tokenId);
        await prefs.setInt('token_number', tokenNumber);

        if (mounted) {
          context.go('/parent/dashboard', extra: tokenId);
        }
      } else {
        _showError('Invalid QR data.');
      }
    }
  }

  @override
  void dispose() {
    stopMaintenanceWatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF4DB6AC);

    return Scaffold(
      backgroundColor: const Color(0xFF082923),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF103D35),
              Color(0xFF092C26),
              Color(0xFF081F20),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const NoInternetBanner(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 40,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Material(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () => context.go('/role'),
                                borderRadius: BorderRadius.circular(12),
                                child: const SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                    size: 21,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: constraints.maxHeight < 600 ? 30 : 54,
                          ),
                          Center(
                            child: Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: accent.withOpacity(0.22),
                                ),
                              ),
                              child: const Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 52,
                                color: accent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Scan Your Token',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 29,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'Scan the QR code provided by the RTE office to securely access your application dashboard.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.66),
                                height: 1.55,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.035),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: accent,
                                  size: 19,
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Text(
                                    'You can scan with your camera or choose a QR image from your gallery.',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.7),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: PrivacyPolicyLink(
                              language: 'en',
                              color: accent.withValues(alpha: 0.8),
                              dense: true,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _showScanOptions,
                              icon: _isLoading
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF082923),
                                ),
                              )
                                  : const Icon(Icons.qr_code_scanner_rounded),
                              label: Text(
                                _isLoading ? 'Processing image...' : 'Scan QR Code',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: const Color(0xFF082923),
                                disabledBackgroundColor: accent.withOpacity(0.5),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: Text(
                              'RTE PARENT PORTAL',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: Colors.white.withOpacity(0.36),
                              ),
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
        ),
      ),
    );
  }

}

class _TokenQrScanner extends StatefulWidget {
  const _TokenQrScanner();

  @override
  State<_TokenQrScanner> createState() => _TokenQrScannerState();
}

class _TokenQrScannerState extends State<_TokenQrScanner> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() => _isProcessing = true);

    try {
      final Map<String, dynamic> data = jsonDecode(code);
      final String? tokenId = data['tokenId'];
      final int? tokenNumber = data['tokenNumber'];

      if (tokenId != null && tokenNumber != null) {
        Navigator.of(context).pop({'tokenId': tokenId, 'tokenNumber': tokenNumber});
      } else {
        _showError('Invalid QR data.');
      }
    } catch (e) {
      _showError('Invalid QR format.');
    } finally {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _isProcessing = false);
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(fontSize: 14),
        ),
        backgroundColor: const Color(0xFFB3261E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF4DB6AC);

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final frameSize = (constraints.maxWidth - 48)
              .clamp(220.0, 280.0)
              .toDouble();

          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
              ),

              // Darken the camera preview while keeping the scan area clear.
              Positioned.fill(
                child: CustomPaint(
                  painter: _ScannerOverlayPainter(frameSize: frameSize),
                ),
              ),

              Center(
                child: SizedBox(
                  width: frameSize,
                  height: frameSize,
                  child: Stack(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: accent.withOpacity(0.28),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const SizedBox.expand(),
                      ),
                      _buildCorner(Alignment.topLeft, 0),
                      _buildCorner(Alignment.topRight, 1.5708),
                      _buildCorner(Alignment.bottomLeft, -1.5708),
                      _buildCorner(Alignment.bottomRight, 3.1416),
                    ],
                  ),
                ),
              ),

              // Top controls
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Row(
                      children: [
                        _buildControlButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Close scanner',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Scan QR Code',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _buildControlButton(
                          icon: Icons.flash_on_rounded,
                          tooltip: 'Toggle flashlight',
                          onTap: () => _controller.toggleTorch(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Instructions and gallery option
              Positioned(
                left: 20,
                right: 20,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Align the parent's QR code inside the frame",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Keep your phone steady for a moment',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: Colors.white.withOpacity(0.62),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pop('gallery'),
                            icon: const Icon(Icons.photo_library_outlined, size: 20),
                            label: Text(
                              'Choose from gallery',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.black.withOpacity(0.25),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.24),
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
                ),
              ),

              if (_isProcessing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.55),
                    child: const Center(
                      child: CircularProgressIndicator(color: accent),
                    ),
                  ),
                ),
            ],
          );
        },
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
        color: Colors.black.withOpacity(0.32),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
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
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFF4DB6AC), width: 3.5),
              left: BorderSide(color: Color(0xFF4DB6AC), width: 3.5),
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

class _ScannerOverlayPainter extends CustomPainter {
  const _ScannerOverlayPainter({required this.frameSize});

  final double frameSize;

  @override
  void paint(Canvas canvas, Size size) {
    final side = frameSize.clamp(0.0, size.width).toDouble();
    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side,
      height: side,
    );

    final overlay = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(
        RRect.fromRectAndRadius(scanRect, const Radius.circular(20)),
      );

    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withOpacity(0.58),
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) =>
      oldDelegate.frameSize != frameSize;
}
