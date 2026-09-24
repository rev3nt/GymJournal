import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/models.dart';

/// Colors from Lift Log prototype `:root` oklch tokens (converted to sRGB).
abstract final class AppColors {
  static const bg = Color(0xFF1A1A1A); // oklch(15.9% 0 89.9)
  static const surface = Color(0xFF2B2B2B); // oklch(21.8% 0 89.9)
  static const fg = Color(0xFFF3F3F3); // oklch(96.1% 0 89.9)
  static const muted = Color(0xFF949494); // oklch(63.3% 0 89.9)
  static const border = Color(0xFF3A3A3A); // oklch(28.5% 0 89.9)
  static const accent = Color(0xFF7EFFB2); // oklch(88.5% 0.204 154.7)
  static const accentOn = Color(0xFF0A2E18); // oklch(18% 0.04 155)
  static const danger = Color(0xFFE45757); // oklch(65.7% 0.173 23.1)
  static const setNormal = Color(0xFF4A4A4A); // oklch(34.8% 0 89.9)
  static const setDrop = Color(0xFFE45757);
  static const setMyo = Color(0xFF7A8CFF); // oklch(61.3% 0.169 269.7)
  static const setCheat = Color(0xFFE8C15A); // oklch(80.8% 0.122 81.5)
  static const accentSoft = Color(0x297EFFB2); // accent @ 16%
  static const radius = 12.0;
  static const radiusLg = 16.0;
}

Color colorForSetType(SetType type) => switch (type) {
      SetType.normal => AppColors.fg,
      SetType.drop => AppColors.setDrop,
      SetType.myo => AppColors.setMyo,
      SetType.cheat => AppColors.setCheat,
    };

Color softForSetType(SetType type) => switch (type) {
      SetType.normal => AppColors.border,
      SetType.drop => AppColors.setDrop.withValues(alpha: 0.14),
      SetType.myo => AppColors.setMyo.withValues(alpha: 0.14),
      SetType.cheat => AppColors.setCheat.withValues(alpha: 0.14),
    };

String get appFontFamily {
  if (kIsWeb) return 'Segoe UI';
  if (Platform.isIOS || Platform.isMacOS) return '.SF Pro Text';
  if (Platform.isWindows) return 'Segoe UI';
  return 'Roboto';
}

List<String> get appFontFallbacks => const [
      'SF Pro Text',
      'Segoe UI',
      'Helvetica Neue',
      'Roboto',
      'sans-serif',
    ];

List<String> get monoFontFallbacks => const [
      'SF Mono',
      'ui-monospace',
      'Menlo',
      'Consolas',
      'monospace',
    ];

TextStyle monoStyle({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w500,
  Color color = AppColors.fg,
  double? letterSpacing,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'Consolas',
    fontFamilyFallback: monoFontFallbacks,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: appFontFamily,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.surface,
      primary: AppColors.accent,
      onPrimary: AppColors.accentOn,
      secondary: AppColors.accent,
      error: AppColors.danger,
      onSurface: AppColors.fg,
      outline: AppColors.border,
    ),
  );

  final textTheme = base.textTheme.apply(
    bodyColor: AppColors.fg,
    displayColor: AppColors.fg,
    fontFamily: appFontFamily,
  );

  return base.copyWith(
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    highlightColor: AppColors.fg.withValues(alpha: 0.06),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.fg,
      elevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppColors.radius),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppColors.radius),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppColors.radius),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.muted),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerColor: AppColors.border,
  );
}
