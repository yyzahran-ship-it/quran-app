import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Available tafsirs from api.quran.com/api/v4
class TafsirInfo {
  const TafsirInfo(
      {required this.id, required this.name, required this.language});

  final int id;
  final String name;
  final String language;
}

const kTafsirs = [
  TafsirInfo(id: 169, name: 'Ibn Kathir', language: 'English'),
  TafsirInfo(id: 164, name: 'Al-Muyassar', language: 'Arabic'),
  TafsirInfo(id: 16, name: 'Al-Jalalayn', language: 'Arabic'),
];

// ─── Persisted tafsir selection ───────────────────────────────────────────────

class TafsirIdNotifier extends Notifier<int> {
  static const _key = 'tafsir_id';
  static const _default = 169;

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

// ─── Tafsir fetcher ───────────────────────────────────────────────────────────

class TafsirRepository {
  TafsirRepository(this._dio);

  final Dio _dio;

  Future<String> fetchTafsir(
      {required int tafsirId, required String verseKey}) async {
    final url =
        'https://api.quran.com/api/v4/tafsirs/$tafsirId/by_ayah/$verseKey';
    final response = await _dio.get<Map<String, dynamic>>(url);
    final text =
        (response.data!['tafsir'] as Map<String, dynamic>)['text'] as String;
    return _stripHtml(text);
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

// Named Dart record used as family key — has structural == and hashCode.
typedef TafsirKey = ({int tafsirId, String verseKey});

final tafsirTextProvider =
    FutureProvider.autoDispose.family<String, TafsirKey>((ref, key) {
  return ref.read(tafsirRepositoryProvider).fetchTafsir(
        tafsirId: key.tafsirId,
        verseKey: key.verseKey,
      );
});
