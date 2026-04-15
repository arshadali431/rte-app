import 'package:dio/dio.dart';
import 'package:html/parser.dart' as parser;
import '../models.dart';

class RteService {
  final Dio dio = Dio();
  final String userAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

  static final RteService _instance = RteService._internal();
  factory RteService() => _instance;
  RteService._internal();

  Future<RteApplicationData> fetchApplicationStatus(String appNum, String dob) async {
    try {
      // Step 1: GET for Token
      final getResponse = await dio.get(
        "https://rte.orpgujarat.com/ApplicationFormStatus",
        options: Options(
          headers: {"User-Agent": userAgent},
        ),
      );

      List<String> rawCookies = getResponse.headers["set-cookie"] ?? [];
      String cookieString = rawCookies.map((e) => e.split(";")[0]).join("; ");

      final tokenMatch = RegExp(
              r'name="__RequestVerificationToken".*?value="([^"]+)"',
              dotAll: true)
          .firstMatch(getResponse.data.toString());

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
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
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

  RteApplicationData _parseResponse(String html, String defaultAppNum) {
    final doc = parser.parse(html);
    String appNum = defaultAppNum;
    final cardHeader = doc.querySelector('.card-header');
    if (cardHeader != null) {
      final match = RegExp(r'(?:for\s+)([A-Z0-9/\-]+)').firstMatch(cardHeader.text);
      if (match != null) appNum = match.group(1)!.trim();
    }

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
          if (children[i].localName == 'dt' && children[i + 1].localName == 'dd') {
            final key = children[i].text.trim().replaceAll(':', '').replaceAll(RegExp(r'\s+'), ' ').trim();
            final value = children[i + 1].text.trim().replaceAll(RegExp(r'\s+'), ' ').trim();
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
            final rowData = row.querySelectorAll('th, td').map((c) => c.text.trim().replaceAll(RegExp(r'\s+'), ' ')).toList();
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
                return href.startsWith('http') ? href : 'https://rte.orpgujarat.com$href';
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
    );
  }

  String classifyStatus(String status) {
    if (status.isEmpty || status.contains('No status information found')) {
      return "ERROR";
    }
    
    String s = status.toLowerCase();

    // 1. APPROVED: "આપનું આ ફોર્મ જીલ્લા કક્ષાએ મંજુર (approve) કરેલ છે."
    if (s.contains('મંજૂર') || s.contains('મંજુર') || s.contains('approved') || s.contains('ફાળવ')) {
      return "APPROVED";
    } 
    
    // 2. CANCELLED: "આપે આ ફોર્મ કેન્સલ કરેલ છે."
    if (s.contains('કેન્સલ') || s.contains('cancel') || s.contains('નામંજૂર') || s.contains('રદ')) {
      return "CANCELLED";
    } 

    // 3. PENDING/WAITING: "આપનું આ ફોર્મ જીલ્લા કક્ષાએ સમીક્ષા (મંજુર) કરવાનું બાકી છે."
    // Also "આપે શાળાઓ ની પુનઃ પસંદગી કરેલ નથી."
    if (s.contains('બાકી છે') || s.contains('પુનઃ પસંદગી') || s.contains('સબમીટ કરેલ છે')) {
      return "PENDING";
    }

    // 4. ERROR/NOT FOUND
    if (s.contains('error') || s.contains('not found') || s.contains('detail mismatch') || s.contains('enter correct details')) {
      return "ERROR";
    }

    // 5. DEFAULT: CORRECTION (As user said: "dusri sab quary hai jo usko correction bolte hai")
    return "CORRECTION";
  }
}
