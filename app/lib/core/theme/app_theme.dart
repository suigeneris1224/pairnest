import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'palettes.dart';

ThemeData buildTheme(PairnestPalette p, {bool googleFonts = true}) {
  final brightness = p.isDark ? Brightness.dark : Brightness.light;
  final base = ThemeData(brightness: brightness, useMaterial3: true);

  var text = base.textTheme.apply(bodyColor: p.text, displayColor: p.text);
  if (googleFonts) {
    text = text.apply(fontFamily: GoogleFonts.inter().fontFamily);
    final heading = GoogleFonts.nunito;
    text = text.copyWith(
      displaySmall: heading(textStyle: text.displaySmall, fontWeight: FontWeight.w800),
      headlineMedium: heading(textStyle: text.headlineMedium, fontWeight: FontWeight.w800),
      headlineSmall: heading(textStyle: text.headlineSmall, fontWeight: FontWeight.w800),
      titleLarge: heading(textStyle: text.titleLarge, fontWeight: FontWeight.w800),
      titleMedium: heading(textStyle: text.titleMedium, fontWeight: FontWeight.w700),
    );
  }

  // Headings use the palette's deep tone, as in the dashboard design.
  text = text.copyWith(
    displaySmall: text.displaySmall?.copyWith(color: p.heading),
    headlineMedium: text.headlineMedium?.copyWith(color: p.heading),
    headlineSmall: text.headlineSmall?.copyWith(color: p.heading),
    titleLarge: text.titleLarge?.copyWith(color: p.heading),
    titleMedium: text.titleMedium?.copyWith(color: p.heading),
  );

  final radius12 = BorderRadius.circular(14);

  return base.copyWith(
    extensions: [p],
    scaffoldBackgroundColor: p.background,
    textTheme: text,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: p.primaryDeep,
      onPrimary: p.onPrimary,
      primaryContainer: p.soft,
      onPrimaryContainer: p.text,
      secondary: p.accent,
      onSecondary: Colors.white,
      error: const Color(0xFFD9534F),
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.text,
      surfaceContainerHighest: p.soft,
      outline: p.border,
      outlineVariant: p.border,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(fontSize: 20),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: p.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primaryDeep,
        foregroundColor: p.onPrimary,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: text.titleMedium?.copyWith(fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.primaryDeep,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        side: BorderSide(color: p.primary),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: p.primaryDeep)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      labelStyle: TextStyle(color: p.muted),
      hintStyle: TextStyle(color: p.muted.withValues(alpha: 0.7)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: radius12,
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius12,
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius12,
        borderSide: BorderSide(color: p.primary, width: 1.5),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primaryDeep : null),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.background,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.surface),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.text,
      contentTextStyle: TextStyle(color: p.background),
      shape: RoundedRectangleBorder(borderRadius: radius12),
    ),
    dividerTheme: DividerThemeData(color: p.border, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primaryDeep),
  );
}
