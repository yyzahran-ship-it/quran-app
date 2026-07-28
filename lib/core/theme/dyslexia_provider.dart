import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Dyslexia-friendly font setting ──────────────────────────────────────────
//
// When enabled, translation text is rendered with:
//   • fontFamily: 'monospace'   — equal-width characters aid tracking
//   • letterSpacing: 1.0        — extra spacing between letters
//   • height: 1.8               — generous line height reduces crowding
//
// The Arabic Quran text is intentionally NOT affected — UthmanicHafs is a
// liturgically significant font and must not be substituted.

class DyslexiaFontNotifier extends Notifier<bool> {
  static const _key = 'dyslexia_font';

  @override
  bool build() {
    _load();
    return false; // default until prefs load
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled({required bool enabled}) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

final dyslexiaFontProvider =
    NotifierProvider<DyslexiaFontNotifier, bool>(DyslexiaFontNotifier.new);
