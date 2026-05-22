import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/dyslexia_provider.dart';
import '../audio/audio_provider.dart';
import '../audio/audio_repository.dart';
import '../mushaf/mushaf_provider.dart';
import '../mushaf/tafsir_repository.dart';

// ─── Font size persistence ────────────────────────────────────────────────────

class FontSizeNotifier extends Notifier<double> {
  static const _key = 'arabic_font_size';
  static const _default = 26.0;
  static const _min = 14.0; // ~50% of default
  static const _max = 56.0; // ~200% of default

  @override
  double build() {
    _load();
    return _default;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble(_key) ?? _default;
  }

  Future<void> set(double size) async {
    state = size.clamp(_min, _max);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, state);
  }
}

final fontSizeProvider =
    NotifierProvider<FontSizeNotifier, double>(FontSizeNotifier.new);

// Translation font size is controlled independently from Arabic.
class TranslationFontSizeNotifier extends Notifier<double> {
  static const _key = 'translation_font_size';
  static const _default = 13.0;
  static const _min = 10.0;
  static const _max = 22.0;

  @override
  double build() {
    _load();
    return _default;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble(_key) ?? _default;
  }

  Future<void> set(double size) async {
    state = size.clamp(_min, _max);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, state);
  }
}

final translationFontSizeProvider =
    NotifierProvider<TranslationFontSizeNotifier, double>(
        TranslationFontSizeNotifier.new);

