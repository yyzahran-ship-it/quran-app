import 'package:flutter/material.dart';

// Quran app palette — warm off-white for day, deep navy for night.
const _seedColor = Color(0xFF1B6B3A); // Forest green (Islam-inspired)

final appThemeLight = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: _seedColor,
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFFAF7F2), // warm off-white
  textTheme: _baseTextTheme,
);

final appThemeDark = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: _seedColor,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF0D1117), // near-black for eye comfort
  textTheme: _baseTextTheme,
);

// True inverted (white-on-black) for night reading — CLAUDE.md requirement.
final appThemeInverted = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: _seedColor,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Colors.black,
  textTheme: _baseTextTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
);

const _baseTextTheme = TextTheme(
  // Arabic Quran text uses UthmanicHafs font; translation uses system default.
  bodyLarge: TextStyle(fontSize: 18),
  bodyMedium: TextStyle(fontSize: 16),
  bodySmall: TextStyle(fontSize: 14),
);
