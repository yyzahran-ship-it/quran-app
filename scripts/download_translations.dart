/// Downloads Urdu and Indonesian translations from alquran.cloud and saves
/// them to assets/quran/ in the format expected by QuranSeeder.
///
/// Run once from the project root:
///   dart run scripts/download_translations.dart
///
/// Then hot-restart the app — the new translations will be seeded on the
/// next launch and appear in Settings → Reading → Translation language.

import 'dart:convert';
import 'dart:io';

const _editions = {
  'ur_jalandhry': 'ur.jalandhry',    // Fateh Muhammad Jalandhry (Urdu)
  'id_indonesian': 'id.indonesian',  // Kemenag Ministry (Indonesian)
};

const _baseUrl = 'https://api.alquran.cloud/v1/quran';

Future<void> main() async {
  final client = HttpClient();

  for (final entry in _editions.entries) {
    final key = entry.key;
    final edition = entry.value;
    final outPath = 'assets/quran/translations_$key.json';

    stdout.write('Downloading $edition ... ');

    try {
      final uri = Uri.parse('$_baseUrl/$edition');
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        stderr.writeln('HTTP ${response.statusCode} — skipping');
        continue;
      }

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final surahs =
          (data['data'] as Map<String, dynamic>)['surahs'] as List<dynamic>;

      // Flatten nested surah→ayah structure into [{id, text}] list.
      int globalId = 0;
      final translations = <Map<String, dynamic>>[];
      for (final surah in surahs) {
        final ayahs = (surah as Map<String, dynamic>)['ayahs'] as List<dynamic>;
        for (final ayah in ayahs) {
          globalId++;
          final m = ayah as Map<String, dynamic>;
          // Strip HTML entities that some editions include.
          final text = (m['text'] as String)
              .replaceAll('&nbsp;', ' ')
              .replaceAll('&amp;', '&')
              .trim();
          translations.add({'id': globalId, 'text': text});
        }
      }

      final out = jsonEncode({'translations': translations});
      await File(outPath).writeAsString(out);
      stdout.writeln('saved → $outPath (${translations.length} ayahs)');
    } catch (e) {
      stderr.writeln('Error: $e');
    }
  }

  client.close();
  stdout.writeln('\nDone. Add the new files to pubspec.yaml assets, then:');
  stdout.writeln('  flutter clean && flutter run');
}
