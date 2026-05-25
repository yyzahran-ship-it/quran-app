import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/quran_repository.dart';
import '../mushaf/mushaf_provider.dart';
import 'audio_repository.dart';
import 'quran_foundation_repository.dart';

const _kReciterPrefKey = 'selected_reciter';

// ─── State ────────────────────────────────────────────────────────────────────

class AudioState {
  const AudioState({
    this.surahNumber,
    this.currentAyahIndex = 0,
    this.ayahCount = 0,
    this.isPlaying = false,
    this.isLoading = false,
    this.hasError = false,
    this.reciter = AudioRepository.defaultReciter,
    this.speed = 1.0,
    this.loopStart,
    this.loopEnd,
  });

  final int? surahNumber;
  final int currentAyahIndex; // 0-based index within current surah
  final int ayahCount;
  final bool isPlaying;
  final bool isLoading;
  final bool hasError;
  final String reciter;
  final double speed;
  final int? loopStart; // 0-based; A point of A-B repeat
  final int? loopEnd; // 0-based; B point of A-B repeat

  int? get currentAyahNumber =>
      surahNumber != null ? currentAyahIndex + 1 : null;

  bool get hasAudio => surahNumber != null && ayahCount > 0;

  // A is set, waiting for B.
  bool get loopASet => loopStart != null && loopEnd == null;

  // Both A and B are set — loop is running.
  bool get loopActive => loopStart != null && loopEnd != null;

  // Reciter slugs starting with "qf_" come from the Quran Foundation API.
  bool get isQFReciter => reciter.startsWith('qf_');
  int? get qfRecitationId =>
      isQFReciter ? int.tryParse(reciter.substring(3)) : null;

  AudioState copyWith({
    int? surahNumber,
    int? currentAyahIndex,
    int? ayahCount,
    bool? isPlaying,
    bool? isLoading,
    bool? hasError,
    String? reciter,
    double? speed,
    // Pass clearLoop: true to reset both loop points to null.
    bool clearLoop = false,
    int? loopStart,
    int? loopEnd,
  }) =>
      AudioState(
        surahNumber: surahNumber ?? this.surahNumber,
        currentAyahIndex: currentAyahIndex ?? this.currentAyahIndex,
        ayahCount: ayahCount ?? this.ayahCount,
        isPlaying: isPlaying ?? this.isPlaying,
        isLoading: isLoading ?? this.isLoading,
        hasError: hasError ?? this.hasError,
        reciter: reciter ?? this.reciter,
        speed: speed ?? this.speed,
        loopStart: clearLoop ? null : (loopStart ?? this.loopStart),
        loopEnd: clearLoop ? null : (loopEnd ?? this.loopEnd),
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AudioNotifier extends Notifier<AudioState> {
  late final AudioPlayer _player;

  @override
  AudioState build() {
    _player = AudioPlayer();

    // Advance to next ayah (or loop back to A) when the current one finishes.
    _player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed) {
        _onAyahComplete();
      }
    });

    ref.onDispose(() => _player.dispose());

    // Load persisted reciter asynchronously; update state once ready.
    _loadSavedReciter();