// ─── Settings screen ──────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final translationFontSize = ref.watch(translationFontSizeProvider);
    final dyslexiaFont = ref.watch(dyslexiaFontProvider);
    final audio = ref.watch(audioProvider);
    final tafsirId = ref.watch(tafsirIdProvider);
    final mushaf = ref.watch(mushafProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Appearance ────────────────────────────────────────────────────
          _SectionHeader(title: 'Appearance', colors: colors),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            trailing: DropdownButton<AppThemeMode>(
              value: theme,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                    value: AppThemeMode.light, child: Text('Light')),
                DropdownMenuItem(
                    value: AppThemeMode.dark, child: Text('Dark')),
                DropdownMenuItem(
                    value: AppThemeMode.inverted,
                    child: Text('Inverted (night)')),
                DropdownMenuItem(
                    value: AppThemeMode.highContrast,
                    child: Text('High Contrast')),
              ],
              onChanged: (v) {
                if (v != null) ref.read(themeProvider.notifier).setTheme(v);
              },
            ),
          ),
          _FontSizeTile(
            label: 'Arabic font size',
            value: fontSize,
            min: FontSizeNotifier._min,
            max: FontSizeNotifier._max,
            defaultValue: 26.0,
            divisions: 21,
            colors: colors,
            onChanged: (v) => ref.read(fontSizeProvider.notifier).set(v),
          ),
          _FontSizeTile(
            label: 'Translation font size',
            value: translationFontSize,
            min: TranslationFontSizeNotifier._min,
            max: TranslationFontSizeNotifier._max,
            defaultValue: 13.0,
            divisions: 12,
            colors: colors,
            onChanged: (v) =>
                ref.read(translationFontSizeProvider.notifier).set(v),
          ),
          // Dyslexia-friendly font: monospace + extra letter spacing + tall line
          // height for translation text. Arabic Quran text is not affected.
          SwitchListTile(
            secondary: const Icon(Icons.font_download_outlined),
            title: const Text('Dyslexia-friendly translation font'),
            subtitle: const Text(
              'Applies monospace font with extra letter spacing and '
              'line height to translation text only.',
              style: TextStyle(fontSize: 12),
            ),
            value: dyslexiaFont,
            onChanged: (v) =>
                ref.read(dyslexiaFontProvider.notifier).setEnabled(enabled: v),
          ),
          // ── Reading ───────────────────────────────────────────────────────
          _SectionHeader(title: 'Reading', colors: colors),
          ListTile(
            leading: const Icon(Icons.translate_outlined),
            title: const Text('Translation language'),
            subtitle: mushaf.availableTranslationKeys.length <= 1
                ? const Text(
                    'Only Sahih International available — see README to add more',
                    style: TextStyle(fontSize: 11),
                  )
                : null,
            trailing: DropdownButton<String>(
              value: mushaf.activeTranslationKey,
              underline: const SizedBox.shrink(),
              items: mushaf.availableTranslationKeys
                  .map((k) => DropdownMenuItem(
                        value: k,
                        child: Text(
                          kTranslationNames[k] ?? k,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref.read(mushafProvider.notifier).setTranslationKey(v);
                }
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.book_outlined),
            title: const Text('Tafsir'),
            trailing: DropdownButton<int>(
              value: tafsirId,
              underline: const SizedBox.shrink(),
              items: kTafsirs
                  .map((t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(
                          '${t.name} (${t.language})',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) ref.read(tafsirIdProvider.notifier).set(v);
              },
            ),
          ),
          // ── Audio ─────────────────────────────────────────────────────────
          _SectionHeader(title: 'Audio', colors: colors),
          ListTile(
            leading: const Icon(Icons.mic_none_outlined),
            title: const Text('Reciter'),
            trailing: DropdownButton<String>(
              value: audio.reciter,
              underline: const SizedBox.shrink(),
              items: AudioRepository.reciters.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value,
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref.read(audioProvider.notifier).setReciter(v);
                }
              },
            ),
          ),
          // ── About ─────────────────────────────────────────────────────────
          _SectionHeader(title: 'About', colors: colors),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Quran text'),
            subtitle: const Text('Tanzil Uthmani script — tanzil.net'),
          ),
          ListTile(
            leading: const Icon(Icons.translate_outlined),
            title: const Text('Translation'),
            subtitle: const Text('Saheeh International'),
          ),
          ListTile(
            leading: const Icon(Icons.headphones_outlined),
            title: const Text('Audio'),
            subtitle: const Text(
                'Streamed from audio.qurancdn.com — requires internet'),
          ),
          ListTile(
            leading: const Icon(Icons.font_download_outlined),
            title: const Text('Font'),
            subtitle: const Text(
              'KFGQPC Uthmanic Script Hafs v8 — King Fahad Quran Printing Complex',
            ),
          ),
          // Live font preview — plain white background matching the Mushaf page
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                    color: const Color(0xFFCCCCCC), width: 0.8),
              ),
              child: const Text(
                'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'UthmanicHafs',
                  fontSize: 26,
                  height: 2.4,
                  color: Color(0xFF0D0D0D),
                ),
              ),
            ),
          ),
          // ── Privacy ───────────────────────────────────────────────────────
          _SectionHeader(title: 'Privacy', colors: colors),
          ListTile(
            leading: Icon(Icons.shield_outlined, color: colors.primary),
            title: const Text('Zero tracking'),
            subtitle: const Text(
              'No analytics, no crash reporters, no third-party SDKs. '
              'Your reading habits stay on your device.',
            ),
            isThreeLine: true,
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(fontSize: 11, color: colors.outlineVariant),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'No tracking · No ads · No subscription · Forever free',
              style: TextStyle(fontSize: 11, color: colors.outlineVariant),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Font size tile ───────────────────────────────────────────────────────────

class _FontSizeTile extends StatelessWidget {
  const _FontSizeTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.defaultValue,
    required this.divisions,
    required this.colors,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double defaultValue;
  final int divisions;
  final ColorScheme colors;
  final ValueChanged<double> onChanged;

  String get _pct =>
      '${((value / defaultValue) * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.format_size),
      title: Text(label),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: _pct,
        onChanged: onChanged,
      ),
      trailing: Text(
        _pct,
        style:
            TextStyle(fontWeight: FontWeight.bold, color: colors.primary),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.colors});

  final String title;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: colors.primary,
        ),
      ),
    );
  }
}
