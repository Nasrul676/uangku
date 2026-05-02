import 'package:flutter/material.dart';

enum AppThemeStyle { classic, neoBrutalism }

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
    covariant ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) {
      return this;
    }
    return AppThemeExtension(
      cardBorder: BoxBorder.lerp(cardBorder, other.cardBorder, t),
      buttonBorder: BoxBorder.lerp(buttonBorder, other.buttonBorder, t),
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t),
      primaryActionColor: Color.lerp(
        primaryActionColor,
        other.primaryActionColor,
        t,
      ),
      negativeActionColor: Color.lerp(
        negativeActionColor,
        other.negativeActionColor,
        t,
      ),
    );
  }
}

class AppTheme {
  static const Color cream = Color(0xFFF5F2E9);
  static const Color borderColor = Color(0xFF1E1E1E);
  static const Color classicBorder = Color(0x331E1E1E);
  static const Color lightScaffold = Color(0xFFFAFAFA);
  static const Color neoScaffold = Color(0xFFF4F2ED);
  static const Color neoPaper = Color(0xFFFFFCF5);
  static const Color neoInk = Color(0xFF121212);
  static const Color neoYellow = Color(0xFFFFD84D);
  static const Color neoBlue = Color(0xFF8EC5FF);
  static const Color neoMint = Color(0xFF98E6A8);
  static const Color neoCoral = Color(0xFFFF9D8E);
  static const Color neoLavender = Color(0xFFC8B6FF);

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
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
            ),
          ],
          primaryActionColor: const Color(0xFFA4DBB2),
          negativeActionColor: const Color(0xFFF0C8C8),
        ),
      ],
    );
  }

  static ThemeData _buildNeoBrutalismTheme() {
    const neoColorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: neoYellow,
      onPrimary: neoInk,
      secondary: neoBlue,
      onSecondary: neoInk,
      error: Color(0xFFCC3A2B),
      onError: Colors.white,
      surface: neoPaper,
      onSurface: neoInk,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'DMSans',
      scaffoldBackgroundColor: neoScaffold,
      colorScheme: neoColorScheme,
      iconTheme: const IconThemeData(color: neoInk, size: 22),
      dividerTheme: const DividerThemeData(
        color: neoInk,
        thickness: 2,
        space: 24,
      ),
      cardTheme: CardThemeData(
        color: neoPaper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: neoInk, width: 2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: neoPaper,
        foregroundColor: neoInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'DMSerifDisplay',
          color: neoInk,
          fontSize: 34,
        ),
        iconTheme: IconThemeData(color: neoInk, size: 22),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: neoPaper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: neoInk, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: neoInk, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: neoInk, width: 2.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: neoYellow,
          foregroundColor: neoInk,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: neoInk, width: 2),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: neoInk,
          backgroundColor: neoPaper,
          side: const BorderSide(color: neoInk, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: neoInk,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: neoBlue,
        selectedColor: neoMint,
        disabledColor: const Color(0xFFE2E2E2),
        deleteIconColor: neoInk,
        labelStyle: const TextStyle(color: neoInk, fontWeight: FontWeight.w700),
        secondaryLabelStyle: const TextStyle(
          color: neoInk,
          fontWeight: FontWeight.w700,
        ),
        side: const BorderSide(color: neoInk, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return neoInk;
          return neoPaper;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return neoMint;
          return neoLavender;
        }),
        trackOutlineColor: WidgetStateProperty.all(neoInk),
        trackOutlineWidth: WidgetStateProperty.all(2),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return neoYellow;
          return neoPaper;
        }),
        checkColor: WidgetStateProperty.all(neoInk),
        side: const BorderSide(color: neoInk, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return neoCoral;
          return neoInk;
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: neoCoral,
        foregroundColor: neoInk,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          side: BorderSide(color: neoInk, width: 2),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: neoInk,
        contentTextStyle: TextStyle(
          color: neoPaper,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: neoPaper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: neoInk, width: 2),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: neoPaper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          side: BorderSide(color: neoInk, width: 2),
        ),
      ),
      textTheme: _textTheme(),
      extensions: [
        AppThemeExtension(
          cardBorder: Border.all(color: neoInk, width: 2),
          buttonBorder: Border.all(color: neoInk, width: 2),
          cardShadow: const [
            BoxShadow(color: neoInk, blurRadius: 0, offset: Offset(6, 6)),
          ],
          primaryActionColor: neoMint,
          negativeActionColor: neoCoral,
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
