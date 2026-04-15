import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/rte_service.dart';
import '../../models/token_model.dart';
import '../../core/maintenance_mixin.dart';
import '../../widgets/no_internet_banner.dart';

class OfficeDashboardScreen extends StatefulWidget {
  const OfficeDashboardScreen({super.key});

  @override
  State<OfficeDashboardScreen> createState() => _OfficeDashboardScreenState();
}

class _OfficeDashboardScreenState extends State<OfficeDashboardScreen> with MaintenanceWatcher {
  bool _isSyncing = false;
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
        backgroundColor: const Color(0xFF0D2B2B),
        appBar: AppBar(
          title: Text(
            'Dashboard',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white70),
              onPressed: () => _showLogoutDialog(context),
            ),
          ],
        ),
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
                    colors: [
                      Color(0xFF0D2B2B),
                      Color(0xFF004D40),
                      Color(0xFF00796B),
                    ],
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMenuCard(
                        context,
                        icon: Icons.add_card_rounded,
                        title: 'New Token',
                        subtitle: 'Generate token for a new family',
                        onTap: () => context.push('/office/new-token'),
                      ),
                      const SizedBox(height: 20),
                      _buildMenuCard(
                        context,
                        icon: Icons.search_rounded,
                        title: 'All Application',
                        subtitle: 'Find application by name or mobile',
                        onTap: () => context.push('/office/search'),
                      ),
                      const SizedBox(height: 20),
                      _buildMenuCard(
                        context,
                        icon: Icons.language_rounded,
                        title: 'Check Status Gov.',
                        subtitle: 'Verify on government portal',
                        iconColor: Colors.blue[700],
                        borderColor: Colors.blue.withOpacity(0.2),
                        onTap: () => context.push('/rte/status-checker'),
                      ),
                      const SizedBox(height: 20),
                      _buildMenuCard(
                        context,
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'Scan QR',
                        subtitle: 'Scan parent QR to view details',
                        onTap: () => context.push('/office/scan'),
                      ),
                      const SizedBox(height: 32),
                      _buildAnalysisCardWidget(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCardWidget() {
    return StreamBuilder<List<TokenModel>>(
      stream: FirestoreService().getAllTokens(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF81D4FA)));
        }

        final tokens = snapshot.data!;
        
        // Dynamic Filtering
        List<TokenModel> totalList = tokens;
        List<TokenModel> approvedList = tokens.where((t) => t.govStatus == 'APPROVED').toList();
        List<TokenModel> cancelledList = tokens.where((t) => t.govStatus == 'CANCELLED').toList();
        List<TokenModel> correctionList = tokens.where((t) => t.govStatus == 'CORRECTION').toList();
        List<TokenModel> reSubmitList = tokens.where((t) => t.applicationHistory.isNotEmpty).toList();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3535),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'APPLICATION ANALYSIS',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF81D4FA),
                      letterSpacing: 2,
                    ),
                  ),
                  // _isSyncing
                  //   ? const SizedBox(
                  //       width: 16,
                  //       height: 16,
                  //       child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
                  //     )
                  //   : IconButton(
                  //       icon: const Icon(Icons.sync_rounded, color: Colors.white24, size: 20),
                  //       onPressed: () => _syncAllStatuses(tokens),
                  //       constraints: const BoxConstraints(),
                  //       padding: EdgeInsets.zero,
                  //       tooltip: 'Sync all from portal',
                  //     ),
                ],
              ),
              const SizedBox(height: 24),
              _buildAnalysisStat('Total Generated', totalList.length, Colors.white, () => _openDetails('All Generated', totalList)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Colors.white10),
              ),
              Row(
                children: [
                  Expanded(child: _buildAnalysisStat('Approved', approvedList.length, Colors.greenAccent, () => _openDetails('Approved', approvedList))),
                  Expanded(child: _buildAnalysisStat('Correction', correctionList.length, Colors.orangeAccent, () => _openDetails('Correction', correctionList))),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildAnalysisStat('Cancelled', cancelledList.length, Colors.redAccent, () => _openDetails('Cancelled', cancelledList))),
                  Expanded(child: _buildAnalysisStat('Re-submitted', reSubmitList.length, const Color(0xFFE1F5FE), () => _openDetails('Re-submitted', reSubmitList))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _openDetails(String category, List<TokenModel> tokens) {
    context.push('/office/analysis-details', extra: {'category': category, 'tokens': tokens});
  }

  Widget _buildAnalysisStat(String label, int count, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count.toString(),
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.white38,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.open_in_new_rounded, size: 10, color: Colors.white12),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? borderColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3535),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor ?? Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (iconColor ?? const Color(0xFF00796B)).withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 32,
                color: iconColor ?? const Color(0xFF81D4FA),
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3535),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Logout',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to logout from the dashboard?',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().signOut();
              if (context.mounted) context.go('/role');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.8),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncAllStatuses(List<TokenModel> tokens) async {
    final toSync = tokens.where((t) => t.applicationId != null && t.childDob != null).toList();

    if (toSync.isEmpty) return;

    setState(() => _isSyncing = true);

    int count = 0;
    try {
      for (final token in toSync) {
        try {
          final data = await RteService().fetchApplicationStatus(
            token.applicationId!,
            token.childDob!,
          );
          
          final classified = RteService().classifyStatus(data.statusMessage);
          await FirestoreService().updateGovStatus(
            token.id,
            govStatus: classified,
            message: data.statusMessage,
          );
          count++;
          debugPrint("Synced (${count}/${toSync.length}): ${token.applicationId}");
        } catch (e) {
          debugPrint("Failed to sync ${token.applicationId}: $e");
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Portal Sync Complete: $count records updated')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }
}
