import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// For each ayah on a page: which line it starts and ends on (1-based).
// Lines come from api.quran.com word data.
typedef PageLineMap = Map<int, ({int start, int end})>;

class _PageLineRepo {
  _PageLineRepo(this._dio);

  final Dio _dio;
  final Map<int, PageLineMap> _mem = {};

  Future<PageLineMap> fetchPage(int page) async {
    // 1 — memory hit
    final cached = _mem[page];
    if (cached != null) return cached;

    // 2 — SharedPreferences hit
    final prefs = await SharedPreferences.getInstance();
    final key = 'page_lines_v1_$page';
    final raw = prefs.getString(key);
    if (raw != null) {
      try {
        final m = _decode(raw);
        _mem[page] = m;
        return m;
      } catch (_) {}
    }

    // 3 — Network fetch
    final resp = await _dio.get<Map<String, dynamic>>(
      'https://api.quran.com/api/v4/verses/by_page/$page',
      queryParameters: {
        'words': 'true',
        'per_page': '50',
        'fields': 'id',
      },
    );

    final verses = resp.data!['verses'] as List<dynamic>;
    final result = <int, ({int start, int end})>{};

    for (final verse in verses) {
      final ayahId = verse['id'] as int;
      final words = verse['words'] as List<dynamic>;
      final lines = words
          .map((w) => w['line_number'] as int?)
          .whereType<int>()
          .toList();
      if (lines.isEmpty) continue;
      result[ayahId] = (start: lines.first, end: lines.last);
    }

    _mem[page] = result;
    unawaited(prefs.setString(key, _encode(result)));
    return result;
  }

  static String _encode(PageLineMap m) =>
      jsonEncode(m.map((k, v) => MapEntry('$k', [v.start, v.end])));

  static PageLineMap _decode(String s) {
    final map = jsonDecode(s) as Map<String, dynamic>;
    return map.map((k, v) {
      final list = v as List<dynamic>;
      return MapEntry(
        int.parse(k),
        (start: list[0] as int, end: list[1] as int),
      );
    });
  }
}

// Silently swallows a future — used for fire-and-forget cache writes.
void unawaited(Future<void> f) {}

final _pageLineRepoProvider = Provider<_PageLineRepo>((ref) => _PageLineRepo(
      Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
      )),
    ));

/// Fetches the start/end line numbers for every ayah on [page].
/// Returns an empty map (falls back to proportional layout) on network failure.
final pageLineProvider =
    FutureProvider.autoDispose.family<PageLineMap, int>((ref, page) async {
  try {
    return await ref.read(_pageLineRepoProvider).fetchPage(page);
  } catch (_) {
    return const {};
  }
});
