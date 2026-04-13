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
              colors: [Color(0xFF0D2B2B), Color(0xFF004D40), Color(0xFF00796B)],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(height: 50),
                      Image.asset('assets/app_logo.png',
                          height: 100, width: 100),
                      const SizedBox(height: 10),
                      Text(
                        'Welcome',
                        style: GoogleFonts.outfit(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select your role to continue',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 60),
                      _buildRoleCard(
                        context,
                        title: 'Parent / Guardian',
                        subtitle: 'Access your application or enter your token',
                        icon: Icons.family_restroom_rounded,
                        onTap: () {
                          final maintenance =
                              context.read<AppState>().maintenance;
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
                        subtitle: 'Manage tokens and applications',
                        icon: Icons.admin_panel_settings_rounded,
                        onTap: () {
                          final maintenance =
                              context.read<AppState>().maintenance;
                          if (maintenance.officeMaintenance) {
                            context.go('/maintenance/office');
                            return;
                          }
                          context.go('/office/login');
                        },
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
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3535),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00796B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 32, color: const Color(0xFF81D4FA)),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.white24,
            ),
          ],
        ),
      ),
    );
  }
}
