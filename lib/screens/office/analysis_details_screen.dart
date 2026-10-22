import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/token_model.dart';
import '../../services/firestore_service.dart';

class AnalysisDetailsScreen extends StatefulWidget {
  final String category;

  const AnalysisDetailsScreen({
    super.key,
    required this.category,
  });

  @override
  State<AnalysisDetailsScreen> createState() => _AnalysisDetailsScreenState();
}

class _AnalysisDetailsScreenState extends State<AnalysisDetailsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final int _pageSize = 20;

  // For ALL GENERATED → server-side cursor pagination
  List<TokenModel> _tokens = [];          // Current page tokens
  List<DocumentSnapshot?> _pageHistory = [null]; // Cursors per page

  // For specific categories → client-side pagination (fetch-all once)
  List<TokenModel> _allTokens = [];       // Full list (only for categories)
  bool _isClientSide = false;             // Whether we're in client-side mode

  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  int _totalCount = 0;
  int _currentPage = 1;
  StreamSubscription? _metaSubscription;

  bool get _isAllGenerated => widget.category == 'All Generated';
  int get _totalPages => (_totalCount / _pageSize).ceil().clamp(1, 9999).toInt();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _startMetaListener();
  }

  void _startMetaListener() {
    _metaSubscription = FirebaseFirestore.instance
        .collection('meta')
        .doc('token_counter')
        .snapshots()
        .listen((_) {
      if (mounted && !_isLoading) {
        _loadInitialData();
      }
    });
  }

  @override
  void dispose() {
    _metaSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() { _isLoading = true; _hasError = false; });

    try {
      if (_isAllGenerated) {
        // ── Server-side pagination ─────────────────────────────────────
        _isClientSide = false;
        final counts = await _firestoreService.getTokenCounts();
        _totalCount = counts['total'] ?? 0;
        await _fetchServerPage(1);
      } else {
        // ── Client-side: fetch ALL once, paginate in memory ────────────
        _isClientSide = true;
        final snapshot = await _firestoreService.getTokensPaginated(
          limit: 200,       // Safer memory limit — categories have < 200 records
          category: widget.category,
          startAfter: null,
        );
        _allTokens = snapshot.docs
            .map((d) => TokenModel.fromFirestore(d.data(), d.id))
            .toList();
        _totalCount = _allTokens.length;
        _setClientPage(1);
      }
    } catch (e) {
      debugPrint('AnalysisDetails error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  // ── Client-side page switch (instant, no network) ────────────────────
  void _setClientPage(int page) {
    if (!mounted) return;
    final start = (page - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, _allTokens.length).toInt();
    setState(() {
      _tokens = _allTokens.sublist(start, end);
      _currentPage = page;
      _isLoading = false;
    });
  }

  // ── Server-side page fetch (only for All Generated) ──────────────────
  Future<void> _fetchServerPage(int page) async {
    if (!mounted) return;
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final snapshot = await _firestoreService.getTokensPaginated(
        limit: _pageSize,
        category: null,  // All Generated = no filter
        startAfter: _pageHistory[page - 1],
      );
      final newTokens = snapshot.docs
          .map((d) => TokenModel.fromFirestore(d.data(), d.id))
          .toList();

      if (!mounted) return;
      setState(() {
        _tokens = newTokens;
        _currentPage = page;
        _isLoading = false;
        if (newTokens.length == _pageSize && _pageHistory.length <= page) {
          _pageHistory.add(snapshot.docs.last);
        }
      });
    } catch (e) {
      debugPrint('Server page error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  // ── Unified page navigation ───────────────────────────────────────────
  void _fetchPage(int page) {
    if (_isClientSide) {
      _setClientPage(page);
    } else {
      _fetchServerPage(page);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF4DB6AC);

    return Scaffold(
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
        child: SafeArea(
          child: Column(
            children: [
              // Compact page header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(context),
                        child: const SizedBox(
                          width: 42,
                          height: 42,
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${widget.category} Applications',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTotalCounter(),
                  ],
                ),
              ),

              // Results table and pagination
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFF102F2B).withOpacity(0.78),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: _isLoading
                            ? const Center(
                          child: CircularProgressIndicator(
                            color: accent,
                            strokeWidth: 2.5,
                          ),
                        )
                            : RefreshIndicator(
                          onRefresh: _loadInitialData,
                          color: accent,
                          backgroundColor: const Color(0xFF102F2B),
                          child: _hasError
                              ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: 300,
                                child: _buildErrorState(),
                              ),
                            ],
                          )
                              : _tokens.isEmpty
                              ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: 300,
                                child: _buildEmptyState(),
                              ),
                            ],
                          )
                              : SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  dividerColor: Colors.white.withOpacity(0.07),
                                ),
                                child: DataTable(
                                  showCheckboxColumn: false,
                                  horizontalMargin: 18,
                                  columnSpacing: 26,
                                  headingRowHeight: 48,
                                  dataRowMinHeight: 54,
                                  dataRowMaxHeight: 72,
                                  headingRowColor: WidgetStatePropertyAll(
                                    Colors.white.withOpacity(0.035),
                                  ),
                                  headingTextStyle: GoogleFonts.outfit(
                                    color: accent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    letterSpacing: 0.4,
                                  ),
                                  dataTextStyle: GoogleFonts.outfit(
                                    color: Colors.white.withOpacity(0.88),
                                    fontSize: 13,
                                  ),
                                  columns: const [
                                    DataColumn(label: Text('TOKEN')),
                                    DataColumn(label: Text('PARENT NAME')),
                                    DataColumn(label: Text('CHILD NAME')),
                                    DataColumn(label: Text('APPLICATION ID')),
                                    DataColumn(label: Text('DOB')),
                                    DataColumn(label: Text('GOV MOBILE')),
                                    DataColumn(label: Text('STATUS')),
                                    DataColumn(label: Text('SYNC DATE')),
                                  ],
                                  rows: _tokens
                                      .map((token) => _buildDataRow(token))
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!_isLoading && !_hasError && _tokens.isNotEmpty)
                        _buildProfessionalPagination(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: Colors.white.withOpacity(0.35),
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load applications',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white.withOpacity(0.58),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadInitialData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4DB6AC),
                side: BorderSide(color: const Color(0xFF4DB6AC).withOpacity(0.45)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF4DB6AC).withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF4DB6AC).withOpacity(0.22)),
      ),
      child: Text(
        '$_totalCount Total',
        style: GoogleFonts.outfit(
          color: const Color(0xFF4DB6AC),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProfessionalPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();

    final canPrev = _currentPage > 1;
    final canNext = _isClientSide
        ? _currentPage < _totalPages
        : _currentPage < _totalPages && _pageHistory.length > _currentPage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          // ← Prev
          TextButton.icon(
            onPressed: canPrev ? () => _fetchPage(_currentPage - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            label: const Text('Prev', style: TextStyle(fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              foregroundColor: canPrev ? const Color(0xFF4DB6AC) : Colors.white12,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _buildPageNumbers(),
              ),
            ),
          ),

          // Next →
          TextButton.icon(
            onPressed: canNext ? () => _fetchPage(_currentPage + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            label: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
            iconAlignment: IconAlignment.end,
            style: TextButton.styleFrom(
              foregroundColor: canNext ? const Color(0xFF4DB6AC) : Colors.white12,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> widgets = [];
    int start = _currentPage - 1;
    if (start < 1) start = 1;

    int end = start + 2;
    if (end > _totalPages) end = _totalPages;
    if (end - start < 2 && start > 1) {
      start = (end - 2).clamp(1, _totalPages).toInt();
    }

    // Always show Page 1 if not in range
    if (start > 1) {
      widgets.add(_buildNumButton(1, _currentPage == 1));
      if (start > 2) widgets.add(_buildEllipsis());
    }

    for (int i = start; i <= end; i++) {
      widgets.add(_buildNumButton(i, _currentPage == i));
    }

    // Show Last Page if not in range
    if (end < _totalPages) {
      if (end < _totalPages - 1) widgets.add(_buildEllipsis());
      widgets.add(_buildNumButton(_totalPages, _currentPage == _totalPages));
    }

    return widgets;
  }

  Widget _buildNumButton(int page, bool isSelected) {
    final bool canJump = _isClientSide
        ? page <= _totalPages
        : page <= _pageHistory.length;

    return GestureDetector(
      onTap: (canJump && !isSelected) ? () => _fetchPage(page) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00796B) : Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
          border: isSelected ? null : Border.all(color: Colors.white.withOpacity(0.01)),
        ),
        child: Center(
          child: Text(
            '$page',
            style: GoogleFonts.outfit(
              color: isSelected ? Colors.white : (canJump ? Colors.white70 : Colors.white12),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEllipsis() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text('...', style: TextStyle(color: Colors.white24)),
    );
  }

  Widget _buildActionButton({required String label, required bool enabled, required VoidCallback onTap}) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.2,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildDataRow(TokenModel token) {
    final bool hasHistory = token.applicationHistory.isNotEmpty;
    final bool isNoStatus = token.govStatusMessage?.contains('No status information found') ?? false;

    final Color statusColor = isNoStatus
        ? Colors.white24
        : token.govStatus == 'APPROVED'
        ? const Color(0xFF69F0AE)
        : token.govStatus == 'SUBMITTED'
        ? const Color(0xFF90CAF9)   // light blue
        : token.govStatus == 'CANCELLED'
        ? const Color(0xFFFF5252)
        : token.govStatus == 'PENDING'
        ? const Color(0xFFFFD54F)
        : Colors.white38;

    return DataRow(
      onSelectChanged: (_) => context.push('/office/token-detail', extra: token),
      cells: [
        DataCell(Text('#${token.tokenNumber}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4DB6AC)))),
        DataCell(Text(token.parentName, style: const TextStyle(fontWeight: FontWeight.w600))),
        // ── Child Name ───────────────────────────────────────────────
        DataCell(
          token.govChildName != null
              ? Text(
            token.govChildName!,
            style: GoogleFonts.notoSansGujarati(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
          )
              : Text(
            '—',
            style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
          ),
        ),
        DataCell(Text(token.applicationId ?? 'N/A', style: TextStyle(color: Colors.white.withOpacity(0.5)))),
        DataCell(Text(token.childDob ?? 'N/A', style: TextStyle(color: Colors.white.withOpacity(0.5)))),
        DataCell(Text(token.govParentMobile ?? '—', style: TextStyle(color: Colors.white.withOpacity(0.5)))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (hasHistory ? const Color(0xFF64B5F6) : statusColor).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (hasHistory ? const Color(0xFF64B5F6) : statusColor).withOpacity(0.15)),
            ),
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  if (hasHistory)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: Color(0xFF64B5F6), shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  TextSpan(
                    text: token.govStatusMessage ?? (token.govStatus ?? 'PENDING'),
                    style: GoogleFonts.notoSansGujarati(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: hasHistory ? const Color(0xFF64B5F6) : statusColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            token.lastSyncAt != null
                ? DateFormat('dd/MM HH:mm').format(token.lastSyncAt!)
                : 'Never',
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_late_rounded, size: 64, color: Colors.white10),
          const SizedBox(height: 16),
          Text(
            'No records found for this category',
            style: GoogleFonts.outfit(color: Colors.white24),
          ),
        ],
      ),
    );
  }
}
