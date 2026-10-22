import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_links.dart';
import '../../services/deletion_service.dart';
import '../../widgets/privacy_policy_link.dart';

// ---------------------------------------------------------------------------
// Language strings
// ---------------------------------------------------------------------------

enum _Lang { en, hi, gu }

extension _LangX on _Lang {
  String get label {
    switch (this) {
      case _Lang.en:
        return 'English';
      case _Lang.hi:
        return 'हिन्दी';
      case _Lang.gu:
        return 'ગુજરાતી';
    }
  }

  String get locale {
    switch (this) {
      case _Lang.en:
        return 'en';
      case _Lang.hi:
        return 'hi';
      case _Lang.gu:
        return 'gu';
    }
  }

  String get title {
    switch (this) {
      case _Lang.en:
        return 'Delete my data';
      case _Lang.hi:
        return 'मेरा डेटा हटाएँ';
      case _Lang.gu:
        return 'મારો ડેટા ડિલીટ કરો';
    }
  }

  String get intro {
    switch (this) {
      case _Lang.en:
        return 'Request permanent deletion of your data from the RTE Token and Document Service. Please read carefully before confirming.';
      case _Lang.hi:
        return 'आरटीई टोकन और दस्तावेज़ सेवा से अपना डेटा स्थायी रूप से हटाने का अनुरोध करें। पुष्टि करने से पहले ध्यान से पढ़ें।';
      case _Lang.gu:
        return 'RTE ટોકન અને દસ્તાવેજ સેવા માંથી તમારો ડેટા કાયમી ધોરણે ડિલીટ કરવાની વિનંતી કરો. પુષ્ટિ કરતા પહેલા કૃપા કરી ધ્યાનથી વાંચો.';
    }
  }

  String get deletedHeading {
    switch (this) {
      case _Lang.en:
        return 'What will be deleted';
      case _Lang.hi:
        return 'क्या हटाया जाएगा';
      case _Lang.gu:
        return 'શું ડિલીટ થશે';
    }
  }

  List<String> get deletedItems {
    switch (this) {
      case _Lang.en:
        return [
          'Parent / guardian profile details (name, mobile number)',
          'Child details (name, date of birth, gender, Aadhaar number)',
          'Uploaded documents and their copies',
          'Application records and status history',
          'Copies created for volunteers / Trust staff',
        ];
      case _Lang.hi:
        return [
          'माता-पिता / अभिभावक की प्रोफ़ाइल (नाम, मोबाइल नंबर)',
          'बच्चे का विवरण (नाम, जन्म तिथि, लिंग, आधार नंबर)',
          'अपलोड किए गए दस्तावेज़ और उनकी प्रतियाँ',
          'आवेदन रिकॉर्ड और स्थिति इतिहास',
          'स्वयंसेवकों / ट्रस्ट स्टाफ के लिए बनाई गई प्रतियाँ',
        ];
      case _Lang.gu:
        return [
          'માતા-પિતા / વાલીની પ્રોફાઇલ (નામ, મોબાઇલ નંબર)',
          'બાળકની વિગતો (નામ, જન્મ તારીખ, જાતિ, આધાર નંબર)',
          'અપલોડ કરેલા દસ્તાવેજો અને તેમની નકલો',
          'અરજી રેકોર્ડ અને સ્થિતિ ઇતિહાસ',
          'સ્વયંસેવકો / ટ્રસ્ટ સ્ટાફ માટે બનાવેલી નકલો',
        ];
    }
  }

  String get keptHeading {
    switch (this) {
      case _Lang.en:
        return 'What is kept';
      case _Lang.hi:
        return 'क्या रखा जाएगा';
      case _Lang.gu:
        return 'શું રાખવામાં આવશે';
    }
  }

  List<String> get keptItems {
    switch (this) {
      case _Lang.en:
        return [
          'Only a minimal record with NO personal details: token number, deletion date, and proof of consent / withdrawal.',
        ];
      case _Lang.hi:
        return [
          'केवल एक न्यूनतम रिकॉर्ड बिना किसी व्यक्तिगत विवरण के: टोकन नंबर, हटाने की तिथि, और सहमति / वापसी का प्रमाण।',
        ];
      case _Lang.gu:
        return [
          'ફક્ત ન્યૂનતમ રેકોર્ડ, કોઈ વ્યક્તિગત વિગતો વગર: ટોકન નંબર, ડિલીટ કરવાની તારીખ, અને સંમતિ / પાછળ ખેંચવાનો પુરાવો.',
        ];
    }
  }

