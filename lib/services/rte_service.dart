import 'package:dio/dio.dart';
import 'package:html/parser.dart' as parser;
import '../models.dart';

/// Lightweight result returned by [RteService.fetchStatusWithChildName].
/// Contains everything needed for a single sync write to Firestore.
class RteStatusResult {
  final String statusMessage;
  final String classifiedStatus;

  /// Child full name as extracted from the government portal (Gujarati script).
  final String? childName;
  /// Parent mobile number as extracted from the government portal. Null if not found.
  final String? parentMobile;

  const RteStatusResult({
    required this.statusMessage,
    required this.classifiedStatus,
    this.childName,
    this.parentMobile,
  });
}

class RteService {
  final Dio dio = Dio();
  final String userAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

  static final RteService _instance = RteService._internal();
  factory RteService() => _instance;
  RteService._internal() {
    dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
    );
  }

  Future<RteApplicationData> fetchApplicationStatus(
    String appNum,
    String dob,
  ) async {
    try {
      // Step 1: GET for Token
      final getResponse = await dio.get(
        "https://rte.orpgujarat.com/ApplicationFormStatus",
        options: Options(headers: {"User-Agent": userAgent}),
      );

      List<String> rawCookies = getResponse.headers["set-cookie"] ?? [];
      String cookieString = rawCookies.map((e) => e.split(";")[0]).join("; ");

      final tokenMatch = RegExp(
        r'name="__RequestVerificationToken".*?value="([^"]+)"',
        dotAll: true,
      ).firstMatch(getResponse.data.toString());

      String? token = tokenMatch?.group(1);
      if (token == null) {
        throw Exception("Verification token not found");
      }

      // Step 2: POST Status Check
      final postResponse = await dio.post(
        "https://rte.orpgujarat.com/ApplicationFormStatus",
        data: {
          "__RequestVerificationToken": token,
          "ApplicationNumber": appNum.trim(),
          "DateOfBirth": dob.trim(),
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

      return _parseResponse(postResponse.data.toString(), appNum);
    } catch (e) {
      rethrow;
    }
  }

  // ── Focused sync method ───────────────────────────────────────────────
  /// Performs the same HTTP round-trip as [fetchApplicationStatus] but returns
  /// only the fields needed for Firestore sync: status message, classification,
  /// and the child's full name assembled from the "બાળકની માહિતી" fieldset.
  ///
  /// This is the preferred method for all sync flows (single token or bulk).
  Future<RteStatusResult> fetchStatusWithChildName(
    String appNum,
    String dob,
  ) async {
    // Step 1: GET page to grab CSRF token + session cookie
    final getResponse = await dio.get(
      'https://rte.orpgujarat.com/ApplicationFormStatus',
      options: Options(headers: {'User-Agent': userAgent}),
    );

    final rawCookies = getResponse.headers['set-cookie'] ?? [];
    final cookieString = rawCookies.map((e) => e.split(';')[0]).join('; ');

    final tokenMatch = RegExp(
      r'name="__RequestVerificationToken".*?value="([^"]+)"',
      dotAll: true,
    ).firstMatch(getResponse.data.toString());
    final csrfToken = tokenMatch?.group(1);
    if (csrfToken == null) throw Exception('Verification token not found');

    // Step 2: POST
    final postResponse = await dio.post(
      'https://rte.orpgujarat.com/ApplicationFormStatus',
      data: {
        '__RequestVerificationToken': csrfToken,
        'ApplicationNumber': appNum.trim(),
        'DateOfBirth': dob.trim(),
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Cookie': cookieString,
          'Origin': 'https://rte.orpgujarat.com',
          'Referer': 'https://rte.orpgujarat.com/ApplicationFormStatus',
          'User-Agent': userAgent,
        },
        followRedirects: true,
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    final html = postResponse.data.toString();
    final statusMsg = _parseStatusMessage(html);
    final classified = classifyStatus(statusMsg);
    final childName = _extractChildNameFromFieldset(html);
    final parentMobile = _extractParentMobileFromFieldset(html);

    return RteStatusResult(
      statusMessage: statusMsg,
      classifiedStatus: classified,
      childName: childName,
      parentMobile: parentMobile,
    );
  }

  // ── Internal helpers ──────────────────────────────────────────────────

  /// Extracts the status message from raw HTML (shared logic).
  String _parseStatusMessage(String html) {
    final doc = parser.parse(html);

    // Priority 1: Check for alert boxes (common for rejection/warnings)
    for (final alert in doc.querySelectorAll(
      '.alert, .alert-danger, .alert-success, .alert-warning, .alert-info',
    )) {
      final text = alert.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (text.isNotEmpty &&
          (text.contains('મંજૂર') ||
              text.contains('નામંજૂર') ||
              text.contains('તપાસ') ||
              text.contains('reject') ||
              text.contains('approve'))) {
        return text;
      }
    }

    // Priority 2: Traditional fieldset/legend approach
    for (final fs in doc.querySelectorAll('fieldset')) {
      final legend = fs.querySelector('legend');
      if (legend != null && legend.text.trim().contains('અરજીની સ્થિતિ')) {
        final p = fs.querySelector('p');
        final msg = p != null
            ? p.text.trim()
            : fs.text.replaceAll(legend.text, '').trim();
        if (msg.isNotEmpty) return msg.replaceAll(RegExp(r'\s+'), ' ');
      }
    }

    // Priority 3: Search for elements containing "અરજીની સ્થિતિ" and pick up the text following it
    // This handles cases where it might be a div header or label.
    final allElements = doc.querySelectorAll('*');
    for (final el in allElements) {
      final text = el.text.trim();
      if (text == 'અરજીની સ્થિતિ') {
        final parent = el.parent;
        if (parent != null) {
          final parentText = parent.text.replaceAll('અરજીની સ્થિતિ', '').trim();
          if (parentText.isNotEmpty && parentText.length < 500) {
            return parentText.replaceAll(RegExp(r'\s+'), ' ');
          }
        }
      }
    }

    // Priority 4: Final regex fallback for the most common rejection pattern
    // This targets the text that starts with "આપણું આ ફોર્મ" or contains "નામંજૂર"
    // We look for a few common start patterns and stop at the next HTML tag or long whitespace.
    final rejectionMatch = RegExp(
      r'(?:આપણું આ ફોર્મ|અરજી\s+નામંજૂર).*?(?=<|$)',
      dotAll: true,
    ).firstMatch(html);
    if (rejectionMatch != null) {
      final raw = rejectionMatch.group(0)!;
      final cleaned = parser
          .parseFragment(raw)
          .text
          ?.trim()
          .replaceAll(RegExp(r'\s+'), ' ');
      if (cleaned != null && cleaned.isNotEmpty) return cleaned;
    }

    return 'No status information found.';
  }

  /// Targets the "બાળકની માહિતી" fieldset specifically.
  /// Extracts first name, father/guardian name, surname and joins them.
  /// Returns null when the section is absent or all parts are empty.
  String? _extractChildNameFromFieldset(String html) {
    final doc = parser.parse(html);
    for (final fs in doc.querySelectorAll('fieldset')) {
      final legend = fs.querySelector('legend');
      if (legend == null) continue;
      if (!legend.text.trim().contains('બાળકની માહિતી')) continue;

      // Gather all dt→dd pairs in this fieldset
      final Map<String, String> fields = {};
      for (final dl in fs.querySelectorAll('dl.row')) {
        final nodes = dl.children
            .where((el) => el.localName == 'dt' || el.localName == 'dd')
            .toList();
        for (var i = 0; i < nodes.length - 1; i++) {
          if (nodes[i].localName == 'dt' && nodes[i + 1].localName == 'dd') {
            final key = nodes[i].text
                .trim()
                .replaceAll(':', '')
                .replaceAll(RegExp(r'\s+'), ' ')
                .toLowerCase();
            final value = nodes[i + 1].text.trim().replaceAll(
              RegExp(r'\s+'),
              ' ',
            );
            if (key.isNotEmpty && value.isNotEmpty) fields[key] = value;
          }
        }
      }

      if (fields.isEmpty) return null;

      // Identify first name, father/guardian name, surname by key heuristics
      String get(List<String> hints) {
        for (final hint in hints) {
          for (final MapEntry<String, String> e in fields.entries) {
            if (e.key.contains(hint)) return e.value.trim();
          }
        }
        return '';
      }

      final firstName = get(['પ્રથમ', 'first', 'child first', 'બાળ']);
      final fatherName = get(['પિતા', 'father', 'guardian', 'middle']);
      final surname = get(['અટક', 'surname', 'last']);

      final fullName = [
        firstName,
        fatherName,
        surname,
      ].where((p) => p.isNotEmpty).join(' ').trim();
      return fullName.isNotEmpty ? fullName : null;
    }
    return null;
  }

  /// Targets the "સંપર્કની માહિતી" fieldset specifically.
  /// Extracts the primary mobile number.
  /// Returns null when the section is absent or mobile is empty.
  String? _extractParentMobileFromFieldset(String html) {
    final doc = parser.parse(html);
    for (final fs in doc.querySelectorAll('fieldset')) {
      final legend = fs.querySelector('legend');
      if (legend == null) continue;
      if (!legend.text.trim().contains('સંપર્કની માહિતી')) continue;

      for (final dt in fs.querySelectorAll('dt')) {
        final label = dt.text.trim().toLowerCase();
        if (label.contains('મોબાઇલ') || label.contains('mobile')) {
          final dd = dt.nextElementSibling;
          if (dd != null && dd.localName == 'dd') {
            final val = dd.text.trim();
            if (val.isNotEmpty) return val;
          }
        }
      }
    }
    return null;
  }

  RteApplicationData _parseResponse(String html, String defaultAppNum) {
    final doc = parser.parse(html);
    String appNum = defaultAppNum;
    final cardHeader = doc.querySelector('.card-header');
    if (cardHeader != null) {
      final match = RegExp(
        r'(?:for\s+)([A-Z0-9/\-]+)',
      ).firstMatch(cardHeader.text);
      if (match != null) appNum = match.group(1)!.trim();
    }

    String statusMsg = _parseStatusMessage(html);

    final allFieldsets = doc.querySelectorAll('fieldset');
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

    return RteApplicationData(
      applicationNumber: appNum,
      statusMessage: statusMsg,
      sections: sections,
      schools: schools,
      documents: documents,
      childName: _extractChildName(sections),
    );
  }

  /// Fallback: scans all parsed sections for a child-name-like key.
  /// Used only by the legacy [fetchApplicationStatus] path.
  String? _extractChildName(Map<String, Map<String, String>> sections) {
    for (final sectionData in sections.values) {
      for (final entry in sectionData.entries) {
        final key = entry.key.toLowerCase();
        if (key.contains('બાળ') ||
            key.contains('child') ||
            key.contains('name of child')) {
          final val = entry.value.trim();
          if (val.isNotEmpty) return val;
        }
      }
    }
    return null;
  }

  String classifyStatus(String status) {
    if (status.isEmpty || status.contains('No status information found')) {
      return "PENDING";
    }

    final s = status.toLowerCase();

    // 1. SUBMITTED — specific "district review pending" phrase (check first)
    //    "જિલ્લા કક્ષાએ સમીક્ષા (મંજૂ/મંજુ) કરવાનું બાકી છે"
    if (status.contains('જીલ્લા કક્ષાએ સમીક્ષા') ||
        status.contains('જિલ્લા કક્ષાએ સમીક્ષા') ||
        (s.contains('સમીક્ષા') && s.contains('બાકી'))) {
      return "SUBMITTED";
    }

    // 2. CANCELLED — rejection / cancelled by admin or user
    if (s.contains('નામંજૂર') ||
        s.contains('નામંજુર') ||
        s.contains('નામંજુ') ||
        s.contains('reject') ||
        s.contains('refused') ||
        s.contains('cancel') ||
        s.contains('કેન્સલ') ||
        s.contains('રદ') ||
        s.contains('અમાન્ય')) {
      return "CANCELLED";
    }

    // 3. APPROVED — district approved / seat allotted
    if (s.contains('મંજૂર') ||
        s.contains('મંજુર') ||
        s.contains('approved') ||
        s.contains('approve') ||
        s.contains('accept') ||
        s.contains('ફાળવ') ||
        s.contains('allot')) {
      return "APPROVED";
    }

    // 4. DEFAULT → PENDING (covers all remaining states)
    return "PENDING";
  }
}
