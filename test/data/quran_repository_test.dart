import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/data/repositories/quran_repository.dart';
import 'package:quran_app/data/sources/local/quran_database.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

QuranDatabase _makeDb() => QuranDatabase.forTesting(NativeDatabase.memory());

Future<void> _insertFixture(QuranDatabase db) async {
  // Juz 1: verses 1–148
  await db.into(db.juzs).insert(JuzsCompanion.insert(
        juzNumber: const Value(1),
        firstVerseId: 1,
        lastVerseId: 148,
        versesCount: 148,
      ));

  // Surah Al-Fatihah (7 verses, surah 1)
  await db.into(db.surahs).insert(SurahsCompanion.insert(
        id: const Value(1),
        nameArabic: 'الفاتحة',
        nameSimple: 'Al-Fatihah',
        nameComplex: 'Al-Fātiĥah',
        nameEnglish: 'The Opener',
        revelationPlace: 'makkah',
        versesCount: 7,
      ));

  // Al-Fatihah ayahs (1:1 – 1:7)
  final fatihah = [
    (1, 1, 1, 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ'),
    (2, 1, 2, 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ'),
    (3, 1, 3, 'ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ'),
    (4, 1, 4, 'مَـٰلِكِ يَوْمِ ٱلدِّينِ'),
    (5, 1, 5, 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ'),
    (6, 1, 6, 'ٱهْدِنَا ٱلصِّرَٰطَ ٱلْمُسْتَقِيمَ'),
    (7, 1, 7, 'صِرَٰطَ ٱلَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ ٱلْمَغْضُوبِ عَلَيْهِمْ وَلَا ٱلضَّآلِّينَ'),
  ];

  for (final (id, surah, ayah, text) in fatihah) {
    await db.into(db.ayahs).insert(AyahsCompanion.insert(
          id: Value(id),
          surahNumber: surah,
          ayahNumber: ayah,
          textUthmani: text,
          juzNumber: 1,
        ));
  }
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late QuranDatabase db;
  late QuranRepository repo;

  setUp(() async {
    db = _makeDb();
    repo = QuranRepository(db);
    await _insertFixture(db);
  });

  tearDown(() => db.close());

  group('getSurah', () {
    test('returns Al-Fatihah correctly', () async {
      final surah = await repo.getSurah(1);
      expect(surah.id, 1);
      expect(surah.nameSimple, 'Al-Fatihah');
      expect(surah.versesCount, 7);
      expect(surah.revelationPlace, 'makkah');
    });

    test('throws when surah does not exist', () async {
      expect(() => repo.getSurah(999), throwsA(anything));
    });
  });

  group('getAllSurahs', () {
    test('returns all inserted surahs ordered by id', () async {
      final surahs = await repo.getAllSurahs();
      expect(surahs.length, 1);
      expect(surahs.first.id, 1);
    });
  });

  group('getAyah', () {
    test('returns Basmala (1:1)', () async {
      final ayah = await repo.getAyah(1, 1);
      expect(ayah.surahNumber, 1);
      expect(ayah.ayahNumber, 1);
      expect(ayah.verseKey, '1:1');
      expect(ayah.textUthmani, contains('بِسْمِ'));
    });

    test('returns last ayah of Al-Fatihah (1:7)', () async {
      final ayah = await repo.getAyah(1, 7);
      expect(ayah.ayahNumber, 7);
      expect(ayah.juzNumber, 1);
    });
  });

  group('getSurahAyahs', () {
    test('returns 7 ayahs for Al-Fatihah in order', () async {
      final ayahs = await repo.getSurahAyahs(1);
      expect(ayahs.length, 7);
      expect(ayahs.first.ayahNumber, 1);
      expect(ayahs.last.ayahNumber, 7);
    });

    test('returns empty for nonexistent surah', () async {
      final ayahs = await repo.getSurahAyahs(999);
      expect(ayahs, isEmpty);
    });
  });

  group('getJuzAyahs', () {
    test('returns all 7 ayahs for juz 1 (fixture only has Al-Fatihah)', () async {
      final ayahs = await repo.getJuzAyahs(1);
      expect(ayahs.length, 7);
    });
  });

  group('searchAyahs', () {
    test('finds ayah containing الرحمن', () async {
      final results = await repo.searchAyahs('ٱلرَّحْمَـٰنِ');
      expect(results, isNotEmpty);
      expect(results.every((a) => a.textUthmani.contains('ٱلرَّحْمَـٰنِ')), isTrue);
    });

    test('returns empty for blank query', () async {
      final results = await repo.searchAyahs('   ');
      expect(results, isEmpty);
    });

    test('returns empty for text not in Quran', () async {
      final results = await repo.searchAyahs('xyzxyzxyz');
      expect(results, isEmpty);
    });
  });

  group('getJuz', () {
    test('returns juz 1 metadata', () async {
      final juz = await repo.getJuz(1);
      expect(juz.juzNumber, 1);
      expect(juz.firstVerseId, 1);
      expect(juz.lastVerseId, 148);
    });
  });
}
