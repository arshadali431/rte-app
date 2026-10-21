import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/maintenance_mixin.dart';
import '../core/app_state.dart';
import '../widgets/no_internet_banner.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with MaintenanceWatcher {
  @override
  void initState() {
    super.initState();
    startMaintenanceWatch();
  }

  @override
  void dispose() {
    stopMaintenanceWatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // do nothing
      },
      child: Scaffold(
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
            
            // 2. Decorative Background Blobs
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00796B).withOpacity(0.15),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF80CBC4).withOpacity(0.1),
                ),
              ),
            ),

            // 3. Content
            Column(
              children: [
                const NoInternetBanner(),
                Expanded(
                  child: SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 60),
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/app_logo.png',
                                height: 110,
                                width: 110,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'WELCOME',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF4DB6AC),
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select your role',
                            style: GoogleFonts.outfit(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Continue to access your dashboard and manage RTE applications',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              color: Colors.white.withOpacity(0.6),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 60),
                          
                          _buildRoleCard(
                            context,
                            title: 'Parent / Guardian',
                            subtitle: 'View your status or upload docs',
                            icon: Icons.family_restroom_rounded,
                            primaryColor: const Color(0xFF4DB6AC),
                            onTap: () {
                              final maintenance = context.read<AppState>().maintenance;
                              if (maintenance.parentMaintenance) {
                                context.go('/maintenance/parent');
                                return;
                              }
                              context.go('/parent/token-entry');
                            },
                          ),
                          const SizedBox(height: 24),
                          _buildRoleCard(
                            context,
                            title: 'Office Staff',
                            subtitle: 'Manage tokens & sync portal data',
                            icon: Icons.admin_panel_settings_rounded,
                            primaryColor: const Color(0xFFFFD54F),
                            onTap: () {
                              final maintenance = context.read<AppState>().maintenance;
                              if (maintenance.officeMaintenance) {
                                context.go('/maintenance/office');
                                return;
                              }
                              context.go('/office/login');
                            },
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                icon,
                size: 32,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
