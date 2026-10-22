import 'package:flutter/material.dart';

import '../core/app_links.dart';
import '../core/external_links.dart';

/// Reusable "Privacy Policy" link that opens the policy in the external
/// browser. No GoogleFonts here on purpose: it keeps widget tests offline and
/// fast.
class PrivacyPolicyLink extends StatelessWidget {
  final String language;
  final Color? color;
  final bool dense;

  const PrivacyPolicyLink({
    super.key,
    this.language = 'en',
    this.color,
    this.dense = false,
  });

  static const Map<String, String> _labels = {
    'en': 'Privacy Policy',
    'hi': 'गोपनीयता नीति',
    'gu': 'ગોપનીયતા નીતિ',
  };

  Future<void> _open(BuildContext context) async {
    final url = privacyPolicyUrlFor(language);
    final opened = await openExternalUrl(url);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Privacy policy link is not available right now.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _labels[language] ?? _labels['en']!;
    final linkColor = color ?? Theme.of(context).colorScheme.primary;
    final fontSize = dense ? 11.5 : 13.0;

    return TextButton.icon(
      onPressed: () => _open(context),
      icon: Icon(Icons.privacy_tip_outlined, size: dense ? 15 : 18, color: linkColor),
      label: Text(
        label,
        style: TextStyle(
          color: linkColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: linkColor,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: linkColor,
        padding: EdgeInsets.symmetric(horizontal: dense ? 4 : 8, vertical: 2),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
