import 'package:flutter/material.dart';

/// Palette copied from web/src/theme.css. Keep both files in sync.
class AppColors {
  AppColors._();

  static const ink = Color(0xFF243247);
  static const action = Color(0xFF0866D9);
  static const actionHover = Color(0xFF0754B3);
  static const onAction = Color(0xFFFFFFFF);
  static const muted = Color(0xFF606975);
  static const paper = Color(0xFFF5F6F8);
  static const white = Color(0xFFFFFFFF);
  static const line = Color(0xFFD8DDE5);
  static const wash = Color(0xFFE9EDF3);
  static const stage = Color(0xFFEDF2F8);
  static const hover = Color(0xFFEAF1FB);
  static const selection = Color(0xFFD4E5FF);
  static const disabled = Color(0xFFE2E6EC);
  static const disabledInk = Color(0xFF5B6575);
  static const focus = Color(0xFF0866D9);
  static const success = Color(0xFF39604F);
  static const successWash = Color(0xFFE8F0EB);
  static const danger = Color(0xFFA12B35);
  static const dangerWash = Color(0xFFFDF0F1);
  // CSS #24324712 is RRGGBBAA; Flutter's Color is AARRGGBB.
  static const shadow = Color(0x12243247);
  static const orbit = Color(0xFFC9D9ED);
  static const globe = action;

  // Workspace tokens, also in web/src/theme.css: the Chats background, the
  // message bubbles and the role chips.
  static const sidebar = Color(0xFFEEF1F5);
  static const incomingBubble = wash;
  static const outgoingBubble = action;
  static const outgoingText = onAction;
  static const link = action;
  static const hackerInk = Color(0xFF24558C);
  static const hackerWash = Color(0xFFE6EFFA);
  static const mentorInk = Color(0xFF39604F);
  static const mentorWash = Color(0xFFE8F0EB);
  static const sponsorInk = Color(0xFF805915);
  static const sponsorWash = Color(0xFFF6E9C9);

  // The little crown on "Find mentor" (web/src/hacky.css .hk-crown).
  static const crown = Color(0xFFF1B938);
  static const crownLine = Color(0xFFA8741A);
}

/// The app's ThemeData: Lato, the web palette and the web's 12px radius.
class AppTheme {
  AppTheme._();

  static const fontFamily = 'Lato';
  static const radius = 12.0;
  static final borderRadius = BorderRadius.circular(radius);

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
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
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.action,
        selectionColor: AppColors.selection,
      ),
      appBarTheme: const AppBarTheme(
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
          side: const BorderSide(color: AppColors.line),
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
          side: const BorderSide(color: AppColors.line),
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
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: AppColors.focus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
    );
  }
}
