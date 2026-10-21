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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF00796B).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF00796B)),
                ),
                title: Text('Scan with Camera', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                subtitle: Text('Point at a physical QR code', style: GoogleFonts.outfit(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _openCameraScanner();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF81D4FA).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF0288D1)),
                ),
                title: Text('Upload from Gallery', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                subtitle: Text('Select a QR code image from your phone', style: GoogleFonts.outfit(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _scanFromGallery();
                },
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

    setState(() => _isLoading = true);

    try {
      final controller = MobileScannerController();
      final BarcodeCapture? capture = await controller.analyzeImage(image.path);
      
      if (capture != null && capture.barcodes.isNotEmpty) {
        final code = capture.barcodes.first.rawValue;
        if (code != null) {
          try {
            final Map<String, dynamic> data = jsonDecode(code);
            await _processQrResult(data);
            return;
          } catch (e) {
             _showError('Invalid QR format in image.');
          }
        }
      } else {
        _showError('No QR code found in image. Please try another or scan manually.');
      }
    } catch (e) {
      _showError('Failed to analyze image. Please try again.');
    } finally {
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
    return Scaffold(
      body: Stack(
        children: [
          // 1. Dynamic Background Gradient
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF004D40), // Deep Teal
                  Color(0xFF00251A), // Darker Teal
                  Color(0xFF0D2B2B), // Very Dark
                ],
              ),
            ),
          ),
          
          // 2. Decorative Background blobs
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00796B).withOpacity(0.12),
              ),
            ),
          ),

          // 3. Content
          Column(
            children: [
              const NoInternetBanner(),
              Expanded(
                child: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Back Button
                      Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: InkWell(
                            onTap: () => context.go('/role'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // Scanner Visual
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4DB6AC).withOpacity(0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF4DB6AC).withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 72,
                          color: Color(0xFF4DB6AC),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      Text(
                        'Scan Your Token',
                        style: GoogleFonts.outfit(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Scan the QR code provided by the RTE office to access your application dashboard',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.5),
                            height: 1.5,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 60),
                      
                      // Scan Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _showScanOptions,
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            label: Text(
                              'Scan QR Code',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00796B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      if (_isLoading) ...[
                        const SizedBox(height: 32),
                        const CircularProgressIndicator(color: Color(0xFF4DB6AC)),
                      ],
                      
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera View
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          
          // 2. Futuristic Overlay
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
            ),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    // Using BlendMode.clear to create the scanner hole
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF4DB6AC).withOpacity(0.15),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                  ),
                ),
                // Glowing Corners
                Center(
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      children: [
                        _buildCorner(Alignment.topLeft, 0, 0),
                        _buildCorner(Alignment.topRight, 1.57, 0),
                        _buildCorner(Alignment.bottomLeft, -1.57, 0),
                        _buildCorner(Alignment.bottomRight, 3.14, 0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Top Controls (Close & Flash)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGlassButton(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                _buildGlassButton(
                  icon: Icons.flash_on_rounded,
                  onTap: () => _controller.toggleTorch(),
                ),
              ],
            ),
          ),

          // 4. Bottom Instructions & Gallery
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(
                    "Point camera at parent's QR code",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Upload from gallery glass button
                InkWell(
                  onTap: () {
                    Navigator.of(context).pop('gallery'); // Signal to open gallery
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4DB6AC).withOpacity(0.9),
                          const Color(0xFF00796B),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4DB6AC).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          "Upload from Gallery",
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF4DB6AC)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({required IconData icon, required VoidCallback onTap, Color color = Colors.white70}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildCorner(Alignment alignment, double angle, double offset) {
    return Align(
      alignment: alignment,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFF4DB6AC), width: 4),
              left: BorderSide(color: Color(0xFF4DB6AC), width: 4),
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
