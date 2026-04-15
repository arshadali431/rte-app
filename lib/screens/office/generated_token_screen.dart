import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../widgets/no_internet_banner.dart';

class GeneratedTokenScreen extends StatefulWidget {
  final Map<String, dynamic> tokenData;

  const GeneratedTokenScreen({
    super.key,
    required this.tokenData,
  });

  @override
  State<GeneratedTokenScreen> createState() => _GeneratedTokenScreenState();
}

class _GeneratedTokenScreenState extends State<GeneratedTokenScreen> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isSaving = false;

  Future<void> _captureAndSave() async {
    setState(() => _isSaving = true);
    try {
      final boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/token_${widget.tokenData['tokenNumber']}.png').create();
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(file.path)], text: 'RTE Token #${widget.tokenData['tokenNumber']}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int tokenNumber = widget.tokenData['tokenNumber'] ?? 0;
    final String parentName = widget.tokenData['parentName'] ?? '';
    final String parentMobile = widget.tokenData['parentMobile'] ?? '';

    final String qrJson = jsonEncode({
      'tokenId': widget.tokenData['tokenId'] ?? '',
      'tokenNumber': tokenNumber,
      'parentName': parentName,
      'parentMobile': parentMobile,
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D2B2B),
      body: Column(
        children: [
          const NoInternetBanner(),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0D2B2B), Color(0xFF0A1A1A)],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 80),
                    const SizedBox(height: 16),
                    Text(
                      'Token Generated!',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Wrap Token Card in RepaintBoundary for capturing
                    RepaintBoundary(
                      key: _globalKey,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A3535),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Token #$tokenNumber',
                              style: GoogleFonts.outfit(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF81D4FA),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              parentName,
                              style: GoogleFonts.outfit(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              parentMobile,
                              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white54),
                            ),
                            const SizedBox(height: 30),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: QrImageView(
                                data: qrJson,
                                version: QrVersions.auto,
                                size: 200.0,
                                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF004D40)),
                                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF004D40)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Scan this QR on parent app',
                              style: GoogleFonts.outfit(fontSize: 12, color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.go('/office/dashboard'),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Close'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white54,
                                side: const BorderSide(color: Colors.white12),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _captureAndSave,
                              icon: _isSaving 
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_alt_rounded),
                              label: Text(_isSaving ? 'Processing...' : 'Save & Share'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00796B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
