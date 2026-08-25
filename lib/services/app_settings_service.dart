import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const webAppUrlKey = 'web_app_url';
  static const payloadRootKey = 'payload_root_key';
  static const incomeCategoriesKey = 'income_categories';
  static const expenseCategoriesKey = 'expense_categories';
  static const planNotificationHourKey = 'plan_notification_hour';
  static const planNotificationMinuteKey = 'plan_notification_minute';
  static const hideBalanceKey = 'hide_balance';
  static const appThemeKey = 'app_theme';
  static const themeModeKey = 'theme_mode';
  static const appFontFamilyKey = 'app_font_family';
  static const geminiApiKeyKey = 'gemini_api_key';
  static const geminiModelKey = 'gemini_model';
  static const showCalculatorShortcutKey = 'show_calculator_shortcut';
  static const showAiAssistantShortcutKey = 'show_ai_assistant_shortcut';

  static const defaultMapping = {
    'id': 'id',
    'book_period_id': 'book_period_id',
    'financial_plan_id': 'financial_plan_id',
    'title': 'title',
    'amount': 'amount',
    'type': 'type',
    'category': 'category',
    'date': 'date',
    'time': 'time',
    'is_synced': 'is_synced',
  };

  static const defaultIncomeCategories = ['Gaji', 'Bonus', 'Lain-lain'];
  static const defaultExpenseCategories = [
    'Pengeluaran',
    'Tabungan/Investasi',
    'Needs',
  ];

  Future<String> getWebAppUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(webAppUrlKey) ?? '';
  }

  Future<void> saveWebAppUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(webAppUrlKey, url);
  }

  Future<String> getPayloadRootKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(payloadRootKey) ?? 'transactions';
  }

  Future<void> savePayloadRootKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(payloadRootKey, value);
  }

  Future<Map<String, String>> getJsonKeyMapping() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, String>{};

    for (final key in defaultMapping.keys) {
      final prefKey = 'json_key_$key';
      result[key] = prefs.getString(prefKey) ?? defaultMapping[key]!;
    }

    return result;
  }

  Future<void> saveJsonKeyMapping(Map<String, String> mapping) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in mapping.entries) {
      await prefs.setString('json_key_${entry.key}', entry.value);
    }
  }

  Future<List<String>> getIncomeCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final result = prefs.getStringList(incomeCategoriesKey);
    if (result == null || result.isEmpty) {
      return defaultIncomeCategories;
    }
    return result;
  }

  Future<void> saveIncomeCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(incomeCategoriesKey, categories);
  }

  Future<List<String>> getExpenseCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final result = prefs.getStringList(expenseCategoriesKey);
    if (result == null || result.isEmpty) {
      return defaultExpenseCategories;
    }
    return result;
  }

  Future<void> saveExpenseCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(expenseCategoriesKey, categories);
  }

  Future<int> getPlanNotificationHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(planNotificationHourKey) ?? 8;
  }

  Future<int> getPlanNotificationMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(planNotificationMinuteKey) ?? 0;
  }

  Future<void> savePlanNotificationTime({
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(planNotificationHourKey, hour);
    await prefs.setInt(planNotificationMinuteKey, minute);
  }

  Future<bool> getHideBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(hideBalanceKey) ?? false;
  }

  Future<void> saveHideBalance(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hideBalanceKey, value);
  }

  Future<String> getAppTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(appThemeKey) ?? 'classic';
  }

  Future<void> saveAppTheme(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(appThemeKey, themeName);
  }

  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(themeModeKey) ?? 'system';
  }

  Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeModeKey, mode);
  }

  Future<String> getAppFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(appFontFamilyKey) ?? 'default';
  }

  Future<void> saveAppFontFamily(String fontName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(appFontFamilyKey, fontName);
  }

  /// API key disimpan di Keychain (iOS) / EncryptedSharedPreferences (Android),
  /// bukan di SharedPreferences yang berupa file polos.
  static const _secureStorage = FlutterSecureStorage();

  Future<String> getGeminiApiKey() async {
    final secure = await _secureStorage.read(key: geminiApiKeyKey);
    if (secure != null && secure.isNotEmpty) return secure;

    // Migrasi sekali jalan dari penyimpanan lama yang tidak terenkripsi.
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(geminiApiKeyKey) ?? '';
    if (legacy.isNotEmpty) {
      await _secureStorage.write(key: geminiApiKeyKey, value: legacy);
      await prefs.remove(geminiApiKeyKey);
    }
    return legacy;
  }

  Future<void> saveGeminiApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(geminiApiKeyKey);
    if (apiKey.isEmpty) {
      await _secureStorage.delete(key: geminiApiKeyKey);
      return;
    }
    await _secureStorage.write(key: geminiApiKeyKey, value: apiKey);
  }

  /// Kedua pintasan melayang menyala secara bawaan — itu keadaan yang sudah
  /// dipakai pengguna sebelum setelan ini ada, jadi memperbarui aplikasi tidak
  /// boleh diam-diam menghilangkan tombol yang sudah jadi kebiasaan.
  Future<bool> getShowCalculatorShortcut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(showCalculatorShortcutKey) ?? true;
  }

  Future<void> saveShowCalculatorShortcut(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(showCalculatorShortcutKey, value);
  }

  Future<bool> getShowAiAssistantShortcut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(showAiAssistantShortcutKey) ?? true;
  }

  Future<void> saveShowAiAssistantShortcut(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(showAiAssistantShortcutKey, value);
  }

  Future<String> getGeminiModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(geminiModelKey) ?? 'gemini-flash-lite-latest';
  }

  Future<void> saveGeminiModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(geminiModelKey, model);
  }
}
