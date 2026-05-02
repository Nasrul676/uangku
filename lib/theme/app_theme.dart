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

  static const Color darkScaffold = Color(0xFF121212);
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color darkBorder = Color(0xFF333333);
  static const Color darkText = Color(0xFFF5F5F5);

  static ThemeData getThemeData(AppThemeStyle style,
      {Brightness brightness = Brightness.light}) {
    if (style == AppThemeStyle.neoBrutalism) {
      return _buildNeoBrutalismTheme(brightness);
    }
    return _buildClassicTheme(brightness);
  }

  static ThemeData _buildClassicTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkScaffold : lightScaffold;
    final cardBg = isDark ? darkCard : Colors.white;
    final textCol = isDark ? darkText : borderColor;
    final borderCol = isDark ? darkBorder : classicBorder;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'DMSans',
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFEDD07D),
        surface: cardBg,
        brightness: brightness,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderCol, width: 1.0),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cardBg,
        foregroundColor: textCol,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'DMSerifDisplay',
          color: textCol,
          fontSize: 34,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderCol, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderCol, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? neoYellow : borderColor, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFEDD07D),
          foregroundColor: borderColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderCol, width: 1.0),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      textTheme: _textTheme(textCol),
      extensions: [
        AppThemeExtension(
          cardBorder: Border.all(color: borderCol, width: 1.0),
          buttonBorder: Border.all(color: borderCol, width: 1.0),
          cardShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04),
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

  static ThemeData _buildNeoBrutalismTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkScaffold : neoScaffold;
    final paperCol = isDark ? darkCard : neoPaper;
    final inkCol = isDark ? neoPaper : neoInk;

    final neoColorScheme = ColorScheme(
      brightness: brightness,
      primary: neoYellow,
      onPrimary: neoInk,
      secondary: neoBlue,
      onSecondary: neoInk,
      error: const Color(0xFFCC3A2B),
      onError: Colors.white,
      surface: paperCol,
      onSurface: inkCol,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'DMSans',
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: neoColorScheme,
      iconTheme: IconThemeData(color: inkCol, size: 22),
      dividerTheme: DividerThemeData(
        color: inkCol,
        thickness: 2,
        space: 24,
      ),
      cardTheme: CardThemeData(
        color: paperCol,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: inkCol, width: 2),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: paperCol,
        foregroundColor: inkCol,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'DMSerifDisplay',
          color: inkCol,
          fontSize: 34,
        ),
        iconTheme: IconThemeData(color: inkCol, size: 22),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paperCol,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: inkCol, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: inkCol, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: inkCol, width: 2.5),
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
          foregroundColor: inkCol,
          backgroundColor: paperCol,
          side: BorderSide(color: inkCol, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: inkCol,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: neoBlue,
        selectedColor: neoMint,
        disabledColor: const Color(0xFFE2E2E2),
        deleteIconColor: inkCol,
        labelStyle: TextStyle(color: neoInk, fontWeight: FontWeight.w700),
        secondaryLabelStyle: const TextStyle(
          color: neoInk,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(color: inkCol, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return isDark ? neoYellow : neoInk;
          return paperCol;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return neoMint;
          return neoLavender;
        }),
        trackOutlineColor: WidgetStateProperty.all(inkCol),
        trackOutlineWidth: WidgetStateProperty.all(2),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return neoYellow;
          return paperCol;
        }),
        checkColor: WidgetStateProperty.all(neoInk),
        side: BorderSide(color: inkCol, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return neoCoral;
          return inkCol;
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: neoCoral,
        foregroundColor: neoInk,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          side: BorderSide(color: inkCol, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: inkCol,
        contentTextStyle: TextStyle(
          color: paperCol,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: paperCol,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: inkCol, width: 2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: paperCol,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          side: BorderSide(color: inkCol, width: 2),
        ),
      ),
      textTheme: _textTheme(inkCol),
      extensions: [
        AppThemeExtension(
          cardBorder: Border.all(color: inkCol, width: 2),
          buttonBorder: Border.all(color: neoInk, width: 2),
          cardShadow: [
            BoxShadow(color: inkCol, blurRadius: 0, offset: const Offset(6, 6)),
          ],
          primaryActionColor: neoMint,
          negativeActionColor: neoCoral,
        ),
      ],
    );
  }

  static TextTheme _textTheme(Color textColor) {
    return const TextTheme().copyWith(
      headlineMedium: TextStyle(
        fontFamily: 'DMSerifDisplay',
        fontSize: 32,
        color: textColor,
        fontWeight: FontWeight.w400,
      ),
      titleLarge: TextStyle(
        fontFamily: 'DMSerifDisplay',
        fontSize: 30,
        color: textColor,
        fontWeight: FontWeight.w400,
      ),
      titleMedium: TextStyle(
        fontFamily: 'DMSerifDisplay',
        fontSize: 22,
        color: textColor,
        fontWeight: FontWeight.w400,
      ),
      bodyLarge: TextStyle(color: textColor),
      bodyMedium: TextStyle(color: textColor),
      bodySmall: TextStyle(color: textColor.withOpacity(0.7)),
    );
  }
}
