import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/quran_word.dart';

// Loads pre-generated word-timing JSON assets produced by
// scripts/align_reciters.py for reciters not covered by the QDC API.
//
// Asset path: assets/timings/r<appReciterId>s<surahNumber>.json
// Flat naming avoids Flutter's one-level-deep directory glob limitation.
//
// JSON schema (one file per surah):
//   { "reciter_id": 20, "surah": 1,
//     "ayahs": { "1": [ {"position":1,"text":"بسم","start_ms":0,"end_ms":850}, ... ] } }

class LocalWordTimingRepository {
  // Session-level cache: "appReciterId:surahNumber" → result.
  // Null sentinel means the asset doesn't exist — avoids repeated failures.
  final _cache = <String, Map<int, List<QuranWord>>?>{};

  /// Returns ayah→words map for the surah, or null if no asset exists.
  Future<Map<int, List<QuranWord>>?> fetchSurahTimings(
    int appReciterId,
    int surahNumber,
  ) async {
    final cacheKey = '$appReciterId:$surahNumber';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    try {
      final raw = await rootBundle
          .loadString('assets/timings/r${appReciterId}s$surahNumber.json');
      final data = json.decode(raw) as Map<String, dynamic>;
      final ayahsRaw = data['ayahs'] as Map<String, dynamic>? ?? {};

      final result = <int, List<QuranWord>>{};
      for (final entry in ayahsRaw.entries) {
        final ayahNum = int.tryParse(entry.key);
        if (ayahNum == null) continue;

        final rawList = entry.value as List<dynamic>;
        final words = rawList.map((w) {
          final m = w as Map<String, dynamic>;
          return QuranWord(
            position: (m['position'] as num).toInt(),
            text: (m['text'] as String?) ?? '',
            startTime: (m['start_ms'] as num).toInt(),
            endTime: (m['end_ms'] as num).toInt(),
          );
        }).toList()
          ..sort((a, b) => a.position.compareTo(b.position));
        result[ayahNum] = words;
      }

      _cache[cacheKey] = result;
      return result;
    } catch (_) {
      // Asset missing or malformed — fall back to proportional timing.
      _cache[cacheKey] = null;
      return null;
    }
  }
}

final localWordTimingRepositoryProvider =
    Provider<LocalWordTimingRepository>((ref) {
  return LocalWordTimingRepository();
});

// Keyed by "$appReciterId:$surahNumber" — mirrors surahWordTimingsProvider
// but uses app IDs (not QDC IDs) to look up bundled asset files.
final localSurahWordTimingsProvider = FutureProvider.autoDispose
    .family<Map<int, List<QuranWord>>?, String>(
  (ref, key) async {
    final parts = key.split(':');
    final appReciterId = int.parse(parts[0]);
    final surahNumber = int.parse(parts[1]);
    final result = await ref
        .read(localWordTimingRepositoryProvider)
        .fetchSurahTimings(appReciterId, surahNumber);
    ref.keepAlive();
    return result;
  },
);
