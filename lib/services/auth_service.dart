import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _userNameKey = 'user_name';
  static const _authNameKey = 'auth_name';
  static const _authEmailKey = 'auth_email';
  static const _authPasswordKey = 'auth_password';
  static const _isLoggedInKey = 'auth_logged_in';
  static const _rememberMeKey = 'auth_remember_me';

  Future<bool> shouldSkipAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    final rememberMe = prefs.getBool(_rememberMeKey) ?? false;
    return isLoggedIn && rememberMe;
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final normalizedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();

    await prefs.setString(_authNameKey, normalizedName);
    await prefs.setString(_userNameKey, normalizedName);
    await prefs.setString(_authEmailKey, normalizedEmail);
    await prefs.setString(_authPasswordKey, password);
    await prefs.setBool(_isLoggedInKey, true);

    // Register tidak memakai checkbox ingat saya.
    await prefs.setBool(_rememberMeKey, false);
  }

  Future<bool> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(_authEmailKey)?.trim().toLowerCase();
    final savedPassword = prefs.getString(_authPasswordKey) ?? '';

    final normalizedEmail = email.trim().toLowerCase();
    if (savedEmail == null || savedEmail.isEmpty || savedPassword.isEmpty) {
      return false;
    }

    if (normalizedEmail != savedEmail || password != savedPassword) {
      return false;
    }

    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setBool(_rememberMeKey, rememberMe);

    final savedName = prefs.getString(_authNameKey) ?? '';
    if (savedName.trim().isNotEmpty) {
      await prefs.setString(_userNameKey, savedName.trim());
    }

    return true;
  }

  Future<String> getCurrentUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_authNameKey) ??
            prefs.getString(_userNameKey) ??
            '')
        .trim();
  }

  Future<String> getCurrentUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_authEmailKey) ?? '').trim();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, false);
    await prefs.setBool(_rememberMeKey, false);
  }

  Future<bool> verifyPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPassword = prefs.getString(_authPasswordKey) ?? '';
    return password == savedPassword;
  }
}
