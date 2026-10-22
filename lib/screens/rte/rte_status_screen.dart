import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils.dart';
import '../../services/rte_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/no_internet_banner.dart';
import 'rte_result_screen.dart';

class RteStatusScreen extends StatefulWidget {
  const RteStatusScreen({super.key});

  @override
  State<RteStatusScreen> createState() => _RteStatusScreenState();
}

class _RteStatusScreenState extends State<RteStatusScreen> {
  final TextEditingController appController =
  TextEditingController(text: 'GJ/2026-27/SRC/');
  final TextEditingController dobController = TextEditingController();

  bool loading = false;
  String? errorMessage;
  List<Map<String, String>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyJson = prefs.getString('rte_check_history');
      if (historyJson == null || !mounted) return;

      final decoded = json.decode(historyJson) as List<dynamic>;
      final history = decoded
          .map((item) => Map<String, String>.from(item as Map))
          .toList();

      if (mounted) setState(() => _history = history);
    } catch (e) {
      debugPrint('Unable to load RTE check history: $e');
    }
  }

  Future<void> _saveToHistory(String appNum, String dob) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final String time = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    // Remove if already exists to move to top
    _history.removeWhere((item) => item['appNum'] == appNum);

    _history.insert(0, {
      'appNum': appNum,
      'dob': dob,
      'time': time,
    });

    // Keep last 10
    if (_history.length > 10) _history.removeLast();

    await prefs.setString('rte_check_history', json.encode(_history));
    if (mounted) setState(() {});
  }

  Future<void> _removeFromHistory(int index) async {
    if (index < 0 || index >= _history.length) return;
    final prefs = await SharedPreferences.getInstance();
    _history.removeAt(index);
    await prefs.setString('rte_check_history', json.encode(_history));
    if (mounted) setState(() {});
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A3535),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Checks',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (_history.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('rte_check_history');
                        setState(() => _history = []);
                        setModalState(() {});
                        if (mounted) Navigator.pop(context);
                      },
                      child: Text('Clear All', style: TextStyle(color: Colors.redAccent.withOpacity(0.7))),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_history.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.history_rounded, color: Colors.white12, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'No check history yet',
                          style: GoogleFonts.outfit(color: Colors.white24),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: ListTile(
                          onTap: () {
                            setState(() {
                              appController.text = item['appNum']!;
                              dobController.text = item['dob']!;
                            });
                            Navigator.pop(context);
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.tag_rounded, color: Colors.blue[300], size: 20),
                          ),
                          title: Text(
                            item['appNum']!,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'DOB: ${item['dob']} • at ${item['time']}',
                            style: GoogleFonts.outfit(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.close_rounded, color: Colors.white24, size: 18),
                            onPressed: () async {
                              await _removeFromHistory(index);
                              setModalState(() {});
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> fetchStatus() async {
    FocusScope.of(context).unfocus();
    if (appController.text.trim().isEmpty || dobController.text.trim().isEmpty) {
      _showSnackbar('Please fill all fields');
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final appNumber = appController.text.trim();
      final dob = dobController.text.trim();
      final data = await RteService().fetchApplicationStatus(appNumber, dob);

      if (!mounted) return;
      setState(() => loading = false);
      await _saveToHistory(appNumber, dob);
      if (!mounted) return;

      FocusScope.of(context).unfocus();
      await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              RteResultScreen(data: data),
          transitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
              child: child,
            );
          },
        ),
      );

      if (mounted) {
        setState(() {
          appController.text = 'GJ/2026-27/SRC/';
          dobController.clear();
        });
        FocusScope.of(context).unfocus();
      }
    } catch (e, stackTrace) {
      debugPrint('RTE status check failed: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          errorMessage = 'Something went wrong. Check details or connection.';
          loading = false;
        });
      }
    }
  }


  @override
  void dispose() {
    appController.dispose();
    dobController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
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
              NoInternetBanner(),

              // Compact page header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 14, 16),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(context).maybePop(),
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
                            'Status Checker',
                            style: GoogleFonts.outfit(
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Check your RTE application',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.62),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _showHistory,
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(
                            Icons.history_rounded,
                            color: Colors.white,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.045),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.09),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Application details',
                              style: GoogleFonts.outfit(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Enter your application number and date of birth.',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.62),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 22),
                            _buildDarkTextField(
                              controller: appController,
                              label: 'Application Number',
                              hint: 'GJ/2026-27/SRC/...',
                              icon: Icons.tag_rounded,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 16),
                            _buildDarkTextField(
                              controller: dobController,
                              label: 'Date of Birth',
                              icon: Icons.calendar_today_outlined,
                              hint: 'DD-MM-YYYY',
                              keyboardType: TextInputType.datetime,
                              inputFormatters: [DateInputFormatter()],
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) {
                                if (!loading) fetchStatus();
                              },
                            ),
                            if (errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B6B).withOpacity(0.09),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFFF6B6B).withOpacity(0.25),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: Color(0xFFFF8A80),
                                      size: 19,
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        errorMessage!,
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFFFFB4AB),
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: loading ? null : fetchStatus,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: const Color(0xFF082923),
                                  disabledBackgroundColor:
                                  accent.withOpacity(0.45),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                                child: loading
                                    ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Color(0xFF082923),
                                  ),
                                )
                                    : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.search_rounded, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Check Status',
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.white.withOpacity(0.55),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'આ એપ્લિકેશન ફક્ત અરજીની સ્થિતિ તપાસવાના હેતુ માટે જ છે, અન્ય કોઈપણ હેતુ માટે ઉપયોગમાં લેવામાં આવી નથી.',
                                style: GoogleFonts.notoSansGujarati(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.62),
                                  height: 1.55,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildDarkTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    const accent = Color(0xFF4DB6AC);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: Colors.white.withOpacity(0.78),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
              color: Colors.white.withOpacity(0.4),
              fontSize: 13,
            ),
            prefixIcon: Icon(
              icon,
              color: accent,
              size: 20,
            ),
            filled: true,
            fillColor: const Color(0xFF102F2B),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 15,
              horizontal: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.09),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.09),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(
                color: accent,
                width: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }

}
