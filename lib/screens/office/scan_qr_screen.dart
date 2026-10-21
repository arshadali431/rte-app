import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/firestore_service.dart';
import '../../core/permission_handler.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    _processQrCode(code);
  }

  Future<void> _processQrCode(String code) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final Map<String, dynamic> data = jsonDecode(code);
      final String? tokenId = data['tokenId'];

      if (tokenId != null) {
        final token = await FirestoreService().getTokenById(tokenId);
        if (token != null) {
          if (mounted) {
            context.push('/office/token-detail', extra: token);
          }
        } else {
          _showError('Token not found in database.');
        }
      } else {
        _showError('Invalid QR data: Token ID missing.');
      }
    } catch (e) {
      _showError('Invalid QR code format.');
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isProcessing = false);
      });
    }
  }

  Future<void> _pickFromGallery() async {
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

    setState(() => _isProcessing = true);
    try {
      final barcodeCapture = await _controller.analyzeImage(image.path);
      if (barcodeCapture != null && barcodeCapture.barcodes.isNotEmpty) {
        final code = barcodeCapture.barcodes.first.rawValue;
        if (code != null) {
          setState(() => _isProcessing = false);
          await _processQrCode(code);
        } else {
          _showError('No QR code found in selected image.');
        }
      } else {
        _showError('No QR code detected in this image.');
      }
    } catch (e) {
      _showError('Failed to analyze image.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
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
                        _buildCorner(Alignment.topLeft, 0),
                        _buildCorner(Alignment.topRight, 1.57),
                        _buildCorner(Alignment.bottomLeft, -1.57),
                        _buildCorner(Alignment.bottomRight, 3.14),
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
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/office/dashboard');
                    }
                  },
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
                    "Point camera at application QR code",
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
                  onTap: _pickFromGallery,
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

  Widget _buildCorner(Alignment alignment, double angle) {
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
