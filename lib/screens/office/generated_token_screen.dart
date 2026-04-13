import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../widgets/no_internet_banner.dart';

class GeneratedTokenScreen extends StatelessWidget {
  final Map<String, dynamic> tokenData;

  const GeneratedTokenScreen({
    super.key,
    required this.tokenData,
  });

  @override
  Widget build(BuildContext context) {
    final String tokenId = tokenData['tokenId'] ?? '';
    final int tokenNumber = tokenData['tokenNumber'] ?? 0;
    final String parentName = tokenData['parentName'] ?? '';
    final String parentMobile = tokenData['parentMobile'] ?? '';

    // Data to encode in QR
    final String qrJson = jsonEncode({
      'tokenId': tokenId,
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
              height: double.infinity,
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
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.greenAccent, size: 80),
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

                    // Token Info Card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3535),
                        borderRadius: BorderRadius.circular(24),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.05)),
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
                            style: GoogleFonts.outfit(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w500),
                          ),
                          Text(
                            parentMobile,
                            style: GoogleFonts.outfit(
                                fontSize: 14, color: Colors.white54),
                          ),
                          const SizedBox(height: 30),

                          // QR Code
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
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF004D40),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF004D40),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Scan this QR on parent app',
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Actions
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Share.share(
                                  'Your RTE Token is #$tokenNumber. Download our app and enter this token to complete your registration.',
                                );
                              },
                              icon: const Icon(Icons.share_rounded),
                              label: const Text('Share'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF81D4FA),
                                side:
                                    const BorderSide(color: Color(0xFF81D4FA)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => context.go('/office/dashboard'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00796B),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              child: const Text('Done'),
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
