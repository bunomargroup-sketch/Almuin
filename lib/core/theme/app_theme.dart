import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/settings_service.dart';

/// Luxury-minimal Islamic design system.
///
/// Palette: deep emerald + warm gold on soft ivory (light) and midnight
/// teal (dark). Typography: Amiri / Noto Naskh for the revealed text,
/// IBM Plex Sans Arabic (or Cairo) for UI. All fonts resolve through
/// `google_fonts`, which caches them on-device after first fetch — see
/// assets/fonts/README.md to bundle TTFs for guaranteed first-launch offline.
abstract final class AppTheme {
  // ---- Palette ----
  static const emerald = Color(0xFF0E6B5C);
  static const emeraldDeep = Color(0xFF083E36);
  static const gold = Color(0xFFC9A227);
  static const goldSoft = Color(0xFFE7CE8B);
  static const ivory = Color(0xFFF7F4EC);
  static const sand = Color(0xFFEFE8D8);
  static const midnight = Color(0xFF0C1512);
  static const midnightCard = Color(0xFF132019);
  static const rose = Color(0xFFB4665E);

  static ThemeData light(AppSettings s) => _base(s, Brightness.light);
  static ThemeData dark(AppSettings s) => _base(s, Brightness.dark);

  static ThemeData _base(AppSettings s, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: emerald,
      brightness: brightness,
    ).copyWith(
      primary: emerald,
      secondary: gold,
      tertiary: rose,
      surface: dark ? midnight : ivory,
      onSurface: dark ? const Color(0xFFEDE9DD) : const Color(0xFF1C2420),
      surfaceContainerHighest: dark ? midnightCard : sand,
      outline: dark ? const Color(0xFF2B4238) : const Color(0xFFCFC7B4),
    );

    final uiFont = switch (s.arabicFontKey) {
      ArabicFontKey.cairo => GoogleFonts.cairoTextTheme,
      _ => GoogleFonts.ibmPlexSansArabicTextTheme,
    };
    final base = dark ? ThemeData.dark() : ThemeData.light();
    final textTheme = uiFont(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface.withValues(alpha: 0.9),
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      sliderTheme: const SliderThemeData(showValueIndicator: ShowValueIndicator.always),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 0.6),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  /// The display font for revealed text (Quran & adhkar) per user setting.
  static TextStyle mushafText(
    AppSettings s, {
    double size = 22,
    double height = 1.9,
    Color? color,
  }) {
    final base = switch (s.arabicFontKey) {
      ArabicFontKey.amiri => GoogleFonts.amiri(),
      ArabicFontKey.notoNaskh => GoogleFonts.notoNaskhArabic(),
      ArabicFontKey.cairo => GoogleFonts.cairo(),
    };
    return base.copyWith(fontSize: size, height: height, color: color);
  }
}
