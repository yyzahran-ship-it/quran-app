import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

// Persist / restore QDC word-timing JSON to the app's documents directory.
// Call sites guard with `if (!kIsWeb)` — dart:io is not available on web.

Future<String?> _path(int qdcReciterId, int surahNumber) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/timings/qdc${qdcReciterId}s$surahNumber.json';
  } catch (_) {
    return null;
  }
}

Future<Map<String, dynamic>?> timingDiskRead(
    int qdcReciterId, int surahNumber) async {
  final path = await _path(qdcReciterId, surahNumber);
  if (path == null) return null;
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

Future<void> timingDiskWrite(
    int qdcReciterId, int surahNumber, Map<String, dynamic> data) async {
  final path = await _path(qdcReciterId, surahNumber);
  if (path == null) return;
  try {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data));
  } catch (_) {}
}
