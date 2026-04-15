import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils.dart';
import '../../services/rte_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models.dart';
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
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString('rte_check_history');
    if (historyJson != null) {
      setState(() {
        _history = List<Map<String, String>>.from(
          json.decode(historyJson).map((item) => Map<String, String>.from(item)),
        );
      });
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
    setState(() {});
  }

  Future<void> _removeFromHistory(int index) async {
    final prefs = await SharedPreferences.getInstance();
    _history.removeAt(index);
    await prefs.setString('rte_check_history', json.encode(_history));
    setState(() {});
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
    if (appController.text.isEmpty || dobController.text.isEmpty) {
      _showSnackbar("Please fill all fields");
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final data = await RteService().fetchApplicationStatus(
        appController.text.trim(),
        dobController.text.trim(),
      );

      setState(() => loading = false);

      if (mounted) {
        _saveToHistory(appController.text.trim(), dobController.text.trim());
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
      }
    } catch (e) {
      setState(() {
        errorMessage = "Something went wrong. Check details or connection.";
        loading = false;
      });
    }
  }


  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('RTE Status Checker',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D2B2B),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            onPressed: _showHistory,
            icon: const Icon(Icons.history_rounded, color: Colors.white70),
            tooltip: 'Recent Checks',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D2B2B),
              Color(0xFF122929),
              Color(0xFF0A1A1A),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 10, 28, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3535),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white.withOpacity(0.07)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Application Credentials",
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Enter your details to track application status",
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildDarkTextField(
                        controller: appController,
                        label: "Application Number",
                        hint: "GJ/2026-27/SRC/1234567",
                        icon: Icons.tag_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildDarkTextField(
                        controller: dobController,
                        label: "Date of Birth",
                        icon: Icons.calendar_today_outlined,
                        hint: "DD-MM-YYYY",
                        keyboardType: TextInputType.datetime,
                        inputFormatters: [DateInputFormatter()],
                      ),
                      const SizedBox(height: 25),
                      if (loading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: CircularProgressIndicator(
                              color: Color(0xFF81D4FA),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 58,
                          child: ElevatedButton(
                            onPressed: fetchStatus,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF81D4FA),
                              foregroundColor: const Color(0xFF0A1A1A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              "Check Status",
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "આ એપ્લિકેશન ફક્ત અરજીની સ્થિતિ તપાસવાના હેતુ માટે જ છે, અન્ય કોઈપણ હેતુ માટે ઉપયોગમાં લેવામાં આવી નથી.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSansGujarati(
                          fontSize: 14,
                          color: Colors.white60,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
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
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2E5050), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF81D4FA), width: 1.8),
        ),
        filled: true,
        fillColor: const Color(0xFF122929),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 16,
        ),
      ),
    );
  }
}
