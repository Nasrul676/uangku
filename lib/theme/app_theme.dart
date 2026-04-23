import 'package:flutter/material.dart';

enum AppThemeStyle {
  classic,
  neoBrutalism,
}

class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.cardBorder,
    required this.buttonBorder,
    required this.cardShadow,
    this.primaryActionColor,
    this.negativeActionColor,
  });

  final BoxBorder? cardBorder;
  final BoxBorder? buttonBorder;
  final List<BoxShadow>? cardShadow;
  final Color? primaryActionColor;
  final Color? negativeActionColor;

  @override
  ThemeExtension<AppThemeExtension> copyWith({
    BoxBorder? cardBorder,
    BoxBorder? buttonBorder,
    List<BoxShadow>? cardShadow,
    Color? primaryActionColor,
    Color? negativeActionColor,
  }) {
    return AppThemeExtension(
      cardBorder: cardBorder ?? this.cardBorder,
      buttonBorder: buttonBorder ?? this.buttonBorder,
      cardShadow: cardShadow ?? this.cardShadow,
      primaryActionColor: primaryActionColor ?? this.primaryActionColor,
      negativeActionColor: negativeActionColor ?? this.negativeActionColor,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(
      covariant ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) {
      return this;
    }
    return AppThemeExtension(
      cardBorder: BoxBorder.lerp(cardBorder, other.cardBorder, t),
      buttonBorder: BoxBorder.lerp(buttonBorder, other.buttonBorder, t),
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t),
      primaryActionColor: Color.lerp(primaryActionColor, other.primaryActionColor, t),
      negativeActionColor: Color.lerp(negativeActionColor, other.negativeActionColor, t),
    );
  }
}

class AppTheme {
  static const Color cream = Color(0xFFF5F2E9);
  static const Color borderColor = Color(0xFF1E1E1E);
  static const Color classicBorder = Color(0x331E1E1E);
  static const Color lightScaffold = Color(0xFFFAFAFA);
  static const Color neoScaffold = Color(0xFFE6EBFA); // Light bluish for brutalism

  static ThemeData getThemeData(AppThemeStyle style) {
    if (style == AppThemeStyle.neoBrutalism) {
      return _buildNeoBrutalismTheme();
    }
    return _buildClassicTheme();
  }

  static ThemeData _buildClassicTheme() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'DMSans',
      scaffoldBackgroundColor: lightScaffold,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFEDD07D),
        surface: Colors.white,
        brightness: Brightness.light,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: classicBorder, width: 1.0),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: borderColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'DMSerifDisplay',
          color: borderColor,
          fontSize: 34,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: classicBorder, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: classicBorder, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFEDD07D),
          foregroundColor: borderColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: classicBorder, width: 1.0),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      textTheme: _textTheme(),
      extensions: [
        AppThemeExtension(
          cardBorder: Border.all(color: classicBorder, width: 1.0),
          buttonBorder: Border.all(color: classicBorder, width: 1.0),
          cardShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ],
          primaryActionColor: const Color(0xFFA4DBB2),
          negativeActionColor: const Color(0xFFF0C8C8),
        ),
      ],
    );
  }

  static ThemeData _buildNeoBrutalismTheme() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'DMSans',
      scaffoldBackgroundColor: neoScaffold,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFEDD07D),
        surface: cream,
        brightness: Brightness.light,
      ),
      cardTheme: CardThemeData(
        color: cream,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderColor, width: 1.2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: borderColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'DMSerifDisplay',
          color: borderColor,
          fontSize: 34,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFEDD07D),
          foregroundColor: borderColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: borderColor, width: 1.2),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      textTheme: _textTheme(),
      extensions: [
        AppThemeExtension(
          cardBorder: Border.all(color: borderColor, width: 1.2), // Reduced by half (1.2 instead of ~2-3 thick)
          buttonBorder: Border.all(color: borderColor, width: 1.2),
          cardShadow: const [
            BoxShadow(
              color: borderColor,
              blurRadius: 0,
              offset: Offset(4, 4), // Solid drop shadow
            )
          ],
          primaryActionColor: const Color(0xFFA4DBB2),
          negativeActionColor: const Color(0xFFF0C8C8),
        ),
      ],
    );
  }

  static TextTheme _textTheme() {
    return const TextTheme().copyWith(
      headlineMedium: const TextStyle(
        fontFamily: 'DMSerifDisplay',
        fontSize: 32,
        color: borderColor,
        fontWeight: FontWeight.w400,
      ),
      titleLarge: const TextStyle(
        fontFamily: 'DMSerifDisplay',
        fontSize: 30,
        color: borderColor,
        fontWeight: FontWeight.w400,
      ),
      titleMedium: const TextStyle(
        fontFamily: 'DMSerifDisplay',
        fontSize: 22,
        color: borderColor,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
