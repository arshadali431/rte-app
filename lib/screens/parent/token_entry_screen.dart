import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class TokenEntryScreen extends StatefulWidget {
  const TokenEntryScreen({super.key});

  @override
  State<TokenEntryScreen> createState() => _TokenEntryScreenState();
}

class _TokenEntryScreenState extends State<TokenEntryScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
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

  void _openCameraScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const _TokenQrScanner(),
      ),
    ).then((result) => _processQrResult(result));
  }

  Future<void> _scanFromGallery() async {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D2B2B),
              Color(0xFF0A1A1A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back button top left
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () => context.go('/role'), // go to role, NOT pop
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                ),
              ),
              
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00796B).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded, 
                        size: 64, color: Color(0xFF81D4FA)),
                    ),
                    const SizedBox(height: 32),
                    
                    Text('Scan Your Token',
                      style: GoogleFonts.outfit(
                        fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Scan the QR code given by our office',
                      style: GoogleFonts.outfit(fontSize: 15, color: Colors.white54),
                      textAlign: TextAlign.center),
                      
                    const SizedBox(height: 48),
                    
                    // Scan button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _showScanOptions,
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: Text('Scan QR Code',
                            style: GoogleFonts.outfit(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00796B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                    
                    if (_isLoading) ...[
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(color: Color(0xFF81D4FA)),
                    ],
                  ],
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          
          // Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF81D4FA), width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          
          Positioned(
            bottom: 100,
            left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  "Point camera at office QR code",
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),

          if (_isProcessing)
            Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Color(0xFF81D4FA)))),
        ],
      ),
    );
  }
}
