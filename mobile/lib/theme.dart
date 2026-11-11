import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One set of the web's color tokens (web/src/theme.css): [light] is `:root`,
/// [dark] is `:root[data-theme=dark]`. Keep both files in sync.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.ink,
    required this.muted,
    required this.paper,
    required this.white,
    required this.line,
    required this.wash,
    required this.stage,
    required this.hover,
    required this.selection,
    required this.disabled,
    required this.disabledInk,
    required this.focus,
    required this.success,
    required this.successWash,
    required this.danger,
    required this.dangerWash,
    required this.shadow,
    required this.orbit,
    required this.sidebar,
    required this.incomingBubble,
    required this.link,
    required this.hackerInk,
    required this.hackerWash,
    required this.mentorInk,
    required this.mentorWash,
    required this.sponsorInk,
    required this.sponsorWash,
  });

  final Brightness brightness;
  final Color ink;
  final Color muted;
  final Color paper;

  /// Cards, fields and sheets: white in light, a raised grey in dark.
  final Color white;
  final Color line;
  final Color wash;
  final Color stage;
  final Color hover;
  final Color selection;
  final Color disabled;
  final Color disabledInk;
  final Color focus;
  final Color success;
  final Color successWash;
  final Color danger;
  final Color dangerWash;
  final Color shadow;
  final Color orbit;
  final Color sidebar;
  final Color incomingBubble;
  final Color link;
  final Color hackerInk;
  final Color hackerWash;
  final Color mentorInk;
  final Color mentorWash;
  final Color sponsorInk;
  final Color sponsorWash;

  static const light = AppPalette(
    brightness: Brightness.light,
    ink: Color(0xFF243247),
    muted: Color(0xFF606975),
    paper: Color(0xFFF5F6F8),
    white: Color(0xFFFFFFFF),
    line: Color(0xFFD8DDE5),
    wash: Color(0xFFE9EDF3),
    stage: Color(0xFFEDF2F8),
    hover: Color(0xFFEAF1FB),
    selection: Color(0xFFD4E5FF),
    disabled: Color(0xFFE2E6EC),
    disabledInk: Color(0xFF5B6575),
    focus: Color(0xFF0866D9),
    success: Color(0xFF39604F),
    successWash: Color(0xFFE8F0EB),
    danger: Color(0xFFA12B35),
    dangerWash: Color(0xFFFDF0F1),
    // CSS #24324712 is RRGGBBAA; Flutter's Color is AARRGGBB.
    shadow: Color(0x12243247),
    orbit: Color(0xFFC9D9ED),
    sidebar: Color(0xFFEEF1F5),
    incomingBubble: Color(0xFFE9EDF3),
    link: Color(0xFF0866D9),
    hackerInk: Color(0xFF24558C),
    hackerWash: Color(0xFFE6EFFA),
    mentorInk: Color(0xFF39604F),
    mentorWash: Color(0xFFE8F0EB),
    sponsorInk: Color(0xFF805915),
    sponsorWash: Color(0xFFF6E9C9),
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    ink: Color(0xFFEDF1F7),
    muted: Color(0xFFADB7C5),
    paper: Color(0xFF181C24),
    white: Color(0xFF242A35),
    line: Color(0xFF404B5C),
    wash: Color(0xFF2D3542),
    stage: Color(0xFF252F3E),
    hover: Color(0xFF303D50),
    selection: Color(0xFF27476F),
    disabled: Color(0xFF323B49),
    disabledInk: Color(0xFFACB6C6),
    focus: Color(0xFF80B5FF),
    success: Color(0xFFC5DBCC),
    successWash: Color(0xFF30463D),
    danger: Color(0xFFFF9AA2),
    dangerWash: Color(0xFF46282C),
    shadow: Color(0x66000000),
    orbit: Color(0xFF3A4A61),
    sidebar: Color(0xFF1E242E),
    incomingBubble: Color(0xFF2D3542),
    link: Color(0xFF80B5FF),
    hackerInk: Color(0xFFBAD8FF),
    hackerWash: Color(0xFF283E5B),
    mentorInk: Color(0xFFC5DBCC),
    mentorWash: Color(0xFF30463D),
    sponsorInk: Color(0xFFEFD097),
    sponsorWash: Color(0xFF493E29),
  );
}

