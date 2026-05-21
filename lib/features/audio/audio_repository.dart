import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds streaming audio URLs for verse-level recitation.
///
/// CDN priority order tried by AudioNotifier:
///   1. cdn.islamic.network  — uses global ayah ID (1-6236), very reliable
///   2. audio.qurancdn.com   — uses surah+ayah padding, same folder names
///   3. everyayah.com        — same path format, fallback
class AudioRepository {
  const AudioRepository();

  static const _islamicNetBase = 'https://cdn.islamic.network/quran/audio/128';
  static const _primaryBase = 'https://audio.qurancdn.com';
  static const _fallbackBase = 'https://everyayah.com/data';

  // Available reciters — slug must match CDN folder names (CDN 2 & 3).
  static const Map<String, String> reciters = {
    'Alafasy_128kbps': 'Mishary Alafasy',
    'Bandar_Balilah_128kbps': 'Bandar Balilah',
    'Abdul_Basit_Murattal_192kbps': 'Abdul Basit (Murattal)',
    'Minshawi_Murattal_128kbps': 'Mohamed Siddiq El-Minshawi',
  };

  // cdn.islamic.network identifiers (CDN 1).
  static const Map<String, String> _islamicNetIds = {
    'Alafasy_128kbps': 'ar.alafasy',
    'Bandar_Balilah_128kbps': 'ar.bandarbalilah',
    'Abdul_Basit_Murattal_192kbps': 'ar.abdulbasitmurattal',
    'Minshawi_Murattal_128kbps': 'ar.minshawi',
  };

  static const defaultReciter = 'Alafasy_128kbps';

  String _path(int surahNumber, int ayahNumber, String reciter) {
    final s = surahNumber.toString().padLeft(3, '0');
    final a = ayahNumber.toString().padLeft(3, '0');
    return '/$reciter/$s$a.mp3';
  }

  /// CDN 1 — cdn.islamic.network (global ayah ID 1-6236).
  String ayahUrlIslamicNet(int globalAyahId, {String? reciter}) {
    final r = reciter ?? defaultReciter;
    final id = _islamicNetIds[r] ?? 'ar.alafasy';
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
}

final audioRepositoryProvider =
    Provider<AudioRepository>((_) => const AudioRepository());

