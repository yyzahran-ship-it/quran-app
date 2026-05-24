import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds streaming audio URLs for verse-level recitation.
///
/// CDN priority order tried by AudioNotifier:
///   1. cdn.islamic.network     — global ayah ID (1-6236), fastest for supported reciters
///   2. mirrors.quranicaudio.com — official QuranicAudio mirror (Quran for Android's CDN)
///   3. everyayah.com           — direct fallback, same URL pattern
///   4. audio.qurancdn.com      — additional mirror
///   5. verses.quran.foundation — quran.com CDN (Bandar Baleela only)
class AudioRepository {
  const AudioRepository();

  static const _islamicNetBase  = 'https://cdn.islamic.network/quran/audio/128';
  static const _mirrorsBase     = 'https://mirrors.quranicaudio.com/everyayah';
  static const _fallbackBase    = 'https://everyayah.com/data';
  static const _primaryBase     = 'https://audio.qurancdn.com';
  static const _versesQfBase    = 'https://verses.quran.foundation';

  // Display name → slug.
  // For CDNs 1-3 the slug is also the folder name in the URL path.
  // Reciters with entries in _versesQfFolders use CDN 4 instead.
  static const Map<String, String> reciters = {
    'Alafasy_128kbps': 'Mishary Alafasy',
    'Bandar_Baleela': 'Bandar Baleela',
    'Abdul_Basit_Murattal_192kbps': 'Abdul Basit (Murattal)',
    'Minshawi_Murattal_128kbps': 'Mohamed Siddiq El-Minshawi',
    'Husary_128kbps': 'Mahmoud Al-Husary',
    'MaherAlMuaiqly128kbps': 'Maher Al Muaiqly',
    'Abdullah_Basfar_192kbps': 'Abdullah Basfar',
    'Shuraim_128kbps': "Sa'ud ash-Shuraym",
  };

  // cdn.islamic.network edition identifiers (CDN 1).
  static const Map<String, String> _islamicNetIds = {
    'Alafasy_128kbps': 'ar.alafasy',
    'Abdul_Basit_Murattal_192kbps': 'ar.abdulbasitmurattal',
    'Minshawi_Murattal_128kbps': 'ar.minshawi',
    'Husary_128kbps': 'ar.husary',
    'MaherAlMuaiqly128kbps': 'ar.mahermuaiqly',
    'Abdullah_Basfar_192kbps': 'ar.abdullahbasfar',
    'Shuraim_128kbps': 'ar.saoudshuraym',
  };

  // Candidate folder names on verses.quran.foundation (CDN 4).
  // The CDN uses PascalCase names (Alafasy, AbdulBaset) so BandarBaleela
  // is tried first, with underscore variants as fallbacks.
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

  /// CDN 2 — mirrors.quranicaudio.com (official QuranicAudio mirror of everyayah).
  /// This is the primary per-ayah CDN used by Quran for Android.
  String ayahUrlMirrors(int surahNumber, int ayahNumber, {String? reciter}) {
    final r = reciter ?? defaultReciter;
    return '$_mirrorsBase${_path(surahNumber, ayahNumber, r)}';
  }

  /// CDN 3 — everyayah.com (direct, same URL pattern as mirrors CDN).
  String ayahFallbackUrl(int surahNumber, int ayahNumber, {String? reciter}) {
    final r = reciter ?? defaultReciter;
    return '$_fallbackBase${_path(surahNumber, ayahNumber, r)}';
  }

  /// CDN 4 — audio.qurancdn.com (additional mirror).
  String ayahUrl(int surahNumber, int ayahNumber, {String? reciter}) {
    final r = reciter ?? defaultReciter;
    return '$_primaryBase${_path(surahNumber, ayahNumber, r)}';
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
    return folders.map((f) => '$_versesQfBase/$f/mp3/$s$a.mp3').toList();
  }
}

final audioRepositoryProvider =
    Provider<AudioRepository>((_) => const AudioRepository());
