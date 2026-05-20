import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/quran_repository.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/surah.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class MushafState {
  const MushafState({
    required this.surahs,
    required this.currentPage,
    required this.ayahs,
    this.translations = const {},
    this.showTranslation = false,
    this.isLoading = false,
  });

  final List<Surah> surahs;        // all 114 — for title lookups and navigation
  final int currentPage;           // 1–604 (Madinah Mushaf)
  final List<Ayah> ayahs;          // ayahs on currentPage (may span surahs)
  final Map<int, String> translations; // ayahId → text
  final bool showTranslation;
  final bool isLoading;

  // Convenience: surah metadata for any surah number
  Surah? surahFor(int surahNumber) {
    for (final s in surahs) {
      if (s.id == surahNumber) return s;
    }
    return null;
  }

  MushafState copyWith({
    List<Surah>? surahs,
    int? currentPage,
    List<Ayah>? ayahs,
    Map<int, String>? translations,
    bool? showTranslation,
    bool? isLoading,
  }) =>
      MushafState(
        surahs: surahs ?? this.surahs,
        currentPage: currentPage ?? this.currentPage,
        ayahs: ayahs ?? this.ayahs,
        translations: translations ?? this.translations,
        showTranslation: showTranslation ?? this.showTranslation,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MushafNotifier extends Notifier<MushafState> {
  @override
  MushafState build() {
    Future.microtask(() => _init());
    return const MushafState(
        surahs: [], currentPage: 1, ayahs: [], isLoading: true);
  }

  QuranRepository get _repo => ref.read(quranRepositoryProvider);

  Future<void> _init() async {
    try {
      final results = await Future.wait<dynamic>([
        _repo.getAllSurahs(),
        _repo.getPageAyahs(1),
      ]);
      final surahs = results[0] as List<Surah>;
      final ayahs = results[1] as List<Ayah>;
      if (surahs.isEmpty) {
        state = const MushafState(
            surahs: [], currentPage: 1, ayahs: [], isLoading: false);
        return;
      }
      state = MushafState(
        surahs: surahs,
        currentPage: 1,
        ayahs: ayahs,
        isLoading: false,
      );
    } catch (_) {
      state = const MushafState(
          surahs: [], currentPage: 1, ayahs: [], isLoading: false);
    }
  }

  Future<void> navigateToPage(int page) async {
    final p = page.clamp(1, kTotalPages);
    state = state.copyWith(isLoading: true);
    try {
      final showTx = state.showTranslation;
      final idx = p - 1;
      final firstId = kPageFirstAyah[idx];
      final lastId = kPageLastAyah[idx];
      final results = await Future.wait<dynamic>([
        _repo.getPageAyahs(p),
        if (showTx)
          _repo.getPageTranslations(firstId, lastId)
        else
          Future<Map<int, String>>.value({}),
      ]);
      state = state.copyWith(
        currentPage: p,
        ayahs: results[0] as List<Ayah>,
        translations: results[1] as Map<int, String>,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Navigate to the page where a surah starts.
  Future<void> navigateToSurah(int surahNumber) async {
    final page = kSurahStartPages[surahNumber - 1];
    await navigateToPage(page);
  }

  /// Navigate to the page where a juz starts.
  Future<void> navigateToJuz(int juzNumber) async {
    final page = kJuzStartPages[juzNumber - 1];
    await navigateToPage(page);
  }

  void nextPage() {
    if (state.currentPage < kTotalPages) {
      navigateToPage(state.currentPage + 1);
    }
  }

  void previousPage() {
    if (state.currentPage > 1) {
      navigateToPage(state.currentPage - 1);
    }
  }

  Future<void> toggleTranslation() async {
    final next = !state.showTranslation;
    if (next && state.ayahs.isNotEmpty) {
      final idx = state.currentPage - 1;
      final firstId = kPageFirstAyah[idx];
      final lastId = kPageLastAyah[idx];
      final translations =
          await _repo.getPageTranslations(firstId, lastId);
      state = state.copyWith(showTranslation: next, translations: translations);
    } else {
      state = state.copyWith(showTranslation: next, translations: {});
    }
  }
}

final mushafProvider =
    NotifierProvider<MushafNotifier, MushafState>(MushafNotifier.new);
