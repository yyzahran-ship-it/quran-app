import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TafsirDownloadInfo {
  const TafsirDownloadInfo({
    this.progress = 0.0,
    this.completed = false,
    this.error,
  });

  final double progress; // 0.0 – 1.0 (fraction of 114 chapters done)
  final bool completed;
  final String? error;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class TafsirDownloadNotifier
    extends Notifier<Map<int, TafsirDownloadInfo>> {
  static const _completedPrefKey = 'fully_downloaded_tafsir_ids';

  @override
  Map<int, TafsirDownloadInfo> build() {
    _loadCompleted();
    return {};
  }

  Future<void> _loadCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_completedPrefKey) ?? [];
    if (raw.isEmpty) return;
    final update = <int, TafsirDownloadInfo>{};
    for (final s in raw) {
      final id = int.tryParse(s);
      if (id != null) {
        update[id] = const TafsirDownloadInfo(completed: true, progress: 1.0);
      }
    }
    state = {...state, ...update};
  }

  bool isDownloading(int id) {
    final info = state[id];
    return info != null && !info.completed && info.error == null;
  }

  Future<void> startDownload(int tafsirId) async {
    if (isDownloading(tafsirId)) return;
    if (state[tafsirId]?.completed == true) return;

    state = {...state, tafsirId: const TafsirDownloadInfo()};

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
    final prefs = await SharedPreferences.getInstance();
    int totalCached = 0;

    try {
      for (int chapter = 1; chapter <= 114; chapter++) {
        int page = 1;
        int totalPages = 1;

        do {
          // Fetch all verses for the chapter including tafsir text.
          final url =
              'https://api.quran.com/api/v4/verses/by_chapter/$chapter'
              '?tafsirs=$tafsirId&per_page=50&page=$page';
          final resp = await dio.get<Map<String, dynamic>>(url);
          final data = resp.data!;

          final verses = data['verses'] as List<dynamic>? ?? [];
          for (final v in verses) {
            // verse_key is like "1:1"; fall back to chapter:verse_number.
            final verseKey = (v['verse_key'] as String?) ??
                _buildKey(
                  v['chapter_id'] as int? ?? chapter,
                  v['verse_number'] as int? ?? 0,
                );
            if (verseKey.endsWith(':0')) continue;

            final tafsirList = v['tafsirs'] as List<dynamic>? ?? [];
            if (tafsirList.isNotEmpty) {
              final raw = tafsirList.first['text'] as String? ?? '';
              final text = _stripHtml(raw);
              if (text.isNotEmpty) {
                await prefs.setString('tafsir_${tafsirId}_$verseKey', text);
                totalCached++;
              }
            }
          }

          final meta = data['meta'] as Map<String, dynamic>?;
          totalPages = meta?['total_pages'] as int? ?? 1;
          page++;
        } while (page <= totalPages);

        // Report per-chapter progress.
        state = {
          ...state,
          tafsirId: TafsirDownloadInfo(progress: chapter / 114.0),
        };
      }

      if (totalCached == 0) {
        throw Exception('No tafsir content received from server');
      }

      // Persist completion.
      state = {...state, tafsirId: const TafsirDownloadInfo(completed: true, progress: 1.0)};
      final completedIds = state.entries
          .where((e) => e.value.completed)
          .map((e) => e.key.toString())
          .toList();
      await prefs.setStringList(_completedPrefKey, completedIds);
    } catch (e) {
      state = {
        ...state,
        tafsirId: TafsirDownloadInfo(error: 'Download failed — tap to retry'),
      };
    }
  }

  static String _buildKey(int chapter, int verse) => '$chapter:$verse';

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

final tafsirDownloadProvider =
    NotifierProvider<TafsirDownloadNotifier, Map<int, TafsirDownloadInfo>>(
        TafsirDownloadNotifier.new);
