import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/quran_word.dart';
// Conditional import: native platforms use dart:io; web uses a no-op stub.
import 'timing_disk_cache_stub.dart'
    if (dart.library.io) 'timing_disk_cache.dart';

// Quran.com QDC API — returns per-verse word timing segments for a reciter.
// Endpoint: GET /api/qdc/audio/reciters/{qdcReciterId}/audio_files
//           ?chapter_number={n}&segments=true
//
// Response per audio_file:  { "verse_key": "1:1", "segments": [[wordPos,startMs,endMs], ...] }
// wordPos is 1-based; startMs/endMs are ms from the start of the verse clip.
const _kQdcBase = 'https://api.qurancdn.com/api/qdc';

class WordTimingRepository {
  WordTimingRepository(this._dio);

  final Dio _dio;

  // Session-level cache (fast in-memory lookup).
  final _memCache = <String, Map<int, List<QuranWord>>?>{};

  // Parses the shared JSON schema used by both bundled assets and disk cache.
  // Schema: { "ayahs": { "1": [ {"position":1, "text":"", "start_ms":0, "end_ms":850}, ...] } }
  static Map<int, List<QuranWord>> _decode(Map<String, dynamic> json) {
    final ayahsRaw = json['ayahs'] as Map<String, dynamic>? ?? {};
    final result = <int, List<QuranWord>>{};
    for (final entry in ayahsRaw.entries) {
      final ayahNum = int.tryParse(entry.key);
      if (ayahNum == null) continue;
      final rawList = entry.value as List<dynamic>;
      result[ayahNum] = rawList.map((w) {
        final m = w as Map<String, dynamic>;
        return QuranWord(
          position: (m['position'] as num).toInt(),
          text: (m['text'] as String?) ?? '',
          startTime: (m['start_ms'] as num).toInt(),
          endTime: (m['end_ms'] as num).toInt(),
        );
      }).toList()
        ..sort((a, b) => a.position.compareTo(b.position));
    }
    return result;
  }

  // Encodes to the same schema for disk-cache writes.
  static Map<String, dynamic> _encode(Map<int, List<QuranWord>> data) => {
        'ayahs': {
          for (final e in data.entries)
            '${e.key}': [
              for (final w in e.value)
                {
                  'position': w.position,
                  'text': w.text,
                  'start_ms': w.startTime,
                  'end_ms': w.endTime,
                }
            ]
        }
      };

  // Load from bundled assets (pre-fetched by scripts/fetch_qdc_timings.py).
  // Asset path: assets/timings/qdc{qdcReciterId}s{surahNumber}.json
  Future<Map<int, List<QuranWord>>?> _loadBundled(
      int qdcReciterId, int surahNumber) async {
    try {
      final raw = await rootBundle
          .loadString('assets/timings/qdc${qdcReciterId}s$surahNumber.json');
      return _decode(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Returns a map of ayahNumber → word-timing list for every verse in the
  /// surah. Look-up order:
  ///   1. Session memory cache (immediate)
  ///   2. Bundled asset (pre-fetched by scripts/fetch_qdc_timings.py)
  ///   3. Persistent disk cache (written after first successful QDC fetch)
  ///   4. QDC API (network)
  /// Returns null if all sources fail; caller falls back to proportional timing.
  Future<Map<int, List<QuranWord>>?> fetchSurahTimings(
    int qdcReciterId,
    int surahNumber,
  ) async {
    final cacheKey = '$qdcReciterId:$surahNumber';

    // 1. Memory cache (only populated on success — failures are not cached so
    //    the next call can retry, e.g. after a network outage).
    final mem = _memCache[cacheKey];
    if (mem != null) return mem;

    // 2. Bundled asset.
    final bundled = await _loadBundled(qdcReciterId, surahNumber);
    if (bundled != null) {
      _memCache[cacheKey] = bundled;
      return bundled;
    }

    // 3. Persistent disk cache (no-op stub on web).
    final disk = await timingDiskRead(qdcReciterId, surahNumber);
    if (disk != null) {
      final decoded = _decode(disk);
      _memCache[cacheKey] = decoded;
      return decoded;
    }

    // 4. QDC API (network).
    try {
      final response = await _dio.get(
        '$_kQdcBase/audio/reciters/$qdcReciterId/audio_files',
        queryParameters: {
          'chapter_number': surahNumber,
          'segments': true,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      final audioFiles =
          response.data['audio_files'] as List<dynamic>? ?? [];
      final result = <int, List<QuranWord>>{};

      for (final file in audioFiles) {
        final verseKey = file['verse_key'] as String? ?? '';
        final parts = verseKey.split(':');
        if (parts.length != 2) continue;
        final ayahNumber = int.tryParse(parts[1]);
        if (ayahNumber == null) continue;

        final segments = file['segments'] as List<dynamic>?;
        if (segments == null || segments.isEmpty) continue;

        final words = <QuranWord>[];
        for (final seg in segments) {
          final s = seg as List<dynamic>;
          if (s.length < 3) continue;
          words.add(QuranWord(
            position: (s[0] as num).toInt(),
            text: '',
            startTime: (s[1] as num).toInt(),
            endTime: (s[2] as num).toInt(),
          ));
        }
        words.sort((a, b) => a.position.compareTo(b.position));
        result[ayahNumber] = words;
      }

      if (result.isNotEmpty) {
        _memCache[cacheKey] = result;
        // Persist so next session skips the network call (no-op stub on web).
        unawaited(timingDiskWrite(qdcReciterId, surahNumber, _encode(result)));
        return result;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

final wordTimingRepositoryProvider = Provider<WordTimingRepository>((ref) {
  return WordTimingRepository(Dio());
});

// Keyed by "$qdcReciterId:$surahNumber" — a plain String avoids the Dart
// record-type syntax that build_runner's older analyzer can't parse.
// keepAlive() is called once data arrives so navigating away and back doesn't
// re-fetch within the same session.
final surahWordTimingsProvider = FutureProvider.autoDispose
    .family<Map<int, List<QuranWord>>?, String>(
  (ref, key) async {
    final parts = key.split(':');
    final qdcReciterId = int.parse(parts[0]);
    final surahNumber = int.parse(parts[1]);
    final result = await ref
        .read(wordTimingRepositoryProvider)
        .fetchSurahTimings(qdcReciterId, surahNumber);
    ref.keepAlive();
    return result;
  },
);
