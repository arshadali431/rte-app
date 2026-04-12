import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as parser;
import 'package:google_fonts/google_fonts.dart';
import 'models.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Dio dio = Dio();
  final TextEditingController appController = TextEditingController();
  final TextEditingController dobController = TextEditingController();

  bool loading = false;
  String? errorMessage;

  // ── Network Logic (unchanged from original) ──────────────────────────
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
      debugPrint("--- STEP 1: INITIAL GET REQUEST ---");
      const String userAgent =
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

      final getResponse = await dio.get(
        "https://rte.orpgujarat.com/ApplicationFormStatus",
        options: Options(
          headers: {"User-Agent": userAgent},
        ),
      );

      List<String> rawCookies = getResponse.headers["set-cookie"] ?? [];
      String cookieString = rawCookies.map((e) => e.split(";")[0]).join("; ");
      debugPrint("Extracted Cookies: $cookieString");

      // Optimization: Using Regex for token extraction is much faster than parsing the entire DOM
      final tokenMatch = RegExp(
              r'name="__RequestVerificationToken".*?value="([^"]+)"',
              dotAll: true)
          .firstMatch(getResponse.data.toString());

      String? token = tokenMatch?.group(1);
      debugPrint("Extracted Token Found: ${token != null}");

      if (token == null) {
        throw Exception(
          "Could not find verification token. The site structure might have changed.",
        );
      }

      debugPrint("--- STEP 2: POST STATUS CHECK ---");
      debugPrint(
        "Checking Status for: ${appController.text} | DOB: ${dobController.text}",
      );

      final postResponse = await dio.post(
        "https://rte.orpgujarat.com/ApplicationFormStatus",
        data: {
          "__RequestVerificationToken": token,
          "ApplicationNumber": appController.text.trim(),
          "DateOfBirth": dobController.text.trim(),
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            "Accept":
                "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Cookie": cookieString,
            "Origin": "https://rte.orpgujarat.com",
            "Referer": "https://rte.orpgujarat.com/ApplicationFormStatus",
            "User-Agent": userAgent,
          },
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      debugPrint("POST Response Status Code: ${postResponse.statusCode}");
      debugPrint(
        "POST Response Body Length: ${postResponse.data.toString().length}",
      );

      final data = _parseResponseNew(postResponse.data.toString());

      setState(() => loading = false);

      if (mounted) {
        FocusScope.of(context).unfocus();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResultScreen(data: data)),
        );
      }
    } catch (e) {
      setState(() {
        errorMessage =
            "Something went wrong. Check your application number, date of birth, or internet connection.";
        loading = false;
      });
      debugPrint("EXCEPTION CAUGHT: $e");
    }
  }

  RteApplicationData _parseResponseNew(String html) {
    final doc = parser.parse(html);

    // ── 1. Application Number ──────────────────────────────────────────
    String appNum = appController.text.trim();
    final cardHeader = doc.querySelector('.card-header');
    if (cardHeader != null) {
      final match = RegExp(
        r'(?:for\s+)([A-Z0-9/\-]+)',
      ).firstMatch(cardHeader.text);
      if (match != null) appNum = match.group(1)!.trim();
    }

    // ── 2. Status Message ──────────────────────────────────────────────
    String statusMsg = '';
    final allFieldsets = doc.querySelectorAll('fieldset');
    for (final fs in allFieldsets) {
      final legend = fs.querySelector('legend');
      if (legend != null && legend.text.trim().contains('અરજીની સ્થિતિ')) {
        final p = fs.querySelector('p');
        statusMsg = p != null
            ? p.text.trim()
            : fs.text.replaceAll(legend.text, '').trim();
        break;
      }
    }
    if (statusMsg.isEmpty) statusMsg = 'No status information found.';

    // ── 3. Sections ────────────────────────────────────────────────────
    Map<String, Map<String, String>> sections = {};
    const tableFieldsets = {'Selected Schools', 'Uploaded Documents'};
    const skipLegendContains = 'અરજીની સ્થિતિ';

    for (final fs in allFieldsets) {
      final legend = fs.querySelector('legend');
      if (legend == null) continue;
      final sectionTitle = legend.text.trim();
      if (sectionTitle.contains(skipLegendContains)) continue;
      if (tableFieldsets.contains(sectionTitle)) continue;

      Map<String, String> sectionData = {};
      for (final dl in fs.querySelectorAll('dl.row')) {
        final children = dl.children
            .where((el) => el.localName == 'dt' || el.localName == 'dd')
            .toList();
        for (var i = 0; i < children.length - 1; i++) {
          if (children[i].localName == 'dt' &&
              children[i + 1].localName == 'dd') {
            final key = children[i].text
                .trim()
                .replaceAll(':', '')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
            final value = children[i + 1].text
                .trim()
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
            if (key.isNotEmpty) sectionData[key] = value;
          }
        }
      }
      if (sectionData.isNotEmpty) sections[sectionTitle] = sectionData;
    }

    // ── 4. Schools Table ───────────────────────────────────────────────
    List<List<String>> schools = [];
    for (final fs in allFieldsets) {
      final legend = fs.querySelector('legend');
      if (legend != null && legend.text.trim() == 'Selected Schools') {
        final table = fs.querySelector('table');
        if (table != null) {
          for (final row in table.querySelectorAll('tr')) {
            final rowData = row
                .querySelectorAll('th, td')
                .map((c) => c.text.trim().replaceAll(RegExp(r'\s+'), ' '))
                .toList();
            if (rowData.any((c) => c.isNotEmpty)) schools.add(rowData);
          }
        }
        break;
      }
    }

    // ── 5. Documents Table ─────────────────────────────────────────────
    List<List<String>> documents = [];
    for (final fs in allFieldsets) {
      final legend = fs.querySelector('legend');
      if (legend != null && legend.text.trim() == 'Uploaded Documents') {
        final table = fs.querySelector('table');
        if (table != null) {
          for (final row in table.querySelectorAll('tr')) {
            final rowData = row.querySelectorAll('th, td').map((c) {
              final anchor = c.querySelector('a');
              if (anchor != null) {
                final href = anchor.attributes['href'] ?? '';
                if (href.isEmpty) return '';
                return href.startsWith('http')
                    ? href
                    : 'https://rte.orpgujarat.com$href';
              }
              return c.text.trim().replaceAll(RegExp(r'\s+'), ' ');
            }).toList();
            if (rowData.any((c) => c.isNotEmpty)) documents.add(rowData);
          }
        }
        break;
      }
    }

    debugPrint(
      '✅ Parsed: appNum=$appNum | status=${statusMsg.substring(0, statusMsg.length.clamp(0, 40))} | sections=${sections.keys.toList()} | schools=${schools.length} | docs=${documents.length}',
    );

    return RteApplicationData(
      applicationNumber: appNum,
      statusMessage: statusMsg,
      sections: sections,
      schools: schools,
      documents: documents,
    );
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D2B2B), // very dark teal
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
                // ── Icon ──────────────────────────────────────────
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),

                // ── App Name ──────────────────────────────────────
                Text(
                  'RTE Status Checker',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Credentials Card ──────────────────────────────
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

                      // Application Number
                      _buildDarkTextField(
                        controller: appController,
                        label: "Application Number",
                        hint: "GJ/2026-27/SRC/1234567",
                        icon: Icons.tag_rounded,
                      ),
                      const SizedBox(height: 16),

                      // Date of Birth
                      _buildDarkTextField(
                        controller: dobController,
                        label: "Date of Birth",
                        icon: Icons.calendar_today_outlined,
                        hint: "DD-MM-YYYY",
                        keyboardType: TextInputType.datetime,
                        inputFormatters: [DateInputFormatter()],
                      ),
                      const SizedBox(height: 25),

                      // Button / Loader
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

                      // Error
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

                // ── Footer Note (Gujarati) ──────────────────────
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
                      // const SizedBox(height: 16),
                      // Text(
                      //   "જો તમને સ્થિતિ અંગે કોઈ પ્રશ્ન હોય, તો સંપર્ક કરો:",
                      //   textAlign: TextAlign.center,
                      //   style: GoogleFonts.notoSansGujarati(
                      //     fontSize: 14,
                      //     color: Colors.white70,
                      //     fontWeight: FontWeight.w500,
                      //   ),
                      // ),
                      // const SizedBox(height: 12),
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.center,
                      //   children: [
                      //     const Icon(
                      //       Icons.phone_rounded,
                      //       size: 16,
                      //       color: Color(0xFF81D4FA),
                      //     ),
                      //     const SizedBox(width: 8),
                      //     Text(
                      //       "૭૮૬૫૦૦૯૨૦૦, ૭૮૬૫૦૦૭૨૦૦",
                      //       style: GoogleFonts.outfit(
                      //         fontSize: 15,
                      //         color: const Color(0xFF81D4FA),
                      //         fontWeight: FontWeight.bold,
                      //       ),
                      //     ),
                      //   ],
                      // ),
                      // const SizedBox(height: 4),
                      // Text(
                      //   "૭૮૬૪૦૦૭૨૦૦",
                      //   style: GoogleFonts.outfit(
                      //     fontSize: 15,
                      //     color: const Color(0xFF81D4FA),
                      //     fontWeight: FontWeight.bold,
                      //   ),
                      // ),
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

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    String text = newValue.text.replaceAll('-', '');
    String formatted = "";

    for (int i = 0; i < text.length; i++) {
      formatted += text[i];
      if (i == 1 || i == 3) {
        if (formatted.length < 10) formatted += "-";
      }
      if (formatted.length >= 10) break;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
