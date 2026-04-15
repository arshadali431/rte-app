import 'package:flutter/material.dart';

class AppConstants {
  // Collection Names
  static const String kTokensCollection = 'tokens';
  static const String kChildrenCollection = 'children';
  static const String kDocumentsCollection = 'documents';
  static const String kMetaCollection = 'meta';
  
  // Document Names
  static const String kTokenCounterDoc = 'token_counter';
  static const String kAdminCollection = 'rte-2026-27';
  static const String kAdminDoc = 'admin';

  // Statuses
  static const String statusPending = 'pending';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';

  // Mandatory documents
  static const List<String> mandatoryDocTypes = [
    'child_photo',
    'child_birth_cert',
    'child_aadhaar',
    'income_cert',
    'parent_pan',
    'self_declaration',
    'parent_signature',
  ];

  // Combined list for logic (Mandatory + any that exist in DB)
  static List<String> get allDocTypes => mandatoryDocTypes;

  // Display names
  static const Map<String, String> docTypeNames = {
    'child_photo': 'Child Passport Photo',
    'child_birth_cert': 'Child Birth Certificate',
    'child_aadhaar': 'Child Aadhaar Card',
    'income_cert': 'Father Income Certificate',
    'parent_pan': 'Parent PAN Card',
    'self_declaration': 'Self Declaration',
    'parent_signature': 'Parent Signature',
  };

  // Icons for each doc type
  static const Map<String, IconData> docTypeIcons = {
    'child_photo': Icons.face_rounded,
    'child_birth_cert': Icons.cake_rounded,
    'child_aadhaar': Icons.credit_card_rounded,
    'income_cert': Icons.account_balance_rounded,
    'parent_pan': Icons.credit_card_rounded,
    'self_declaration': Icons.verified_user_rounded,
    'parent_signature': Icons.draw_rounded,
  };
}
