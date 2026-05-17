import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/quran_repository.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/note.dart';

// ─── Bookmarks list ───────────────────────────────────────────────────────────

class BookmarksNotifier extends Notifier<List<Bookmark>> {
  @override
  List<Bookmark> build() {
    Future.microtask(_load);
    return [];
  }

  QuranRepository get _repo => ref.read(quranRepositoryProvider);

  Future<void> _load() async {
    state = await _repo.getAllBookmarks();
  }

  Future<void> toggle(
      {required int ayahId,
      required int surahNumber,
      required int ayahNumber}) async {
    final already = await _repo.isBookmarked(ayahId);
    if (already) {
      await _repo.removeBookmark(ayahId);
    } else {
      await _repo.addBookmark(ayahId, surahNumber, ayahNumber);
    }
    state = await _repo.getAllBookmarks();
  }

  Future<bool> isBookmarked(int ayahId) => _repo.isBookmarked(ayahId);
}

final bookmarksProvider =
    NotifierProvider<BookmarksNotifier, List<Bookmark>>(BookmarksNotifier.new);

// ─── Per-ayah bookmark state (used by action sheet for instant feedback) ──────

final bookmarkedAyahProvider =
    FutureProvider.family<bool, int>((ref, ayahId) async {
  // Depend on the bookmarks list so it refreshes when toggles happen.
  ref.watch(bookmarksProvider);
  return ref.read(quranRepositoryProvider).isBookmarked(ayahId);
});

// ─── Notes ────────────────────────────────────────────────────────────────────

class NotesNotifier extends Notifier<List<Note>> {
  @override
  List<Note> build() {
    Future.microtask(_load);
    return [];
  }

  QuranRepository get _repo => ref.read(quranRepositoryProvider);

  Future<void> _load() async {
    state = await _repo.getAllNotes();
  }

  Future<void> save(
      int ayahId, int surahNumber, int ayahNumber, String body) async {
    await _repo.saveNote(ayahId, surahNumber, ayahNumber, body);
    state = await _repo.getAllNotes();
  }

  Future<void> delete(int ayahId) async {
    await _repo.deleteNote(ayahId);
    state = await _repo.getAllNotes();
  }
}

final notesProvider =
    NotifierProvider<NotesNotifier, List<Note>>(NotesNotifier.new);

final noteForAyahProvider =
    FutureProvider.family<Note?, int>((ref, ayahId) async {
  ref.watch(notesProvider);
  return ref.read(quranRepositoryProvider).getNoteForAyah(ayahId);
});
