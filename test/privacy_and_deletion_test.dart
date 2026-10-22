import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rte_status_checker/core/app_links.dart';
import 'package:rte_status_checker/core/external_links.dart';
import 'package:rte_status_checker/models/token_model.dart';
import 'package:rte_status_checker/services/deletion_service.dart';
import 'package:rte_status_checker/widgets/privacy_policy_link.dart';

TokenModel _token({bool deletionPending = false}) => TokenModel(
      id: '57',
      tokenNumber: 57,
      parentName: 'Test Parent',
      parentMobile: '9876543210',
      createdBy: 'office',
      status: 'pending',
      deletionPending: deletionPending,
    );

void main() {
  group('privacy policy links', () {
    test('English policy URL is configured', () {
      expect(isConfiguredUrl(kPrivacyPolicyUrl), isTrue);
      expect(kPrivacyPolicyUrl.startsWith('https://'), isTrue);
    });

    test('every language resolves to an openable URL', () {
      for (final language in ['en', 'hi', 'gu']) {
        expect(
          isConfiguredUrl(privacyPolicyUrlFor(language)),
          isTrue,
          reason: 'privacy URL missing for $language',
        );
      }
    });

    testWidgets('tapping Privacy Policy opens the external browser', (tester) async {
      final previousOpener = externalUrlOpener;
      Uri? openedUri;
      externalUrlOpener = (uri) async {
        openedUri = uri;
        return true;
      };
      addTearDown(() => externalUrlOpener = previousOpener);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PrivacyPolicyLink(language: 'en')),
        ),
      );
      await tester.tap(find.text('Privacy Policy'));
      await tester.pump();

      expect(openedUri, Uri.parse(kPrivacyPolicyUrl));
    });
  });

  group('deletion identity check (stopgap token + mobile)', () {
    test('token number must match exactly', () {
      expect(
        DeletionRules.tokenNumberMatches(tokenNumber: 57, input: '57'),
        isTrue,
      );
      expect(
        DeletionRules.tokenNumberMatches(tokenNumber: 57, input: '58'),
        isFalse,
      );
      expect(
        DeletionRules.tokenNumberMatches(tokenNumber: 57, input: 'abc'),
        isFalse,
      );
      expect(
        DeletionRules.tokenNumberMatches(tokenNumber: 57, input: ' 57 '),
        isTrue,
      );
    });

    test('registered mobile must match (formatting tolerated)', () {
      expect(
        DeletionRules.mobileMatches(
          registeredMobile: '9876543210',
          input: '9876543210',
        ),
        isTrue,
      );
      expect(
        DeletionRules.mobileMatches(
          registeredMobile: '9876543210',
          input: '98765 43210',
        ),
        isTrue,
      );
      expect(
        DeletionRules.mobileMatches(
          registeredMobile: '9876543210',
          input: '9123456780',
        ),
        isFalse,
      );
      expect(
        DeletionRules.mobileMatches(registeredMobile: '', input: ''),
        isFalse,
      );
    });

    test('both factors are required together', () {
      expect(
        DeletionRules.identityMatches(
          tokenNumber: 57,
          registeredMobile: '9876543210',
          tokenNumberInput: '57',
          mobileInput: '9876543210',
        ),
        isTrue,
      );
      expect(
        DeletionRules.identityMatches(
          tokenNumber: 57,
          registeredMobile: '9876543210',
          tokenNumberInput: '57',
          mobileInput: '0000000000',
        ),
        isFalse,
      );
      expect(
        DeletionRules.identityMatches(
          tokenNumber: 57,
          registeredMobile: '9876543210',
          tokenNumberInput: '58',
          mobileInput: '9876543210',
        ),
        isFalse,
      );
    });
  });

  group('deletion grace period', () {
    test('is 48 hours', () {
      expect(kDeletionGraceHours, 48);
    });

    test('executeAfter is requestedAt + 48h', () {
      final requestedAt = DateTime(2026, 10, 23, 10, 30);
      expect(
        DeletionRules.executeAfter(requestedAt),
        requestedAt.add(const Duration(hours: 48)),
      );
    });
  });

  group('office visibility', () {
    test('pending-deletion tokens are hidden from office lists', () {
      final pending = _token(deletionPending: true);
      final visible = _token();

      expect(DeletionRules.shouldHideToken(pending), isTrue);
      expect(DeletionRules.isHiddenFromOffice(deletionPending: true), isTrue);
      expect(DeletionRules.visibleToOffice([pending, visible]), [visible]);
    });

    test('cancelling a request restores visibility', () {
      final pending = _token(deletionPending: true);
      expect(DeletionRules.visibleToOffice([pending]), isEmpty);

      // After the cancel flow sets deletionPending=false the token reappears.
      final afterCancel = _token(deletionPending: false);
      expect(DeletionRules.visibleToOffice([afterCancel]), contains(afterCancel));
      expect(DeletionRules.shouldHideToken(afterCancel), isFalse);
    });
  });

  group('tombstone', () {
    test('contains only the allowed non-personal fields', () {
      final tombstone = DeletionRules.buildTombstone(
        tokenId: '57',
        deletedAt: DateTime(2026, 10, 23, 12),
        consentGivenAt: DateTime(2026, 9, 1, 9),
        consentVersion: 1,
        withdrawnAt: DateTime(2026, 10, 22, 18),
      );

      expect(
        tombstone.keys.toSet(),
        equals(DeletionRules.tombstoneFieldWhitelist.toSet()),
      );
      for (final forbidden in [
        'parentName',
        'parentMobile',
        'childName',
        'aadhaarNumber',
        'aadhaar',
        'applicationId',
        'childDob',
        'documents',
        'address',
      ]) {
        expect(
          tombstone.containsKey(forbidden),
          isFalse,
          reason: 'tombstone must not contain $forbidden',
        );
      }
    });

    test('omits optional metadata when absent', () {
      final tombstone = DeletionRules.buildTombstone(
        tokenId: '57',
        deletedAt: DateTime(2026, 10, 23, 12),
      );
      expect(tombstone.keys.toSet(), {'tokenId', 'deletedAt'});
    });
  });
}
