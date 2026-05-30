import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/quran_repository.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/surah.dart';

// Human-readable names for each bundled translation key.
const kTranslationNames = <String, String>{
  'en_sahih': 'Sahih International (English)',
  'ur_jalandhry': 'Jalandhry (Urdu)',
  'id_indonesian': 'Kemenag (Indonesian)',
};

// ─── State ────────────────────────────────────────────────────────────────────

class MushafState {
  const MushafState({
    required this.surahs,
    required this.currentPage,
    required this.ayahs,
    this.translations = const {},
    this.showTranslation = false,
    this.activeTranslationKey = 'en_sahih',
    this.availableTranslationKeys = const ['en_sahih'],
    this.isLoading = false,
  });

  final List<Surah> surahs;        // all 114 — for title lookups and navigation
  final int currentPage;           // 1–604 (Madinah Mushaf)
  final List<Ayah> ayahs;          // ayahs on currentPage (may span surahs)
  final Map<int, String> translations; // ayahId → text
  final bool showTranslation;
  final String activeTranslationKey;
  final List<String> availableTranslationKeys;
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
    String? activeTranslationKey,
    List<String>? availableTranslationKeys,
    bool? isLoading,
  }) =>
      MushafState(
        surahs: surahs ?? this.surahs,
        currentPage: currentPage ?? this.currentPage,
        ayahs: ayahs ?? this.ayahs,
        translations: translations ?? this.translations,
        showTranslation: showTranslation ?? this.showTranslation,
        activeTranslationKey: activeTranslationKey ?? this.activeTranslationKey,
        availableTranslationKeys:
            availableTranslationKeys ?? this.availableTranslationKeys,
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

  static const _txKeyPref = 'active_translation_key';

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString(_txKeyPref) ?? 'en_sahih';

      final results = await Future.wait<dynamic>([
        _repo.getAllSurahs(),
        _repo.getPageAyahs(1),
        _repo.getAvailableTranslationKeys(),
      ]);
      final surahs = results[0] as List<Surah>;
      final ayahs = results[1] as List<Ayah>;
      final available = results[2] as List<String>;

      // Fall back to en_sahih if saved key was removed from DB.
      final activeKey =
          available.contains(savedKey) ? savedKey : 'en_sahih';

      if (surahs.isEmpty) {
        state = const MushafState(
            surahs: [], currentPage: 1, ayahs: [], isLoading: false);
        return;
      }
      state = MushafState(
        surahs: surahs,
        currentPage: 1,
        ayahs: ayahs,
        activeTranslationKey: activeKey,
        availableTranslationKeys: available,
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
          _repo.getPageTranslations(firstId, lastId,
              translationKey: state.activeTranslationKey)
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

  /// Navigate to the page containing a specific ayah.
  Future<void> navigateToAyah(int surahNumber, int ayahNumber) async {
    int globalId = 1;
    for (int i = 0; i < surahNumber - 1; i++) {
      globalId += kSurahVerseCounts[i];
    }
    globalId += ayahNumber - 1;
    if (globalId < 1 || globalId > kTotalAyahs) return;
    await navigateToPage(kAyahPages[globalId - 1]);
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

  Future<void> setTranslationKey(String key) async {
    if (!state.availableTranslationKeys.contains(key)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_txKeyPref, key);
    if (state.showTranslation && state.ayahs.isNotEmpty) {
      final idx = state.currentPage - 1;
      final firstId = kPageFirstAyah[idx];
      final lastId = kPageLastAyah[idx];
      final translations = await _repo.getPageTranslations(firstId, lastId,
          translationKey: key);
      state = state.copyWith(
          activeTranslationKey: key, translations: translations);
    } else {
      state = state.copyWith(activeTranslationKey: key);
    }
  }

  Future<void> toggleTranslation() async {
    final next = !state.showTranslation;
    if (next && state.ayahs.isNotEmpty) {
      final idx = state.currentPage - 1;
      final firstId = kPageFirstAyah[idx];
      final lastId = kPageLastAyah[idx];
      final translations = await _repo.getPageTranslations(firstId, lastId,
          translationKey: state.activeTranslationKey);
      state = state.copyWith(showTranslation: next, translations: translations);
    } else {
      state = state.copyWith(showTranslation: next, translations: {});
    }
  }
}

final mushafProvider =
    NotifierProvider<MushafNotifier, MushafState>(MushafNotifier.new);

// Visibility of the reciter strip at the bottom of the Mushaf screen.
// Any widget with ref access can toggle it — tap blank page to hide/show.
final reciterStripVisibleProvider = StateProvider<bool>((_) => true);

