import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

// Downloads and caches the KFGQPC Uthmanic Script HAFS font at runtime.
// On cache hit, font loads instantly during startup.
// On cache miss, the bundled placeholder renders text and a background download
// runs — next launch uses the real King Fahad Mushaf font.
class ArabicFontService {
  static const _fontFamily = 'UthmanicHafs';
  static const _cacheFile = 'kfgqpc_uthmanic_hafs.ttf';
  static const _minValidSize = 300 * 1024; // real font is ~500-600 KB

  static const _urls = [
    'https://fonts.qurancomplex.gov.sa/wp02/uploads/2019/08/UthmanicHafs1Ver18.ttf',
    'https://www.qurancomplex.gov.sa/quran/fonts/UthmanicHafs1Ver18.ttf',
    'https://quran.ksu.edu.sa/fonts/hafs/UthmanicHafs1Ver18.ttf',
  ];

  /// Call during app startup. Returns immediately if no cached font exists
  /// (starts a background download) or loads the cached font synchronously.
  static Future<bool> tryLoadCached() async {
    try {
      final file = await _cacheFileHandle();
      if (await file.exists() && file.lengthSync() >= _minValidSize) {
        return await _loadBytes(await file.readAsBytes());
      }
    } catch (_) {}

    // No valid cache — kick off background download without blocking startup.
    _downloadInBackground();
    return false;
  }

  /// Runs a download attempt and caches on success.
  /// Should only be called when there is no valid cached file.
  static Future<void> _downloadInBackground() async {
    try {
      final bytes = await _downloadFont();
      if (bytes == null) return;

      final file = await _cacheFileHandle();
      await file.writeAsBytes(bytes);
      // Font is now cached for next launch; optionally load it live:
      await _loadBytes(bytes);
    } catch (_) {}
  }

  static Future<Uint8List?> _downloadFont() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    for (final url in _urls) {
      try {
        final uri = Uri.parse(url);
        final req = await client.getUrl(uri);
        final res = await req.close().timeout(const Duration(seconds: 30));
        if (res.statusCode == 200) {
          final chunks = <List<int>>[];
          await res.forEach(chunks.add);
          final bytes = Uint8List.fromList(chunks.expand((c) => c).toList());
          if (_isValidFont(bytes)) return bytes;
        }
      } catch (_) {}
    }
    client.close();
    return null;
  }

  static bool _isValidFont(Uint8List bytes) {
    if (bytes.length < _minValidSize) return false;
    // TTF: 00 01 00 00  |  OTF CFF: 4F 54 54 4F  |  TrueType Mac: 74 72 75 65
    final magic = bytes.sublist(0, 4);
    return _eq(magic, [0x00, 0x01, 0x00, 0x00]) ||
        _eq(magic, [0x4F, 0x54, 0x54, 0x4F]) ||
        _eq(magic, [0x74, 0x72, 0x75, 0x65]);
  }

  static bool _eq(Uint8List a, List<int> b) {
    for (int i = 0; i < b.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static Future<bool> _loadBytes(Uint8List bytes) async {
    try {
      final loader = FontLoader(_fontFamily);
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<File> _cacheFileHandle() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_cacheFile');
  }
}
