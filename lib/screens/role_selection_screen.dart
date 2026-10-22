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
  static const Color _accent = Color(0xFF4DB6AC);

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
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topSpacing = screenHeight < 700 ? 22.0 : 36.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
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
          child: Column(
            children: [
              const NoInternetBanner(),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: topSpacing),
                            Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.asset(
                                  'assets/app_logo.png',
                                  height: 84,
                                  width: 84,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'WELCOME',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _accent,
                                letterSpacing: 2.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Select your role',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 29,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'Choose how you want to access the RTE application portal.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: Colors.white.withOpacity(0.66),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildRoleCard(
                              title: 'Parent / Guardian',
                              subtitle: 'Check application status and upload documents',
                              icon: Icons.family_restroom_rounded,
                              accentColor: _accent,
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
                            const SizedBox(height: 12),
                            _buildRoleCard(
                              title: 'Office Staff',
                              subtitle: 'Manage tokens and application records',
                              icon: Icons.admin_panel_settings_rounded,
                              accentColor: const Color(0xFFFFD54F),
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
                            const SizedBox(height: 26),
                            Center(
                              child: Text(
                                'RTE APPLICATION PORTAL',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.6,
                                  color: Colors.white.withOpacity(0.34),
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.045),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.09)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 24, color: accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Colors.white.withOpacity(0.62),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Colors.white.withOpacity(0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
