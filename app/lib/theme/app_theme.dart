import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.g.dart';

/// KnowBody theme, derived from the shared design tokens (`packages/design-tokens`).
/// Regenerate `tokens.g.dart` with `node packages/design-tokens/build.mjs`.
abstract final class AppTheme {
  static ThemeData light() {
    final textTheme = GoogleFonts.promptTextTheme();
    final scheme = ColorScheme.fromSeed(
      seedColor: KbTokens.limeColor,
      primary: KbTokens.limeColor,
      onPrimary: KbTokens.inkColor,
      surface: KbTokens.surfaceColor,
      onSurface: KbTokens.inkColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: KbTokens.surfaceColor,
      textTheme: textTheme.apply(
        bodyColor: KbTokens.inkColor,
        displayColor: KbTokens.inkColor,
      ),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: KbTokens.inkColor,
      ),
      // Primary is lime, so default TextButtons (dialog/date-picker OK/Cancel)
      // would be lime-on-white and invisible — force ink foreground.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: KbTokens.inkColor),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: KbTokens.surfaceColor,
        headerBackgroundColor: KbTokens.inkColor,
        headerForegroundColor: Colors.white,
        todayForegroundColor: const WidgetStatePropertyAll(KbTokens.inkColor),
        todayBorder: const BorderSide(color: KbTokens.inkColor),
        dayForegroundColor: const WidgetStatePropertyAll(KbTokens.inkColor),
        yearForegroundColor: const WidgetStatePropertyAll(KbTokens.inkColor),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: KbTokens.inkColor),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: KbTokens.inkColor),
      ),
    );
  }

  // Reusable style shorthands ----------------------------------------------
  static TextStyle display() =>
      GoogleFonts.prompt(fontSize: 34, height: 1.15, letterSpacing: -0.6, fontWeight: FontWeight.w600, color: KbTokens.inkColor);
  static TextStyle title() =>
      GoogleFonts.prompt(fontSize: 24, height: 1.2, letterSpacing: -0.4, fontWeight: FontWeight.w600, color: KbTokens.inkColor);
  static TextStyle heading() =>
      GoogleFonts.prompt(fontSize: 17, fontWeight: FontWeight.w600, color: KbTokens.inkColor);
  static TextStyle body({Color? color}) =>
      GoogleFonts.prompt(fontSize: 15, height: 1.5, color: color ?? KbTokens.inkColor);
  static TextStyle label({Color? color}) =>
      GoogleFonts.prompt(fontSize: 13, fontWeight: FontWeight.w500, color: color ?? KbTokens.inkSoftColor);
  static TextStyle caption({Color? color}) =>
      GoogleFonts.prompt(fontSize: 12, color: color ?? KbTokens.inkFaintColor);

  static const cardRadius = BorderRadius.all(Radius.circular(KbTokens.radiusCard));
  static const heroRadius = BorderRadius.all(Radius.circular(KbTokens.radiusHero));
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 8)),
  ];
}
