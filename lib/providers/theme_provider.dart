import 'package:flutter/material.dart';
import '../services/app_settings_service.dart';
import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._appSettingsService);

  final AppSettingsService _appSettingsService;

  AppThemeStyle _currentStyle = AppThemeStyle.classic;

  AppThemeStyle get currentStyle => _currentStyle;
  ThemeData get themeData => AppTheme.getThemeData(_currentStyle);

  Future<void> init() async {
    final styleString = await _appSettingsService.getAppTheme();
    if (styleString == 'neoBrutalism') {
      _currentStyle = AppThemeStyle.neoBrutalism;
    } else {
      _currentStyle = AppThemeStyle.classic;
    }
    notifyListeners();
  }

  Future<void> setTheme(AppThemeStyle style) async {
    _currentStyle = style;
    notifyListeners();
    await _appSettingsService.saveAppTheme(style.name);
  }
}
