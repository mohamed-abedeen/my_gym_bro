import 'package:flutter/material.dart';

/// Dynamic color theme that adapts to light/dark mode.
///
/// Access via `AppColors.of(context)` in any widget's build method.
@immutable
class AppColorsTheme extends ThemeExtension<AppColorsTheme> {
  final Color background;
  final Color card;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color amber;
  final Color danger;
  final Color muscleUntrained;
  final Color trendPositive;
  final Color trendNegative;
  final Color separator;
  final Color panelBackground;
  final Color cardElevated;
  final Color divider;
  final Color subtitleText;

  const AppColorsTheme({
    required this.background,
    required this.card,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.amber,
    required this.danger,
    required this.muscleUntrained,
    required this.trendPositive,
    required this.trendNegative,
    required this.separator,
    required this.panelBackground,
    required this.cardElevated,
    required this.divider,
    required this.subtitleText,
  });

  static const dark = AppColorsTheme(
    background: Color(0xFF000000),
    card: Color(0xFF161414),
    accent: Color(0xFFD2FF00),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF999999),
    success: Color(0xFF49995C),
    amber: Color(0xFFEF9F27),
    danger: Color(0xFFFF0004),
    muscleUntrained: Color(0xFF888780),
    trendPositive: Color(0xFF49995C),
    trendNegative: Color(0xFFFF0004),
    separator: Color(0xFF3B3B3B),
    panelBackground: Color(0xFF1C1C1E),
    cardElevated: Color(0xFF29292B),
    divider: Color(0xFF414546),
    subtitleText: Color(0xFF9B9B9B),
  );

  static const light = AppColorsTheme(
    background: Color(0xFFF2F2F7),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFFD2FF00),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0xFF8E8E93),
    success: Color(0xFF34C759),
    amber: Color(0xFFFF9500),
    danger: Color(0xFFFF3B30),
    muscleUntrained: Color(0xFFC7C7CC),
    trendPositive: Color(0xFF34C759),
    trendNegative: Color(0xFFFF3B30),
    separator: Color(0xFFD1D1D6),
    panelBackground: Color(0xFFE5E5EA),
    cardElevated: Color(0xFFFFFFFF),
    divider: Color(0xFFD1D1D6),
    subtitleText: Color(0xFF8E8E93),
  );

  @override
  AppColorsTheme copyWith({
    Color? background,
    Color? card,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? success,
    Color? amber,
    Color? danger,
    Color? muscleUntrained,
    Color? trendPositive,
    Color? trendNegative,
    Color? separator,
    Color? panelBackground,
    Color? cardElevated,
    Color? divider,
    Color? subtitleText,
  }) =>
      AppColorsTheme(
        background: background ?? this.background,
        card: card ?? this.card,
        accent: accent ?? this.accent,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        success: success ?? this.success,
        amber: amber ?? this.amber,
        danger: danger ?? this.danger,
        muscleUntrained: muscleUntrained ?? this.muscleUntrained,
        trendPositive: trendPositive ?? this.trendPositive,
        trendNegative: trendNegative ?? this.trendNegative,
        separator: separator ?? this.separator,
        panelBackground: panelBackground ?? this.panelBackground,
        cardElevated: cardElevated ?? this.cardElevated,
        divider: divider ?? this.divider,
        subtitleText: subtitleText ?? this.subtitleText,
      );

  @override
  AppColorsTheme lerp(AppColorsTheme? other, double t) {
    if (other == null) return this;
    return AppColorsTheme(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      muscleUntrained: Color.lerp(muscleUntrained, other.muscleUntrained, t)!,
      trendPositive: Color.lerp(trendPositive, other.trendPositive, t)!,
      trendNegative: Color.lerp(trendNegative, other.trendNegative, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      panelBackground: Color.lerp(panelBackground, other.panelBackground, t)!,
      cardElevated: Color.lerp(cardElevated, other.cardElevated, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      subtitleText: Color.lerp(subtitleText, other.subtitleText, t)!,
    );
  }
}

/// Convenience accessor for the current theme colors.
class AppColors {
  AppColors._();

  /// Returns the [AppColorsTheme] for the current context.
  static AppColorsTheme of(BuildContext context) =>
      Theme.of(context).extension<AppColorsTheme>()!;

  // ── Static fallbacks (dark-theme values) for code that doesn't have context ──
  static const background = Color(0xFF000000);
  static const card = Color(0xFF161414);
  static const accent = Color(0xFFD2FF00);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF999999);
  static const success = Color(0xFF49995C);
  static const amber = Color(0xFFEF9F27);
  static const danger = Color(0xFFFF0004);
  static const muscleUntrained = Color(0xFF888780);
  static const trendPositive = Color(0xFF49995C);
  static const trendNegative = Color(0xFFFF0004);
}

/// Border radius values from Figma.
class AppRadius {
  AppRadius._();

  static const card = 24.0;
  static const dailyChallenge = 27.0;
  static const anatomy = 45.0;
  static const schedule = 40.0;
  static const sheet = 55.0;
  static const button = 296.0;
  static const navPill = 296.0;
  static const scheduleCircle = 34.0;
  static const exerciseThumb = 12.0;
  static const sessionIcon = 7.0;
  static const howtoGif = 15.0;
}

/// Fixed sizes from Figma design spec.
class AppSizes {
  AppSizes._();

  static const screenWidth = 440.0;
  static const screenHeight = 956.0;
  static const contentPaddingH = 20.0;

  // Nav pill (exact from Figma)
  static const navPillWidth = 278.0;
  static const navPillHeight = 70.0;
  static const navPillLeft = 81.0;
  static const navPillTop = 877.0;
  static const navActiveW = 94.0;
  static const navActiveH = 65.0;

  // Anatomy card
  static const anatomyW = 400.0;
  static const anatomyH = 368.0;

  // Stats cards (right column + left healing)
  static const statsCardW = 194.0;
  static const statsCardH = 179.0;

  // Schedule card
  static const scheduleCardW = 400.0;
  static const scheduleCardH = 190.0;

  // Daily Challenge card
  static const challengeCardW = 399.0;
  static const challengeCardH = 187.0;

  // Weekly strip pills
  static const dayPillW = 50.0;
  static const dayPillH = 74.0;

  // Exercise thumbnails
  static const thumbStandard = 58.0;
  static const thumbActive = 83.0;

  // How-to GIF frame
  static const howtoGifW = 353.0;
  static const howtoGifH = 331.0;

  // Liquid glass buttons
  static const lgButtonSmall = 48.0;
  static const lgButtonTiny = 18.0;

  // Schedule circles
  static const scheduleCircleD2FF00 = 69.0;
  static const scheduleCircleH = 68.0;

  // Separator bars
  static const separatorThickH = 4.0;
  static const separatorThinH = 1.0;
  static const separatorW = 285.0;
}
