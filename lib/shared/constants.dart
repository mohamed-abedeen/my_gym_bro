import 'package:flutter/material.dart';

/// Dynamic color theme that adapts to light/dark mode.
///
/// Access via `AppColors.of(context)` in any widget's build method.
@immutable
class AppColorsTheme extends ThemeExtension<AppColorsTheme> {

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
    required this.avatarPlaceholder,
    required this.avatarPlaceholderDark,
    required this.avatarPlaceholderDarker,
    required this.overlayBlack,
    required this.todayPillText,
    required this.black,
    required this.white,
    required this.grey,
  });
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
  final Color avatarPlaceholder;
  final Color avatarPlaceholderDark;
  final Color avatarPlaceholderDarker;
  final Color overlayBlack;
  final Color todayPillText;
  final Color black;
  final Color white;
  final Color grey;

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
    avatarPlaceholder: Color(0xFF616161),   // AppColors.of(context).avatarPlaceholder
    avatarPlaceholderDark: Color(0xFF424242), // AppColors.of(context).avatarPlaceholderDark
    avatarPlaceholderDarker: Color(0xFF212121), // AppColors.of(context).avatarPlaceholderDarker
    overlayBlack: Color(0x80000000),         // black 50%
    todayPillText: Color(0xFF000000),
    black: Color(0xFF000000),
    white: Color(0xFFFFFFFF),
    grey: Color(0xFF9E9E9E),
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
    avatarPlaceholder: Color(0xFFBDBDBD),   // lighter grey for light mode
    avatarPlaceholderDark: Color(0xFF9E9E9E),
    avatarPlaceholderDarker: Color(0xFF757575),
    overlayBlack: Color(0x80000000),
    todayPillText: Color(0xFF000000),
    black: Color(0xFF000000),
    white: Color(0xFFFFFFFF),
    grey: Color(0xFF9E9E9E),
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
    Color? avatarPlaceholder,
    Color? avatarPlaceholderDark,
    Color? avatarPlaceholderDarker,
    Color? overlayBlack,
    Color? todayPillText,
    Color? black,
    Color? white,
    Color? grey,
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
        avatarPlaceholder: avatarPlaceholder ?? this.avatarPlaceholder,
        avatarPlaceholderDark: avatarPlaceholderDark ?? this.avatarPlaceholderDark,
        avatarPlaceholderDarker: avatarPlaceholderDarker ?? this.avatarPlaceholderDarker,
        overlayBlack: overlayBlack ?? this.overlayBlack,
        todayPillText: todayPillText ?? this.todayPillText,
        black: black ?? this.black,
        white: white ?? this.white,
        grey: grey ?? this.grey,
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
      avatarPlaceholder: Color.lerp(avatarPlaceholder, other.avatarPlaceholder, t)!,
      avatarPlaceholderDark: Color.lerp(avatarPlaceholderDark, other.avatarPlaceholderDark, t)!,
      avatarPlaceholderDarker: Color.lerp(avatarPlaceholderDarker, other.avatarPlaceholderDarker, t)!,
      overlayBlack: Color.lerp(overlayBlack, other.overlayBlack, t)!,
      todayPillText: Color.lerp(todayPillText, other.todayPillText, t)!,
      black: Color.lerp(black, other.black, t)!,
      white: Color.lerp(white, other.white, t)!,
      grey: Color.lerp(grey, other.grey, t)!,
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
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);
  static const grey = Color(0xFF9E9E9E);

  // Story ring gradients
  static const storyRingStart = Color(0xFFD0FF00);
  static const storyRingEnd = Color(0xFF12FF00);
  static const storyRingAltStart = Color(0xFFD2FF00);
  static const storyRingAltEnd = Color(0xFF0DFF00);

  // Community category avatar colors
  static const categoryGreen = Color(0xFF4A6741);
  static const categoryBrown = Color(0xFF6B4423);
  static const categoryBlue = Color(0xFF3D5A80);
  static const categoryTan = Color(0xFF7B6B4F);
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

/// Rotation angles (radians) used for icon transforms.
class AppAngles {
  AppAngles._();

  /// −90° — points a right-facing arrow upward (trend-up arrow).
  static const quarterTurnCcw = -1.5708;

  /// +90° — points a right-facing arrow downward (trend-down arrow).
  static const quarterTurnCw = 1.5708;
}
