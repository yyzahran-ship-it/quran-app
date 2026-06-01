import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_models.dart';
import 'reciter_provider.dart';

enum AudioStatus { idle, loading, playing, paused }

class AudioPlaybackState {
  const AudioPlaybackState({
    this.status = AudioStatus.idle,
    this.reciter,
    this.surahNumber,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  final AudioStatus status;
  final QuranicReciter? reciter;
  final int? surahNumber; // 1–114
  final Duration position;
  final Duration duration;

  bool get isPlaying => status == AudioStatus.playing;
  bool get isActive => status != AudioStatus.idle;

  AudioPlaybackState copyWith({
    AudioStatus? status,
    QuranicReciter? reciter,
    int? surahNumber,
    Duration? position,
    Duration? duration,
  }) =>
      AudioPlaybackState(
        status: status ?? this.status,
        reciter: reciter ?? this.reciter,
        surahNumber: surahNumber ?? this.surahNumber,
        position: position ?? this.position,
        duration: duration ?? this.duration,
      );
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

  void _onPlayerState(PlayerState ps) {
    if (!mounted) return;
    if (ps.processingState == ProcessingState.completed) {
      state = const AudioPlaybackState();
    } else if (ps.playing) {
      state = state.copyWith(status: AudioStatus.playing);
    } else if (state.status == AudioStatus.playing) {
      state = state.copyWith(status: AudioStatus.paused);
    }
  }

  Future<void> playSurah(int surahNumber, {QuranicReciter? reciter}) async {
    final r = reciter ?? _ref.read(selectedReciterProvider);
    if (r == null) return;

    state = AudioPlaybackState(
      status: AudioStatus.loading,
      reciter: r,
      surahNumber: surahNumber,
    );

    try {
      await _player.setUrl(r.surahAudioUrl(surahNumber));
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
    await _player.stop();
    if (mounted) state = const AudioPlaybackState();
  }

  Future<void> seekTo(Duration position) => _player.seek(position);

  @override
  void dispose() {
    _playerStateSub.cancel();
    _positionSub.cancel();
    _durationSub.cancel();
    _player.dispose();
    super.dispose();
  }
}

final audioProvider =
    StateNotifierProvider<AudioNotifier, AudioPlaybackState>((ref) {
  return AudioNotifier(ref);
});
