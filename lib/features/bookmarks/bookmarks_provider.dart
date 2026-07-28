import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<void> toggle({
    required int ayahId,
    required int surahNumber,
    required int ayahNumber,
    String? tag,
  }) async {
    final already = await _repo.isBookmarked(ayahId);
    if (already) {
      await _repo.removeBookmark(ayahId);
    } else {
      await _repo.addBookmark(ayahId, surahNumber, ayahNumber, tag: tag);
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

// ─── Page bookmark (single saved reading position) ────────────────────────────

typedef PageBookmark = ({int page, String label});

class PageBookmarkNotifier extends Notifier<PageBookmark?> {
  static const _pageKey  = 'page_bk_page';
  static const _labelKey = 'page_bk_label';

  @override
  PageBookmark? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final page  = prefs.getInt(_pageKey);
    final label = prefs.getString(_labelKey);
    if (page != null) {
      state = (page: page, label: label ?? 'Page $page');
    }
  }

  Future<void> toggle(int page, String label) async {
    final prefs = await SharedPreferences.getInstance();
    if (state?.page == page) {
      state = null;
      await prefs.remove(_pageKey);
      await prefs.remove(_labelKey);
    } else {
      state = (page: page, label: label);
      await prefs.setInt(_pageKey, page);
      await prefs.setString(_labelKey, label);
    }
  }
}

final pageBookmarkProvider =
    NotifierProvider<PageBookmarkNotifier, PageBookmark?>(PageBookmarkNotifier.new);
