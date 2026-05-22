import 'package:flutter/material.dart';

// ─── King Fahad Mushaf Complex — Official Color Palette ──────────────────────
//
// The printed Madinah Mushaf uses:
//   • Warm parchment cream  (#FDF6E3) for page background
//   • Deep forest green     (#1B5E20) for chapter headers & navigation
//   • Burnished gold        (#B8860B / #D4AF37) for ornamental borders & accents
//   • Near-black ink        (#1A1A1A) for Arabic text
//   • Soft charcoal         (#3E3E3E) for secondary text
//
// These values replicate the authentic printed Mushaf experience on screen.

// Primary seed: forest green (matches KFGQPC chapter header color)
const _kSeedColor = Color(0xFF1B5E20);

// Mushaf parchment — light mode scaffold background
const kMushafahCream = Color(0xFFFDF6E3);
// Gold ornamental — borders, badges, dividers
const kMushafahGold = Color(0xFFB8860B);
const kMushafahGoldLight = Color(0xFFD4AF37);
// Forest green — AppBar, chapter headers, navigation
const kMushafahGreen = Color(0xFF1B5E20);
const kMushafahGreenLight = Color(0xFF2E7D32);
// Night mode background
const kMushafahNight = Color(0xFF0D1117);

// ─── Text theme (shared across all modes) ────────────────────────────────────
//
// Arabic Quran text uses UthmanicHafs (KFGQPC official font).
// Translation / UI text uses the system default (Roboto on Android).

const _kBaseTextTheme = TextTheme(
  displayLarge: TextStyle(
    fontFamily: 'UthmanicHafs',
    fontSize: 36,
    fontWeight: FontWeight.w400,
    height: 2.2,
  ),
  displayMedium: TextStyle(
    fontFamily: 'UthmanicHafs',
    fontSize: 30,
    fontWeight: FontWeight.w400,
    height: 2.2,
  ),
  displaySmall: TextStyle(
    fontFamily: 'UthmanicHafs',
    fontSize: 26,
    fontWeight: FontWeight.w400,
    height: 2.2,
  ),
  // bodyLarge is the default Arabic verse text style
  bodyLarge: TextStyle(
    fontFamily: 'UthmanicHafs',
    fontSize: 28,
    height: 2.2,
    fontWeight: FontWeight.w400,
  ),
  bodyMedium: TextStyle(fontSize: 16, height: 1.6),
  bodySmall: TextStyle(fontSize: 14, height: 1.5),
);

// ─── Light theme (Mushaf white — matches the printed page image background) ───

final appThemeLight = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: _kSeedColor,
  brightness: Brightness.light,
  scaffoldBackgroundColor: Colors.white,
  textTheme: _kBaseTextTheme,
  appBarTheme: const AppBarTheme(
    // White AppBar matches the King Fahad Mushaf page header style
    backgroundColor: Colors.white,
    foregroundColor: Color(0xFF1A1A1A),
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: IconThemeData(color: Colors.white),
    actionsIconTheme: IconThemeData(color: Colors.white),
    shape: Border(
      bottom: BorderSide(color: kMushafahGold, width: 2),
    ),
  ),
  cardTheme: const CardThemeData(
    color: kMushafahCream,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
      side: BorderSide(color: kMushafahGold, width: 0.8),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: kMushafahGold,
    thickness: 0.5,
  ),
  iconTheme: const IconThemeData(color: kMushafahGreen),
  listTileTheme: const ListTileThemeData(
    iconColor: kMushafahGreen,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: kMushafahGreen,
    selectedItemColor: kMushafahGoldLight,
    unselectedItemColor: Colors.white70,
    elevation: 0,
  ),
  sliderTheme: const SliderThemeData(
    activeTrackColor: kMushafahGreen,
    thumbColor: kMushafahGold,
    inactiveTrackColor: Color(0xFFB0BEC5),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xFFF5E6C8),
    labelStyle: const TextStyle(
      fontSize: 11,
      color: kMushafahGreen,
      fontWeight: FontWeight.w600,
    ),
    side: const BorderSide(color: kMushafahGold, width: 0.8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
);

// ─── Dark theme (night reading) ───────────────────────────────────────────────

final appThemeDark = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: _kSeedColor,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kMushafahNight,
  textTheme: _kBaseTextTheme,
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1A2E1A),
    foregroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: IconThemeData(color: Colors.white),
    actionsIconTheme: IconThemeData(color: Colors.white),
    shape: Border(
      bottom: BorderSide(color: kMushafahGold, width: 2),
    ),
  ),
  cardTheme: const CardThemeData(
    color: Color(0xFF1E2A1E),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
      side: BorderSide(color: kMushafahGold, width: 0.8),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: kMushafahGold,
    thickness: 0.5,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFF1A2E1A),
    selectedItemColor: kMushafahGoldLight,
    unselectedItemColor: Colors.white54,
    elevation: 0,
  ),
  sliderTheme: const SliderThemeData(
    activeTrackColor: kMushafahGreenLight,
    thumbColor: kMushafahGold,
    inactiveTrackColor: Color(0xFF455A64),
  ),
);

// ─── Inverted theme (true black — night reading) ──────────────────────────────

final appThemeInverted = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: _kSeedColor,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Colors.black,
  textTheme: _kBaseTextTheme.apply(
    bodyColor: Colors.white,
    displayColor: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0A0A0A),
    foregroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
    shape: Border(
      bottom: BorderSide(color: kMushafahGold, width: 2),
    ),
  ),
  cardTheme: const CardThemeData(
    color: Color(0xFF111111),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
      side: BorderSide(color: kMushafahGold, width: 0.8),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: kMushafahGold,
    thickness: 0.5,
  ),
);
