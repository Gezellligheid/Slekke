import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SlekkeColors {
  static const background    = Color(0xFF191919);
  static const surface       = Color(0xFF1F1F1F);
  static const surfaceVariant= Color(0xFF191919);
  static const inputBg       = Color(0xFF262626);
  static const elevated      = Color(0xFF2D2D2D);
  static const channelSelected = Color(0xFF282828);
  static const primary       = Color(0xFFFFFFFF);
  static const primaryHover  = Color(0xFFE8E8E8);
  static const success       = Color(0xFF4CA87D);
  static const danger        = Color(0xFFC04545);
  static const warning       = Color(0xFFC88B2A);
  static const textPrimary   = Color(0xFFCFCFCF);
  static const textSecondary = Color(0xFF7A7A7A);
  static const textMuted     = Color(0xFF4C4C4C);
  static const divider       = Color(0xFF282828);
  static const mention       = Color(0xFFCFCFCF);
  static const mentionBg     = Color(0xFF2A2A27);

  // Dark text for use on the white primary background
  static const onPrimary     = Color(0xFF191919);
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: SlekkeColors.background,
      colorScheme: const ColorScheme.dark(
        primary: SlekkeColors.primary,
        surface: SlekkeColors.surface,
        error: SlekkeColors.danger,
        onPrimary: SlekkeColors.onPrimary,
        onSurface: SlekkeColors.textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        bodyMedium: GoogleFonts.inter(
          color: SlekkeColors.textPrimary,
          fontSize: 14,
        ),
        bodySmall: GoogleFonts.inter(
          color: SlekkeColors.textSecondary,
          fontSize: 12,
        ),
        titleMedium: GoogleFonts.inter(
          color: SlekkeColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SlekkeColors.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: SlekkeColors.divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: SlekkeColors.textMuted, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(color: SlekkeColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SlekkeColors.primary,
          foregroundColor: SlekkeColors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          elevation: 0,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: SlekkeColors.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: SlekkeColors.elevated, width: 1),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: SlekkeColors.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          side: BorderSide(color: SlekkeColors.elevated, width: 1),
        ),
      ),
      dividerColor: SlekkeColors.divider,
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(SlekkeColors.elevated),
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(3),
      ),
    );
  }
}
