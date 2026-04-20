import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  static const _tokenKey = 'session_token';
  static const _userNameKey = 'session_user_name';
  static const _userEmailKey = 'session_user_email';
  static const _userPhoneKey = 'session_user_phone';

  Future<void> saveSession({
    required String token,
    required String name,
    required String email,
    required String phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userNameKey, name);
    await prefs.setString(_userEmailKey, email);
    await prefs.setString(_userPhoneKey, phone);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<Map<String, String>?> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_userNameKey);
    final email = prefs.getString(_userEmailKey);
    final phone = prefs.getString(_userPhoneKey);
    if (name == null || email == null || phone == null) {
      return null;
    }
    return {
      'name': name,
      'email': email,
      'phone': phone,
    };
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userPhoneKey);
  }
}
