// Reciter data. Two CDN strategies:
//
// 1. Islamic Network CDN (islamicNetworkEdition != null):
//    - Surah:  https://cdn.islamic.network/quran/audio-surah/128/{edition}/{surah}.mp3
//    - Verse:  https://cdn.islamic.network/quran/audio/128/{edition}/{globalAyahId}.mp3
//    Supports verse-by-verse playback and live ayah highlighting.
//
// 2. QuranicAudio CDN (fallback, surah-level only):
//    - Surah:  https://download.quranicaudio.com/quran/{relativePath}{surah:03d}.mp3
class QuranicReciter {
  const QuranicReciter({
    required this.id,
    required this.name,
    this.arabicName,
    required this.relativePath,
    this.style,
    this.islamicNetworkEdition,
    this.qdcReciterId,
  });

  final int id;
  final String name;
  final String? arabicName;
  final String relativePath;
  final String? style;
  // al-Quran Cloud edition identifier (e.g. "ar.alafasy").
  // When set, verse-by-verse playback and ayah highlighting are enabled.
  final String? islamicNetworkEdition;
  // Quran.com QDC API reciter ID for fetching per-word timing segments.
  // Null means word-level timestamps are unavailable; falls back to proportional timing.
  // Source: https://api.qurancdn.com/api/qdc/audio/reciters
  final int? qdcReciterId;

  bool get supportsVerseTracking => islamicNetworkEdition != null;

  // Full surah audio URL. Prefers Islamic Network CDN when edition is known.
  String surahAudioUrl(int surahNumber) {
    if (islamicNetworkEdition != null) {
      return 'https://cdn.islamic.network/quran/audio-surah/128/$islamicNetworkEdition/$surahNumber.mp3';
    }
    final padded = surahNumber.toString().padLeft(3, '0');
    return 'https://download.quranicaudio.com/quran/$relativePath$padded.mp3';
  }

  // Single verse audio URL. Only valid when [supportsVerseTracking] is true.
  // [globalAyahId] is the cumulative ayah index 1–6236.
  String verseAudioUrl(int globalAyahId) {
    assert(islamicNetworkEdition != null);
    return 'https://cdn.islamic.network/quran/audio/128/$islamicNetworkEdition/$globalAyahId.mp3';
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