  String get govNote {
    switch (this) {
      case _Lang.en:
        return 'Data already submitted to the official RTE portal cannot be deleted by the Trust. For that copy, contact the RTE authorities separately.';
      case _Lang.hi:
        return 'आधिकारिक आरटीई पोर्टल पर पहले से जमा किया गया डेटा ट्रस्ट द्वारा हटाया नहीं जा सकता। उस प्रति के लिए आरटीई प्राधिकरण से अलग से संपर्क करें।';
      case _Lang.gu:
        return 'સત્તાવાર RTE પોર્ટલ પર પહેલેથી સબમિટ કરેલો ડેટા ટ્રસ્ટ દ્વારા ડિલીટ કરી શકાતો નથી. તે નકલ માટે RTE સત્તાવાળાઓનો અલગ સંપર્ક કરો.';
    }
  }

  String get helpNote {
    switch (this) {
      case _Lang.en:
        return 'After deletion the Trust will no longer be able to help you with this application.';
      case _Lang.hi:
        return 'हटाने के बाद ट्रस्ट इस आवेदन में आपकी सहायता नहीं कर पाएगा।';
      case _Lang.gu:
        return 'ડિલીટ કર્યા પછી ટ્રસ્ટ આ અરજીમાં તમને મદદ કરી શકશે નહીં.';
    }
  }

  String graceNote(int hours) {
    switch (this) {
      case _Lang.en:
        return 'You can cancel this request within $hours hours. After that the deletion is permanent and cannot be undone.';
      case _Lang.hi:
        return 'आप इस अनुरोध को $hours घंटे के भीतर रद्द कर सकते हैं। उसके बाद हटाना स्थायी होगा और इसे वापस नहीं लिया जा सकता।';
      case _Lang.gu:
        return 'તમે આ વિનંતી $hours કલાકની અંદર રદ કરી શકો છો. તે પછી ડિલીટ કાયમી થશે અને પાછું લાવી શકાશે નહીં.';
    }
  }

  String get tokenLabel {
    switch (this) {
      case _Lang.en:
        return 'Token number';
      case _Lang.hi:
        return 'टोकन नंबर';
      case _Lang.gu:
        return 'ટોકન નંબર';
    }
  }

  String get mobileLabel {
    switch (this) {
      case _Lang.en:
        return 'Registered mobile number';
      case _Lang.hi:
        return 'पंजीकृत मोबाइल नंबर';
      case _Lang.gu:
        return 'નોંધાયેલ મોબાઇલ નંબર';
    }
  }

  String get confirmLabel {
    switch (this) {
      case _Lang.en:
        return 'Request deletion';
      case _Lang.hi:
        return 'हटाने का अनुरोध करें';
      case _Lang.gu:
        return 'ડિલીટ કરવાની વિનંતી કરો';
    }
  }

  String get enterValuesError {
    switch (this) {
      case _Lang.en:
        return 'Enter your token number and registered mobile number.';
      case _Lang.hi:
        return 'अपना टोकन नंबर और पंजीकृत मोबाइल नंबर दर्ज करें।';
      case _Lang.gu:
        return 'તમારો ટોકન નંબર અને નોંધાયેલ મોબાઇલ નંબર દાખલ કરો.';
    }
  }

