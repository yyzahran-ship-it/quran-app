import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tafsir_repository.dart';

// Info for a translation or tafsir returned by the Quran.com API.
class ApiTranslationInfo {
  const ApiTranslationInfo({
    required this.id,
    required this.name,
    required this.authorName,
    required this.languageName,
  });

  final int id;
  final String name;
  final String authorName;
  final String languageName;
}

// ─── Remote providers ─────────────────────────────────────────────────────────

final _libDioProvider = Provider<Dio>((ref) => Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
    )));

final availableTranslationsProvider =
    FutureProvider<List<ApiTranslationInfo>>((ref) async {
  final dio = ref.read(_libDioProvider);
  final resp = await dio.get<Map<String, dynamic>>(
    'https://api.quran.com/api/v4/resources/translations',
  );
  final list = resp.data!['translations'] as List<dynamic>;
  return list
      .map((e) => ApiTranslationInfo(
            id: e['id'] as int,
            name: (e['name'] as String?) ?? '',
            authorName: (e['author_name'] as String?) ?? '',
            languageName: (e['language_name'] as String?) ?? '',
          ))
      .toList();
});

final availableTafsirsProvider =
    FutureProvider<List<ApiTranslationInfo>>((ref) async {
  final dio = ref.read(_libDioProvider);
  final resp = await dio.get<Map<String, dynamic>>(
    'https://api.quran.com/api/v4/resources/tafsirs',
  );
  final list = resp.data!['tafsirs'] as List<dynamic>;
  return list
      .map((e) => ApiTranslationInfo(
            id: e['id'] as int,
            name: (e['name'] as String?) ?? '',
            authorName: (e['author_name'] as String?) ?? '',
            languageName: (e['language_name'] as String?) ?? '',
          ))
      .toList();
});

// ─── Multi-select tafsir IDs (persisted) ──────────────────────────────────────

class SelectedTafsirsNotifier extends Notifier<Set<int>> {
  static const _key = 'selected_tafsir_ids';

  @override
  Set<int> build() {
    _load();
    return {kTafsirs.first.id};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);
    if (raw != null && raw.isNotEmpty) {
      final ids = raw.map(int.tryParse).whereType<int>().toSet();
      if (ids.isNotEmpty) state = ids;
    }
  }

  Future<void> toggle(int id) async {
    final next = Set<int>.from(state);
    if (next.contains(id)) {
      if (next.length <= 1) return; // always keep at least one
      next.remove(id);
    } else {
      next.add(id);
    }
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.map((e) => e.toString()).toList());
  }
}

final selectedTafsirsProvider =
    NotifierProvider<SelectedTafsirsNotifier, Set<int>>(
        SelectedTafsirsNotifier.new);
