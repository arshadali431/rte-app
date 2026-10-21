import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../models/token_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/rte_service.dart';
import '../../core/maintenance_mixin.dart';
import '../../widgets/no_internet_banner.dart';

class OfficeDashboardScreen extends StatefulWidget {
  const OfficeDashboardScreen({super.key});

  @override
  State<OfficeDashboardScreen> createState() => _OfficeDashboardScreenState();
}

class _OfficeDashboardScreenState extends State<OfficeDashboardScreen>
    with MaintenanceWatcher {
  bool _isSyncing = false;
  String _syncProgress = "";
  int _syncTotal = 0;
  int _syncCurrent = 0;
  int _failedSyncAttempts = 0;
  bool _isSyncButtonHidden = false;

  // Stream for real-time counts
  late Stream<Map<String, int>> _countsStream;

  @override
  void initState() {
    super.initState();
    startMaintenanceWatch();
    _countsStream = FirestoreService().streamTokenCounts();
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

            // 2. Decorative Background blobs
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00796B).withOpacity(0.1),
                ),
              ),
            ),

            // 3. Content
            Column(
              children: [
                const NoInternetBanner(),
                // Custom App Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 50, 16, 20),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dashboard',
                            style: GoogleFonts.outfit(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Administrative Portal',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: const Color(0xFF4DB6AC),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _buildLogoutButton(context),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        _buildMenuCard(
                          context,
                          icon: Icons.add_card_rounded,
                          title: 'New Token',
                          subtitle: 'Generate token for the parent',
                          primaryColor: const Color(0xFF4DB6AC),
                          onTap: () => context.push('/office/new-token'),
                        ),
                        const SizedBox(height: 16),
                        _buildMenuCard(
                          context,
                          icon: Icons.search_rounded,
                          title: 'All Applications',
                          subtitle: 'Search and manage entries',
                          primaryColor: const Color(0xFF81D4FA),
                          onTap: () => context.push('/office/search'),
                        ),
                        const SizedBox(height: 16),
                        _buildMenuCard(
                          context,
                          icon: Icons.language_rounded,
                          title: 'Verify on Gov.',
                          subtitle: 'Government portal check',
                          primaryColor: const Color(0xFF7986CB),
                          onTap: () => context.push('/rte/status-checker'),
                        ),
                        const SizedBox(height: 16),
                        _buildMenuCard(
                          context,
                          icon: Icons.qr_code_scanner_rounded,
                          title: 'Scan QR Code',
                          subtitle: 'Directly view parent status',
                          primaryColor: const Color(0xFFFFD54F),
                          onTap: () => context.push('/office/scan'),
                        ),

                        const SizedBox(height: 32),
                        _buildAnalysisCardWidget(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_isSyncing) Positioned.fill(child: _buildSyncOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return InkWell(
      onTap: () => _showLogoutDialog(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.logout_rounded,
          color: Colors.white70,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildSyncOverlay() {
    double progress = _syncTotal > 0 ? (_syncCurrent / _syncTotal) : 0;
    return Container(
      color: Colors.black.withOpacity(0.85),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3535),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF81D4FA).withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF81D4FA).withOpacity(0.1),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 6,
                  color: Color(0xFF81D4FA),
                  backgroundColor: Colors.white12,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Syncing Data...',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_syncCurrent / $_syncTotal Records',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: const Color(0xFF81D4FA),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white10,
                  color: const Color(0xFF81D4FA),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Please keep the app open\nwhile syncing with government portal.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.white38,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisCardWidget() {
    return StreamBuilder<Map<String, int>>(
      stream: _countsStream,
      builder: (context, snapshot) {
        final counts =
            snapshot.data ??
            {
              'total': 0,
              'approved': 0,
              'submitted': 0,
              'pending': 0,
              'correction': 0,
              'cancelled': 0,
            };
        final bool isLoading =
            snapshot.connectionState == ConnectionState.waiting;
        final int correctionCount = counts['correction'] ?? 0;
        final int cancelledCount = counts['cancelled'] ?? 0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'APPLICATION ANALYSIS',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF4DB6AC),
                      letterSpacing: 2,
                    ),
                  ),
                  if (!_isSyncButtonHidden)
                    _isSyncing || isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white24,
                            ),
                          )
                        : InkWell(
                            onTap: _showSyncAuthDialog,
                            child: const Icon(
                              Icons.sync_rounded,
                              color: Colors.white38,
                              size: 20,
                            ),
                          ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 1. Total Generated (full width) ────────────────────────
              _buildAnalysisStat(
                'Total Generated',
                counts['total'] ?? 0,
                Colors.white,
                () => _openDetails('All Generated'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(color: Colors.white12, height: 1),
              ),

              // ── 2. Submitted (left) | Approved (right) ────────────────
              Row(
                children: [
                  Expanded(
                    child: _buildAnalysisStat(
                      'Submitted',
                      counts['submitted'] ?? 0,
                      const Color(0xFF90CAF9),
                      () => _openDetails('Submitted'),
                    ),
                  ),
                  Expanded(
                    child: _buildAnalysisStat(
                      'Approved',
                      counts['approved'] ?? 0,
                      const Color(0xFF69F0AE),
                      () => _openDetails('Approved'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 3. Pending (Full Width) ──────────────────────────
              _buildAnalysisStat(
                'Pending',
                counts['pending'] ?? 0,
                const Color(0xFFFFD54F),
                () => _openDetails('Pending'),
              ),

              // ── 4. Legacy/Correction/Cancelled (Only if > 0) ───────
              if (correctionCount > 0 || cancelledCount > 0) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                Row(
                  children: [
                    if (correctionCount > 0)
                      Expanded(
                        child: _buildAnalysisStat(
                          'Correction',
                          correctionCount,
                          const Color(0xFFFF8A65),
                          () => _openDetails('Correction'),
                        ),
                      ),
                    if (cancelledCount > 0)
                      Expanded(
                        child: _buildAnalysisStat(
                          'Cancelled',
                          cancelledCount,
                          const Color(0xFFFF5252),
                          () => _openDetails('Cancelled'),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _openDetails(String category) {
    context.push('/office/analysis-details', extra: {'category': category});
  }

  Widget _buildAnalysisStat(
    String label,
    int count,
    Color color,
    VoidCallback onTap,
  ) {
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
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.white38),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.open_in_new_rounded,
                size: 10,
                color: Colors.white12,
              ),
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
    required Color primaryColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 28, color: primaryColor),
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
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.white38,
              ),
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
        backgroundColor: const Color(0xFF0D2B2B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: const BorderSide(color: Colors.white10),
        ),
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to exit the administrative portal?',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Stay',
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
              backgroundColor: Colors.redAccent.withOpacity(0.9),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  Future<void> _showSyncAuthDialog() async {
    final TextEditingController userController = TextEditingController();
    final TextEditingController passController = TextEditingController();
    bool isAuthenticating = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF132D2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.white10),
          ),
          title: Text(
            'Security Check',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Please enter credentials to continue sync.',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildAuthField(
                controller: userController,
                hint: 'Username',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              _buildAuthField(
                controller: passController,
                hint: 'Password',
                icon: Icons.lock_outline,
                isPassword: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isAuthenticating ? null : () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: Colors.white38),
              ),
            ),
            ElevatedButton(
              onPressed: isAuthenticating
                  ? null
                  : () async {
                      setDialogState(() => isAuthenticating = true);

                      try {
                        final adminDoc = await FirestoreService()
                            .getAdminConfig();
                        final correctUser = adminDoc['syncing_username'];
                        final correctPass = adminDoc['syncing_password'];

                        if (userController.text == correctUser &&
                            passController.text == correctPass) {
                          Navigator.pop(context);
                          _syncAllStatuses();
                        } else {
                          _failedSyncAttempts++;
                          Navigator.pop(context);

                          if (_failedSyncAttempts >= 2) {
                            setState(() => _isSyncButtonHidden = true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Too many failed attempts. Button disabled.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Invalid credentials. ${_failedSyncAttempts}/2 attempts',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF81D4FA),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isAuthenticating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      'Verify',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: GoogleFonts.outfit(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white24, size: 20),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _syncAllStatuses() async {
    if (!mounted) return;

    // Get total count first for accurate progress display
    final counts = await FirestoreService().getTokenCounts();
    final total = counts['total'] ?? 0;

    if (total == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No applications found to sync')),
        );
      }
      return;
    }

    setState(() {
      _isSyncing = true;
      _syncTotal = total;
      _syncCurrent = 0;
    });

    try {
      // Chunked sync: 100 records at a time, never loads full DB into memory
      await FirestoreService().getTokensForSync(
        chunkSize: 100,
        onChunk: (chunk) async {
          // Only process tokens that have portal data
          final List<TokenModel> toSync = [];
          
          for (final t in chunk) {
            if (t.applicationId != null && t.childDob != null && t.govStatus != 'APPROVED') {
              toSync.add(t);
            } else if (t.govStatus == 'APPROVED') {
              debugPrint('Bulk Sync: Skipping Token #${t.tokenNumber} (Already Approved)');
            }
          }

          for (final token in toSync) {
            try {
              final result = await RteService().fetchStatusWithChildName(
                token.applicationId!,
                token.childDob!,
              );
              await FirestoreService().updateGovStatus(
                token.id,
                govStatus: result.classifiedStatus,
                message: result.statusMessage,
                govChildName: result.childName,
                govParentMobile: result.parentMobile,
              );
            } catch (e) {
              debugPrint("Failed to sync ${token.applicationId}: $e");
            }

            if (mounted) {
              setState(() => _syncCurrent++);
            }

            // Throttle to avoid IP blocking from portal
            await Future.delayed(const Duration(milliseconds: 300));
          }

          // Count non-processable tokens too in progress
          final skipped = chunk.length - toSync.length;
          if (mounted && skipped > 0) {
            setState(() => _syncCurrent += skipped);
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync Complete: $_syncCurrent records processed'),
          ),
        );
        FirestoreService().invalidateCache();
        // No need to manually refresh _counts as StreamBuilder handles it
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }
}