  String errorFor(String code) {
    switch (code) {
      case 'tokenNotFound':
        return _Lang.en == this
            ? 'This token could not be found. Please sign in again.'
            : _Lang.hi == this
                ? 'यह टोकन नहीं मिला। कृपया फिर से साइन इन करें।'
                : 'આ ટોકન મળ્યો નથી. કૃપા કરી ફરી સાઇન ઇન કરો.';
      case 'mobileMismatch':
        return _Lang.en == this
            ? 'The mobile number does not match our records.'
            : _Lang.hi == this
                ? 'मोबाइल नंबर हमारे रिकॉर्ड से मेल नहीं खाता।'
                : 'મોબાઇલ નંબર અમારા રેકોર્ડ સાથે મેળ ખાતો નથી.';
      case 'tokenMismatch':
        return _Lang.en == this
            ? 'The token number does not match our records.'
            : _Lang.hi == this
                ? 'टोकन नंबर हमारे रिकॉर्ड से मेल नहीं खाता।'
                : 'ટોકન નંબર અમારા રેકોર્ડ સાથે મેળ ખાતો નથી.';
      default:
        return _Lang.en == this
            ? 'Could not schedule the deletion. Please try again.'
            : _Lang.hi == this
                ? 'हटाने का अनुरोध नहीं किया जा सका। कृपया पुनः प्रयास करें।'
                : 'ડિલીટ કરવાની વિનંતી થઈ શકી નહીં. કૃપા કરી ફરી પ્રયાસ કરો.';
    }
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Confirmation screen for the parent's self-service "Delete my data" request.
///
/// STOPGAP: identity is proven by token number + registered mobile because the
/// app has no Firebase Auth yet.
/// TODO(auth-migration): replace the token + mobile check with Firebase Auth
/// phone/OTP re-authentication, and make the request client-side call go
/// through a callable Cloud Function.
class DeleteDataScreen extends StatefulWidget {
  const DeleteDataScreen({super.key});

  @override
  State<DeleteDataScreen> createState() => _DeleteDataScreenState();
}

class _DeleteDataScreenState extends State<DeleteDataScreen> {
  static const Color _accent = Color(0xFF26A69A);
  static const Color _background = Color(0xFF082923);

  _Lang _lang = _Lang.en;
  String? _tokenId;
  bool _loadingSession = true;
  bool _submitting = false;
  String? _errorMessage;

  final TextEditingController _tokenNumberController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final deviceLanguage =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    if (deviceLanguage == 'hi') _lang = _Lang.hi;
    if (deviceLanguage == 'gu') _lang = _Lang.gu;
    _loadSession();
  }

  @override
  void dispose() {
    _tokenNumberController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenId = prefs.getString('token_id');
    if (!mounted) return;
    setState(() {
      _tokenId = tokenId;
      _loadingSession = false;
      if (tokenId == null || tokenId.isEmpty) {
        _errorMessage = 'Your session was not found. Please scan your token again.';
      }
    });
  }

  Future<void> _confirmDeletion() async {
    FocusScope.of(context).unfocus();
    final tokenNumber = _tokenNumberController.text.trim();
    final mobile = _mobileController.text.trim();
    if (tokenNumber.isEmpty || mobile.isEmpty) {
      setState(() => _errorMessage = _lang.enterValuesError);
      return;
    }
    final tokenId = _tokenId;
    if (tokenId == null || tokenId.isEmpty) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await DeletionService().requestDeletion(
        tokenId: tokenId,
        tokenNumberInput: tokenNumber,
        mobileInput: mobile,
      );
      if (!mounted) return;
      context.go('/parent/deletion-pending');
    } on DeletionException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = e.code == 'unknown' ? null : _lang.errorFor(e.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = _lang.errorFor('unknown');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _loadingSession
                    ? const Center(
                        child: CircularProgressIndicator(color: _accent),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLanguageSwitcher(),
                            const SizedBox(height: 16),
                            Text(
                              _lang.intro,
                              style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildCard(
                              icon: Icons.delete_outline_rounded,
                              iconColor: const Color(0xFFFF8A80),
                              title: _lang.deletedHeading,
                              items: _lang.deletedItems,
                            ),
                            const SizedBox(height: 14),
                            _buildCard(
                              icon: Icons.inventory_2_outlined,
                              iconColor: const Color(0xFF80CBC4),
                              title: _lang.keptHeading,
                              items: _lang.keptItems,
                            ),
                            const SizedBox(height: 14),
                            _buildNote(_lang.govNote, const Color(0xFFFFCC80)),
                            const SizedBox(height: 10),
                            _buildNote(_lang.helpNote, const Color(0xFFFFAB91)),
                            const SizedBox(height: 10),
                            _buildNote(
                              _lang.graceNote(kDeletionGraceHours),
                              _accent,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _lang.tokenLabel,
                              style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 7),
                            TextField(
                              key: const Key('delete_token_input'),
                              controller: _tokenNumberController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(9),
                              ],
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                'e.g. 104',
                                Icons.confirmation_number_outlined,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _lang.mobileLabel,
                              style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 7),
                            TextField(
                              key: const Key('delete_mobile_input'),
                              controller: _mobileController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                '10-digit mobile number',
                                Icons.phone_iphone_rounded,
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                _errorMessage!,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFFF8A80),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                key: const Key('delete_confirm_button'),
                                onPressed: _submitting ? null : _confirmDeletion,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC62828),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      const Color(0xFFC62828).withValues(alpha: 0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _submitting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _lang.confirmLabel,
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Center(
                              child: PrivacyPolicyLink(
                                language: _lang.locale,
                                color: Colors.white54,
                                dense: true,
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 16, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/parent/dashboard');
              }
            },
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          Expanded(
            child: Text(
              _lang.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSwitcher() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final lang in _Lang.values) ...[
          ChoiceChip(
            label: Text(
              lang.label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _lang == lang ? const Color(0xFF082923) : Colors.white70,
              ),
            ),
            selected: _lang == lang,
            selectedColor: _accent,
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
            onSelected: (_) => setState(() => _lang = lang),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<String> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(color: Colors.white54)),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNote(String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              color: color.withValues(alpha: 0.92),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white54, size: 19),
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.4),
      ),
    );
  }
}
