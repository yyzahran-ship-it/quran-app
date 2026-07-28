// Reciter data. Four CDN strategies:
//
// Verse-level (priority order):
// 1. Islamic Network CDN (islamicNetworkEdition != null):
//    - Verse:  https://cdn.islamic.network/quran/audio/128/{edition}/{globalAyahId}.mp3
//    - Surah:  https://cdn.islamic.network/quran/audio-surah/128/{edition}/{surah}.mp3
//
// 2. everyAyah.com (everyayahSubfolder != null):
//    - Verse:  https://everyayah.com/data/{subfolder}/{surah:3d}{ayah:3d}.mp3
//    Also supports verse-by-verse playback; surah fallback uses CDN 3 or 4.
//
// Surah-level fallback (priority order when no verse CDN matched):
// 3. Custom surahBaseUrl (surahBaseUrl != null):
//    - Surah:  {surahBaseUrl}/{surah:03d}.mp3
//    Used for reciters on mp3quran.net or other CDNs (e.g. server6.mp3quran.net/kanakeri).
//
// 4. QuranicAudio CDN (default fallback):
//    - Surah:  https://download.quranicaudio.com/quran/{relativePath}{surah:03d}.mp3
class QuranicReciter {
  const QuranicReciter({
    required this.id,
    required this.name,
    this.arabicName,
    required this.relativePath,
    this.style,
    this.islamicNetworkEdition,
    this.everyayahSubfolder,
    this.qdcReciterId,
    this.surahBaseUrl,
  });

  final int id;
  final String name;
  final String? arabicName;
  final String relativePath;
  final String? style;
  // al-Quran Cloud edition identifier (e.g. "ar.alafasy").
  // When set, verse-by-verse playback and ayah highlighting are enabled.
  final String? islamicNetworkEdition;
  // everyAyah.com subfolder for verse-by-verse audio.
  // URL: https://everyayah.com/data/{everyayahSubfolder}/{surah:3d}{ayah:3d}.mp3
  // Enables verse tracking for reciters not on Islamic Network.
  final String? everyayahSubfolder;
  // Quran.com QDC API reciter ID for fetching per-word timing segments.
  // Null means word-level timestamps are unavailable; falls back to proportional timing.
  // Source: https://api.qurancdn.com/api/qdc/audio/reciters
  final int? qdcReciterId;
  // Custom surah-level audio base URL (without trailing slash).
  // URL: {surahBaseUrl}/{surah:03d}.mp3
  // Used for reciters hosted on CDNs other than Islamic Network or QuranicAudio
  // (e.g. server6.mp3quran.net/kanakeri for AbdulHadi Kanakeri).
  final String? surahBaseUrl;

  bool get supportsVerseTracking =>
      islamicNetworkEdition != null || everyayahSubfolder != null;

  // Full surah audio URL. Priority: Islamic Network > custom surahBaseUrl > QuranicAudio.
  String surahAudioUrl(int surahNumber) {
    if (islamicNetworkEdition != null) {
      return 'https://cdn.islamic.network/quran/audio-surah/128/$islamicNetworkEdition/$surahNumber.mp3';
    }
    final padded = surahNumber.toString().padLeft(3, '0');
    if (surahBaseUrl != null) {
      return '$surahBaseUrl/$padded.mp3';
    }
    return 'https://download.quranicaudio.com/quran/$relativePath$padded.mp3';
  }

  // Single verse audio URL. Only valid when [supportsVerseTracking] is true.
  // [globalAyahId] is the cumulative ayah index 1–6236 (for Islamic Network).
  // [surahNumber] and [ayahNumber] are needed for everyAyah format.
  String verseAudioUrl(int globalAyahId, {int surahNumber = 0, int ayahNumber = 0}) {
    if (islamicNetworkEdition != null) {
      assert(islamicNetworkEdition != null);
      return 'https://cdn.islamic.network/quran/audio/128/$islamicNetworkEdition/$globalAyahId.mp3';
    }
    if (everyayahSubfolder != null) {
      final s = surahNumber.toString().padLeft(3, '0');
      final a = ayahNumber.toString().padLeft(3, '0');
      return 'https://everyayah.com/data/$everyayahSubfolder/$s$a.mp3';
    }
    throw StateError('verseAudioUrl called on reciter without verse support');
  }

  factory QuranicReciter.fromJson(Map<String, dynamic> json) => QuranicReciter(
        id: (json['id'] as num).toInt(),
        name: (json['name'] as String?)?.trim() ?? 'Unknown',
        arabicName: json['arabic_name'] as String?,
        relativePath: (json['relative_path'] as String?) ?? '',
        style: json['style'] as String?,
      );

  @override
  bool operator ==(Object other) => other is QuranicReciter && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'QuranicReciter($id, $name)';
}
