import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'quran_database.g.dart';

// ─── Tables ───────────────────────────────────────────────────────────────────

// surah = chapter of the Quran (114 total)
// DataClassName avoids conflict with the domain entity named Surah.
@DataClassName('SurahRow')
class Surahs extends Table {
  IntColumn get id => integer()();
  TextColumn get nameArabic => text()();
  TextColumn get nameSimple => text()(); // e.g. "Al-Fatihah"
  TextColumn get nameComplex => text()(); // e.g. "Al-Fātiĥah"
  TextColumn get nameEnglish => text()(); // e.g. "The Opener"
  TextColumn get revelationPlace => text()(); // "makkah" or "madinah"
  IntColumn get versesCount => integer()();
  BoolColumn get bismillahPre => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

// ayah = verse of the Quran (6236 total)
@DataClassName('AyahRow')
class Ayahs extends Table {
  IntColumn get id => integer()(); // global sequential id, 1–6236
  IntColumn get surahNumber => integer()();
  IntColumn get ayahNumber => integer()(); // position within surah
  TextColumn get textUthmani => text()(); // Uthmani script with diacritics
  IntColumn get juzNumber => integer()(); // juz = 1/30 of Quran

  @override
  Set<Column> get primaryKey => {id};
}

// juz = one of 30 equal portions of the Quran
@DataClassName('JuzRow')
class Juzs extends Table {
  IntColumn get juzNumber => integer()();
  IntColumn get firstVerseId => integer()();
  IntColumn get lastVerseId => integer()();
  IntColumn get versesCount => integer()();

  @override
  Set<Column> get primaryKey => {juzNumber};
}

// translation text for each ayah, keyed by (ayahId, translationKey).
// translationKey examples: "en_sahih", "ur_jalandhry", "id_indonesian"
@DataClassName('TranslationRow')
class Translations extends Table {
  IntColumn get ayahId => integer()();
  TextColumn get translationKey => text()();
  TextColumn get body => text()();

  @override
  Set<Column> get primaryKey => {ayahId, translationKey};
}

// bookmark = saved ayah with optional tag
@DataClassName('BookmarkRow')
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ayahId => integer()();       // global 1–6236
  IntColumn get surahNumber => integer()();
  IntColumn get ayahNumber => integer()();
  TextColumn get tag => text().nullable()(); // e.g. "favourite", "memorizing"
  IntColumn get createdAt => integer()();    // Unix ms
}

// note = freeform text attached to one ayah (one note per ayah)
@DataClassName('NoteRow')
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ayahId => integer().unique()();
  IntColumn get surahNumber => integer()();
  IntColumn get ayahNumber => integer()();
  TextColumn get body => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

// hifz_card = one FSRS card per ayah being memorized
@DataClassName('HifzCardRow')
class HifzCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ayahId => integer().unique()(); // global 1–6236
  IntColumn get surahNumber => integer()();
  IntColumn get ayahNumber => integer()();
  RealColumn get stability => real()();    // FSRS stability (days)
  RealColumn get difficulty => real()();   // FSRS difficulty 1–10
  IntColumn get scheduledDays => integer()();
  IntColumn get reps => integer()();       // total successful reviews
  IntColumn get lapses => integer()();     // times forgotten
  IntColumn get dueAt => integer()();      // Unix ms — when next review is due
  IntColumn get lastReviewAt => integer().nullable()(); // Unix ms
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [Surahs, Ayahs, Juzs, Translations, Bookmarks, Notes, HifzCards])
class QuranDatabase extends _$QuranDatabase {
  QuranDatabase() : super(_openConnection());

  // For testing — inject an in-memory database executor.
  QuranDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(translations);
          if (from < 3) {
            await m.createTable(bookmarks);
            await m.createTable(notes);
          }
          if (from < 4) await m.createTable(hifzCards);
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'quran_db');
  }
}
