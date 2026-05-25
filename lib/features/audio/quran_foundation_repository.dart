import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Quran Foundation audio source ───────────────────────────────────────────
//
// api.quran.com/api/v4 is the only source that:
//   • Lists ALL available reciters dynamically (40+).
//   • Returns exact per-ayah audio URLs — no folder-name guessing.
//   • Is free, requires no API key, and is actively maintained.
//
// How it works:
//   1. Fetch /resources/recitations → list of {id, name, style}.
//   2. When playing a surah, call /recitations/{id}/by_chapter/{surah}
//      → returns {"audio_files": [{"verse_key":"1:1","url":"Alafasy/mp3/001001.mp3"}, …]}
//   3. Prepend _kCdnBase → full CDN URL, no further API calls needed for that surah.

const _kApiBase  = 'https://api.quran.com/api/v4';
const _kCdnBase  = 'https://verses.quran.com';

// ─── Model ────────────────────────────────────────────────────────────────────

class QFRecitation {
  const QFRecitation({
    required this.id,
    required this.name,
    required this.style,
  });

  final int    id;
  final String name;   // English name, e.g. "Mishary Rashid Alafasy"
  final String style;  // "Murattal", "Mujawwad", "", …

  String get displayName =>
      style.isNotEmpty ? '$name ($style)' : name;

  // Slug used as AudioState.reciter when this recitation is selected.
  // Prefix "qf_" lets the audio engine distinguish QF from everyayah reciters.
  String get slug => 'qf_$id';
}

// ─── Repository ───────────────────────────────────────────────────────────────

class QuranFoundationRepository {
  QuranFoundationRepository(this._dio);

  final Dio _dio;

  // Per-session cache: "recitationId:surahNumber" → Map<ayahNumber, fullUrl>
  final Map<String, Map<int, String>> _cache = {};

  // Fetch the list of all available per-ayah recitations.
  Future<List<QFRecitation>> fetchRecitations() async {
    final resp = await _dio.get('$_kApiBase/resources/recitations');
    final list = (resp.data['recitations'] as List).cast<Map<String, dynamic>>();
    return list.map((r) {
      final tx = r['translated_name'] as Map<String, dynamic>?;
      return QFRecitation(
        id:    r['id']   as int,
        name:  tx?['name'] as String? ?? r['reciter_name'] as String? ?? '',
        style: r['style'] as String? ?? '',
      );
    }).toList();
  }

  // Fetch per-ayah audio URLs for an entire surah.
  // Returns Map<ayahNumber, absoluteUrl>.
  // Result is cached in memory so repeat calls are instant.
  Future<Map<int, String>> fetchSurahAudio(
    int recitationId,
    int surahNumber,
  ) async {
    final key = '$recitationId:$surahNumber';
    if (_cache.containsKey(key)) return _cache[key]!;

    final resp = await _dio.get(
      '$_kApiBase/recitations/$recitationId/by_chapter/$surahNumber',
      // Largest surah (Al-Baqara) has 286 ayahs — 300 covers all.
      queryParameters: {'per_page': 300},
    );
    final files = (resp.data['audio_files'] as List).cast<Map<String, dynamic>>();

    final result = <int, String>{};
    for (final f in files) {
      final verseKey = f['verse_key'] as String;      // "2:5"
      final relUrl   = f['url']       as String;      // "Alafasy/mp3/002005.mp3"
      final ayah     = int.parse(verseKey.split(':')[1]);
      result[ayah]   = '$_kCdnBase/$relUrl';
    }

    _cache[key] = result;
    return result;
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final qfRepositoryProvider = Provider<QuranFoundationRepository>((ref) {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));
  return QuranFoundationRepository(dio);
});

// List of all QF recitations — fetched once on first watch.
final qfRecitationsProvider = FutureProvider<List<QFRecitation>>((ref) async {
  return ref.read(qfRepositoryProvider).fetchRecitations();
});
