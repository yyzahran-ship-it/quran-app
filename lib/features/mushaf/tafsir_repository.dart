import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TafsirInfo {
  const TafsirInfo(
      {required this.id, required this.name, required this.language});

  final int id;
  final String name;
  final String language;
}

const kTafsirs = [
  TafsirInfo(id: 16,  name: 'الميسّر',          language: 'عربي'),
  TafsirInfo(id: 171, name: 'المختصر',          language: 'عربي'),
  TafsirInfo(id: 74,  name: 'تفسير الجلالين',   language: 'عربي'),
];

// ─── Persisted tafsir selection ───────────────────────────────────────────────

class TafsirIdNotifier extends Notifier<int> {
  static const _key = 'tafsir_id';
  static const _default = 16;

  @override
  int build() {
    _load();
    return _default;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_key) ?? _default;
  }

  Future<void> set(int id) async {
    state = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, id);
  }
}

final tafsirIdProvider =
    NotifierProvider<TafsirIdNotifier, int>(TafsirIdNotifier.new);

// ─── Tafsir fetcher with persistent cache ─────────────────────────────────────

class TafsirRepository {
  TafsirRepository(this._dio);

  final Dio _dio;

  // In-memory layer prevents repeat fetches within the same session.
  final Map<String, String> _memCache = {};

  String _cacheKey(int tafsirId, String verseKey) =>
      'tafsir_${tafsirId}_$verseKey';

  Future<String> fetchTafsir(
      {required int tafsirId, required String verseKey}) async {
    final key = _cacheKey(tafsirId, verseKey);

    // 1 — memory hit
    final mem = _memCache[key];
    if (mem != null) return mem;

    // 2 — SharedPreferences hit (survives app restarts)
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(key);
    if (cached != null) {
      _memCache[key] = cached;
      return cached;
    }

    // 3 — network fetch; on failure re-throw (no stale to serve)
    final url =
        'https://api.quran.com/api/v4/tafsirs/$tafsirId/by_ayah/$verseKey';
    final response = await _dio.get<Map<String, dynamic>>(url);
    final tafsirMap = response.data?['tafsir'] as Map<String, dynamic>?;
    final rawOrNull = tafsirMap?['text'] as String?;
    if (rawOrNull == null || rawOrNull.isEmpty) {
      throw Exception('لا يوجد نص متاح لهذه الآية');
    }
    final text = _stripHtml(rawOrNull);

    _memCache[key] = text;
    // Fire-and-forget: don't block the caller on prefs write.
    prefs.setString(key, text);

    return text;
  }

  static String _stripHtml(String html) => html
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

final _dioProvider = Provider<Dio>((ref) => Dio());

final tafsirRepositoryProvider = Provider<TafsirRepository>(
    (ref) => TafsirRepository(ref.read(_dioProvider)));

// ─── Auto-dispose fetch provider ──────────────────────────────────────────────

typedef TafsirKey = ({int tafsirId, String verseKey});

final tafsirTextProvider =
    FutureProvider.autoDispose.family<String, TafsirKey>((ref, key) {
  return ref.read(tafsirRepositoryProvider).fetchTafsir(
        tafsirId: key.tafsirId,
        verseKey: key.verseKey,
      );
});
