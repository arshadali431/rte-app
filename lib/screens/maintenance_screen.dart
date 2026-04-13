import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

class MaintenanceScreen extends StatelessWidget {
  final String message;
  final bool allowBack;
  
  const MaintenanceScreen({
    super.key,
    this.message = 'We are currently under maintenance.\nPlease check back later.',
    this.allowBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!allowBack) {
          // Minimize app to background instead of navigating back
          SystemNavigator.pop(); // exits to home screen
        }
      },
      child: Scaffold(
        body: Container(
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
                // Back button (only if allowBack)
                if (allowBack)
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, top: 8),
                      child: IconButton(
                        onPressed: () => context.go('/role'),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                // Center content
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated icon
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.construction_rounded,
                          size: 64,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Under Maintenance',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            color: Colors.white54,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_rounded,
                              color: Colors.orange, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'We\'ll be back soon!',
                              style: GoogleFonts.outfit(
                                color: Colors.orange,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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
    );
  }
}
