import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds streaming audio URLs for verse-level recitation.
///
/// CDN priority order tried by AudioNotifier:
///   1. cdn.islamic.network  — uses global ayah ID (1-6236)
///   2. audio.qurancdn.com   — uses surah+ayah padded path
///   3. everyayah.com        — same padded path, fallback
///   4. verses.quran.foundation — quran.com CDN (Bandar Baleela only)
class AudioRepository {
  const AudioRepository();

  static const _islamicNetBase = 'https://cdn.islamic.network/quran/audio/128';
  static const _primaryBase = 'https://audio.qurancdn.com';
  static const _fallbackBase = 'https://everyayah.com/data';
  static const _versesQfBase = 'https://verses.quran.foundation';

  // Available reciters.
  // For CDNs 1-3 the key is also the folder name used in the URL path.
  // For verses.quran.foundation reciters see _versesQfFolders below.
  static const Map<String, String> reciters = {
    'Alafasy_128kbps': 'Mishary Alafasy',
    'Bandar_Baleela': 'Bandar Baleela',
    'Abdul_Basit_Murattal_192kbps': 'Abdul Basit (Murattal)',
    'Minshawi_Murattal_128kbps': 'Mohamed Siddiq El-Minshawi',
    'Husary_128kbps': 'Mahmoud Al-Husary',
  };

  // cdn.islamic.network edition identifiers (CDN 1).
  static const Map<String, String> _islamicNetIds = {
    'Alafasy_128kbps': 'ar.alafasy',
    'Abdul_Basit_Murattal_192kbps': 'ar.abdulbasitmurattal',
    'Minshawi_Murattal_128kbps': 'ar.minshawi',
    'Husary_128kbps': 'ar.husary',
  };

  // Candidate folder names on verses.quran.foundation (CDN 4), tried in
  // order. The CDN uses PascalCase concatenated names (Alafasy, AbdulBaset)
  // so BandarBaleela is the most likely — the others are fallbacks.
  static const Map<String, List<String>> _versesQfFolders = {
    'Bandar_Baleela': ['BandarBaleela', 'bandar_baleela', 'Bandar_Baleela'],
  };

  static const defaultReciter = 'Alafasy_128kbps';

  String _path(int surahNumber, int ayahNumber, String reciter) {
    final s = surahNumber.toString().padLeft(3, '0');
    final a = ayahNumber.toString().padLeft(3, '0');
    return '/$reciter/$s$a.mp3';
  }

  /// CDN 1 — cdn.islamic.network (global ayah ID 1-6236).
  /// Returns null for reciters not on this CDN.
  String? ayahUrlIslamicNet(int globalAyahId, {String? reciter}) {
    final r = reciter ?? defaultReciter;
    final id = _islamicNetIds[r];
    if (id == null) return null;
    return '$_islamicNetBase/$id/$globalAyahId.mp3';
  }

  /// CDN 2 — audio.qurancdn.com (surah+ayah padded path).
  String ayahUrl(int surahNumber, int ayahNumber, {String? reciter}) {
    final r = reciter ?? defaultReciter;
    return '$_primaryBase${_path(surahNumber, ayahNumber, r)}';
  }

  /// CDN 3 — everyayah.com fallback.
  String ayahFallbackUrl(int surahNumber, int ayahNumber, {String? reciter}) {
    final r = reciter ?? defaultReciter;
    return '$_fallbackBase${_path(surahNumber, ayahNumber, r)}';
  }

  /// CDN 4 — verses.quran.foundation (quran.com's verse CDN).
  /// Returns candidate URLs for reciters hosted there, or empty list.
  List<String> ayahUrlsVersesQf(int surahNumber, int ayahNumber,
      {String? reciter}) {
    final r = reciter ?? defaultReciter;
    final folders = _versesQfFolders[r];
    if (folders == null) return const [];
    final s = surahNumber.toString().padLeft(3, '0');
    final a = ayahNumber.toString().padLeft(3, '0');
    return folders
        .map((f) => '$_versesQfBase/$f/mp3/$s$a.mp3')
        .toList();
  }
}

final audioRepositoryProvider =
    Provider<AudioRepository>((_) => const AudioRepository());
