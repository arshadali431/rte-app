import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'constants.dart';

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    String text = newValue.text.replaceAll('-', '');
    String formatted = "";

    for (int i = 0; i < text.length; i++) {
      formatted += text[i];
      if (i == 1 || i == 3) {
        if (formatted.length < 10) formatted += "-";
      }
      if (formatted.length >= 10) break;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class AppUtils {
  // Format Timestamp to "dd MMM yyyy"
  static String formatDate(dynamic date) {
    if (date == null) return 'N/A';
    DateTime dt;
    if (date is Timestamp) {
      dt = date.toDate();
    } else if (date is DateTime) {
      dt = date;
    } else {
      return 'N/A';
    }
    return DateFormat('dd MMM yyyy').format(dt);
  }

  // Format doc type string to display name
  static String formatDocType(String docType) {
    return AppConstants.docTypeNames[docType] ?? docType;
  }

  // Format status string to display name
  static String formatStatus(String status) {
    switch (status) {
       case 'pending': return 'Pending';
       case 'in_progress': return 'In Progress';
       case 'completed': return 'Completed';
       default: return status.toUpperCase().replaceAll('_', ' ');
    }
  }

  // Validate Indian mobile number (10 digits, starts with 6-9)
  static bool isValidMobile(String mobile) {
    return RegExp(r'^[6-9]\d{9}$').hasMatch(mobile);
  }

  // Validate Aadhaar number (12 digits)
  static bool isValidAadhaar(String aadhaar) {
    return RegExp(r'^\d{12}$').hasMatch(aadhaar);
  }
}
