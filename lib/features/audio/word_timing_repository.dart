import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/quran_word.dart';

// Quran.com QDC API — returns per-verse word timing segments for a reciter.
// Endpoint: GET /api/qdc/audio/reciters/{qdcReciterId}/audio_files
//           ?chapter_number={n}&segments=true
//
// Response shape (per audio_file entry):
//   { "verse_key": "1:1", "segments": [[wordPos, startMs, endMs], ...] }
//
// wordPos is 1-based. startMs/endMs are milliseconds from the start of the
// individual verse audio clip — which aligns with just_audio's positionStream.
const _kQdcBase = 'https://api.qurancdn.com/api/qdc';

class WordTimingRepository {
  WordTimingRepository(this._dio);

  final Dio _dio;

  // Two-level cache: qdcReciterId → surahNumber → { ayahNumber: [words] }.
  // Populated on first fetch; never expires within a session.
  final _cache = <int, Map<int, Map<int, List<QuranWord>>>>{};

  /// Returns a map of ayahNumber → word-timing list for every verse in the
  /// surah. Returns null if the network request fails (caller falls back to
  /// proportional timing).
  Future<Map<int, List<QuranWord>>?> fetchSurahTimings(
    int qdcReciterId,
    int surahNumber,
  ) async {
    final cached = _cache[qdcReciterId]?[surahNumber];
    if (cached != null) return cached;

    try {
      final response = await _dio.get(
        '$_kQdcBase/audio/reciters/$qdcReciterId/audio_files',
        queryParameters: {
          'chapter_number': surahNumber,
          'segments': true,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      final audioFiles = response.data['audio_files'] as List<dynamic>? ?? [];
      final result = <int, List<QuranWord>>{};

      for (final file in audioFiles) {
        final verseKey = file['verse_key'] as String? ?? '';
        final parts = verseKey.split(':');
        if (parts.length != 2) continue;
        final ayahNumber = int.tryParse(parts[1]);
        if (ayahNumber == null) continue;

        final segments = file['segments'] as List<dynamic>?;
        if (segments == null || segments.isEmpty) continue;

        // Each segment: [wordPosition (1-based), startMs, endMs]
        final words = <QuranWord>[];
        for (final seg in segments) {
          final s = seg as List<dynamic>;
          if (s.length < 3) continue;
          words.add(QuranWord(
            position: (s[0] as num).toInt(),
            text: '', // text is filled in from textUthmani split at call site
            startTime: (s[1] as num).toInt(),
            endTime: (s[2] as num).toInt(),
          ));
        }
        words.sort((a, b) => a.position.compareTo(b.position));
        result[ayahNumber] = words;
      }

      _cache.putIfAbsent(qdcReciterId, () => {})[surahNumber] = result;
      return result;
    } catch (_) {
      // Network/parse failure — caller uses proportional fallback.
      return null;
    }
  }
}

final wordTimingRepositoryProvider = Provider<WordTimingRepository>((ref) {
  return WordTimingRepository(Dio());
});

// Keyed by "$qdcReciterId:$surahNumber" — a plain String avoids the Dart
// record-type syntax that build_runner's older analyzer can't parse.
// Result is null on network failure, empty map if there is no segment data,
// or a populated ayah→words map. keepAlive() is called once data arrives so
// navigating away and back doesn't re-fetch within the same session.
final surahWordTimingsProvider = FutureProvider.autoDispose
    .family<Map<int, List<QuranWord>>?, String>(
  (ref, key) async {
    final parts = key.split(':');
    final qdcReciterId = int.parse(parts[0]);
    final surahNumber  = int.parse(parts[1]);
    final result = await ref
        .read(wordTimingRepositoryProvider)
        .fetchSurahTimings(qdcReciterId, surahNumber);
    ref.keepAlive();
    return result;
  },
);
