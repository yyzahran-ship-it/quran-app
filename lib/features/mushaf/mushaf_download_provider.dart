import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

const int kTotalMushafPages = 604;

const _kDownloadCdnBases = [
  'https://cdn.qurancdn.com/images/quran/pages/page',
  'https://qurancdn.com/images/quran/pages/page',
  'https://static.qurancdn.com/images/quran/pages/page',
  'https://raw.githubusercontent.com/yyzahran-ship-it/quran-app/mushaf-pages/pages/page',
];

// Shared cache path — used by both _MushafPageLoader and MushafDownloadNotifier
// so downloaded pages are served instantly by the reader.
Future<File> mushafPageCacheFile(int page) async {
  final dir = await getApplicationSupportDirectory();
  final cacheDir = Directory('${dir.path}/mushaf_pages');
  await cacheDir.create(recursive: true);
  return File(
      '${cacheDir.path}/page${page.toString().padLeft(3, '0')}.png');
}

Future<int> countCachedMushafPages() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${dir.path}/mushaf_pages');
    if (!cacheDir.existsSync()) return 0;
    int count = 0;
    for (int p = 1; p <= kTotalMushafPages; p++) {
      final f = File(
          '${cacheDir.path}/page${p.toString().padLeft(3, '0')}.png');
      if (f.existsSync() && f.lengthSync() > 10 * 1024) count++;
    }
    return count;
  } catch (_) {
    return 0;
  }
}

// ─── State ────────────────────────────────────────────────────────────────────

class MushafDownloadState {
  const MushafDownloadState({
    this.cached = 0,
    this.isRunning = false,
    this.isCancelled = false,
  });

  final int cached;
  final bool isRunning;
  final bool isCancelled;

  double get progress => cached / kTotalMushafPages;
  bool get isDone => cached >= kTotalMushafPages;

  MushafDownloadState copyWith({
    int? cached,
    bool? isRunning,
    bool? isCancelled,
  }) =>
      MushafDownloadState(
        cached: cached ?? this.cached,
        isRunning: isRunning ?? this.isRunning,
        isCancelled: isCancelled ?? this.isCancelled,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MushafDownloadNotifier extends Notifier<MushafDownloadState> {
  bool _cancel = false;

  @override
  MushafDownloadState build() {
    Future.microtask(_refreshCount);
    return const MushafDownloadState();
  }

  Future<void> _refreshCount() async {
    final count = await countCachedMushafPages();
    state = state.copyWith(cached: count);
  }

  Future<void> start() async {
    if (state.isRunning) return;
    _cancel = false;

    // Resolve cache dir once — avoids 604 redundant getApplicationSupportDirectory calls.
    final appDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appDir.path}/mushaf_pages');
    await cacheDir.create(recursive: true);

    File _pageFile(int page) =>
        File('${cacheDir.path}/page${page.toString().padLeft(3, '0')}.png');

    int cached = await countCachedMushafPages();
    state = MushafDownloadState(cached: cached, isRunning: true);

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));

    for (int page = 1; page <= kTotalMushafPages; page++) {
      if (_cancel) break;

      final file = _pageFile(page);
      if (file.existsSync() && file.lengthSync() > 10 * 1024) {
        continue;
      }

      final padded = page.toString().padLeft(3, '0');
      for (final base in _kDownloadCdnBases) {
        if (_cancel) break;
        try {
          final resp = await dio.get<List<int>>(
            '$base$padded.png',
            options: Options(responseType: ResponseType.bytes),
          );
          if (resp.statusCode == 200 &&
              resp.data != null &&
              resp.data!.length > 10 * 1024) {
            await file.writeAsBytes(Uint8List.fromList(resp.data!));
            cached++;
            state = state.copyWith(cached: cached);
            break;
          }
        } catch (_) {}
      }
    }

    state = state.copyWith(isRunning: false, isCancelled: _cancel);
  }

  void cancel() {
    _cancel = true;
    state = state.copyWith(isRunning: false, isCancelled: true);
  }
}

final mushafDownloadProvider =
    NotifierProvider<MushafDownloadNotifier, MushafDownloadState>(
        MushafDownloadNotifier.new);
