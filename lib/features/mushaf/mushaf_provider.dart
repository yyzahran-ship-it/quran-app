import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/quran_repository.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/surah.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class MushafState {
  const MushafState({
    required this.surahs,
    required this.currentSurah,
    required this.ayahs,
    this.translations = const {},
    this.showTranslation = false,
    this.isLoading = false,
  });

  final List<Surah> surahs;           // all 114 — for the index drawer
  final Surah? currentSurah;
  final List<Ayah> ayahs;             // ayahs for currentSurah
  final Map<int, String> translations; // ayahId → translation text
  final bool showTranslation;
  final bool isLoading;

  MushafState copyWith({
    List<Surah>? surahs,
    Surah? currentSurah,
    List<Ayah>? ayahs,
    Map<int, String>? translations,
    bool? showTranslation,
    bool? isLoading,
  }) =>
      MushafState(
        surahs: surahs ?? this.surahs,
        currentSurah: currentSurah ?? this.currentSurah,
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
    // Start loading Al-Fatihah (surah 1) immediately.
    Future.microtask(() => _init());
    return const MushafState(surahs: [], currentSurah: null, ayahs: [], isLoading: true);
  }

  QuranRepository get _repo => ref.read(quranRepositoryProvider);

  Future<void> _init() async {
    try {
      // Load surah list and first surah's ayahs in parallel.
      final results = await Future.wait<dynamic>([
        _repo.getAllSurahs(),
        _repo.getSurahAyahs(1),
      ]);
      final surahs = results[0] as List<Surah>;
      final ayahs = results[1] as List<Ayah>;
      state = MushafState(
        surahs: surahs,
        currentSurah: surahs.isEmpty ? null : surahs.first,
        ayahs: ayahs,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> navigateToSurah(int surahNumber) async {
    state = state.copyWith(isLoading: true);
    // Load surah metadata, ayahs, and (if visible) translations in parallel.
    final results = await Future.wait<dynamic>([
      _repo.getSurah(surahNumber),
      _repo.getSurahAyahs(surahNumber),
      if (state.showTranslation)
        _repo.getSurahTranslations(surahNumber)
      else
        Future<Map<int, String>>.value({}),
    ]);
    state = state.copyWith(
      currentSurah: results[0] as Surah,
      ayahs: results[1] as List<Ayah>,
      translations: results[2] as Map<int, String>,
      isLoading: false,
    );
  }

  Future<void> toggleTranslation() async {
    final next = !state.showTranslation;
    if (next && state.currentSurah != null) {
      final translations =
          await _repo.getSurahTranslations(state.currentSurah!.id);
      state = state.copyWith(showTranslation: next, translations: translations);
    } else {
      state = state.copyWith(showTranslation: next, translations: {});
    }
  }

  Future<void> navigateToJuz(int juzNumber) async {
    state = state.copyWith(isLoading: true);
    final juz = await _repo.getJuz(juzNumber);
    final surahNumber = await _repo.getSurahNumberForVerseId(juz.firstVerseId);
    await navigateToSurah(surahNumber);
  }

  void nextSurah() {
    final current = state.currentSurah;
    if (current != null && current.id < 114) {
      navigateToSurah(current.id + 1);
    }
  }

  void previousSurah() {
    final current = state.currentSurah;
    if (current != null && current.id > 1) {
      navigateToSurah(current.id - 1);
    }
  }
}

final mushafProvider = NotifierProvider<MushafNotifier, MushafState>(MushafNotifier.new);
