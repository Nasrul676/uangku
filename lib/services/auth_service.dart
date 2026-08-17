import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan kredensial lokal. Password TIDAK pernah disimpan apa adanya —
/// yang tersimpan hanya salt acak dan hasil PBKDF2-HMAC-SHA256.
class AuthService {
  static const _userNameKey = 'user_name';
  static const _authNameKey = 'auth_name';
  static const _authEmailKey = 'auth_email';

  /// Field lama berisi password plaintext. Masih dibaca sekali untuk migrasi,
  /// lalu dihapus. Jangan dipakai untuk penulisan baru.
  static const _legacyPasswordKey = 'auth_password';

  static const _passwordHashKey = 'auth_password_hash';
  static const _passwordSaltKey = 'auth_password_salt';
  static const _isLoggedInKey = 'auth_logged_in';
  static const _rememberMeKey = 'auth_remember_me';

  static const _iterations = 120000;
  static const _keyLength = 32;

  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// PBKDF2-HMAC-SHA256. Sengaja mahal supaya brute-force atas file
  /// SharedPreferences yang bocor tetap tidak praktis.
  static String _derive(String password, String salt) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final saltBytes = base64Decode(salt);
    final output = Uint8List(_keyLength);
    var offset = 0;
    var block = 1;

    while (offset < _keyLength) {
      final blockIndex = Uint8List(4)
        ..[0] = (block >> 24) & 0xff
        ..[1] = (block >> 16) & 0xff
        ..[2] = (block >> 8) & 0xff
        ..[3] = block & 0xff;

      var u = Uint8List.fromList(
        hmac.convert([...saltBytes, ...blockIndex]).bytes,
      );
      final accumulator = Uint8List.fromList(u);

      for (var i = 1; i < _iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < accumulator.length; j++) {
          accumulator[j] ^= u[j];
        }
      }

      final take = min(accumulator.length, _keyLength - offset);
      accumulator.sublist(0, take).asMap().forEach((i, byte) {
        output[offset + i] = byte;
      });
      offset += take;
      block++;
    }

    return base64Encode(output);
  }

  /// Perbandingan waktu-konstan supaya tidak membocorkan hasil lewat timing.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<void> _writePassword(SharedPreferences prefs, String password) async {
    final salt = _generateSalt();
    await prefs.setString(_passwordSaltKey, salt);
    await prefs.setString(_passwordHashKey, _derive(password, salt));
    await prefs.remove(_legacyPasswordKey);
  }

  /// Akun lama menyimpan password plaintext. Saat login/verifikasi pertama
  /// setelah update, cocokkan dengan field lama lalu langsung upgrade ke hash.
  Future<bool> _matches(SharedPreferences prefs, String password) async {
    final salt = prefs.getString(_passwordSaltKey);
    final hash = prefs.getString(_passwordHashKey);

    if (salt != null && hash != null && salt.isNotEmpty && hash.isNotEmpty) {
      return _constantTimeEquals(hash, _derive(password, salt));
    }

    final legacy = prefs.getString(_legacyPasswordKey) ?? '';
    if (legacy.isEmpty) return false;
    if (!_constantTimeEquals(legacy, password)) return false;

    await _writePassword(prefs, password);
    return true;
  }

  Future<bool> hasCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final hash = prefs.getString(_passwordHashKey) ?? '';
    final legacy = prefs.getString(_legacyPasswordKey) ?? '';
    return hash.isNotEmpty || legacy.isNotEmpty;
  }

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
    await _writePassword(prefs, password);
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

    final normalizedEmail = email.trim().toLowerCase();
    if (savedEmail == null || savedEmail.isEmpty) {
      return false;
    }

    if (normalizedEmail != savedEmail) {
      return false;
    }

    if (!await _matches(prefs, password)) {
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
    if (password.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return _matches(prefs, password);
  }
}