    return const AudioState();
  }

  Future<void> _loadSavedReciter() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kReciterPrefKey);
    if (saved != null && saved.isNotEmpty) {
      state = state.copyWith(reciter: saved);
    }
  }

  QuranRepository get _repo => ref.read(quranRepositoryProvider);
  AudioRepository get _audioRepo => ref.read(audioRepositoryProvider);
  QuranFoundationRepository get _qfRepo => ref.read(qfRepositoryProvider);

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> playSurah(int surahNumber, {int startAyah = 1}) async {
    await _player.stop();
    state = state.copyWith(isLoading: true);

    try {
      final surah = await _repo.getSurah(surahNumber);
      final count = surah.versesCount;
      final index = (startAyah - 1).clamp(0, count - 1);

      state = AudioState(
        surahNumber: surahNumber,
        currentAyahIndex: index,
        ayahCount: count,
        isLoading: false,
        reciter: state.reciter,
        speed: state.speed,
      );

      ref.read(mushafProvider.notifier).navigateToSurah(surahNumber);
      await _playCurrentAyah();
    } catch (_) {
      state = state.copyWith(isLoading: false, hasError: true);
    }
  }

  Future<void> playAyah(int surahNumber, int ayahNumber) async {
    if (state.surahNumber != surahNumber) {
      await playSurah(surahNumber, startAyah: ayahNumber);
    } else {
      await _seekToAyah(ayahNumber - 1);
      await _playCurrentAyah();
    }
  }

  Future<void> togglePlayPause() async {
    if (!state.hasAudio) return;
    if (state.isPlaying) {
      await _player.pause();
      state = state.copyWith(isPlaying: false);
    } else {
      await _playCurrentAyah();
    }
  }

  Future<void> nextAyah() async {
    if (!state.hasAudio) return;
    final next = state.currentAyahIndex + 1;
    if (next < state.ayahCount) {
      await _seekToAyah(next);
      await _playCurrentAyah();
    }
  }

  Future<void> previousAyah() async {
    if (!state.hasAudio) return;
    final prev = state.currentAyahIndex - 1;
    if (prev >= 0) {
      await _seekToAyah(prev);
      await _playCurrentAyah();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    state = const AudioState();
  }

  /// Retry the current ayah after a network error.
  Future<void> retryCurrentAyah() async {
    if (!state.hasAudio) return;
    state = state.copyWith(isLoading: true, hasError: false);
    await _playCurrentAyah();
  }

  Future<void> setReciter(String reciterSlug) async {
    final wasPlaying = state.isPlaying;
    await _player.stop();
    state = state.copyWith(reciter: reciterSlug, isPlaying: false);
    // Persist selection so it survives app restarts.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kReciterPrefKey, reciterSlug);
    if (wasPlaying && state.hasAudio) {
      await _playCurrentAyah();
    }
  }

  /// Cycle through 0.75 → 1.0 → 1.25 → 1.5 → 0.75…
  Future<void> cycleSpeed() async {
    const steps = [0.75, 1.0, 1.25, 1.5];
    final idx = steps.indexWhere((s) => (s - state.speed).abs() < 0.01);
    final next = steps[(idx + 1) % steps.length];
    state = state.copyWith(speed: next);
    await _player.setSpeed(next);
  }

  /// Three-tap A-B loop cycle:
  ///   No loop → set A → set B (loop active) → clear
  void tapLoopButton() {
    if (state.loopActive) {
      state = state.copyWith(clearLoop: true);
    } else if (state.loopASet) {
      final b = state.currentAyahIndex;
      final a = state.loopStart!;
      state = a <= b
          ? state.copyWith(loopEnd: b)
          : state.copyWith(loopStart: b, loopEnd: a);
    } else {
      state = state.copyWith(loopStart: state.currentAyahIndex);
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _playCurrentAyah() async {
    if (state.surahNumber == null) return;
    final surah      = state.surahNumber!;
    final ayahNumber = state.currentAyahIndex + 1;

    state = state.copyWith(isLoading: true, hasError: false);

    // ── Path A: Quran Foundation API (slug starts with "qf_") ──────────────
    // Fetches all ayah URLs for the surah in one API call (cached after first
    // request), then plays the exact URL returned — no folder-guessing.
    final qfId = state.qfRecitationId;
    if (qfId != null) {
      try {
        final urls = await _qfRepo.fetchSurahAudio(qfId, surah);
        final url  = urls[ayahNumber];
        if (url != null) {
          try {
            await _player.setUrl(url);
            await _player.setSpeed(state.speed);
            await _player.play();
            state = state.copyWith(
                isPlaying: true, isLoading: false, hasError: false);
            return;
          } catch (_) {
            // CDN request failed even though we got the URL — fall through.
          }
        }
      } catch (_) {
        // API call failed (offline / rate-limited).
      }
      state = state.copyWith(isPlaying: false, isLoading: false, hasError: true);
      return;
    }

    // ── Path B: everyayah CDN chain (hardcoded reciters) ───────────────────
    // Compute global ayah ID (1-indexed, 1-6236) for cdn.islamic.network.
    int globalId = 0;
    for (int i = 0; i < surah - 1; i++) {
      globalId += kSurahVerseCounts[i];
    }
    globalId += ayahNumber;

    // CDNs tried in order — first success wins.
    final candidates = [
      _audioRepo.ayahUrlIslamicNet(globalId, reciter: state.reciter),
      _audioRepo.ayahUrlMirrors(surah, ayahNumber, reciter: state.reciter),
      _audioRepo.ayahUrlDownloadQa(surah, ayahNumber, reciter: state.reciter),
      _audioRepo.ayahFallbackUrl(surah, ayahNumber, reciter: state.reciter),
      _audioRepo.ayahUrl(surah, ayahNumber, reciter: state.reciter),
      ..._audioRepo.ayahUrlsVersesQf(surah, ayahNumber, reciter: state.reciter),
    ];

    bool loaded = false;
    for (final url in candidates) {
      if (loaded) break;
      if (url == null) continue;
      try {
        await _player.setUrl(url);
        loaded = true;
      } catch (_) {}
    }

    if (!loaded) {
      state = state.copyWith(isPlaying: false, isLoading: false, hasError: true);
      return;
    }

    try {
      await _player.setSpeed(state.speed);
      await _player.play();
      state = state.copyWith(isPlaying: true, isLoading: false, hasError: false);
    } catch (_) {
      state = state.copyWith(isPlaying: false, isLoading: false, hasError: true);
    }
  }

  Future<void> _seekToAyah(int index) async {
    state = state.copyWith(currentAyahIndex: index, isPlaying: false);
  }

  void _onAyahComplete() {
    if (state.loopActive) {
      if (state.currentAyahIndex >= state.loopEnd!) {
        _seekToAyah(state.loopStart!).then((_) => _playCurrentAyah());
        return;
      }
    }
    final next = state.currentAyahIndex + 1;
    if (next < state.ayahCount) {
      _seekToAyah(next).then((_) => _playCurrentAyah());
    } else {
      state = state.copyWith(isPlaying: false);
    }
  }
}

final audioProvider =
    NotifierProvider<AudioNotifier, AudioState>(AudioNotifier.new);
