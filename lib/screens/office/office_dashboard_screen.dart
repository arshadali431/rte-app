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
        // Dashboard remains the root screen for the office flow.
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF082923),
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
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
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const NoInternetBanner(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dashboard',
                                style: GoogleFonts.outfit(
                                  fontSize: 29,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Administrative Portal',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.62),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildLogoutButton(context),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QUICK ACTIONS',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: Colors.white.withOpacity(0.58),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.add_card_rounded,
                            title: 'New Token',
                            subtitle: 'Generate a token for a parent',
                            primaryColor: const Color(0xFF4DB6AC),
                            onTap: () => context.push('/office/new-token'),
                          ),
                          const SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.search_rounded,
                            title: 'All Applications',
                            subtitle: 'Search and manage entries',
                            primaryColor: const Color(0xFF81D4FA),
                            onTap: () => context.push('/office/search'),
                          ),
                          const SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.language_rounded,
                            title: 'Verify on Gov.',
                            subtitle: 'Check application on the government portal',
                            primaryColor: const Color(0xFF9FA8DA),
                            onTap: () => context.push('/rte/status-checker'),
                          ),
                          const SizedBox(height: 12),
                          _buildMenuCard(
                            context,
                            icon: Icons.qr_code_scanner_rounded,
                            title: 'Scan QR Code',
                            subtitle: 'View a parent’s application status',
                            primaryColor: const Color(0xFFFFD54F),
                            onTap: () => context.push('/office/scan'),
                          ),
                          const SizedBox(height: 24),
                          _buildAnalysisCardWidget(),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isSyncing) Positioned.fill(child: _buildSyncOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Tooltip(
      message: 'Log out',
      child: Material(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _showLogoutDialog(context),
          borderRadius: BorderRadius.circular(12),
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              Icons.logout_rounded,
              color: Colors.white70,
              size: 19,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncOverlay() {
    final double progress = _syncTotal > 0
        ? (_syncCurrent / _syncTotal).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return Container(
      color: Colors.black.withOpacity(0.68),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF102F2B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.09)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF4DB6AC),
                backgroundColor: Colors.white12,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Syncing data',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$_syncCurrent of $_syncTotal records processed',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.white.withOpacity(0.65),
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white12,
                color: const Color(0xFF4DB6AC),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Keep the app open while syncing with the government portal.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: Colors.white.withOpacity(0.55),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCardWidget() {
    return StreamBuilder<Map<String, int>>(
      stream: _countsStream,
      builder: (context, snapshot) {
        final counts = snapshot.data ?? {
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.045),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Application overview',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Live application counts',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isSyncButtonHidden)
                    if (_isSyncing || isLoading)
                      const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF4DB6AC),
                        ),
                      )
                    else
                      IconButton(
                        tooltip: 'Sync application statuses',
                        onPressed: _showSyncAuthDialog,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.sync_rounded,
                          color: Color(0xFF4DB6AC),
                          size: 22,
                        ),
                      ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildAnalysisStat(
                      'Total Generated',
                      counts['total'] ?? 0,
                      Colors.white,
                          () => _openDetails('All Generated'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildAnalysisStat(
                      'Submitted',
                      counts['submitted'] ?? 0,
                      const Color(0xFF90CAF9),
                          () => _openDetails('Submitted'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildAnalysisStat(
                      'Approved',
                      counts['approved'] ?? 0,
                      const Color(0xFF69F0AE),
                          () => _openDetails('Approved'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildAnalysisStat(
                      'Pending',
                      counts['pending'] ?? 0,
                      const Color(0xFFFFD54F),
                          () => _openDetails('Pending'),
                    ),
                  ),
                ],
              ),
              if (correctionCount > 0 || cancelledCount > 0) ...[
                const SizedBox(height: 10),
                if (correctionCount > 0 && cancelledCount > 0)
                  Row(
                    children: [
                      Expanded(
                        child: _buildAnalysisStat(
                          'Correction',
                          correctionCount,
                          const Color(0xFFFF8A65),
                              () => _openDetails('Correction'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildAnalysisStat(
                          'Cancelled',
                          cancelledCount,
                          const Color(0xFFFF5252),
                              () => _openDetails('Cancelled'),
                        ),
                      ),
                    ],
                  )
                else
                  _buildAnalysisStat(
                    correctionCount > 0 ? 'Correction' : 'Cancelled',
                    correctionCount > 0 ? correctionCount : cancelledCount,
                    correctionCount > 0
                        ? const Color(0xFFFF8A65)
                        : const Color(0xFFFF5252),
                        () => _openDetails(
                      correctionCount > 0 ? 'Correction' : 'Cancelled',
                    ),
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
    return Material(
      color: Colors.white.withOpacity(0.035),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.055)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: GoogleFonts.outfit(
                  fontSize: 25,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.65),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 12,
                    color: Colors.white.withOpacity(0.28),
                  ),
                ],
              ),
            ],
          ),
        ),
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
    return Material(
      color: Colors.white.withOpacity(0.045),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: primaryColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.white.withOpacity(0.58),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Colors.white.withOpacity(0.4),
              ),
            ],
          ),
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
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
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
