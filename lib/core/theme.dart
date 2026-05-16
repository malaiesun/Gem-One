import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GemColors {
  // Backgrounds
  static const bg          = Color(0xFF0D0B1E);
  static const bgMid       = Color(0xFF1A0A2E);
  static const bgDeep      = Color(0xFF0D1B3E);
  static const surface     = Color(0xFF13102A);
  static const card        = Color(0xFF14142E);
  static const cardBorder  = Color(0xFF1E1E3F);

  // Glass
  static const glassColor  = Color(0x12FFFFFF); // Colors.white.withOpacity(0.07)
  static const glassBorder = Color(0x1FFFFFFF); // Colors.white.withOpacity(0.12)

  // Accent - Lavender Glass
  static const accent      = Color(0xFF9B8BFF); // lavender
  static const accentDim   = Color(0xFF3D3580);
  static const accentGlow  = Color(0x339B8BFF);
  static const iceBlue     = Color(0xFF6BCFFF); // secondary accent

  // Semantic
  static const success     = Color(0xFF6BFFB8);
  static const warning     = Color(0xFFFFD166);
  static const danger      = Color(0xFFFF6B8A);
  static const info        = Color(0xFF6BCFFF);

  // Text
  static const textPrimary   = Colors.white;
  static const textSecondary = Color(0xFF9898BB);
  static const textHint      = Color(0xFF50507A);

  // Module colors (kept for legacy compatibility)
  static const medicalColor  = Color(0xFFFF6B8A);  // danger-pink (medic)
  static const learnColor    = Color(0xFF6BFFB8);   // success-green (learn)
  static const mathColor     = Color(0xFF9B8BFF);   // lavender (scholar)
  static const chatColor     = Color(0xFF9B8BFF);   // lavender (assistant)

  // Module specific
  static const scholarColor   = Color(0xFF9B8BFF);
  static const medicColor     = Color(0xFFFF6B8A);
  static const polyglotColor  = Color(0xFF6BCFFF);
  static const studyColor     = Color(0xFF6BFFB8);
  static const docColor       = Color(0xFFFFB347);
  static const assistantColor = Color(0xFF2DD4BF);
  static const referenceColor = Color(0xFFFB923C);
}

class GemOneTheme {
  static ThemeData dark([Color accent = GemColors.accent]) {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: GemColors.bg,
      colorScheme: ColorScheme.dark(
        surface: GemColors.surface,
        primary: accent,
        secondary: GemColors.iceBlue,
        onSurface: Colors.white,
        error: GemColors.danger,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: accent,
        labelColor: accent,
        unselectedLabelColor: GemColors.textSecondary,
        dividerColor: GemColors.cardBorder,
      ),
      dividerColor: GemColors.cardBorder,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GemColors.glassColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: GemColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: GemColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: GemColors.textHint, fontSize: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
