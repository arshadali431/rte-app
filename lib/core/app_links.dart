// External links and data-retention policy constants.
//
// PRIVACY POLICY URLS
// -------------------
// The English policy is live. The Hindi and Gujarati URLs are placeholders
// until the translated policies are published; while a placeholder is
// detected, the app falls back to the English policy so users never hit a
// broken link.
//
// TODO(owner): replace the two placeholders below with the published URLs.
//   kPrivacyPolicyUrlHi -> [PRIVACY_POLICY_URL_HI]
//   kPrivacyPolicyUrlGu -> [PRIVACY_POLICY_URL_GU]
const String kPrivacyPolicyUrl =
    'https://researchworkarshadali.blogspot.com/2026/10/rte-app-privacy-policy.html';
const String kPrivacyPolicyUrlHi = '[PRIVACY_POLICY_URL_HI]';
const String kPrivacyPolicyUrlGu = '[PRIVACY_POLICY_URL_GU]';

/// Hours a parent has to change their mind before a requested data deletion
/// becomes irreversible. Mirrored by functions/deleteScheduled.js and the
/// deletion confirmation copy.
const int kDeletionGraceHours = 48;

/// True when [url] is a real, openable http(s) URL (not a placeholder).
bool isConfiguredUrl(String url) =>
    url.startsWith('http://') || url.startsWith('https://');

/// Returns the best privacy-policy URL for the given language code.
/// Falls back to English while a translation is still a placeholder.
String privacyPolicyUrlFor(String languageCode) {
  switch (languageCode) {
    case 'hi':
      return isConfiguredUrl(kPrivacyPolicyUrlHi)
          ? kPrivacyPolicyUrlHi
          : kPrivacyPolicyUrl;
    case 'gu':
      return isConfiguredUrl(kPrivacyPolicyUrlGu)
          ? kPrivacyPolicyUrlGu
          : kPrivacyPolicyUrl;
    default:
      return kPrivacyPolicyUrl;
  }
}
