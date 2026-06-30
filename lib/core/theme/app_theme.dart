import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryRed = Color(0xFFE80E15);
  static const Color primaryRedDark = Color(0xFFC20B12);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE80E15), Color(0xFFC20B12)],
  );

  static const LinearGradient peachGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFECD2), Color(0xFFFCB69F)],
  );

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5F7FA), Color(0xFFC3CFE2)],
  );

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey50 = Color(0xFFF5F5F5);
  static const Color grey100 = Color(0xFFF8F9FA);
  static const Color grey200 = Color(0xFFE5E5E5);
  static const Color grey300 = Color(0xFFCCCCCC);
  static const Color grey400 = Color(0xFF999999);
  static const Color grey500 = Color(0xFF666666);
  static const Color grey600 = Color(0xFF555555);
  static const Color grey700 = Color(0xFF333333);
  static const Color grey800 = Color(0xFF222222);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color successDark = Color(0xFF2E7D32);

  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color warningDark = Color(0xFFE65100);

  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFFE3F2FD);
  static const Color infoDark = Color(0xFF1565C0);

  static const Color error = Color(0xFFF44336);
  static const Color errorLight = Color(0xFFFFEBEE);

  // Badge Colors
  static const Color badgeYellow = Color(0xFFFFF3CD);
  static const Color badgeYellowText = Color(0xFF856404);

  // Spacing
  static const double spacing4 = 4.0;
  static const double spacing6 = 6.0;
  static const double spacing8 = 8.0;
  static const double spacing10 = 10.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing70 = 70.0;
  static const double spacing80 = 80.0;
  static const double spacing90 = 90.0;
  static const double spacing100 = 100.0;

  // Border Radius
  static const double radius6 = 6.0;
  static const double radius8 = 8.0;
  static const double radius10 = 10.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius20 = 20.0;
  static const double radius30 = 30.0;
  static const double radius40 = 40.0;

  // Font Sizes
  static const double fontSize10 = 10.0;
  static const double fontSize11 = 11.0;
  static const double fontSize12 = 12.0;
  static const double fontSize13 = 13.0;
  static const double fontSize14 = 14.0;
  static const double fontSize15 = 15.0;
  static const double fontSize18 = 18.0;
  static const double fontSize20 = 20.0;
  static const double fontSize22 = 22.0;
  static const double fontSize24 = 24.0;
  static const double fontSize32 = 32.0;

  static ThemeData lightTheme() {
    final textTheme = GoogleFonts.dmSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryRed,
      scaffoldBackgroundColor: grey50,

      colorScheme: const ColorScheme.light(
        primary: primaryRed,
        secondary: primaryRedDark,
        surface: white,
        error: error,
      ),

      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontSize: fontSize32,
          fontWeight: FontWeight.w700,
          color: grey800,
        ),
        displayMedium: textTheme.displayMedium?.copyWith(
          fontSize: fontSize24,
          fontWeight: FontWeight.w700,
          color: grey800,
        ),
        displaySmall: textTheme.displaySmall?.copyWith(
          fontSize: fontSize20,
          fontWeight: FontWeight.w700,
          color: grey800,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontSize: fontSize18,
          fontWeight: FontWeight.w600,
          color: grey800,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontSize: fontSize15,
          fontWeight: FontWeight.w600,
          color: grey700,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontSize: fontSize14,
          fontWeight: FontWeight.w400,
          color: grey700,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: fontSize13,
          fontWeight: FontWeight.w400,
          color: grey600,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontSize: fontSize12,
          fontWeight: FontWeight.w600,
          color: grey500,
          letterSpacing: 0.5,
        ),
      ),

      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: primaryRed,
        foregroundColor: white,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: fontSize20,
          fontWeight: FontWeight.w700,
          color: white,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        contentPadding: const EdgeInsets.all(spacing12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius12),
          borderSide: const BorderSide(color: grey200, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius12),
          borderSide: const BorderSide(color: grey200, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius12),
          borderSide: const BorderSide(color: primaryRed, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius12),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: grey600,
          fontWeight: FontWeight.w600,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            vertical: spacing12,
            horizontal: spacing20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: fontSize15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius12),
        ),
        color: white,
      ),
    );
  }
}







