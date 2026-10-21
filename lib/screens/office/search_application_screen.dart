import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/token_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/no_internet_banner.dart';

class _SearchFieldConfig {
  const _SearchFieldConfig({
    required this.hint,
    required this.icon,
    required this.keyboard,
    required this.digits,
    required this.maxLen,
  });

  final String hint;
  final IconData icon;
  final TextInputType keyboard;
  final bool digits;
  final int maxLen;
}

class SearchApplicationScreen extends StatefulWidget {
  const SearchApplicationScreen({super.key});

  @override
  State<SearchApplicationScreen> createState() =>
      _SearchApplicationScreenState();
}

class _SearchApplicationScreenState extends State<SearchApplicationScreen> {
  static const Color _accent = Color(0xFF4DB6AC);
  static const Color _background = Color(0xFF082923);

  final TextEditingController _searchController = TextEditingController();

  // Search modes: mobile, name, token, appId.
  String _searchMode = 'mobile';

  bool _isLoading = false;
  bool _hasSearched = false;
  bool _recentLoading = true;

  List<TokenModel> _results = [];
  List<TokenModel> _recentTokens = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchTextChanged);
    _loadRecentTokens();
  }

  void _handleSearchTextChanged() {
    if (!mounted) return;

    if (_searchController.text.isEmpty && _hasSearched && !_isLoading) {
      setState(() {
        _hasSearched = false;
        _results = [];
      });
    }
  }

  Future<void> _loadRecentTokens() async {
    try {
      final recent = await FirestoreService().getRecentTokens(5);
      if (!mounted) return;

      setState(() {
        _recentTokens = recent;
        _recentLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load recent tokens: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      setState(() => _recentLoading = false);
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      _showMessage('Enter a value to search.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _results = [];
    });

    try {
      List<TokenModel> results = [];

      switch (_searchMode) {
        case 'mobile':
          results = await FirestoreService().searchByMobile(query);
          break;
        case 'name':
          results = await FirestoreService().searchByName(query);
          break;
        case 'token':
          final tokenNumber = int.tryParse(query);
          if (tokenNumber != null) {
            final token = await FirestoreService().searchByTokenNumber(
              tokenNumber,
            );
            if (token != null) results = [token];
          }
          break;
        case 'appId':
          results = await FirestoreService().searchByApplicationId(query);
          break;
      }

      if (!mounted) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Application search failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Unable to search right now. Please try again.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.outfit(fontSize: 14),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF203C37),
          showCloseIcon: true,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const fieldConfig = <String, _SearchFieldConfig>{
      'mobile': _SearchFieldConfig(
        hint: 'Enter 10-digit mobile number',
        icon: Icons.phone_android_rounded,
        keyboard: TextInputType.phone,
        digits: true,
        maxLen: 10,
      ),
      'name': _SearchFieldConfig(
        hint: 'Enter parent name',
        icon: Icons.person_search_rounded,
        keyboard: TextInputType.text,
        digits: false,
        maxLen: 60,
      ),
      'token': _SearchFieldConfig(
        hint: 'Enter token number (e.g. 53)',
        icon: Icons.confirmation_number_rounded,
        keyboard: TextInputType.number,
        digits: true,
        maxLen: 10,
      ),
      'appId': _SearchFieldConfig(
        hint: 'Enter Application ID',
        icon: Icons.badge_rounded,
        keyboard: TextInputType.text,
        digits: false,
        maxLen: 40,
      ),
    };

    final cfg = fieldConfig[_searchMode] ?? fieldConfig['mobile']!;

    return Scaffold(
      backgroundColor: _background,
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
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              const SliverToBoxAdapter(child: NoInternetBanner()),
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(child: _buildSearchControls(cfg)),

              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _accent,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              else if (_results.isNotEmpty) ...[
                SliverToBoxAdapter(child: _buildResultsHeading()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildResultCard(_results[index]),
                      childCount: _results.length,
                    ),
                  ),
                ),
              ] else if (_hasSearched)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else ...[
                  SliverToBoxAdapter(child: _buildRecentHeading()),
                  if (_recentLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _accent,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  else if (_recentTokens.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildNoRecentState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                              _buildResultCard(_recentTokens[index]),
                          childCount: _recentTokens.length,
                        ),
                      ),
                    ),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      child: Row(
        children: [
          Material(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/office/dashboard');
                }
              },
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search Application',
                  style: GoogleFonts.outfit(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Find an application quickly',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.62),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchControls(_SearchFieldConfig cfg) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SEARCH BY',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.white.withOpacity(0.58),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.13),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildModeToggle(
                      'By Mobile',
                      'mobile',
                      Icons.phone_android_rounded,
                    ),
                    _buildModeToggle(
                      'By Name',
                      'name',
                      Icons.person_outline_rounded,
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildModeToggle(
                      'Token No.',
                      'token',
                      Icons.confirmation_number_outlined,
                    ),
                    _buildModeToggle(
                      'App ID',
                      'appId',
                      Icons.badge_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            readOnly: _isLoading,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 15,
            ),
            keyboardType: cfg.keyboard,
            maxLength: cfg.maxLen,
            textInputAction: TextInputAction.search,
            inputFormatters: cfg.digits
                ? [FilteringTextInputFormatter.digitsOnly]
                : [],
            onSubmitted: (_) => _performSearch(),
            decoration: InputDecoration(
              hintText: cfg.hint,
              counterText: '',
              hintStyle: GoogleFonts.outfit(
                color: Colors.white.withOpacity(0.42),
                fontSize: 13,
              ),
              prefixIcon: Icon(cfg.icon, color: _accent, size: 21),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, child) {
                  if (value.text.isEmpty) return const SizedBox.shrink();

                  return IconButton(
                    tooltip: 'Clear search',
                    onPressed: _isLoading ? null : _searchController.clear,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 19,
                      color: Colors.white.withOpacity(0.65),
                    ),
                  );
                },
              ),
              filled: true,
              fillColor: const Color(0xFF102F2B),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 17,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.09),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.09),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _accent, width: 1.3),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _performSearch,
              icon: const Icon(Icons.search_rounded, size: 21),
              label: Text(
                'Search Application',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _background,
                disabledBackgroundColor: _accent.withOpacity(0.45),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle(String label, String mode, IconData icon) {
    final isSelected = _searchMode == mode;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: isSelected ? _accent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _isLoading
                ? null
                : () {
              if (_searchMode == mode) return;

              FocusScope.of(context).unfocus();
              setState(() {
                _searchMode = mode;
                _results = [];
                _hasSearched = false;
              });
              _searchController.clear();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 11,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: isSelected
                        ? _accent
                        : Colors.white.withOpacity(0.65),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsHeading() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Text(
            'Search Results',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Text(
            '${_results.length} found',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentHeading() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Icon(
            Icons.history_rounded,
            color: Colors.white.withOpacity(0.55),
            size: 17,
          ),
          const SizedBox(width: 8),
          Text(
            'RECENTLY ADDED',
            style: GoogleFonts.outfit(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(TokenModel token) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.09),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/office/token-detail', extra: token),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 17,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Token #${token.tokenNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: _accent,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildStatusChip(token.status),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  token.parentName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(
                      Icons.phone_iphone_rounded,
                      size: 15,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        token.parentMobile,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: Colors.white.withOpacity(0.45),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final normalizedStatus = status.toLowerCase();

    final Color color = switch (normalizedStatus) {
      'pending' => const Color(0xFFFFB74D),
      'in_progress' => const Color(0xFF64B5F6),
      'completed' => const Color(0xFF81C784),
      _ => Colors.white70,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status.toUpperCase().replaceAll('_', ' '),
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 44,
              color: Colors.white.withOpacity(0.35),
            ),
            const SizedBox(height: 14),
            Text(
              'No applications found',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try another search term or search method.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white.withOpacity(0.58),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRecentState() {
    return Center(
      child: Text(
        'No recent applications',
        style: GoogleFonts.outfit(
          color: Colors.white.withOpacity(0.58),
          fontSize: 14,
        ),
      ),
    );
  }
}
