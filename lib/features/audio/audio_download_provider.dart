import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import 'audio_repository.dart';
import 'quran_foundation_repository.dart';

// ─── Per-surah download state ─────────────────────────────────────────────────

class SurahDownloadInfo {
  const SurahDownloadInfo({
    this.downloaded = 0,
    this.total = 0,
    this.isDownloading = false,
    this.error,
  });

  final int downloaded;
  final int total;
  final bool isDownloading;
  final String? error;

  bool get isComplete => total > 0 && downloaded >= total;
  double get progress => total > 0 ? downloaded / total : 0.0;

  SurahDownloadInfo copyWith({
    int? downloaded,
    int? total,
    bool? isDownloading,
    String? error,
  }) =>
      SurahDownloadInfo(
        downloaded: downloaded ?? this.downloaded,
        total: total ?? this.total,
        isDownloading: isDownloading ?? this.isDownloading,
        error: error,
      );
}

// State type: reciterSlug → surahNumber → download info
typedef AudioDownloadState = Map<String, Map<int, SurahDownloadInfo>>;

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AudioDownloadNotifier extends Notifier<AudioDownloadState> {
  static const _prefKey = 'audio_downloaded_list'; // stores "slug|surahNum" entries

  late final Dio _dio;

  @override
  AudioDownloadState build() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 90),
    ));
    _loadCompleted();
    return {};
  }

  // ── File system helpers ────────────────────────────────────────────────────

  Future<Directory> _reciterDir(String slug) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/audio_cache/$slug');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  static String _fileName(int surah, int ayah) =>
      '${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3';

  Future<String> getLocalPath(String slug, int surah, int ayah) async {
    final dir = await _reciterDir(slug);
    return '${dir.path}/${_fileName(surah, ayah)}';
  }

  /// Returns true when the cached file exists and is not suspiciously small.
  Future<bool> isAyahCached(String slug, int surah, int ayah) async {
    final path = await getLocalPath(slug, surah, ayah);
    final f = File(path);
    return f.existsSync() && f.lengthSync() > 512;
  }

  // ── Persist / load ─────────────────────────────────────────────────────────

  Future<void> _loadCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefKey) ?? [];
    if (raw.isEmpty) return;

    final update = <String, Map<int, SurahDownloadInfo>>{};
    for (final entry in raw) {
      final idx = entry.lastIndexOf('|');
      if (idx < 0) continue;
      final slug = entry.substring(0, idx);
      final surahNum = int.tryParse(entry.substring(idx + 1));
      if (surahNum == null || surahNum < 1 || surahNum > 114) continue;
      final total = kSurahVerseCounts[surahNum - 1];
      update[slug] ??= {};
      update[slug]![surahNum] = SurahDownloadInfo(
        downloaded: total,
        total: total,
      );
    }
    if (update.isNotEmpty) {
      state = {...state, for (final e in update.entries) e.key: {...(state[e.key] ?? {}), ...e.value}};
    }
  }

  Future<void> _persistCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final list = <String>[];
    for (final slug in state.keys) {
      for (final entry in (state[slug] ?? {}).entries) {
        if (entry.value.isComplete) {
          list.add('$slug|${entry.key}');
        }
      }
    }
    await prefs.setStringList(_prefKey, list);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool isDownloading(String slug, int surahNumber) =>
      state[slug]?[surahNumber]?.isDownloading == true;

  bool isSurahComplete(String slug, int surahNumber) =>
      state[slug]?[surahNumber]?.isComplete == true;

  SurahDownloadInfo? infoFor(String slug, int surahNumber) =>
      state[slug]?[surahNumber];

  void _set(String slug, int surah, SurahDownloadInfo info) {
    state = {
      ...state,
      slug: {...(state[slug] ?? {}), surah: info},
    };
  }

  // ── Download ───────────────────────────────────────────────────────────────

  Future<void> downloadSurah({
    required String reciterSlug,
    required int surahNumber,
    int? qfRecitationId,
  }) async {
    if (isDownloading(reciterSlug, surahNumber)) return;
    if (isSurahComplete(reciterSlug, surahNumber)) return;

    final versesCount = kSurahVerseCounts[surahNumber - 1];
    _set(reciterSlug, surahNumber,
        SurahDownloadInfo(total: versesCount, isDownloading: true));

    // For QF reciters fetch all CDN URLs up-front in one API call.
    Map<int, String>? qfUrls;
    if (qfRecitationId != null) {
      try {
        final repo = ref.read(qfRepositoryProvider);
        qfUrls = await repo.fetchSurahAudio(qfRecitationId, surahNumber);
      } catch (_) {
        _set(reciterSlug, surahNumber, SurahDownloadInfo(
          total: versesCount,
          error: 'Could not fetch audio URLs — check internet connection',
        ));
        return;
      }
    }

    int done = 0;
    final repo = const AudioRepository();

    for (int ayah = 1; ayah <= versesCount; ayah++) {
      if (await isAyahCached(reciterSlug, surahNumber, ayah)) {
        done++;
        _set(reciterSlug, surahNumber,
            SurahDownloadInfo(downloaded: done, total: versesCount, isDownloading: true));
        continue;
      }

      final savePath = await getLocalPath(reciterSlug, surahNumber, ayah);

      final List<String> candidates;
      if (qfUrls != null) {
        final u = qfUrls[ayah];
        candidates = u != null ? [u] : [];
      } else {
        int gid = 0;
        for (int i = 0; i < surahNumber - 1; i++) gid += kSurahVerseCounts[i];
        gid += ayah;
        candidates = [
          repo.ayahUrlMirrors(surahNumber, ayah, reciter: reciterSlug),
          repo.ayahUrlDownloadQa(surahNumber, ayah, reciter: reciterSlug),
          repo.ayahFallbackUrl(surahNumber, ayah, reciter: reciterSlug),
          repo.ayahUrl(surahNumber, ayah, reciter: reciterSlug),
          if (repo.ayahUrlIslamicNet(gid, reciter: reciterSlug) != null)
            repo.ayahUrlIslamicNet(gid, reciter: reciterSlug)!,
        ];
      }

      bool saved = false;
      for (final url in candidates) {
        try {
          await _dio.download(url, savePath);
          final f = File(savePath);
          if (f.existsSync() && f.lengthSync() > 512) {
            saved = true;
            break;
          }
          if (f.existsSync()) await f.delete();
        } catch (_) {
          try { await File(savePath).delete(); } catch (_) {}
        }
      }

      if (saved) done++;

      _set(reciterSlug, surahNumber,
          SurahDownloadInfo(downloaded: done, total: versesCount, isDownloading: true));
    }

    final allDone = done >= versesCount;
    _set(reciterSlug, surahNumber, SurahDownloadInfo(
      downloaded: done,
      total: versesCount,
      error: allDone ? null : 'Some files could not be downloaded',
    ));

    if (allDone) await _persistCompleted();
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> deleteSurah({
    required String reciterSlug,
    required int surahNumber,
  }) async {
    final dir = await _reciterDir(reciterSlug);
    final versesCount = kSurahVerseCounts[surahNumber - 1];
    for (int ayah = 1; ayah <= versesCount; ayah++) {
      try {
        await File('${dir.path}/${_fileName(surahNumber, ayah)}').delete();
      } catch (_) {}
    }
    _set(reciterSlug, surahNumber, const SurahDownloadInfo());
    await _persistCompleted();
  }

  Future<void> deleteAll(String reciterSlug) async {
    try {
      final dir = await _reciterDir(reciterSlug);
      await dir.delete(recursive: true);
    } catch (_) {}
    state = {...state, reciterSlug: {}};
    await _persistCompleted();
  }

  // ── Storage size ───────────────────────────────────────────────────────────

  Future<int> downloadedBytes(String reciterSlug) async {
    try {
      final dir = await _reciterDir(reciterSlug);
      if (!dir.existsSync()) return 0;
      int total = 0;
      await for (final f in dir.list()) {
        if (f is File) total += await f.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}

final audioDownloadProvider =
    NotifierProvider<AudioDownloadNotifier, AudioDownloadState>(
        AudioDownloadNotifier.new);