/// The colors in use: the light or dark [AppPalette], picked by [HackyApp]
/// from the phone's setting (lib/app.dart). Widgets read them while they
/// build, so the app rebuilds everything when the setting changes.
class AppColors {
  AppColors._();

  static AppPalette _palette = AppPalette.light;

  static AppPalette get palette => _palette;

  /// Switches the palette. The caller rebuilds the widgets.
  static void use(AppPalette palette) => _palette = palette;

  static bool get isDark => _palette.brightness == Brightness.dark;

  // The same in light and dark.
  static const action = Color(0xFF0866D9);
  static const actionHover = Color(0xFF0754B3);
  static const onAction = Color(0xFFFFFFFF);
  static const globe = action;
  static const outgoingBubble = action;
  static const outgoingText = onAction;

  // The little crown on "Find mentor" (web/src/hacky.css .hk-crown).
  static const crown = Color(0xFFF1B938);
  static const crownLine = Color(0xFFA8741A);

  static Color get ink => _palette.ink;
  static Color get muted => _palette.muted;
  static Color get paper => _palette.paper;
  static Color get white => _palette.white;
  static Color get line => _palette.line;
  static Color get wash => _palette.wash;
  static Color get stage => _palette.stage;
  static Color get hover => _palette.hover;
  static Color get selection => _palette.selection;
  static Color get disabled => _palette.disabled;
  static Color get disabledInk => _palette.disabledInk;
  static Color get focus => _palette.focus;
  static Color get success => _palette.success;
  static Color get successWash => _palette.successWash;
  static Color get danger => _palette.danger;
  static Color get dangerWash => _palette.dangerWash;
  static Color get shadow => _palette.shadow;
  static Color get orbit => _palette.orbit;

  // Workspace tokens: the Chats background, the message bubbles and the
  // role chips.
  static Color get sidebar => _palette.sidebar;
  static Color get incomingBubble => _palette.incomingBubble;
  static Color get link => _palette.link;
  static Color get hackerInk => _palette.hackerInk;
  static Color get hackerWash => _palette.hackerWash;
  static Color get mentorInk => _palette.mentorInk;
  static Color get mentorWash => _palette.mentorWash;
  static Color get sponsorInk => _palette.sponsorInk;
  static Color get sponsorWash => _palette.sponsorWash;
}

/// The app's ThemeData: Lato, the web palette and the web's 12px radius.
class AppTheme {
  AppTheme._();

  static const fontFamily = 'Lato';
  static const radius = 12.0;
  static final borderRadius = BorderRadius.circular(radius);

  /// Light status bar icons on the dark palette, dark ones on the light.
  static SystemUiOverlayStyle overlayStyle(AppPalette palette) =>
      palette.brightness == Brightness.dark
      ? SystemUiOverlayStyle.light
      : SystemUiOverlayStyle.dark;

  /// The light theme. Also switches [AppColors] to light.
  static ThemeData light() => of(AppPalette.light);

  /// The theme for [palette]. Also switches [AppColors] to it, so widgets
  /// that read [AppColors] match the theme.
  static ThemeData of(AppPalette palette) {
    AppColors.use(palette);
    final scheme = ColorScheme(
      brightness: palette.brightness,
      primary: AppColors.action,
      onPrimary: AppColors.onAction,
      secondary: AppColors.ink,
      onSecondary: AppColors.white,
      error: AppColors.danger,
      onError: AppColors.white,
      errorContainer: AppColors.dangerWash,
      onErrorContainer: AppColors.danger,
      surface: AppColors.white,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.line,
      outlineVariant: AppColors.line,
      shadow: AppColors.shadow,
    );

    return ThemeData(
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.paper,
      dividerColor: AppColors.line,
      disabledColor: AppColors.disabledInk,
      focusColor: AppColors.focus,
      hoverColor: AppColors.hover,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.action,
        selectionColor: AppColors.selection,
      ),
      appBarTheme: AppBarTheme(
        systemOverlayStyle: overlayStyle(palette),
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: AppColors.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.action,
          foregroundColor: AppColors.onAction,
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: AppColors.disabledInk,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.link,
          side: BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: AppColors.focus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: AppColors.danger),
        ),
      ),
    );
  }
}
