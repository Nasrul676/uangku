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
}
