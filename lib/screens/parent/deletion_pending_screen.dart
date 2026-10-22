import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_links.dart';
import '../../models/deletion_request.dart';
import '../../services/deletion_service.dart';
import '../../widgets/privacy_policy_link.dart';

/// Shown instead of the parent data screens while a deletion request is
/// pending. Gives the parent the promised
/// `Deletion scheduled for <date>. Tap to cancel` state and blocks access to
/// the data being deleted.
class DeletionPendingScreen extends StatefulWidget {
  const DeletionPendingScreen({super.key});

  @override
  State<DeletionPendingScreen> createState() => _DeletionPendingScreenState();
}

class _DeletionPendingScreenState extends State<DeletionPendingScreen> {
  static const Color _accent = Color(0xFF26A69A);
  static const Color _background = Color(0xFF082923);

  bool _loading = true;
  bool _cancelling = false;
  String? _error;
  DeletionRequest? _request;
  String? _tokenId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenId = prefs.getString('token_id');
    if (!mounted) return;
    if (tokenId == null || tokenId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No active session found. Please scan your token again.';
      });
      return;
    }
    final request = await DeletionService().getRequest(tokenId);
    if (!mounted) return;
    setState(() {
      _tokenId = tokenId;
      _request = request;
      _loading = false;
      if (request == null || !request.isPendingAt(DateTime.now())) {
        _error = 'No active deletion request was found for this session.';
      }
    });
  }

  Future<void> _cancelDeletion() async {
    final tokenId = _tokenId;
    if (tokenId == null) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF10332E),
        title: Text(
          'Cancel deletion?',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Your data will be restored and the scheduled deletion will be cancelled. You can request deletion again later from your profile.',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Keep deletion',
              style: GoogleFonts.outfit(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Cancel deletion',
              style: GoogleFonts.outfit(
                color: const Color(0xFFFF8A80),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await DeletionService().cancelDeletion(tokenId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deletion cancelled. Your data has been restored.'),
        ),
      );
      context.go('/parent/dashboard');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cancelling = false;
        _error = 'Could not cancel the deletion. Please try again.';
      });
    }
  }

  Future<void> _logOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token_id');
    await prefs.remove('token_number');
    if (!mounted) return;
    context.go('/role');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _background,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0E3B34), Color(0xFF082923), Color(0xFF061E1B)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _loading
                    ? const CircularProgressIndicator(color: _accent)
                    : _buildContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final request = _request;
    final pending = request != null && request.isPendingAt(DateTime.now());
    final executeAfter = request?.executeAfter;
    final dateText = executeAfter == null
        ? 'the scheduled time'
        : DateFormat('dd MMM yyyy, hh:mm a').format(executeAfter);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: const Color(0xFFFF8A80).withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFFF8A80).withValues(alpha: 0.4),
            ),
          ),
          child: const Icon(
            Icons.delete_sweep_outlined,
            color: Color(0xFFFF8A80),
            size: 40,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          pending ? 'Deletion scheduled' : 'No active deletion request',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (pending) ...[
          Text(
            'Deletion scheduled for $dateText.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: _accent,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your data is hidden from the office while the request is pending. '
            'After this time it will be permanently deleted and cannot be undone. '
            'Tap "Cancel deletion" to keep your data.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ] else ...[
          Text(
            'You can request deletion any time from Profile → Delete my data.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ],
        if (_error != null && !pending) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: const Color(0xFFFF8A80),
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 26),
        if (pending)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              key: const Key('cancel_deletion_button'),
              onPressed: _cancelling ? null : _cancelDeletion,
              icon: _cancelling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF082923),
                      ),
                    )
                  : const Icon(Icons.undo_rounded),
              label: Text(
                'Cancel deletion',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: const Color(0xFF082923),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        if (pending) const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: TextButton(
            onPressed: _logOut,
            style: TextButton.styleFrom(foregroundColor: Colors.white60),
            child: Text(
              pending ? 'Log out' : 'Back to start',
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Colors.white60,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        PrivacyPolicyLink(language: 'en', color: Colors.white38, dense: true),
        const SizedBox(height: 6),
        Text(
          'A minimal record without personal details (token number, deletion '
          'date, and proof of consent/withdrawal) is kept after deletion. Data '
          'already submitted to the official RTE portal cannot be deleted by '
          'the Trust.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: Colors.white38,
            fontSize: 10.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'You can cancel within $kDeletionGraceHours hours.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(color: Colors.white30, fontSize: 10.5),
        ),
      ],
    );
  }
}
