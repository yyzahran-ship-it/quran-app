import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'package:flutter/material.dart';

enum AppThemeMode { light, dark, inverted, highContrast }

class ThemeNotifier extends Notifier<AppThemeMode> {
  static const _key = 'theme_mode';

  @override
  AppThemeMode build() {
    _loadFromPrefs();
    return AppThemeMode.light; // default until prefs load
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      state = AppThemeMode.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppThemeMode.light,
      );
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, AppThemeMode>(ThemeNotifier.new);

ThemeData themeDataFor(AppThemeMode mode) => switch (mode) {
      AppThemeMode.light => appThemeLight,
      AppThemeMode.dark => appThemeDark,
      AppThemeMode.inverted => appThemeInverted,
      AppThemeMode.highContrast => appThemeHighContrast,
    };
