import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Popular translations available on api.quran.com, keyed by their numeric ID.
// ID 0 means "none" (secondary translation disabled).
const kSecondaryTranslations = <int, String>{
  0: 'None',
  234: 'Urdu — Jalandhry',
  131: 'English — Sahih International',
  85:  'French — Hamidullah',
  148: 'Indonesian — Kemenag',
  149: 'Turkish — Diyanet Vakfı',
  203: 'English — King Fahad Complex',
};

// ─── Persisted selection ──────────────────────────────────────────────────────

class SecondTranslationNotifier extends Notifier<int> {
  static const _key = 'second_translation_id';

  @override
  int build() {
    _load();
    return 0; // default: disabled
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_key) ?? 0;
  }

  Future<void> set(int id) async {
    state = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, id);
  }
}

final secondTranslationProvider =
    NotifierProvider<SecondTranslationNotifier, int>(
        SecondTranslationNotifier.new);

// ─── Per-page fetch with in-memory + SharedPreferences cache ─────────────────

class _SecondTranslationRepo {
  _SecondTranslationRepo(this._dio);

  final Dio _dio;
  final Map<String, Map<int, String>> _mem = {};

  String _key(int translationId, int page) => 'tx2_${translationId}_p$page';

  Future<Map<int, String>> fetchPage(
      {required int translationId, required int page}) async {
    final cacheKey = _key(translationId, page);

    // 1 — memory hit
    final mem = _mem[cacheKey];
    if (mem != null) return mem;

    // 2 — SharedPreferences hit
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      final decoded = _decode(cached);
      _mem[cacheKey] = decoded;
      return decoded;
    }

    // 3 — network fetch
    final url =
        'https://api.quran.com/api/v4/verses/by_page/$page'
        '?words=false&translations=$translationId&per_page=50&fields=id';
    final resp = await _dio.get<Map<String, dynamic>>(url);
    final verses = resp.data!['verses'] as List<dynamic>;

    final result = <int, String>{};
    for (final v in verses) {
      final ayahId = v['id'] as int;
      final txList = v['translations'] as List<dynamic>;
      if (txList.isNotEmpty) {
        final raw = txList.first['text'] as String? ?? '';
        result[ayahId] = _stripHtml(raw);
      }
    }

    _mem[cacheKey] = result;
    prefs.setString(cacheKey, _encode(result));
    return result;
  }

  static String _encode(Map<int, String> m) =>
      m.entries.map((e) => '${e.key}\x1f${e.value}').join('\x1e');

  static Map<int, String> _decode(String s) {
    if (s.isEmpty) return {};
    return Map.fromEntries(
      s.split('\x1e').map((e) {
        final idx = e.indexOf('\x1f');
        if (idx < 0) return null;
        final key = int.tryParse(e.substring(0, idx));
        if (key == null) return null;
        return MapEntry(key, e.substring(idx + 1));
      }).whereType<MapEntry<int, String>>(),
    );
  }

  static String _stripHtml(String html) => html
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();
}

final _secondTranslationRepoProvider =
    Provider<_SecondTranslationRepo>((ref) =>
        _SecondTranslationRepo(Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        ))));

// ─── Auto-dispose fetch provider ──────────────────────────────────────────────

typedef _SecondTxKey = ({int translationId, int page});

final secondTranslationPageProvider = FutureProvider.autoDispose
    .family<Map<int, String>, _SecondTxKey>((ref, key) {
  if (key.translationId == 0) return Future.value({});
  return ref
      .read(_secondTranslationRepoProvider)
      .fetchPage(translationId: key.translationId, page: key.page);
});
