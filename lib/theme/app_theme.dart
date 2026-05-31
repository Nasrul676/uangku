import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  // ─── Neo-Brutalism Palette ───────────────────────────────────────────────────
  static const Color cream       = Color(0xFFF5F2E9);
  static const Color borderColor = Color(0xFF1E1E1E);
  static const Color classicBorder = Color(0x331E1E1E);
  static const Color lightScaffold = Color(0xFFFAFAFA);
  static const Color neoScaffold   = Color(0xFFF4F2ED);
  static const Color neoPaper      = Color(0xFFFFFCF5);
  static const Color neoInk        = Color(0xFF121212);
  static const Color neoYellow     = Color(0xFFFFD84D);
  static const Color neoBlue       = Color(0xFF8EC5FF);
  static const Color neoMint       = Color(0xFF98E6A8);
  static const Color neoCoral      = Color(0xFFFF9D8E);
  static const Color neoLavender   = Color(0xFFC8B6FF);

  // ─── Dark Mode ───────────────────────────────────────────────────────────────
  static const Color darkScaffold = Color(0xFF121212);
  static const Color darkCard     = Color(0xFF1E1E1E);
  static const Color darkBorder   = Color(0xFF333333);
  static const Color darkText     = Color(0xFFF5F5F5);

  // ─── Semantic Color Tokens ───────────────────────────────────────────────────
  /// Warna utama aplikasi — dipakai untuk primary action, link, dan highlight.
  static const Color primaryBlue  = Color(0xFF0066FF);

  /// Warna untuk nilai pemasukan / positif / sukses.
  static const Color incomeGreen  = Color(0xFF2A9D50);

  /// Warna untuk nilai pengeluaran / negatif / error.
  static const Color expenseRed   = Color(0xFFC24545);

  /// Versi light/container dari incomeGreen (chip background, badge).
  static const Color incomeLight  = Color(0xFFA4DBB2);

  /// Versi light/container dari expenseRed (chip background, badge).
  static const Color expenseLight = Color(0xFFF0C8C8);

  /// Warna icon khusus (teal gelap) untuk FAB quick add.
  static const Color fabIconColor = Color(0xFF1F5A62);

  /// Warna background FAB quick add.
  static const Color fabBgColor   = Color(0xFFF5BB8A);

  static ThemeData getThemeData(
    AppThemeStyle style, {
    Brightness brightness = Brightness.light,
    String fontFamily = 'default',
  }) {
    if (style == AppThemeStyle.neoBrutalism) {
      return _buildNeoBrutalismTheme(brightness, fontFamily);
    }
    return _buildClassicTheme(brightness, fontFamily);
  }

  static String? _getResolvedFontFamily(String fontChoice) {
    switch (fontChoice) {
      case 'feeling_cute':
        return GoogleFonts.fredoka().fontFamily;
      case 'feeling_childlike':
        return GoogleFonts.mali().fontFamily;
      case 'monospace':
        return GoogleFonts.spaceMono().fontFamily;
      case 'blobby':
        return GoogleFonts.sniglet().fontFamily;
      case 'pixel':
        return GoogleFonts.vt323().fontFamily;
      case 'informal':
        return GoogleFonts.caveat().fontFamily;
      case 'formal':
        return GoogleFonts.merriweather().fontFamily;
      default:
        return 'PlusJakartaSans';
    }
  }

  static String? _getResolvedDisplayFont(String fontChoice) {
    if (fontChoice == 'default') {
      return 'DMSerifDisplay';
    }
    return _getResolvedFontFamily(fontChoice);
  }

  static ThemeData _buildClassicTheme(Brightness brightness, String fontChoice) {
    final isDark = brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkScaffold : lightScaffold;
    final cardBg = isDark ? darkCard : Colors.white;
    final textCol = isDark ? darkText : borderColor;
    final borderCol = isDark ? darkBorder : classicBorder;
    
    final resolvedFontFamily = _getResolvedFontFamily(fontChoice);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: resolvedFontFamily,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        error: expenseRed,
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
          fontFamily: _getResolvedDisplayFont(fontChoice),
          color: textCol,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
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
          borderSide: BorderSide(
            color: isDark ? neoBlue : borderColor,
            width: 1.5,
          ),
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
      textTheme: _textTheme(textCol, fontChoice),
      extensions: [
        AppThemeExtension(
          cardBorder: Border.all(color: borderCol, width: 1.0),
          buttonBorder: Border.all(color: borderCol, width: 1.0),
          cardShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.2)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          primaryActionColor: incomeLight,
          negativeActionColor: expenseLight,
        ),
      ],
    );
  }

  static ThemeData _buildNeoBrutalismTheme(Brightness brightness, String fontChoice) {
    final isDark = brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkScaffold : neoScaffold;
    final paperCol = isDark ? darkCard : neoPaper;
    final inkCol = isDark ? neoPaper : neoInk;

    final neoColorScheme = ColorScheme(
      brightness: brightness,
      primary: neoBlue,
      onPrimary: neoInk,
      secondary: neoBlue,
      onSecondary: neoInk,
      error: expenseRed,
      onError: Colors.white,
      surface: paperCol,
      onSurface: inkCol,
    );

    final resolvedFontFamily = _getResolvedFontFamily(fontChoice);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: resolvedFontFamily,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: neoColorScheme,
      iconTheme: IconThemeData(color: inkCol, size: 22),
      dividerTheme: DividerThemeData(color: inkCol, thickness: 2, space: 24),
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
          fontFamily: _getResolvedDisplayFont(fontChoice),
          color: inkCol,
          fontSize: 24,
          fontWeight: FontWeight.w700,
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
          backgroundColor: neoBlue,
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
          if (states.contains(WidgetState.selected))
            return isDark ? neoBlue : neoInk;
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
          if (states.contains(WidgetState.selected)) return neoBlue;
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
      textTheme: _textTheme(inkCol, fontChoice),
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

  static TextTheme _textTheme(Color textColor, String fontChoice) {
    final resolvedFontFamily = _getResolvedFontFamily(fontChoice);
    final resolvedDisplayFont = _getResolvedDisplayFont(fontChoice);

    return const TextTheme().copyWith(
      displayLarge: TextStyle(
        fontFamily: resolvedDisplayFont,
        fontSize: 57,
        color: textColor,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
      ),
      displayMedium: TextStyle(
        fontFamily: resolvedDisplayFont,
        fontSize: 45,
        color: textColor,
        fontWeight: FontWeight.w400,
      ),
      displaySmall: TextStyle(
        fontFamily: resolvedDisplayFont,
        fontSize: 36,
        color: textColor,
        fontWeight: FontWeight.w400,
      ),
      headlineLarge: TextStyle(
        fontFamily: resolvedDisplayFont,
        fontSize: 34,
        color: textColor,
        fontWeight: FontWeight.w400,
      ),
      headlineMedium: TextStyle(
        fontFamily: resolvedDisplayFont,
        fontSize: 28,
        color: textColor,
        fontWeight: FontWeight.w400,
      ),
      headlineSmall: TextStyle(
        fontFamily: resolvedDisplayFont,
        fontSize: 24,
        color: textColor,
        fontWeight: FontWeight.w400,
      ),
      titleLarge: TextStyle(
        fontFamily: resolvedDisplayFont,
        fontSize: 22,
        color: textColor,
        fontWeight: FontWeight.w400,
      ),
      titleMedium: TextStyle(
        fontFamily: resolvedFontFamily,
        fontSize: 18,
        color: textColor,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      titleSmall: TextStyle(
        fontFamily: resolvedFontFamily,
        fontSize: 14,
        color: textColor,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      bodyLarge: TextStyle(
        fontFamily: resolvedFontFamily,
        fontSize: 16,
        color: textColor,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
      ),
      bodyMedium: TextStyle(
        fontFamily: resolvedFontFamily,
        fontSize: 14,
        color: textColor,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
      ),
      bodySmall: TextStyle(
        fontFamily: resolvedFontFamily,
        fontSize: 12,
        color: textColor.withOpacity(0.7),
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
      ),
      labelLarge: TextStyle(
        fontFamily: resolvedFontFamily,
        fontSize: 14,
        color: textColor,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        fontFamily: resolvedFontFamily,
        fontSize: 12,
        color: textColor,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        fontFamily: resolvedFontFamily,
        fontSize: 11,
        color: textColor.withOpacity(0.7),
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }
}
