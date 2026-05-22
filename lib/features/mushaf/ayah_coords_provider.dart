import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

// List of pixel rectangles (one per text-line segment) for a single ayah.
// Coordinates are in the DB's native space (≈1024×1634 px).
// Scale to widget size before painting.
typedef AyahRects = List<Rect>;

// Map key = surahNumber * 10000 + ayahNumber
typedef PageCoordsMap = Map<int, AyahRects>;

// DB was generated from King Fahad Mushaf images at this resolution.
const double kDbImageWidth  = 1024.0;
const double kDbImageHeight = 1634.0;

class _AyahCoordsRepo {
  // Completer prevents re-entrant open calls.
  Future<Database>? _dbFuture;
  // In-memory cache: page → coords map.
  final Map<int, PageCoordsMap> _cache = {};

  Future<Database> _open() {
    _dbFuture ??= _doOpen();
    return _dbFuture!;
  }

  Future<Database> _doOpen() async {
    final dir  = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/ayahcoords.db';
    if (!File(path).existsSync()) {
      final data = await rootBundle.load('assets/quran/ayahcoords.db');
      await File(path).writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return sqlite3.open(path, mode: OpenMode.readOnly);
  }

  Future<PageCoordsMap> fetchPage(int page) async {
    final hit = _cache[page];
    if (hit != null) return hit;

    final db   = await _open();
    final rows = db.select(
      'SELECT surah, ayah, x, y, width, height '
      'FROM page WHERE page_number = ?',
      [page],
    );

    final result = <int, AyahRects>{};
    for (final row in rows) {
      final key  = (row['surah'] as int) * 10000 + (row['ayah'] as int);
      final rect = Rect.fromLTWH(
        (row['x']      as int).toDouble(),
        (row['y']      as int).toDouble(),
        (row['width']  as int).toDouble(),
        (row['height'] as int).toDouble(),
      );
      result.putIfAbsent(key, () => []).add(rect);
    }

    _cache[page] = result;
    return result;
  }
}

final _ayahCoordsRepoProvider =
    Provider<_AyahCoordsRepo>((_) => _AyahCoordsRepo());

/// Pixel-precise bounding rects for every ayah on [page].
/// Returns empty map on error → caller falls back to proportional layout.
final ayahCoordsProvider =
    FutureProvider.autoDispose.family<PageCoordsMap, int>((ref, page) async {
  try {
    return await ref.read(_ayahCoordsRepoProvider).fetchPage(page);
  } catch (_) {
    return const {};
  }
});
