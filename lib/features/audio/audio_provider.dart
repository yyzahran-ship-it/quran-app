import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/repositories/quran_repository.dart';
import '../mushaf/mushaf_provider.dart';
import 'audio_repository.dart';

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
  });

  final int? surahNumber;
  final int currentAyahIndex; // 0-based index within current surah
  final int ayahCount;
  final bool isPlaying;
  final bool isLoading;
  final bool hasError;
  final String reciter;

  int? get currentAyahNumber =>
      surahNumber != null ? currentAyahIndex + 1 : null;

  bool get hasAudio => surahNumber != null && ayahCount > 0;

  AudioState copyWith({
    int? surahNumber,
    int? currentAyahIndex,
    int? ayahCount,
    bool? isPlaying,
    bool? isLoading,
    bool? hasError,
    String? reciter,
  }) =>
      AudioState(
        surahNumber: surahNumber ?? this.surahNumber,
        currentAyahIndex: currentAyahIndex ?? this.currentAyahIndex,
        ayahCount: ayahCount ?? this.ayahCount,
        isPlaying: isPlaying ?? this.isPlaying,
        isLoading: isLoading ?? this.isLoading,
        hasError: hasError ?? this.hasError,
        reciter: reciter ?? this.reciter,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AudioNotifier extends Notifier<AudioState> {
  late final AudioPlayer _player;

  @override
  AudioState build() {
    _player = AudioPlayer();

    // Advance to next ayah when current one finishes.
    _player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed) {
        _onAyahComplete();
      }
    });

    ref.onDispose(() => _player.dispose());

    return const AudioState();
  }

  QuranRepository get _repo => ref.read(quranRepositoryProvider);
  AudioRepository get _audioRepo => ref.read(audioRepositoryProvider);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Start playing the surah from a given ayah (1-based). Navigates the
  /// Mushaf reader to the surah as well.
  Future<void> playSurah(int surahNumber, {int startAyah = 1}) async {
    await _player.stop();
    state = state.copyWith(isLoading: true);

    final surah = await _repo.getSurah(surahNumber);
    final count = surah.versesCount;
    final index = (startAyah - 1).clamp(0, count - 1);

    state = AudioState(
      surahNumber: surahNumber,
      currentAyahIndex: index,
      ayahCount: count,
      isLoading: false,
      reciter: state.reciter,
    );

    // Also navigate the reader to this surah.
    ref.read(mushafProvider.notifier).navigateToSurah(surahNumber);

    await _playCurrentAyah();
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

  Future<void> setReciter(String reciterSlug) async {
    final wasPlaying = state.isPlaying;
    await _player.stop();
    state = state.copyWith(reciter: reciterSlug, isPlaying: false);
    if (wasPlaying && state.hasAudio) {
      await _playCurrentAyah();
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _playCurrentAyah() async {
    if (state.surahNumber == null) return;
    final url = _audioRepo.ayahUrl(
      state.surahNumber!,
      state.currentAyahIndex + 1,
      reciter: state.reciter,
    );
    try {
      await _player.setUrl(url);
      await _player.play();
      state = state.copyWith(isPlaying: true, isLoading: false, hasError: false);
    } catch (_) {
      state = state.copyWith(isPlaying: false, isLoading: false, hasError: true);
    }
  }

  Future<void> _seekToAyah(int index) async {
    state = state.copyWith(
      currentAyahIndex: index,
      isPlaying: false,
    );
  }

  void _onAyahComplete() {
    final next = state.currentAyahIndex + 1;
    if (next < state.ayahCount) {
      _seekToAyah(next).then((_) => _playCurrentAyah());
    } else {
      state = state.copyWith(isPlaying: false);
    }
  }
}

final audioProvider = NotifierProvider<AudioNotifier, AudioState>(AudioNotifier.new);
