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
    'child_aadhaar',
    'child_birth_cert',
    'father_aadhaar',
    'mother_aadhaar',
    'father_pan',
    'income_cert',
    'father_signature',
    'bank_passbook',
  ];

  // Optional documents
  static const List<String> optionalDocTypes = [
    'bpl',
    'caste',
    'anganwadi',
    'single_girl',
  ];

  // Combined list for logic
  static List<String> get allDocTypes => [...mandatoryDocTypes, ...optionalDocTypes];

  // Display names
  static const Map<String, String> docTypeNames = {
    // Mandatory
    'child_photo': 'Child Passport Size Photo',
    'child_aadhaar': 'Child Aadhaar Card',
    'child_birth_cert': 'Child Birth Certificate',
    'father_aadhaar': 'Father Aadhaar Card',
    'mother_aadhaar': 'Mother Aadhaar Card',
    'father_pan': 'Father PAN Card',
    'income_cert': 'Income Certificate',
    'father_signature': 'Father Signature',
    'bank_passbook': 'Bank Passbook (Child/Parent)',
    // Optional
    'bpl': 'BPL Card',
    'caste': 'Caste Certificate',
    'anganwadi': 'Anganwadi Certificate',
    'single_girl': 'Single Girl Child Certificate',
  };

  // Icons for each doc type
  static const Map<String, IconData> docTypeIcons = {
    'child_photo': Icons.face_rounded,
    'child_aadhaar': Icons.credit_card_rounded,
    'child_birth_cert': Icons.cake_rounded,
    'father_aadhaar': Icons.credit_card_rounded,
    'mother_aadhaar': Icons.credit_card_rounded,
    'father_pan': Icons.receipt_long_rounded,
    'income_cert': Icons.account_balance_rounded,
    'father_signature': Icons.draw_rounded,
    'bank_passbook': Icons.account_balance_wallet_rounded,
    'bpl': Icons.card_membership_rounded,
    'caste': Icons.verified_rounded,
    'anganwadi': Icons.school_rounded,
    'single_girl': Icons.girl_rounded,
  };
}
