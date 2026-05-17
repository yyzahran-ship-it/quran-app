import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds streaming audio URLs for verse-level recitation.
///
/// everyayah.com provides free, verse-level MP3s with a consistent URL scheme:
///   https://everyayah.com/data/{reciterSlug}/{surahPadded}{ayahPadded}.mp3
///
/// Example: surah 2, ayah 255 → .../002255.mp3
class AudioRepository {
  const AudioRepository();

  static const _baseUrl = 'https://everyayah.com/data';

  // Available reciters — slug must match everyayah.com folder names.
  static const Map<String, String> reciters = {
    'Alafasy_128kbps': 'Mishary Alafasy',
    'Abdul_Basit_Murattal_192kbps': 'Abdul Basit (Murattal)',
    'Minshawi_Murattal_128kbps': 'Mohamed Siddiq El-Minshawi',
  };

  static const defaultReciter = 'Alafasy_128kbps';

  /// Streaming URL for a single ayah.
  String ayahUrl(int surahNumber, int ayahNumber, {String? reciter}) {
    final r = reciter ?? defaultReciter;
    final s = surahNumber.toString().padLeft(3, '0');
    final a = ayahNumber.toString().padLeft(3, '0');
    return '$_baseUrl/$r/$s$a.mp3';
  }

  /// Streaming URLs for all ayahs in a surah, in order.
  List<String> surahUrls(int surahNumber, int ayahCount, {String? reciter}) {
    return List.generate(
      ayahCount,
      (i) => ayahUrl(surahNumber, i + 1, reciter: reciter),
    );
  }
}

final audioRepositoryProvider = Provider<AudioRepository>((_) => const AudioRepository());
