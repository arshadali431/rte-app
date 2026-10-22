import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/consent_service.dart';
import '../../widgets/no_internet_banner.dart';

// ---------------------------------------------------------------------------
// Language constants
// ---------------------------------------------------------------------------

enum _Lang { en, hi, gu }

extension _LangExt on _Lang {
  String get label {
    switch (this) {
      case _Lang.en: return 'English';
      case _Lang.hi: return 'हिन्दी';
      case _Lang.gu: return 'ગુજરાતી';
    }
  }

  String get assetPath {
    switch (this) {
      case _Lang.en: return 'assets/legal/consent_v1_en.md';
      case _Lang.hi: return 'assets/legal/consent_v1_hi.md';
      case _Lang.gu: return 'assets/legal/consent_v1_gu.md';
    }
  }

  String get locale {
    switch (this) {
      case _Lang.en: return 'en';
      case _Lang.hi: return 'hi';
      case _Lang.gu: return 'gu';
    }
  }

  /// Labels for UI strings in the selected language
  String get agreeLabel {
    switch (this) {
      case _Lang.en: return 'I Agree';
      case _Lang.hi: return 'मैं सहमत हूँ';
      case _Lang.gu: return 'હું સંમત છું';
    }
  }

  String get disagreeLabel {
    switch (this) {
      case _Lang.en: return 'I Do Not Agree';
      case _Lang.hi: return 'मैं सहमत नहीं हूँ';
      case _Lang.gu: return 'હું સંમત નથી';
    }
  }

  String get scrollHint {
    switch (this) {
      case _Lang.en: return 'Please scroll to the end to enable the agree button.';
      case _Lang.hi: return 'सहमत बटन सक्षम करने के लिए कृपया अंत तक स्क्रॉल करें।';
      case _Lang.gu: return 'સંમત બટન સક્ષમ કરવા માટે કૃપા કરી અંત સુધી સ્ક્રૉલ કરો.';
    }
  }

  String get holdHint {
    switch (this) {
      case _Lang.en: return 'Press and hold for 5 seconds to confirm your consent.';
      case _Lang.hi: return 'सहमति की पुष्टि करने के लिए 5 सेकंड तक दबाए रखें।';
      case _Lang.gu: return 'તમારી સંમતિ નિશ્ચિત કરવા 5 સેકન્ડ સુધી દબાઈ રાખો.';
    }
  }

  String get disagreeMessage {
    switch (this) {
      case _Lang.en: return 'You can apply directly on the official RTE portal.';
      case _Lang.hi: return 'आप सीधे आधिकारिक आरटीई पोर्टल पर आवेदन कर सकते हैं।';
      case _Lang.gu: return 'તમે સીધા સત્તાવાર RTE પોર્ટલ પર અરજી કરી શકો છો.';
    }
  }

  String get loadingError {
    switch (this) {
      case _Lang.en: return 'Could not load consent text. Check your connection.';
      case _Lang.hi: return 'सहमति पाठ लोड नहीं हो सका। अपना कनेक्शन जाँचें।';
      case _Lang.gu: return 'સંમતિ ટેક્સ્ट લોડ ન થઈ. તમારું કનેક્શન તપાસો.';
    }
  }

  String get savingError {
    switch (this) {
      case _Lang.en: return 'Could not save your consent. Please try again.';
      case _Lang.hi: return 'आपकी सहमति सहेजी नहीं जा सकी। कृपया पुनः प्रयास करें।';
      case _Lang.gu: return 'તમારી સંમતિ સાચવી ન શકાઈ. કૃપા કરી ફરી પ્રયાસ કરો.';
    }
  }

  String get title {
    switch (this) {
      case _Lang.en: return 'Consent & Notice';
      case _Lang.hi: return 'सहमति और सूचना';
      case _Lang.gu: return 'સંમતિ અને નોટિસ';
    }
  }
}

// ---------------------------------------------------------------------------
// Main screen widget
// ---------------------------------------------------------------------------

