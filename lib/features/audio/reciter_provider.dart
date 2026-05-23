import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single reciter from the QuranicAudio API (quranicaudio.com/api/qaris).
class QAReciter {
  const QAReciter({
    required this.id,
    required this.name,
    required this.arabicName,
    required this.relativePath, // folder slug, e.g. "Alafasy_128kbps" (no trailing slash)
  });

  final int id;
  final String name;
  final String arabicName;
  final String relativePath;

  factory QAReciter.fromJson(Map<String, dynamic> j) => QAReciter(
        id: j['id'] as int,
        name: _cleanName(j['name'] as String),
        arabicName: j['arabic_name'] as String? ?? '',
        // API returns trailing slash — strip it so it works as a URL path segment.
        relativePath: (j['relative_path'] as String).replaceAll('/', ''),
      );

  /// Strips Arabic script and city names so every label is clean English.
  static String _cleanName(String raw) {
    var s = raw
        // Arabic script blocks
        .replaceAll(RegExp(r'[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]+'), '')
        // City names with optional "Al-" / "Al " prefix
        .replaceAll(
          RegExp(r'\b(Al[- ]?)?(Makkah|Makka|Mecca|Madinah|Madina|Medina|Medinah)\b',
              caseSensitive: false),
          '',
        )
        // "Imam of" left orphaned after city removal
        .replaceAll(RegExp(r'\bImam\s+of\b\s*', caseSensitive: false), '')
        // Empty parentheses / brackets
        .replaceAll(RegExp(r'[(\[]\s*[)\]]'), '')
        // Trailing and leading separators
        .replaceAll(RegExp(r'[\s\-–—,]+$'), '')
        .replaceAll(RegExp(r'^[\s\-–—,]+'), '')
        // Collapse multiple spaces
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
    return s.isEmpty ? raw : s;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'arabic_name': arabicName,
        'relative_path': relativePath,
      };
}

// ─── Repository ───────────────────────────────────────────────────────────────

class _ReciterRepo {
  _ReciterRepo(this._dio);

  final Dio _dio;
  static const _cacheKey = 'qa_reciters_v4'; // v4: cleaned names (no Arabic, no city)
  static const _apiUrl   = 'https://quranicaudio.com/api/qaris';

  Future<List<QAReciter>> fetchReciters() async {
    // 1 — cache hit
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_cacheKey);
    if (raw != null) {
      try { return _decode(raw); } catch (_) {}
    }

    // 2 — network
    final resp = await _dio.get<List<dynamic>>(_apiUrl);
    final list = resp.data!
        .cast<Map<String, dynamic>>()
        .where((r) => (r['relative_path'] as String? ?? '').isNotEmpty)
        .map(QAReciter.fromJson)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    _unawaited(prefs.setString(_cacheKey, _encode(list)));
    return list;
  }

  static String _encode(List<QAReciter> list) =>
      jsonEncode(list.map((r) => r.toJson()).toList());

  static List<QAReciter> _decode(String s) =>
      (jsonDecode(s) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(QAReciter.fromJson)
          .toList();
}

void _unawaited(Future<void> f) {} // fire-and-forget cache writes

final _reciterRepoProvider = Provider<_ReciterRepo>(
  (ref) => _ReciterRepo(Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ))),
);

/// Full list of all reciters from QuranicAudio.
/// Falls back to empty list on error → UI falls back to hardcoded 8.
final reciterListProvider = FutureProvider<List<QAReciter>>((ref) async {
  try {
    return await ref.read(_reciterRepoProvider).fetchReciters();
  } catch (_) {
    return const [];
  }
});

/// Returns the display name for [slug], searching the QA list first,
/// then a hardcoded fallback map.
String reciterDisplayName(List<QAReciter> reciters, String slug) {
  for (final r in reciters) {
    if (r.relativePath == slug) return r.name;
  }
  const fallback = {
    'Alafasy_128kbps':                'Mishary Alafasy',
    'Abdul_Basit_Murattal_192kbps':   'Abdul Basit (Murattal)',
    'Minshawi_Murattal_128kbps':      'Mohamed Siddiq El-Minshawi',
    'Husary_128kbps':                 'Mahmoud Al-Husary',
    'MaherAlMuaiqly128kbps':          'Maher Al Muaiqly',
    'Abdullah_Basfar_192kbps':        'Abdullah Basfar',
    'Shuraim_128kbps':                "Sa'ud ash-Shuraym",
    'Bandar_Baleela':                 'Bandar Baleela',
  };
  return fallback[slug] ?? slug;
}
