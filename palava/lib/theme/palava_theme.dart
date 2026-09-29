import 'package:flutter/material.dart';

import 'palava_colors.dart';

/// Font family names, matching the entries in pubspec.yaml.
class PalavaFonts {
  PalavaFonts._();

  static const title = 'Fraunces';
  static const body = 'DMSans';
}

/// Corner radii used across the app (brief: 12–20).
class PalavaRadius {
  PalavaRadius._();

  static const small = 12.0;
  static const medium = 16.0;
  static const large = 20.0;
}

ThemeData buildPalavaTheme() {
  const scheme = ColorScheme.dark(
    primary: PalavaColors.ember,
    onPrimary: PalavaColors.text,
    secondary: PalavaColors.gold,
    onSecondary: PalavaColors.background,
    surface: PalavaColors.card,
    onSurface: PalavaColors.text,
    outline: PalavaColors.cardBorder,
  );

  const titleStyle = TextStyle(
    fontFamily: PalavaFonts.title,
    fontWeight: FontWeight.w700,
    color: PalavaColors.text,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: PalavaFonts.body,
    scaffoldBackgroundColor: PalavaColors.background,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: PalavaColors.text, displayColor: PalavaColors.text)
        .copyWith(
          displaySmall: titleStyle.copyWith(fontSize: 34, height: 1.1),
          headlineMedium: titleStyle.copyWith(fontSize: 28, height: 1.15),
          headlineSmall: titleStyle.copyWith(fontSize: 22, height: 1.2),
          titleLarge: titleStyle.copyWith(fontSize: 20),
          titleMedium: const TextStyle(
            fontFamily: PalavaFonts.body,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: PalavaColors.text,
          ),
          bodyLarge: const TextStyle(
            fontFamily: PalavaFonts.body,
            fontSize: 16,
            color: PalavaColors.text,
            height: 1.45,
          ),
          bodyMedium: const TextStyle(
            fontFamily: PalavaFonts.body,
            fontSize: 14,
            color: PalavaColors.textSecondary,
            height: 1.45,
          ),
          bodySmall: const TextStyle(
            fontFamily: PalavaFonts.body,
            fontSize: 12,
            color: PalavaColors.textQuiet,
          ),
          labelLarge: const TextStyle(
            fontFamily: PalavaFonts.body,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: PalavaColors.background,
      foregroundColor: PalavaColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: PalavaFonts.title,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: PalavaColors.text,
      ),
    ),
    cardTheme: CardThemeData(
      color: PalavaColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PalavaRadius.medium),
        side: const BorderSide(color: PalavaColors.cardBorder),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: PalavaColors.cardBorder,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PalavaColors.ember,
        foregroundColor: PalavaColors.text,
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(
          fontFamily: PalavaFonts.body,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PalavaRadius.medium),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PalavaColors.text,
        minimumSize: const Size(64, 52),
        side: const BorderSide(color: PalavaColors.cardBorder),
        textStyle: const TextStyle(
          fontFamily: PalavaFonts.body,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PalavaRadius.medium),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: PalavaColors.textSecondary,
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(
          fontFamily: PalavaFonts.body,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PalavaColors.card,
      hintStyle: const TextStyle(
        fontFamily: PalavaFonts.body,
        color: PalavaColors.textQuiet,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PalavaRadius.medium),
        borderSide: const BorderSide(color: PalavaColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PalavaRadius.medium),
        borderSide: const BorderSide(color: PalavaColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PalavaRadius.medium),
        borderSide: const BorderSide(color: PalavaColors.ember, width: 1.5),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? PalavaColors.text
            : PalavaColors.textQuiet,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? PalavaColors.ember
            : PalavaColors.cardBorder,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: PalavaColors.background,
      showDragHandle: true,
      dragHandleColor: PalavaColors.cardBorder,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PalavaRadius.large),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: PalavaColors.background,
      indicatorColor: PalavaColors.card,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: PalavaFonts.body,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? PalavaColors.ember
              : PalavaColors.textQuiet,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? PalavaColors.ember
              : PalavaColors.textQuiet,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: PalavaColors.card,
      contentTextStyle: TextStyle(
        fontFamily: PalavaFonts.body,
        color: PalavaColors.text,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