/// Parent consent screen (DPDP / RTE Token service).
///
/// TODO(auth-migration): [subjectId] is currently derived from the parent's
/// token number + mobile stored in SharedPreferences, because this app has no
/// Firebase Auth yet. When Firebase Auth is introduced, replace the subjectId
/// with the Firebase Auth uid without changing the consent_records schema —
/// the `subjectId` field is designed to be migrated in place.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen>
    with TickerProviderStateMixin {
  // -- Language
  _Lang _lang = _Lang.en;

  // -- Consent text loading
  String? _consentText;
  bool _loadingText = true;
  bool _textError = false;

  // -- Scroll state
  bool _scrolledToEnd = false;
  final ScrollController _scrollController = ScrollController();

  // -- Hold-to-agree state
  bool _holding = false;
  DateTime? _holdStart;
  Timer? _holdTimer;
  double _holdProgress = 0.0; // 0..1
  AnimationController? _progressController;

  // -- Overall saving state
  bool _saving = false;

  // -- Disagree snackbar shown
  bool _disagreeShown = false;

  // -- Subject identity (token-based, pre-auth)
  String? _subjectId; // e.g. "57_9876543210"

  // -- App version (from pubspec, no extra package)
  static const String _appVersion = '1.0.0+1'; // kept in sync with pubspec.yaml

  static const Duration _holdDuration = Duration(seconds: 5);
  static const Color _accent = Color(0xFF4DB6AC);
  static const Color _bg = Color(0xFF082923);
  static const Color _surface = Color(0xFF102F2B);

  @override
  void initState() {
    super.initState();
    _detectLanguage();
    _loadSubjectId();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _holdTimer?.cancel();
    _progressController?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Identity
  // ---------------------------------------------------------------------------

  Future<void> _loadSubjectId() async {
    // TODO(auth-migration): Replace this with FirebaseAuth.instance.currentUser!.uid
    // once real authentication is implemented. The subjectId is stored in the
    // consent record so migration is a field update, not a schema change.
    final prefs = await SharedPreferences.getInstance();
    final tokenId = prefs.getString('token_id') ?? '';
    // tokenId is the sequential token number (e.g. "57")
    // Using it as subjectId for now. Mobile appended for marginal disambiguation.
    // This is NOT a security boundary — see PROJECT_AUDIT.md P0-3.
    setState(() {
      _subjectId = tokenId.isNotEmpty ? tokenId : 'unknown';
    });
  }

  // ---------------------------------------------------------------------------
  // Language detection
  // ---------------------------------------------------------------------------

  void _detectLanguage() {
    // Default to device language, fall back to English
    final locale = PlatformDispatcher.instance.locale.languageCode;
    _Lang detected = _Lang.en;
    if (locale == 'hi') detected = _Lang.hi;
    if (locale == 'gu') detected = _Lang.gu;
    _lang = detected;
    _loadConsentText();
  }

  void _switchLanguage(_Lang lang) {
    if (_lang == lang) return;
    setState(() {
      _lang = lang;
      _consentText = null;
      _loadingText = true;
      _textError = false;
      _scrolledToEnd = false;
      _holdProgress = 0;
      _holding = false;
    });
    _holdTimer?.cancel();
    _progressController?.stop();
    _loadConsentText();
  }

  Future<void> _loadConsentText() async {
    try {
      final text = await rootBundle.loadString(_lang.assetPath);
      if (!mounted) return;
      setState(() {
        _consentText = text;
        _loadingText = false;
        _textError = false;
        _scrolledToEnd = false;
      });
      // After layout, check if content is too short to scroll
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkScrollEnd());
    } catch (e) {
      debugPrint('[ConsentScreen] text load error: $e');
      if (!mounted) return;
      setState(() { _loadingText = false; _textError = true; });
    }
  }

  // ---------------------------------------------------------------------------
  // Scroll detection
  // ---------------------------------------------------------------------------

  void _onScroll() => _checkScrollEnd();

  void _checkScrollEnd() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final atEnd = pos.extentAfter <= 32.0; // 32px tolerance
    if (atEnd && !_scrolledToEnd) {
      setState(() => _scrolledToEnd = true);
    }
  }

  // ---------------------------------------------------------------------------
  // Hold-to-agree logic
  // ---------------------------------------------------------------------------

  void _onHoldStart() {
    if (!_scrolledToEnd || _saving) return;
    final startTime = DateTime.now();
    setState(() {
      _holding = true;
      _holdStart = startTime;
      _holdProgress = 0.0;
    });

    _progressController?.dispose();
    _progressController = AnimationController(
      vsync: this,
      duration: _holdDuration,
    )..addListener(() {
        if (!mounted) return;
        setState(() => _holdProgress = _progressController!.value);
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && _holding) {
          _onHoldComplete();
        }
      });

    _progressController!.forward(from: 0);
  }

  void _onHoldEnd() {
    if (!_holding) return;
    _progressController?.stop();
    setState(() {
      _holding = false;
      _holdProgress = 0.0;
      _holdStart = null;
    });
  }

  Future<void> _onHoldComplete() async {
    final holdMs = DateTime.now().difference(_holdStart!).inMilliseconds;
    HapticFeedback.heavyImpact();
    _progressController?.stop();
    setState(() {
      _holding = false;
      _holdProgress = 1.0;
      _saving = true;
    });

    await _saveConsent(holdMs);
  }

  Future<void> _saveConsent(int holdMs) async {
    if (_subjectId == null || _consentText == null) return;

    final platform = _platformName();

    try {
      await ConsentService().recordConsent(
        subjectId: _subjectId!,
        consentText: _consentText!,
        language: _lang.locale,
        appVersion: _appVersion,
        platform: platform,
        holdDurationMs: holdMs,
      );

      if (!mounted) return;
      // Navigate to parent dashboard (replace so back button cannot return here)
      context.go('/parent/dashboard');
    } catch (e) {
      debugPrint('[ConsentScreen] saveConsent error: $e');
      if (!mounted) return;
      setState(() { _saving = false; _holdProgress = 0; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_lang.savingError, style: GoogleFonts.outfit()),
          backgroundColor: const Color(0xFFB3261E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Disagree
  // ---------------------------------------------------------------------------

  void _onDisagree() {
    if (_saving) return;
    // Show message; do NOT store any data; sign out (clear prefs) and go to role
    setState(() => _disagreeShown = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_lang.disagreeMessage, style: GoogleFonts.outfit()),
        backgroundColor: const Color(0xFF37474F),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    Future.delayed(const Duration(milliseconds: 3200), () async {
      if (!mounted) return;
      // Sign out: clear session data only — no consent record written
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token_id');
      await prefs.remove('token_number');
      if (mounted) context.go('/role');
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _platformName() {
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
    } catch (_) {}
    return 'unknown';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent back navigation — consent cannot be skipped
      canPop: false,
      child: Scaffold(
        backgroundColor: _bg,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF103D35), Color(0xFF092C26), Color(0xFF081F20)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const NoInternetBanner(),
                _buildHeader(),
                Expanded(child: _buildBody()),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -- Header with language switcher ------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              _lang.title,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _buildLanguageSwitcher(),
        ],
      ),
    );
  }

  Widget _buildLanguageSwitcher() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _Lang.values.map((lang) {
        final selected = _lang == lang;
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Semantics(
            label: 'Switch language to ${lang.label}',
            button: true,
            child: GestureDetector(
              onTap: () => _switchLanguage(lang),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: selected
                      ? _accent.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? _accent : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: Text(
                  lang.label,
                  style: GoogleFonts.outfit(
                    color: selected ? _accent : Colors.white54,
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // -- Scrollable body --------------------------------------------------------

  Widget _buildBody() {
    if (_loadingText) {
      return const Center(
        child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
      );
    }
    if (_textError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(
                _lang.loadingError,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  setState(() { _loadingText = true; _textError = false; });
                  _loadConsentText();
                },
                child: Text('Retry', style: GoogleFonts.outfit(color: _accent)),
              ),
            ],
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification) _checkScrollEnd();
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Consent text rendered as styled paragraphs
            _buildConsentText(_consentText ?? ''),
            const SizedBox(height: 16),
            // "Scroll to end" indicator — not a countdown, just informational
            if (!_scrolledToEnd)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: _accent, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    _lang.scrollHint,
                    style: GoogleFonts.outfit(
                        color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Render the markdown-ish consent text with minimal styling.
  /// Headings start with `##`, bold headings with `#`. No external package needed.
  Widget _buildConsentText(String text) {
    final lines = text.split('\n');
    final spans = <Widget>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.startsWith('<!-- ')) continue; // skip HTML comments (draft tag)

      if (line.startsWith('# ')) {
        spans.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(
            line.substring(2).trim(),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ));
      } else if (line.startsWith('## ')) {
        spans.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Text(
            line.substring(3).trim(),
            style: GoogleFonts.outfit(
              color: _accent,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ));
      } else if (line.isEmpty) {
        spans.add(const SizedBox(height: 6));
      } else {
        spans.add(Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            line,
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13.5,
              height: 1.6,
            ),
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: spans,
    );
  }

  // -- Footer with action buttons ---------------------------------------------

  Widget _buildFooter() {
    final canAgree = _scrolledToEnd && !_saving && !_disagreeShown;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hold-to-agree button
          Semantics(
            label: canAgree
                ? _lang.holdHint
                : _lang.scrollHint,
            button: true,
            child: GestureDetector(
              onLongPressStart: (_) => _onHoldStart(),
              onLongPressEnd: (_) => _onHoldEnd(),
              onLongPressCancel: _onHoldEnd,
              child: AnimatedOpacity(
                opacity: canAgree ? 1.0 : 0.45,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: canAgree
                        ? const LinearGradient(
                            colors: [Color(0xFF26A69A), Color(0xFF00796B)],
                          )
                        : null,
                    color: canAgree ? null : Colors.white12,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Progress ring
                      if (_holding || (_holdProgress > 0 && _holdProgress < 1))
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            value: _holdProgress,
                            strokeWidth: 3,
                            color: Colors.white,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      if (!_holding || _holdProgress == 0)
                        _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _lang.agreeLabel,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // "I Do Not Agree" — equally prominent
          Semantics(
            label: _lang.disagreeLabel,
            button: true,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _saving || _disagreeShown ? null : _onDisagree,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  foregroundColor: Colors.white70,
                ),
                child: Text(
                  _lang.disagreeLabel,
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          Text(
            _lang.holdHint,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white30,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
