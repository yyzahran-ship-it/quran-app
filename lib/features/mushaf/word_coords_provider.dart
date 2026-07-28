import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

// List of pixel rects (one per word position) for a single ayah on a page.
// Coordinates are in the same 1024×1634 space as ayah_coords_provider.dart.
// Key = 1-based word position within the ayah.
typedef AyahWordRects = Map<int, Rect>;

// Outer map key = surahNumber * 10000 + ayahNumber
typedef PageWordCoordsMap = Map<int, AyahWordRects>;

class _WordCoordsRepo {
  Future<Database>? _dbFuture;
  final Map<int, PageWordCoordsMap> _cache = {};

  Future<Database> _open() {
    _dbFuture ??= _doOpen();
    return _dbFuture!;
  }

  Future<Database> _doOpen() async {
    final dir  = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/wordcoords.db';
    if (!File(path).existsSync()) {
      final data = await rootBundle.load('assets/quran/wordcoords.db');
      await File(path).writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return sqlite3.open(path, mode: OpenMode.readOnly);
  }

  Future<PageWordCoordsMap> fetchPage(int page) async {
    final hit = _cache[page];
    if (hit != null) return hit;

    final db   = await _open();
    final rows = db.select(
      'SELECT surah, ayah, position, x, y, width, height '
      'FROM word_coords WHERE page_number = ?',
      [page],
    );

    final result = <int, AyahWordRects>{};
    for (final row in rows) {
      final key  = (row['surah'] as int) * 10000 + (row['ayah'] as int);
      final pos  = row['position'] as int;
      final rect = Rect.fromLTWH(
        (row['x']      as int).toDouble(),
        (row['y']      as int).toDouble(),
        (row['width']  as int).toDouble(),
        (row['height'] as int).toDouble(),
      );
      result.putIfAbsent(key, () => {}).putIfAbsent(pos, () => rect);
    }

    _cache[page] = result;
    return result;
  }
}

final _wordCoordsRepoProvider =
    Provider<_WordCoordsRepo>((_) => _WordCoordsRepo());

/// Pixel-precise word bounding rects for every ayah on [page].
/// Returns empty map on error → caller falls back to no word highlight.
final wordCoordsProvider =
    FutureProvider.autoDispose.family<PageWordCoordsMap, int>((ref, page) async {
  try {
    return await ref.read(_wordCoordsRepoProvider).fetchPage(page);
  } catch (_) {
    return const {};
  }
});
