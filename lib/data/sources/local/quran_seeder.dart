import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'quran_database.dart';

// Bump this key when the seed data changes (forces re-seed on next launch).
const _seededKey = 'quran_db_seeded_v3';

/// Populates the database from bundled JSON assets on first launch.
/// Safe to call on every startup — skips if already seeded.
class QuranSeeder {
  const QuranSeeder(this._db);

  final QuranDatabase _db;

  Future<void> seedIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seededKey) == true) return;

    await _seedSurahs();
    await _seedJuzs();
    await _seedAyahs();
    await _seedTranslations(); // seed after ayahs (references ayah ids)
    // Additional translations — only seeded if asset files are present.
    await _seedOptionalTranslation(
        'assets/quran/translations_ur_jalandhry.json', 'ur_jalandhry');
    await _seedOptionalTranslation(
        'assets/quran/translations_id_indonesian.json', 'id_indonesian');

    await prefs.setBool(_seededKey, true);
  }

  Future<void> _seedSurahs() async {
    final raw = await rootBundle.loadString('assets/quran/surahs.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final chapters = data['chapters'] as List<dynamic>;

    final rows = chapters.map((c) {
      final m = c as Map<String, dynamic>;
      return SurahsCompanion.insert(
        id: Value(m['id'] as int),
        nameArabic: m['name_arabic'] as String,
        nameSimple: m['name_simple'] as String,
        nameComplex: m['name_complex'] as String,
        nameEnglish: (m['translated_name'] as Map)['name'] as String,
        revelationPlace: m['revelation_place'] as String,
        versesCount: m['verses_count'] as int,
        bismillahPre: Value(m['bismillah_pre'] as bool),
      );
    }).toList();

    await _db.batch((b) => b.insertAll(_db.surahs, rows, mode: InsertMode.insertOrIgnore));
  }

  Future<void> _seedJuzs() async {
    final raw = await rootBundle.loadString('assets/quran/juzs.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final juzList = data['juzs'] as List<dynamic>;

    // The API may return duplicates per hizb — deduplicate by juz_number,
    // keeping the entry with the widest verse range.
    final Map<int, JuzsCompanion> byNumber = {};
    for (final j in juzList) {
      final m = j as Map<String, dynamic>;
      final num = m['juz_number'] as int;
      final first = m['first_verse_id'] as int;
      final last = m['last_verse_id'] as int;
      final count = m['verses_count'] as int;

      final existing = byNumber[num];
      if (existing == null ||
          first < (existing.firstVerseId.value) ||
          last > (existing.lastVerseId.value)) {
        byNumber[num] = JuzsCompanion.insert(
          juzNumber: Value(num),
          firstVerseId: first,
          lastVerseId: last,
          versesCount: count,
        );
      }
    }

    await _db.batch((b) => b.insertAll(_db.juzs, byNumber.values.toList(),
        mode: InsertMode.insertOrIgnore));
  }

  Future<void> _seedAyahs() async {
    final raw = await rootBundle.loadString('assets/quran/verses_uthmani.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final verses = data['verses'] as List<dynamic>;

    // Build a juz lookup: verseId → juzNumber from already-seeded juz table.
    final juzRows = await _db.select(_db.juzs).get();
    final List<(int first, int last, int num)> juzRanges = juzRows
        .map((r) => (r.firstVerseId, r.lastVerseId, r.juzNumber))
        .toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));

    int juzFor(int verseId) {
      for (final (first, last, num) in juzRanges) {
        if (verseId >= first && verseId <= last) return num;
      }
      return 1; // fallback
    }

    // Insert in batches of 500 to avoid SQLite variable limits.
    const batchSize = 500;
    for (var i = 0; i < verses.length; i += batchSize) {
      final chunk = verses.sublist(i, (i + batchSize).clamp(0, verses.length));
      final rows = chunk.map((v) {
        final m = v as Map<String, dynamic>;
        final id = m['id'] as int;
        final key = m['verse_key'] as String; // "2:255"
        final parts = key.split(':');
        return AyahsCompanion.insert(
          id: Value(id),
          surahNumber: int.parse(parts[0]),
          ayahNumber: int.parse(parts[1]),
          textUthmani: m['text_uthmani'] as String,
          juzNumber: juzFor(id),
        );
      }).toList();

      await _db.batch(
          (b) => b.insertAll(_db.ayahs, rows, mode: InsertMode.insertOrIgnore));
    }
  }

  Future<void> _seedTranslations() async {
    final raw = await rootBundle.loadString('assets/quran/translations_en_sahih.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = data['translations'] as List<dynamic>;

    const key = 'en_sahih';
    const batchSize = 500;
    for (var i = 0; i < list.length; i += batchSize) {
      final chunk = list.sublist(i, (i + batchSize).clamp(0, list.length));
      final rows = chunk.map((t) {
        final m = t as Map<String, dynamic>;
        return TranslationsCompanion.insert(
          ayahId: m['id'] as int,
          translationKey: key,
          body: m['text'] as String,
        );
      }).toList();
      await _db.batch(
          (b) => b.insertAll(_db.translations, rows, mode: InsertMode.insertOrIgnore));
    }
  }

  // Silently skips if the asset file has not been downloaded yet.
  Future<void> _seedOptionalTranslation(
      String assetPath, String translationKey) async {
    String raw;
    try {
      raw = await rootBundle.loadString(assetPath);
    } catch (_) {
      return; // file not bundled — skip
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = data['translations'] as List<dynamic>;

    const batchSize = 500;
    for (var i = 0; i < list.length; i += batchSize) {
      final chunk = list.sublist(i, (i + batchSize).clamp(0, list.length));
      final rows = chunk.map((t) {
        final m = t as Map<String, dynamic>;
        return TranslationsCompanion.insert(
          ayahId: m['id'] as int,
          translationKey: translationKey,
          body: m['text'] as String,
        );
      }).toList();
      await _db.batch(
          (b) => b.insertAll(_db.translations, rows, mode: InsertMode.insertOrIgnore));
    }
  }
}
