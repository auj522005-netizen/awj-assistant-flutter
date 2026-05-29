/// ═══════════════════════════════════════════════════════════════════════════════
/// 🎨 OWJ Assistant — Theme Configuration
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Dark theme with Egyptian-inspired color palette and Arabic-friendly
/// typography. Full RTL support for Egyptian Arabic UI.
///
/// Color Philosophy:
///   - Primary: Gold/Amber (#FFB300) — inspired by ancient Egyptian gold & sun
///   - Secondary: Deep Blue (#1A237E) — Nile night, pharaonic lapis lazuli
///   - Background: Dark (#0D1117) — modern, easy on the eyes
///   - Surface: (#161B22) — subtle elevation, GitHub-dark inspired
///   - Text: White — maximum contrast on dark surfaces
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'package:flutter/material.dart';

class OwjColors {
  OwjColors._();

  // ─── Primary Palette ────────────────────────────────────────────────────

  /// Gold/Amber — Primary action color (ancient Egyptian gold)
  static const Color primary = Color(0xFFFFB300);

  /// Primary variant — darker gold for pressed states
  static const Color primaryDark = Color(0xFFFF8F00);

  /// Primary light — for subtle highlights
  static const Color primaryLight = Color(0xFFFFD54F);

  // ─── Secondary Palette ──────────────────────────────────────────────────

  /// Deep Blue — Secondary color (pharaonic lapis lazuli)
  static const Color secondary = Color(0xFF1A237E);

  /// Secondary variant — lighter blue
  static const Color secondaryLight = Color(0xFF3949AB);

  /// Secondary dark — midnight blue
  static const Color secondaryDark = Color(0xFF0D1442);

  // ─── Background & Surface ───────────────────────────────────────────────

  /// Main background — dark, modern
  static const Color background = Color(0xFF0D1117);

  /// Surface — cards, sheets, dialogs
  static const Color surface = Color(0xFF161B22);

  /// Surface variant — slightly lighter for nested surfaces
  static const Color surfaceVariant = Color(0xFF1C2333);

  /// Elevated surface — for bottom sheets, modals
  static const Color surfaceElevated = Color(0xFF21293A);

  // ─── Text Colors ────────────────────────────────────────────────────────

  /// Primary text — white for headings and important content
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Secondary text — slightly dimmed for descriptions
  static const Color textSecondary = Color(0xFFB0B8C4);

  /// Tertiary text — hints, placeholders
  static const Color textTertiary = Color(0xFF6B7B8D);

  /// Inverted text — for use on light backgrounds
  static const Color textInverted = Color(0xFF0D1117);

  // ─── Semantic Colors ────────────────────────────────────────────────────

  /// Success — green
  static const Color success = Color(0xFF22C55E);

  /// Warning — amber
  static const Color warning = Color(0xFFF59E0B);

  /// Error — red
  static const Color error = Color(0xFFEF4444);

  /// Info — blue
  static const Color info = Color(0xFF3B82F6);

  // ─── Pillar Colors ──────────────────────────────────────────────────────

  /// Career (المسيرة) — amber/gold
  static const Color pillarCareer = Color(0xFFFFB300);

  /// Health (الصحة) — green
  static const Color pillarHealth = Color(0xFF22C55E);

  /// Productivity (الإنتاجية) — blue
  static const Color pillarProductivity = Color(0xFF3B82F6);

  /// Mood (المزاج) — pink/rose
  static const Color pillarMood = Color(0xFFEC4899);

  /// Creativity (الإبداع) — purple
  static const Color pillarCreativity = Color(0xFF8B5CF6);

  // ─── Dividers & Borders ─────────────────────────────────────────────────

  /// Border color — subtle
  static const Color border = Color(0xFF30363D);

  /// Divider color
  static const Color divider = Color(0xFF21262D);

  // ─── Gradients ──────────────────────────────────────────────────────────

  /// Primary gradient — gold to amber
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Hero gradient — deep blue to gold (Egyptian sunset)
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF1A237E), Color(0xFFFFB300)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Surface gradient — subtle elevation
  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF161B22), Color(0xFF1C2333)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

// ─── Dark Theme Definition ───────────────────────────────────────────────────

