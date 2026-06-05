import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/constants/app_constants.dart';
import 'audio_models.dart';
import 'reciter_provider.dart';

enum AudioStatus { idle, loading, playing, paused }

class AudioPlaybackState {
  const AudioPlaybackState({
    this.status = AudioStatus.idle,
    this.reciter,
    this.surahNumber,
    this.currentPlayingAyahId,
    this.currentAyahNumber,
    this.verseTracking = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  final AudioStatus status;
  final QuranicReciter? reciter;
  final int? surahNumber;
  // Global ayah ID (1–6236) of the verse currently being played.
  // Non-null only when [verseTracking] is true.
  final int? currentPlayingAyahId;
  // Within-surah ayah number (1-based). Non-null when verseTracking is true.
  final int? currentAyahNumber;
  final bool verseTracking;
  final Duration position;
  final Duration duration;

  bool get isPlaying => status == AudioStatus.playing;
  bool get isActive => status != AudioStatus.idle;

  AudioPlaybackState copyWith({
    AudioStatus? status,
    QuranicReciter? reciter,
    int? surahNumber,
    int? currentPlayingAyahId,
    int? currentAyahNumber,
    bool? verseTracking,
    Duration? position,
    Duration? duration,
  }) =>
      AudioPlaybackState(
        status: status ?? this.status,
        reciter: reciter ?? this.reciter,
        surahNumber: surahNumber ?? this.surahNumber,
        currentPlayingAyahId: currentPlayingAyahId ?? this.currentPlayingAyahId,
        currentAyahNumber: currentAyahNumber ?? this.currentAyahNumber,
        verseTracking: verseTracking ?? this.verseTracking,
        position: position ?? this.position,
        duration: duration ?? this.duration,
      );
}

// Computes the global (1-based) ayah ID for a given surah + ayah.
int globalAyahId(int surahNumber, int ayahNumber) {
  int id = 0;
  for (int i = 0; i < surahNumber - 1; i++) {
    id += kSurahVerseCounts[i];
  }
  return id + ayahNumber;
}

class AudioNotifier extends StateNotifier<AudioPlaybackState> {
  AudioNotifier(this._ref) : super(const AudioPlaybackState()) {
    _playerStateSub = _player.playerStateStream.listen(_onPlayerState);
    _positionSub = _player.positionStream.listen((pos) {
      if (mounted) state = state.copyWith(position: pos);
    });
    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null && mounted) state = state.copyWith(duration: dur);
    });
  }

  final Ref _ref;
  final _player = AudioPlayer();

  late final StreamSubscription<PlayerState> _playerStateSub;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration?> _durationSub;
  StreamSubscription<int?>? _indexSub;

  void _onPlayerState(PlayerState ps) {
    if (!mounted) return;
    if (ps.processingState == ProcessingState.completed) {
      _indexSub?.cancel();
      state = const AudioPlaybackState();
    } else if (ps.playing) {
      state = state.copyWith(status: AudioStatus.playing);
    } else if (state.status == AudioStatus.playing) {
      state = state.copyWith(status: AudioStatus.paused);
    }
  }

  // Plays all verses of [surahNumber] one by one with live ayah tracking.
  // Falls back to full-surah playback if the reciter has no verse files.
  Future<void> playSurah(
    int surahNumber, {
    QuranicReciter? reciter,
    int startAyahNumber = 1,
  }) async {
    final r = reciter ?? _ref.read(selectedReciterProvider);
    if (r == null) return;

    _indexSub?.cancel();
    _indexSub = null;

    state = AudioPlaybackState(
      status: AudioStatus.loading,
      reciter: r,
      surahNumber: surahNumber,
      currentAyahNumber: r.supportsVerseTracking ? startAyahNumber : null,
      currentPlayingAyahId: r.supportsVerseTracking
          ? globalAyahId(surahNumber, startAyahNumber)
          : null,
    );

    if (r.supportsVerseTracking) {
      await _playVerseByVerse(surahNumber, r, startAyah: startAyahNumber);
    } else {
      await _playSurahLevel(surahNumber, r);
    }
  }

  // Starts verse-by-verse playback from [startAyah] (1-based).
  Future<void> _playVerseByVerse(
    int surahNumber,
    QuranicReciter r, {
    int startAyah = 1,
  }) async {
    final verseCount = kSurahVerseCounts[surahNumber - 1];
    final clampedStart = startAyah.clamp(1, verseCount);
    final sources = List.generate(verseCount, (i) {
      final ayahNum = i + 1;
      final gId = globalAyahId(surahNumber, ayahNum);
      return AudioSource.uri(Uri.parse(
          r.verseAudioUrl(gId, surahNumber: surahNumber, ayahNumber: ayahNum)));
    });

    try {
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        initialIndex: clampedStart - 1,
      );

      // Track which verse index is playing → map to global ayah ID and local number.
      _indexSub = _player.currentIndexStream.listen((idx) {
        if (!mounted || idx == null) return;
        final ayahNum = idx + 1;
        if (ayahNum > verseCount) return;
        state = state.copyWith(
          currentAyahNumber: ayahNum,
          currentPlayingAyahId: globalAyahId(surahNumber, ayahNum),
          verseTracking: true,
        );
      });

      state = state.copyWith(
        verseTracking: true,
        currentAyahNumber: clampedStart,
        currentPlayingAyahId: globalAyahId(surahNumber, clampedStart),
      );
      await _player.play();
    } catch (_) {
      // Verse files unavailable — fall back to surah-level.
      _indexSub?.cancel();
      _indexSub = null;
      await _playSurahLevel(surahNumber, r);
    }
  }

  // Starts playback of a specific ayah within the currently-loaded playlist.
  // Call [playSurah] first to load the surah; this jumps to [ayahNumber].
  Future<void> playAyah(
    int surahNumber,
    int ayahNumber, {
    required QuranicReciter reciter,
  }) async {
    if (state.surahNumber == surahNumber &&
        state.reciter?.id == reciter.id &&
        state.verseTracking) {
      // Playlist already loaded for this surah — just seek.
      await _player.seek(Duration.zero, index: ayahNumber - 1);
      if (!state.isPlaying) await _player.play();
    } else {
      await playSurah(surahNumber, reciter: reciter, startAyahNumber: ayahNumber);
    }
  }

  Future<void> nextAyah() async {
    if (state.surahNumber == null || !state.verseTracking) return;
    final verseCount = kSurahVerseCounts[state.surahNumber! - 1];
    final currentIdx = _player.currentIndex ?? 0;
    if (currentIdx + 1 < verseCount) {
      await _player.seek(Duration.zero, index: currentIdx + 1);
    }
  }

  Future<void> previousAyah() async {
    if (!state.verseTracking) return;
    final currentIdx = _player.currentIndex ?? 0;
    if (currentIdx > 0) {
      await _player.seek(Duration.zero, index: currentIdx - 1);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  Future<void> _playSurahLevel(int surahNumber, QuranicReciter r) async {
    try {
      await _player.setUrl(r.surahAudioUrl(surahNumber));
      state = state.copyWith(verseTracking: false, currentPlayingAyahId: null);
      await _player.play();
    } catch (_) {
      if (mounted) state = const AudioPlaybackState();
    }
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await _player.pause();
    } else if (state.status == AudioStatus.paused) {
      await _player.play();
    }
  }

  Future<void> stop() async {
    _indexSub?.cancel();
    _indexSub = null;
    await _player.stop();
    if (mounted) state = const AudioPlaybackState();
  }

  Future<void> seekTo(Duration position) => _player.seek(position);

  @override
  void dispose() {
    _playerStateSub.cancel();
    _positionSub.cancel();
    _durationSub.cancel();
    _indexSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}

final audioProvider =
    StateNotifierProvider<AudioNotifier, AudioPlaybackState>((ref) {
  return AudioNotifier(ref);
});
