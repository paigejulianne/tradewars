import 'package:flutter/material.dart';

class TWColors {
  static const bg = Color(0xFF05060F);
  static const panel = Color(0xFF0C0E1C);
  static const panelAlt = Color(0xFF12142A);
  static const border = Color(0xFF2A2F55);
  static const accent = Color(0xFF7FD1FF);
  static const accent2 = Color(0xFF3DDC84);
  static const danger = Color(0xFFFF5C5C);
  static const warning = Color(0xFFFFC857);
  static const text = Color(0xFFE8ECFF);
  static const textDim = Color(0xFF9AA3CC);
}

ThemeData buildTwTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: TWColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: TWColors.accent,
      secondary: TWColors.accent2,
      error: TWColors.danger,
      surface: TWColors.panel,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: TWColors.text,
      displayColor: TWColors.text,
      fontFamily: 'monospace',
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: TWColors.panel,
      foregroundColor: TWColors.text,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: TWColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: TWColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TWColors.panelAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: TWColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: TWColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: TWColors.accent),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TWColors.accent,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    dividerColor: TWColors.border,
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: TWColors.panel,
      selectedIconTheme: IconThemeData(color: TWColors.accent),
      selectedLabelTextStyle: TextStyle(color: TWColors.accent),
      unselectedIconTheme: IconThemeData(color: TWColors.textDim),
      unselectedLabelTextStyle: TextStyle(color: TWColors.textDim),
    ),
  );
}
