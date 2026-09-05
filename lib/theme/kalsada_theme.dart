import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the Kalsada look, in light and dark variants.
///
/// Mirrors the "Kinetic Horizon" design system from the "Enhanced Flutter
/// Trip Planner" Stitch project: an electric-blue, AI-forward palette
/// grounded by a deep forest-green secondary, set in a Plus Jakarta Sans /
/// Inter / JetBrains Mono type stack.
@immutable
class KalsadaColors extends ThemeExtension<KalsadaColors> {
  const KalsadaColors({
    required this.bg,
    required this.card,
    required this.text,
    required this.sub,
    required this.ter,
    required this.sep,
    required this.accent,
    required this.accentSoft,
    required this.fill,
    required this.mapBg,
    required this.mapGrid,
    required this.secondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.success,
    required this.warning,
  });

  final Color bg;
  final Color card;
  final Color text;
  final Color sub;
  final Color ter;
  final Color sep;
  final Color accent;
  final Color accentSoft;
  final Color fill;
  final Color mapBg;
  final Color mapGrid;

  /// Deep forest green — the "grounded, outdoor" counterpart to [accent].
  final Color secondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;

  /// "Done" / positive status color (trip status, stop status).
  final Color success;

  /// "Skipped" / caution status color (trip status, stop status).
  final Color warning;

  /// Photo-placeholder stripe colors shared by both variants.
  static const Color heroStripeA = Color(0xFF3F6653);
  static const Color heroStripeB = Color(0xFF2C4A3B);

  /// Neutral badge overlay drawn on top of arbitrary trip photos (not a
  /// card surface), so it intentionally doesn't vary with [light]/[dark].
  static const Color statusOverlay = Color(0xFF1A1C1E);

  static const light = KalsadaColors(
    bg: Color(0xFFF9F9FC),
    card: Color(0xFFFFFFFF),
    text: Color(0xFF1A1C1E),
    sub: Color(0xFF414755),
    ter: Color(0x99414755),
    sep: Color(0xFFC1C6D7),
    accent: Color(0xFF0058BC),
    accentSoft: Color(0x1A0058BC),
    fill: Color(0xFFEEEEF0),
    mapBg: Color(0xFFE4E8DE),
    mapGrid: Color(0x0F000000),
    secondary: Color(0xFF3F6653),
    secondaryContainer: Color(0xFFBEEAD1),
    onSecondaryContainer: Color(0xFF436B58),
    success: Color(0xFF1E8E3E),
    warning: Color(0xFFB25E00),
  );

  static const dark = KalsadaColors(
    bg: Color(0xFF15171B),
    card: Color(0xFF1E2126),
    text: Color(0xFFF0F0F3),
    sub: Color(0xFFA9AFC0),
    ter: Color(0x99A9AFC0),
    sep: Color(0xFF3A3F4B),
    accent: Color(0xFF5B9CFF),
    accentSoft: Color(0x2E5B9CFF),
    fill: Color(0xFF262A31),
    mapBg: Color(0xFF12201C),
    mapGrid: Color(0x0FFFFFFF),
    secondary: Color(0xFFA5D0B9),
    secondaryContainer: Color(0xFF203C2E),
    onSecondaryContainer: Color(0xFFA5D0B9),
    success: Color(0xFF4CD97B),
    warning: Color(0xFFFFA352),
  );

  @override
  KalsadaColors copyWith({
    Color? bg,
    Color? card,
    Color? text,
    Color? sub,
    Color? ter,
    Color? sep,
    Color? accent,
    Color? accentSoft,
    Color? fill,
    Color? mapBg,
    Color? mapGrid,
    Color? secondary,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? success,
    Color? warning,
  }) {
    return KalsadaColors(
      bg: bg ?? this.bg,
      card: card ?? this.card,
      text: text ?? this.text,
      sub: sub ?? this.sub,
      ter: ter ?? this.ter,
      sep: sep ?? this.sep,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      fill: fill ?? this.fill,
      mapBg: mapBg ?? this.mapBg,
      mapGrid: mapGrid ?? this.mapGrid,
      secondary: secondary ?? this.secondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer:
          onSecondaryContainer ?? this.onSecondaryContainer,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  KalsadaColors lerp(ThemeExtension<KalsadaColors>? other, double t) {
    if (other is! KalsadaColors) return this;
    return KalsadaColors(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      text: Color.lerp(text, other.text, t)!,
      sub: Color.lerp(sub, other.sub, t)!,
      ter: Color.lerp(ter, other.ter, t)!,
      sep: Color.lerp(sep, other.sep, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      mapBg: Color.lerp(mapBg, other.mapBg, t)!,
      mapGrid: Color.lerp(mapGrid, other.mapGrid, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryContainer:
          Color.lerp(secondaryContainer, other.secondaryContainer, t)!,
      onSecondaryContainer: Color.lerp(
        onSecondaryContainer,
        other.onSecondaryContainer,
        t,
      )!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension KalsadaThemeContext on BuildContext {
  KalsadaColors get kalsada => Theme.of(this).extension<KalsadaColors>()!;
}

/// Corner radii from the "Kinetic Horizon" shape scale — rounded, echoing
/// trail and road curves.
class KalsadaRadius {
  const KalsadaRadius._();

  static const double sm = 4;
  static const double md = 8;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;
}

/// Plus Jakarta Sans — the display/headline face. Bold, tight tracking.
TextStyle kalsadaHeadline({
  double fontSize = 24,
  FontWeight fontWeight = FontWeight.w700,
  Color? color,
  double? letterSpacing,
  double? height,
}) => GoogleFonts.plusJakartaSans(
  fontSize: fontSize,
  fontWeight: fontWeight,
  color: color,
  letterSpacing: letterSpacing,
  height: height,
);

/// JetBrains Mono — reserved for technical/data points: field labels,
/// distances, timestamps, day badges.
TextStyle kalsadaMono({
  double fontSize = 12,
  FontWeight fontWeight = FontWeight.w500,
  Color? color,
  double letterSpacing = 0.6,
}) => GoogleFonts.jetBrainsMono(
  fontSize: fontSize,
  fontWeight: fontWeight,
  color: color,
  letterSpacing: letterSpacing,
);

ThemeData kalsadaTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark
      ? KalsadaColors.dark
      : KalsadaColors.light;
  final base = ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.accent,
      brightness: brightness,
      primary: colors.accent,
      secondary: colors.secondary,
      surface: colors.card,
    ),
    scaffoldBackgroundColor: colors.bg,
    useMaterial3: true,
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
    extensions: [colors],
  );
}
