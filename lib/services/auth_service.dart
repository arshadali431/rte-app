import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Verify credentials against Firestore
  Future<bool> signIn(String username, String password) async {
    try {
      final doc = await _db
          .collection('rte-2026-27')
          .doc('admin')
          .get();

      if (!doc.exists) return false;

      final data = doc.data()!;
      return data['username'] == username &&
             data['password'] == password;
    } catch (e) {
      return false;
    }
  }

  // Save login state
  Future<void> saveLoginState(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_office_logged_in', true);
    await prefs.setString('office_username', username);
  }

  // Clear login state
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_office_logged_in', false);
    await prefs.remove('office_username');
  }

  // Check if already logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_office_logged_in') ?? false;
  }

  // Get saved username
  Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('office_username') ?? '';
  }
}
