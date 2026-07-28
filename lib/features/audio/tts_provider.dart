import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsStatus { idle, speaking }

class TtsPlaybackState {
  const TtsPlaybackState({
    this.status = TtsStatus.idle,
    this.surahNumber,
    this.currentAyahNumber,
    this.currentWordIndex = -1,
  });

  final TtsStatus status;
  final int? surahNumber;
  final int? currentAyahNumber;
  // 0-based index of the word currently being spoken (-1 = none).
  final int currentWordIndex;

  bool get isSpeaking => status == TtsStatus.speaking;
  bool get isActive   => status != TtsStatus.idle;

  TtsPlaybackState copyWith({
    TtsStatus? status,
    int? surahNumber,
    int? currentAyahNumber,
    int? currentWordIndex,
  }) =>
      TtsPlaybackState(
        status:            status            ?? this.status,
        surahNumber:       surahNumber       ?? this.surahNumber,
        currentAyahNumber: currentAyahNumber ?? this.currentAyahNumber,
        currentWordIndex:  currentWordIndex  ?? this.currentWordIndex,
      );
}

class TtsNotifier extends StateNotifier<TtsPlaybackState> {
  TtsNotifier() : super(const TtsPlaybackState()) {
    _init();
  }

  final _tts = FlutterTts();
  String? _currentText;

  Future<void> _init() async {
    await _tts.setLanguage('ar-SA');
    await _tts.setSpeechRate(0.85);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(false);

    _tts.setCompletionHandler(() {
      if (mounted) state = state.copyWith(status: TtsStatus.idle, currentWordIndex: -1);
    });

    // Word-level progress: count words before startOffset to get 0-based index.
    _tts.setProgressHandler((text, startOffset, endOffset, word) {
      if (!mounted || _currentText == null) return;
      final n = _currentText!
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      final before = text.substring(0, startOffset);
      final idx = before.trim().isEmpty
          ? 0
          : before.trim().split(RegExp(r'\s+')).length;
      state = state.copyWith(currentWordIndex: idx.clamp(0, n - 1));
    });

    _tts.setErrorHandler((_) {
      if (mounted) state = const TtsPlaybackState();
    });
  }

  Future<void> speakAyah(int surahNumber, int ayahNumber, String text) async {
    await _tts.stop();
    if (!mounted) return;
    _currentText = text;
    state = TtsPlaybackState(
      status: TtsStatus.speaking,
      surahNumber: surahNumber,
      currentAyahNumber: ayahNumber,
    );
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _currentText = null;
    if (mounted) state = const TtsPlaybackState();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}

final ttsProvider =
    StateNotifierProvider<TtsNotifier, TtsPlaybackState>((ref) {
  return TtsNotifier();
});

// When true, tapping an ayah badge speaks via TTS instead of the streaming reciter.
final ttsEnabledProvider = StateProvider<bool>((ref) => false);
