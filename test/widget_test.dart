import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rte_status_checker/core/app_links.dart';
import 'package:rte_status_checker/core/external_links.dart';
import 'package:rte_status_checker/widgets/privacy_policy_link.dart';

/// Basic smoke coverage for shared links. The full privacy/deletion suite lives
/// in test/privacy_and_deletion_test.dart.
void main() {
  test('app links are configured', () {
    expect(isConfiguredUrl(kPrivacyPolicyUrl), isTrue);
  });

  testWidgets('privacy policy button is tappable', (tester) async {
    final previousOpener = externalUrlOpener;
    externalUrlOpener = (uri) async => true;
    addTearDown(() => externalUrlOpener = previousOpener);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PrivacyPolicyLink())),
    );
    expect(find.byType(TextButton), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    await tester.pump();
  });
}
