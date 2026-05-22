import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../sources/local/quran_database.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/hifz_card.dart';
import '../../domain/entities/juz.dart';
import '../../domain/entities/note.dart';
import '../../domain/entities/surah.dart';

// ─── Repository ───────────────────────────────────────────────────────────────

class QuranRepository {
  const QuranRepository(this._db);

  final QuranDatabase _db;

  // ── Surahs ─────────────────────────────────────────────────────────────────

  Future<Surah> getSurah(int surahNumber) async {
    final row = await (_db.select(_db.surahs)
          ..where((t) => t.id.equals(surahNumber)))
        .getSingle();
    return _toSurah(row);
  }

  Future<List<Surah>> getAllSurahs() async {
    final rows = await (_db.select(_db.surahs)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    return rows.map(_toSurah).toList();
  }

  // ── Ayahs ──────────────────────────────────────────────────────────────────

  Future<Ayah> getAyah(int surahNumber, int ayahNumber) async {
    final row = await (_db.select(_db.ayahs)
          ..where((t) =>
              t.surahNumber.equals(surahNumber) &
              t.ayahNumber.equals(ayahNumber)))
        .getSingle();
    return _toAyah(row);
  }

  Future<List<Ayah>> getSurahAyahs(int surahNumber) async {
    final rows = await (_db.select(_db.ayahs)
          ..where((t) => t.surahNumber.equals(surahNumber))
          ..orderBy([(t) => OrderingTerm.asc(t.ayahNumber)]))
        .get();
    return rows.map(_toAyah).toList();
  }

  /// All ayahs on a given Mushaf page (1–604), ordered by global ID.
  Future<List<Ayah>> getPageAyahs(int pageNumber) async {
    final idx = pageNumber - 1; // 0-based index into kPageFirstAyah
    if (idx < 0 || idx >= kPageFirstAyah.length) return [];
    final firstId = kPageFirstAyah[idx];
    final lastId = kPageLastAyah[idx];
    if (firstId == 0) return [];
    final rows = await (_db.select(_db.ayahs)
          ..where((t) =>
              t.id.isBiggerOrEqualValue(firstId) &
              t.id.isSmallerOrEqualValue(lastId))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    return rows.map(_toAyah).toList();
  }

  /// Translations for a range of global ayah IDs.
  Future<Map<int, String>> getPageTranslations(
    int firstId,
    int lastId, {
    String translationKey = 'en_sahih',
  }) async {
    final txRows = await (_db.select(_db.translations)
          ..where((t) =>
              t.ayahId.isBiggerOrEqualValue(firstId) &
              t.ayahId.isSmallerOrEqualValue(lastId) &
              t.translationKey.equals(translationKey)))
        .get();
    return {for (final r in txRows) r.ayahId: r.body};
  }

  /// Returns all translation keys currently seeded in the database.
  Future<List<String>> getAvailableTranslationKeys() async {
    final result = await (_db.selectOnly(_db.translations)
          ..addColumns([_db.translations.translationKey])
          ..groupBy([_db.translations.translationKey]))
        .get();
    return result
        .map((r) => r.read(_db.translations.translationKey)!)
        .toList();
  }

  Future<List<Ayah>> getJuzAyahs(int juzNumber) async {
    final rows = await (_db.select(_db.ayahs)
          ..where((t) => t.juzNumber.equals(juzNumber))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    return rows.map(_toAyah).toList();
  }

  /// Full-text search across Uthmani Arabic text. Returns up to 100 results.
  Future<List<Ayah>> searchAyahs(String query) async {
    if (query.trim().isEmpty) return [];
    final rows = await (_db.select(_db.ayahs)
          ..where((t) => t.textUthmani.contains(query.trim()))
          ..limit(100))
        .get();
    return rows.map(_toAyah).toList();
  }

  /// Returns the surah number that contains the given global verse id.
  Future<int> getSurahNumberForVerseId(int verseId) async {
    final row = await (_db.select(_db.ayahs)
          ..where((t) => t.id.equals(verseId)))
        .getSingle();
    return row.surahNumber;
  }

  // ── Juzs ───────────────────────────────────────────────────────────────────

  Future<Juz> getJuz(int juzNumber) async {
    final row = await (_db.select(_db.juzs)
          ..where((t) => t.juzNumber.equals(juzNumber)))
        .getSingle();
    return _toJuz(row);
  }

  Future<List<Juz>> getAllJuzs() async {
    final rows = await (_db.select(_db.juzs)
          ..orderBy([(t) => OrderingTerm.asc(t.juzNumber)]))
        .get();
    return rows.map(_toJuz).toList();
  }

  // ── Translations ───────────────────────────────────────────────────────────

  /// Returns a map of ayahId → translation text for every ayah in a surah.
  /// [translationKey] defaults to Sahih International ("en_sahih").
  Future<Map<int, String>> getSurahTranslations(
    int surahNumber, {
    String translationKey = 'en_sahih',
  }) async {
    // Get ayah ids for this surah first, then fetch translations.
    final ayahRows = await (_db.select(_db.ayahs)
          ..where((t) => t.surahNumber.equals(surahNumber)))
        .get();
    final ids = ayahRows.map((r) => r.id).toList();
    if (ids.isEmpty) return {};

    final txRows = await (_db.select(_db.translations)
          ..where((t) =>
              t.ayahId.isIn(ids) & t.translationKey.equals(translationKey)))
        .get();

    return {for (final r in txRows) r.ayahId: r.body};
  }

  // ── Bookmarks ──────────────────────────────────────────────────────────────

  Future<List<Bookmark>> getAllBookmarks() async {
    final rows = await (_db.select(_db.bookmarks)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_toBookmark).toList();
  }

  Future<bool> isBookmarked(int ayahId) async {
    final row = await (_db.select(_db.bookmarks)
          ..where((t) => t.ayahId.equals(ayahId)))
        .getSingleOrNull();
    return row != null;
  }

  Future<Bookmark> addBookmark(int ayahId, int surahNumber, int ayahNumber,
      {String? tag}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await _db.into(_db.bookmarks).insert(
          BookmarksCompanion.insert(
            ayahId: ayahId,
            surahNumber: surahNumber,
            ayahNumber: ayahNumber,
            tag: Value(tag),
            createdAt: now,
          ),
        );
    return Bookmark(
      id: id,
      ayahId: ayahId,
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      tag: tag,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  Future<void> removeBookmark(int ayahId) async {
    await (_db.delete(_db.bookmarks)
          ..where((t) => t.ayahId.equals(ayahId)))
        .go();
  }

  // ── Notes ──────────────────────────────────────────────────────────────────

  Future<Note?> getNoteForAyah(int ayahId) async {
    final row = await (_db.select(_db.notes)
          ..where((t) => t.ayahId.equals(ayahId)))
        .getSingleOrNull();
    return row == null ? null : _toNote(row);
  }

  Future<List<Note>> getAllNotes() async {
    final rows = await (_db.select(_db.notes)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_toNote).toList();
  }

  Future<Note> saveNote(
      int ayahId, int surahNumber, int ayahNumber, String body) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (_db.select(_db.notes)
          ..where((t) => t.ayahId.equals(ayahId)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.notes)..where((t) => t.ayahId.equals(ayahId)))
          .write(NotesCompanion(body: Value(body), updatedAt: Value(now)));
      return _toNote(existing.copyWith(body: body, updatedAt: now));
    } else {
      final id = await _db.into(_db.notes).insert(
            NotesCompanion.insert(
              ayahId: ayahId,
              surahNumber: surahNumber,
              ayahNumber: ayahNumber,
              body: body,
              createdAt: now,
              updatedAt: now,
            ),
          );
      return Note(
        id: id,
        ayahId: ayahId,
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
        body: body,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    }
  }

  Future<void> deleteNote(int ayahId) async {
    await (_db.delete(_db.notes)..where((t) => t.ayahId.equals(ayahId))).go();
  }

  // ── Hifz cards ─────────────────────────────────────────────────────────────

  Future<bool> isInHifz(int ayahId) async {
    final row = await (_db.select(_db.hifzCards)
          ..where((t) => t.ayahId.equals(ayahId)))
        .getSingleOrNull();
    return row != null;
  }

  Future<HifzCard?> getHifzCard(int ayahId) async {
    final row = await (_db.select(_db.hifzCards)
          ..where((t) => t.ayahId.equals(ayahId)))
        .getSingleOrNull();
    return row == null ? null : _toHifzCard(row);
  }

  /// Cards due now (dueAt ≤ now), ordered by due date ascending.
  Future<List<HifzCard>> getDueCards() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final rows = await (_db.select(_db.hifzCards)
          ..where((t) => t.dueAt.isSmallerOrEqualValue(nowMs))
          ..orderBy([(t) => OrderingTerm.asc(t.dueAt)]))
        .get();
    return rows.map(_toHifzCard).toList();
  }

  Future<List<HifzCard>> getAllHifzCards() async {
    final rows = await (_db.select(_db.hifzCards)
          ..orderBy([(t) => OrderingTerm.asc(t.dueAt)]))
        .get();
    return rows.map(_toHifzCard).toList();
  }

  Future<int> getDueCount() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final rows = await (_db.select(_db.hifzCards)
          ..where((t) => t.dueAt.isSmallerOrEqualValue(nowMs)))
        .get();
    return rows.length;
  }

  /// Add a new ayah to the hifz queue (due immediately).
  Future<HifzCard> addToHifz(
      int ayahId, int surahNumber, int ayahNumber) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final id = await _db.into(_db.hifzCards).insert(
          HifzCardsCompanion.insert(
            ayahId: ayahId,
            surahNumber: surahNumber,
            ayahNumber: ayahNumber,
            stability: 0.0,
            difficulty: 0.0,
            scheduledDays: 0,
            reps: 0,
            lapses: 0,
            dueAt: nowMs,
          ),
        );
    return HifzCard(
      id: id,
      ayahId: ayahId,
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      stability: 0.0,
      difficulty: 0.0,
      scheduledDays: 0,
      reps: 0,
      lapses: 0,
      dueAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
    );
  }

  Future<void> removeFromHifz(int ayahId) async {
    await (_db.delete(_db.hifzCards)
          ..where((t) => t.ayahId.equals(ayahId)))
        .go();
  }

  /// Update card after a review with the new FSRS values.
  Future<void> updateHifzCard({
    required int ayahId,
    required double stability,
    required double difficulty,
    required int scheduledDays,
    required int reps,
    required int lapses,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final dueMs = nowMs + Duration(days: scheduledDays).inMilliseconds;

    await (_db.update(_db.hifzCards)
          ..where((t) => t.ayahId.equals(ayahId)))
        .write(HifzCardsCompanion(
      stability: Value(stability),
      difficulty: Value(difficulty),
      scheduledDays: Value(scheduledDays),
      reps: Value(reps),
      lapses: Value(lapses),
      dueAt: Value(dueMs),
      lastReviewAt: Value(nowMs),
    ));
  }

  // ── Mappers — Drift row → domain entity ────────────────────────────────────

  static Surah _toSurah(SurahRow r) => Surah(
        id: r.id,
        nameArabic: r.nameArabic,
        nameSimple: r.nameSimple,
        nameComplex: r.nameComplex,
        nameEnglish: r.nameEnglish,
        revelationPlace: r.revelationPlace,
        versesCount: r.versesCount,
        bismillahPre: r.bismillahPre,
      );

  static Ayah _toAyah(AyahRow r) => Ayah(
        id: r.id,
        surahNumber: r.surahNumber,
        ayahNumber: r.ayahNumber,
        textUthmani: r.textUthmani,
        juzNumber: r.juzNumber,
      );

  static Juz _toJuz(JuzRow r) => Juz(
        juzNumber: r.juzNumber,
        firstVerseId: r.firstVerseId,
        lastVerseId: r.lastVerseId,
        versesCount: r.versesCount,
      );

  static Bookmark _toBookmark(BookmarkRow r) => Bookmark(
        id: r.id,
        ayahId: r.ayahId,
        surahNumber: r.surahNumber,
        ayahNumber: r.ayahNumber,
        tag: r.tag,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
      );

  static Note _toNote(NoteRow r) => Note(
        id: r.id,
        ayahId: r.ayahId,
        surahNumber: r.surahNumber,
        ayahNumber: r.ayahNumber,
        body: r.body,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
      );

  static HifzCard _toHifzCard(HifzCardRow r) => HifzCard(
        id: r.id,
        ayahId: r.ayahId,
        surahNumber: r.surahNumber,
        ayahNumber: r.ayahNumber,
        stability: r.stability,
        difficulty: r.difficulty,
        scheduledDays: r.scheduledDays,
        reps: r.reps,
        lapses: r.lapses,
        dueAt: DateTime.fromMillisecondsSinceEpoch(r.dueAt),
        lastReviewAt: r.lastReviewAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(r.lastReviewAt!),
      );
}

// ─── Providers ────────────────────────────────────────────────────────────────

final quranDatabaseProvider = Provider<QuranDatabase>((ref) {
  final db = QuranDatabase();
  ref.onDispose(db.close);
  return db;
});

final quranRepositoryProvider = Provider<QuranRepository>((ref) {
  return QuranRepository(ref.watch(quranDatabaseProvider));
});
