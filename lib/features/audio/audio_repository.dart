import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds streaming audio URLs for verse-level recitation.
///
/// Primary CDN: audio.qurancdn.com (Quran.com's own CDN — globally reliable)
/// Fallback CDN: everyayah.com (may be blocked in some regions)
///
/// Both use the same URL path format:
///   /{reciterSlug}/{surahPadded}{ayahPadded}.mp3
/// Example: surah 2, ayah 255 → .../002255.mp3
class AudioRepository {
  const AudioRepository();

  static const _primaryBase = 'https://audio.qurancdn.com';
  static const _fallbackBase = 'https://everyayah.com/data';

  // Available reciters — slug must match CDN folder names.
  static const Map<String, String> reciters = {
    'Alafasy_128kbps': 'Mishary Alafasy',
    'Abdul_Basit_Murattal_192kbps': 'Abdul Basit (Murattal)',
    'Minshawi_Murattal_128kbps': 'Mohamed Siddiq El-Minshawi',
  };

  static const defaultReciter = 'Alafasy_128kbps';

  String _path(int surahNumber, int ayahNumber, String reciter) {
    final s = surahNumber.toString().padLeft(3, '0');
    final a = ayahNumber.toString().padLeft(3, '0');
    return '/$reciter/$s$a.mp3';
  }

  /// Primary streaming URL (Quran.com CDN).
  String ayahUrl(int surahNumber, int ayahNumber, {String? reciter}) {
    final r = reciter ?? defaultReciter;
    return '$_primaryBase${_path(surahNumber, ayahNumber, r)}';
  }

  /// Fallback streaming URL (everyayah.com).
  String ayahFallbackUrl(int surahNumber, int ayahNumber, {String? reciter}) {
    final r = reciter ?? defaultReciter;
    return '$_fallbackBase${_path(surahNumber, ayahNumber, r)}';
  }
}

final audioRepositoryProvider =
    Provider<AudioRepository>((_) => const AudioRepository());