ThemeData get owjDarkTheme => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // ─── Color Scheme ──────────────────────────────────────────────────
      colorScheme: const ColorScheme.dark(
        primary: OwjColors.primary,
        onPrimary: OwjColors.textInverted,
        primaryContainer: OwjColors.primaryDark,
        onPrimaryContainer: OwjColors.textPrimary,
        secondary: OwjColors.secondaryLight,
        onSecondary: OwjColors.textPrimary,
        secondaryContainer: OwjColors.secondary,
        onSecondaryContainer: OwjColors.textPrimary,
        tertiary: OwjColors.primaryLight,
        error: OwjColors.error,
        onError: OwjColors.textPrimary,
        surface: OwjColors.surface,
        onSurface: OwjColors.textPrimary,
        surfaceContainerHighest: OwjColors.surfaceVariant,
        outline: OwjColors.border,
        outlineVariant: OwjColors.divider,
      ),

      // ─── Scaffold ──────────────────────────────────────────────────────
      scaffoldBackgroundColor: OwjColors.background,

      // ─── AppBar ────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: OwjColors.surface,
        foregroundColor: OwjColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: OwjColors.textPrimary,
        ),
      ),

      // ─── Card ──────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: OwjColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: OwjColors.border, width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // ─── Elevated Button ───────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: OwjColors.primary,
          foregroundColor: OwjColors.textInverted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ─── Outlined Button ───────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: OwjColors.primary,
          side: const BorderSide(color: OwjColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ─── Text Button ───────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: OwjColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ─── Input Decoration ──────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OwjColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: OwjColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: OwjColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: OwjColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: OwjColors.error),
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Cairo',
          color: OwjColors.textTertiary,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Cairo',
          color: OwjColors.textSecondary,
        ),
      ),

      // ─── Bottom Navigation ─────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: OwjColors.surface,
        selectedItemColor: OwjColors.primary,
        unselectedItemColor: OwjColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12),
      ),

      // ─── Floating Action Button ────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: OwjColors.primary,
        foregroundColor: OwjColors.textInverted,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // ─── Chip ──────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: OwjColors.surfaceVariant,
        selectedColor: OwjColors.primary.withValues(alpha: 0.2),
        labelStyle: const TextStyle(
          fontFamily: 'Cairo',
          color: OwjColors.textPrimary,
          fontSize: 13,
        ),
        side: const BorderSide(color: OwjColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // ─── Dialog ────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: OwjColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: OwjColors.textPrimary,
        ),
      ),

      // ─── SnackBar ──────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: OwjColors.surfaceElevated,
        contentTextStyle: const TextStyle(
          fontFamily: 'Cairo',
          color: OwjColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ─── Divider ───────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: OwjColors.divider,
        thickness: 0.5,
        space: 1,
      ),

      // ─── Tab Bar ───────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: OwjColors.primary,
        unselectedLabelColor: OwjColors.textTertiary,
        indicatorColor: OwjColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      // ─── Text Theme (Arabic-friendly, Cairo font) ─────────────────────
      textTheme: const TextTheme(
        // Display styles — large, bold headings
        displayLarge: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: OwjColors.textPrimary,
          height: 1.2,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: OwjColors.textPrimary,
          height: 1.25,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: OwjColors.textPrimary,
          height: 1.3,
        ),
        // Headline styles — section headers
        headlineLarge: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: OwjColors.textPrimary,
          height: 1.3,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: OwjColors.textPrimary,
          height: 1.3,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: OwjColors.textPrimary,
          height: 1.35,
        ),
        // Title styles — card titles, list items
        titleLarge: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: OwjColors.textPrimary,
          height: 1.35,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: OwjColors.textPrimary,
          height: 1.4,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: OwjColors.textSecondary,
          height: 1.4,
        ),
        // Body styles — main content text
        bodyLarge: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: OwjColors.textPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: OwjColors.textPrimary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: OwjColors.textSecondary,
          height: 1.5,
        ),
        // Label styles — buttons, tags, captions
        labelLarge: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: OwjColors.textPrimary,
          height: 1.4,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: OwjColors.textSecondary,
          height: 1.4,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: OwjColors.textTertiary,
          height: 1.4,
        ),
      ),
    );

// ─── RTL Helper ──────────────────────────────────────────────────────────────

/// Returns the appropriate `TextDirection` for Arabic content.
/// Use this when manually setting direction for mixed-content widgets.
TextDirection getArabicTextDirection(String text) {
  // Check if the text starts with an Arabic character
  final arabicRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]');
  if (text.isNotEmpty && arabicRegex.hasMatch(text.substring(0, 1))) {
    return TextDirection.rtl;
  }
  return TextDirection.ltr;
}

/// Returns the appropriate `Alignment` for RTL layouts.
/// In RTL, start is right; in LTR, start is left.
Alignment getRtlStartAlignment(TextDirection direction) {
  return direction == TextDirection.rtl
      ? Alignment.centerRight
      : Alignment.centerLeft;
}

/// Padding helper for RTL-aware horizontal padding.
EdgeInsets rtlHorizontalPadding({
  required double start,
  required double end,
  required TextDirection direction,
}) {
  return direction == TextDirection.rtl
      ? EdgeInsets.only(right: start, left: end)
      : EdgeInsets.only(left: start, right: end);
}
