import 'package:flutter/material.dart';
import '../services/app_settings_service.dart';
import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._appSettingsService);

  final AppSettingsService _appSettingsService;

  AppThemeStyle _currentStyle = AppThemeStyle.classic;
  ThemeMode _themeMode = ThemeMode.system;
  String _appFontFamily = 'default';

  AppThemeStyle get currentStyle => _currentStyle;
  ThemeMode get themeMode => _themeMode;
  String get appFontFamily => _appFontFamily;

  ThemeData get themeData => AppTheme.getThemeData(_currentStyle, fontFamily: _appFontFamily);
  ThemeData get darkThemeData =>
      AppTheme.getThemeData(_currentStyle, brightness: Brightness.dark, fontFamily: _appFontFamily);

  Future<void> init() async {
    final styleString = await _appSettingsService.getAppTheme();
    if (styleString == 'neoBrutalism') {
      _currentStyle = AppThemeStyle.neoBrutalism;
    } else {
      _currentStyle = AppThemeStyle.classic;
    }

    final modeString = await _appSettingsService.getThemeMode();
    _themeMode = ThemeMode.values.firstWhere(
      (e) => e.name == modeString,
      orElse: () => ThemeMode.system,
    );

    _appFontFamily = await _appSettingsService.getAppFontFamily();

    notifyListeners();
  }

  Future<void> setTheme(AppThemeStyle style) async {
    _currentStyle = style;
    notifyListeners();
    await _appSettingsService.saveAppTheme(style.name);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _appSettingsService.saveThemeMode(mode.name);
  }

  Future<void> setAppFontFamily(String fontName) async {
    _appFontFamily = fontName;
    notifyListeners();
    await _appSettingsService.saveAppFontFamily(fontName);
  }
}
