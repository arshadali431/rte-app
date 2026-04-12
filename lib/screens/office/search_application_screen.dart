import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../services/firestore_service.dart';
import '../../models/token_model.dart';

class SearchApplicationScreen extends StatefulWidget {
  const SearchApplicationScreen({super.key});

  @override
  State<SearchApplicationScreen> createState() => _SearchApplicationScreenState();
}

class _SearchApplicationScreenState extends State<SearchApplicationScreen> {
  final _searchController = TextEditingController();
  bool _byMobile = true;
  bool _isLoading = false;
  List<TokenModel> _results = [];
  bool _hasSearched = false;
  List<TokenModel> _recentTokens = [];
  bool _recentLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentTokens();
    _searchController.addListener(() {
      if (_searchController.text.isEmpty && _hasSearched) {
        setState(() {
          _hasSearched = false;
          _results = [];
        });
      }
    });
  }

  Future<void> _loadRecentTokens() async {
    try {
      final recent = await FirestoreService().getRecentTokens(5);
      if (mounted) {
        setState(() {
          _recentTokens = recent;
          _recentLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _recentLoading = false);
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      List<TokenModel> results;
      if (_byMobile) {
        results = await FirestoreService().searchByMobile(query);
      } else {
        results = await FirestoreService().searchByName(query);
      }
      
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2B2B),
      appBar: AppBar(
        title: Text('Search Application', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/office/dashboard');
            }
          },
        ),
      ),
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
        child: Column(
          children: [
            // Search Bar Section
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Toggle Buttons
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3535),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        _buildToggleOption('By Mobile', _byMobile, () => setState(() => _byMobile = true)),
                        _buildToggleOption('By Name', !_byMobile, () => setState(() => _byMobile = false)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Search Field
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: _byMobile ? TextInputType.phone : TextInputType.text,
                          maxLength: _byMobile ? 10 : null,
                          inputFormatters: _byMobile ? [FilteringTextInputFormatter.digitsOnly] : [],
                          onSubmitted: (_) => _performSearch(),
                          decoration: InputDecoration(
                            hintText: _byMobile ? 'Enter 10-digit mobile' : 'Enter parent name',
                            counterText: '',
                            hintStyle: const TextStyle(color: Colors.white24),
                            prefixIcon: Icon(_byMobile ? Icons.phone_android_rounded : Icons.person_search_rounded, color: const Color(0xFF81D4FA)),
                            filled: true,
                            fillColor: const Color(0xFF1A3535),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 56,
                        width: 56,
                        child: ElevatedButton(
                          onPressed: _performSearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00796B),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Icon(Icons.search_rounded, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Results Section
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF81D4FA)))
                  : _results.isEmpty
                      ? _hasSearched 
                          ? _buildEmptyState() 
                          : _buildRecentSection()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _results.length,
                          itemBuilder: (context, index) => _buildResultCard(_results[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00796B) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: isSelected ? Colors.white : Colors.white38,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(TokenModel token) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3535),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        onTap: () => context.push('/office/token-detail', extra: token),
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Text(
              'Token #${token.tokenNumber}',
              style: GoogleFonts.outfit(
                color: const Color(0xFF81D4FA),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            _buildStatusChip(token.status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(token.parentName, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone_rounded, size: 14, color: Colors.white38),
                const SizedBox(width: 8),
                Text(token.parentMobile, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14)),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'pending': color = Colors.orange; break;
      case 'in_progress': color = Colors.blue; break;
      case 'completed': color = Colors.green; break;
      default: color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase().replaceAll('_', ' '),
        style: GoogleFonts.outfit(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 64, color: Colors.white12),
          const SizedBox(height: 16),
          Text('No results found', style: GoogleFonts.outfit(color: Colors.white24)),
        ],
      ),
    );
  }

  Widget _buildRecentSection() {
    return _recentLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF81D4FA)))
        : _recentTokens.isEmpty
            ? Center(child: Text('No tokens yet', style: GoogleFonts.outfit(color: Colors.white24)))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.history_rounded, color: Colors.white38, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'RECENTLY ADDED',
                          style: GoogleFonts.outfit(
                            color: Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _recentTokens.length,
                      itemBuilder: (context, index) => _buildResultCard(_recentTokens[index]),
                    ),
                  ),
                ],
              );
  }
}
