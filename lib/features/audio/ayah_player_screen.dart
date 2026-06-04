import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/quran_repository.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/surah.dart';
import 'audio_models.dart';
import 'audio_provider.dart';
import 'reciter_provider.dart';
import 'tts_provider.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _surahAyahsProvider =
    FutureProvider.family<List<Ayah>, int>((ref, surahNumber) {
  return ref.read(quranRepositoryProvider).getSurahAyahs(surahNumber);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class AyahPlayerScreen extends ConsumerStatefulWidget {
  const AyahPlayerScreen({super.key, required this.surah});

  final Surah surah;

  @override
  ConsumerState<AyahPlayerScreen> createState() => _AyahPlayerScreenState();
}

class _AyahPlayerScreenState extends ConsumerState<AyahPlayerScreen> {
  final _scrollController = ScrollController();
  final Map<int, GlobalKey> _keys = {};
  int? _lastScrolledAyah;

  // ValueNotifier fed from audioProvider after each frame.
  // _AyahRow uses ValueListenableBuilder on this notifier so that row shading
  // fires even when ListView.builder's element reconciliation skips the row.
  late final ValueNotifier<AudioPlaybackState> _audioNotifier;
  late final ValueNotifier<TtsPlaybackState>   _ttsNotifier;

  @override
  void initState() {
    super.initState();
    // Initialise with current provider values so any in-flight playback is
    // immediately reflected (e.g. user navigated here while audio was playing).
    _audioNotifier = ValueNotifier(ref.read(audioProvider));
    _ttsNotifier   = ValueNotifier(ref.read(ttsProvider));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _audioNotifier.dispose();
    _ttsNotifier.dispose();
    super.dispose();
  }

  void _scrollToAyah(int ayahNumber) {
    if (ayahNumber == _lastScrolledAyah) return;
    _lastScrolledAyah = ayahNumber;
    final key = _keys[ayahNumber];
    if (key?.currentContext == null) return;
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.3,
    );
  }

  void _ttsSpeakNextAfter(int? completedAyahNumber) {
    if (completedAyahNumber == null) return;
    final ayahs =
        ref.read(_surahAyahsProvider(widget.surah.id)).valueOrNull;
    if (ayahs == null) return;
    final idx = ayahs.indexWhere((a) => a.ayahNumber == completedAyahNumber);
    if (idx >= 0 && idx + 1 < ayahs.length) {
      final next = ayahs[idx + 1];
      ref.read(ttsProvider.notifier).speakAyah(
        widget.surah.id, next.ayahNumber, next.textUthmani,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ayahsAsync = ref.watch(_surahAyahsProvider(widget.surah.id));
    final audioState = ref.watch(audioProvider);
    final ttsState   = ref.watch(ttsProvider);
    final ttsEnabled = ref.watch(ttsEnabledProvider);
    final reciter    = ref.watch(selectedReciterProvider);

    // Push every provider-state change into the ValueNotifiers immediately
    // (before any frame renders). ref.listen fires synchronously during
    // Riverpod's notification phase — faster than addPostFrameCallback and
    // catches rapid idle→loading→idle transitions that span a single frame.
    ref.listen<AudioPlaybackState>(audioProvider, (_, next) {
      _audioNotifier.value = next;
    });
    ref.listen<TtsPlaybackState>(ttsProvider, (_, next) {
      _ttsNotifier.value = next;
    });

    // Auto-scroll to the currently-playing ayah.
    final currentAyah = audioState.surahNumber == widget.surah.id
        ? audioState.currentAyahNumber
        : ttsState.surahNumber == widget.surah.id
            ? ttsState.currentAyahNumber
            : null;
    if (currentAyah != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToAyah(currentAyah);
      });
    }

    // TTS auto-advance.
    ref.listen<TtsPlaybackState>(ttsProvider, (prev, curr) {
      if (!ref.read(ttsEnabledProvider)) return;
      if (prev?.isSpeaking == true && curr.status == TtsStatus.idle) {
        _ttsSpeakNextAfter(prev!.currentAyahNumber);
      }
    });

    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.surah.nameSimple,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            Text(
              widget.surah.nameArabic,
              style: TextStyle(
                fontSize: 13,
                fontFamily: kArabicFont,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [_ReciterButton(surah: widget.surah)],
      ),
      body: Column(
        children: [
          _TtsBanner(surah: widget.surah),
          Expanded(
            child: ayahsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('Error loading ayahs: $err')),
              data: (ayahs) => _AyahList(
                surah: widget.surah,
                ayahs: ayahs,
                reciter: reciter,
                scrollController: _scrollController,
                keys: _keys,
                audioNotifier: _audioNotifier,
                ttsNotifier: _ttsNotifier,
              ),
            ),
          ),
          _PlayerBar(surah: widget.surah, reciter: reciter),
        ],
      ),
    );
  }
}

// ── TTS banner ────────────────────────────────────────────────────────────────

class _TtsBanner extends ConsumerWidget {
  const _TtsBanner({required this.surah});

  final Surah surah;

  static const _kGreen = Color(0xFF34A853);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsEnabled = ref.watch(ttsEnabledProvider);
    final ttsState   = ref.watch(ttsProvider);

    final speakingThis =
        ttsState.surahNumber == surah.id && ttsState.isSpeaking;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: ttsEnabled
          ? const Color(0xFFE8F5E9)
          : const Color(0xFFF5F5F5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          Icon(Icons.record_voice_over_rounded,
              size: 16,
              color: ttsEnabled ? _kGreen : Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ttsEnabled
                  ? speakingThis
                      ? 'Speaking ayah ${ttsState.currentAyahNumber}…'
                      : 'TTS mode — tap any ayah to speak'
                  : 'TTS mode — off',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    ttsEnabled ? const Color(0xFF2E7D32) : Colors.grey,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              final enabled = ref.read(ttsEnabledProvider);
              if (enabled) {
                ref.read(ttsProvider.notifier).stop();
              } else {
                ref.read(audioProvider.notifier).stop();
              }
              ref.read(ttsEnabledProvider.notifier).state = !enabled;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: ttsEnabled
                    ? _kGreen
                    : Colors.grey.shade400,
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: ttsEnabled
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 2)
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ayah list ─────────────────────────────────────────────────────────────────

class _AyahList extends StatelessWidget {
  const _AyahList({
    required this.surah,
    required this.ayahs,
    required this.reciter,
    required this.scrollController,
    required this.keys,
    required this.audioNotifier,
    required this.ttsNotifier,
  });

  final Surah surah;
  final List<Ayah> ayahs;
  final QuranicReciter? reciter;
  final ScrollController scrollController;
  final Map<int, GlobalKey> keys;
  final ValueNotifier<AudioPlaybackState> audioNotifier;
  final ValueNotifier<TtsPlaybackState>   ttsNotifier;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      itemCount: ayahs.length,
      padding: const EdgeInsets.only(bottom: 8),
      itemBuilder: (context, i) {
        final ayah = ayahs[i];
        keys.putIfAbsent(ayah.ayahNumber, GlobalKey.new);
        return _AyahRow(
          key: keys[ayah.ayahNumber],
          ayah: ayah,
          reciter: reciter,
          surah: surah,
          audioNotifier: audioNotifier,
          ttsNotifier: ttsNotifier,
        );
      },
    );
  }
}

// ── Ayah row ──────────────────────────────────────────────────────────────────

// Row shading is driven by ValueListenableBuilder on audioNotifier/ttsNotifier.
// These notifiers are updated from _AyahPlayerScreenState after each frame,
// so they fire independently of ListView's element-reconciliation pass —
// fixing the bug where GlobalKey rows were not being rebuilt by Riverpod.
class _AyahRow extends ConsumerWidget {
  const _AyahRow({
    super.key,
    required this.ayah,
    required this.reciter,
    required this.surah,
    required this.audioNotifier,
    required this.ttsNotifier,
  });

  final Ayah ayah;
  final QuranicReciter? reciter;
  final Surah surah;
  final ValueNotifier<AudioPlaybackState> audioNotifier;
  final ValueNotifier<TtsPlaybackState>   ttsNotifier;

  static const _kGreen   = Color(0xFF34A853);
  static const _kGreenBg = Color(0xFFE6F4EA);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors     = Theme.of(context).colorScheme;
    final ttsEnabled = ref.watch(ttsEnabledProvider);

    return ValueListenableBuilder<AudioPlaybackState>(
      valueListenable: audioNotifier,
      builder: (context, audio, _) {
        return ValueListenableBuilder<TtsPlaybackState>(
          valueListenable: ttsNotifier,
          builder: (context, tts, _) {
            final isAudioActive = audio.surahNumber == surah.id &&
                audio.currentAyahNumber == ayah.ayahNumber &&
                audio.isActive;
            final isAudioPlaying = audio.surahNumber == surah.id &&
                audio.currentAyahNumber == ayah.ayahNumber &&
                audio.isPlaying;
            final isTtsSpeaking = tts.surahNumber == surah.id &&
                tts.currentAyahNumber == ayah.ayahNumber &&
                tts.isSpeaking;

            final isActive  = isAudioActive || isTtsSpeaking;
            final isPlaying = isAudioPlaying;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: isActive
                  ? const BoxDecoration(
                      color: _kGreenBg,
                      border: Border(
                          left: BorderSide(color: _kGreen, width: 3)),
                    )
                  : const BoxDecoration(),
              child: Padding(
                padding:
                    EdgeInsets.fromLTRB(isActive ? 13 : 16, 10, 16, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (ttsEnabled) {
                          ref.read(ttsProvider.notifier).speakAyah(
                            surah.id,
                            ayah.ayahNumber,
                            ayah.textUthmani,
                          );
                        } else {
                          if (reciter == null) return;
                          if (!reciter!.supportsVerseTracking) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'This reciter only supports full-surah '
                                  'playback. Choose a reciter with verse '
                                  'tracking.',
                                ),
                              ),
                            );
                            return;
                          }
                          ref.read(audioProvider.notifier).playAyah(
                            surah.id,
                            ayah.ayahNumber,
                            reciter: reciter!,
                          );
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? _kGreen
                              : colors.surfaceContainerHighest,
                        ),
                        child: Center(
                          child: isTtsSpeaking
                              ? const _WaveformIcon()
                              : isPlaying
                                  ? const Icon(Icons.pause,
                                      size: 18, color: Colors.white)
                                  : isActive
                                      ? const Icon(Icons.play_arrow,
                                          size: 18, color: Colors.white)
                                      : Text(
                                          '${ayah.ayahNumber}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                colors.onSurfaceVariant,
                                          ),
                                        ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _WordDisplay(ayah: ayah, surah: surah),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Waveform animation ────────────────────────────────────────────────────────

class _WaveformIcon extends StatefulWidget {
  const _WaveformIcon();

  @override
  State<_WaveformIcon> createState() => _WaveformIconState();
}

class _WaveformIconState extends State<_WaveformIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _bar(t, 0.0, 4.0, 9.0),
            const SizedBox(width: 2),
            _bar(t, 0.2, 7.0, 15.0),
            const SizedBox(width: 2),
            _bar(t, 0.4, 4.0, 9.0),
          ],
        );
      },
    );
  }

  Widget _bar(double t, double offset, double min, double max) {
    final v = (t + offset) % 1.0;
    final h = min + (max - min) * (v < 0.5 ? v * 2 : (1 - v) * 2);
    return Container(
      width: 3,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ── Word-by-word display ──────────────────────────────────────────────────────

class _WordDisplay extends ConsumerWidget {
  const _WordDisplay({required this.ayah, required this.surah});

  final Ayah ayah;
  final Surah surah;

  static const _kGreen  = Color(0xFF34A853);
  static const _kSpoken = Color(0xFF8D6E1A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    final tts   = ref.watch(ttsProvider);

    final words = ayah.textUthmani
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final n = words.length;

    final isAudioAyah = audio.surahNumber == surah.id &&
        audio.currentAyahNumber == ayah.ayahNumber &&
        audio.isActive;
    final isTtsAyah = tts.surahNumber == surah.id &&
        tts.currentAyahNumber == ayah.ayahNumber &&
        tts.isActive;

    int activeIdx;
    if (isTtsAyah) {
      activeIdx = tts.currentWordIndex.clamp(-1, n - 1);
    } else if (isAudioAyah && audio.duration != Duration.zero) {
      activeIdx = (audio.position.inMilliseconds /
              audio.duration.inMilliseconds *
              n)
          .floor()
          .clamp(0, n - 1);
    } else {
      activeIdx = -1;
    }

    final baseStyle = TextStyle(
      fontFamily: kArabicFont,
      fontSize: 22,
      height: 1.8,
      color: Theme.of(context)
          .colorScheme
          .onSurface
          .withValues(alpha: 0.85),
    );

    return Wrap(
      alignment: WrapAlignment.end,
      textDirection: TextDirection.rtl,
      spacing: 6,
      runSpacing: 0,
      children: List.generate(n, (i) {
        final isActive = i == activeIdx;
        final isSpoken = activeIdx >= 0 && i < activeIdx;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: isActive ? 6 : 0,
            vertical: isActive ? 2 : 0,
          ),
          decoration: isActive
              ? BoxDecoration(
                  color: _kGreen,
                  borderRadius: BorderRadius.circular(6),
                )
              : null,
          child: Text(
            words[i],
            textDirection: TextDirection.rtl,
            style: baseStyle.copyWith(
              color:
                  isActive ? Colors.white : isSpoken ? _kSpoken : null,
            ),
          ),
        );
      }),
    );
  }
}

// ── Player control bar ────────────────────────────────────────────────────────

class _PlayerBar extends ConsumerWidget {
  const _PlayerBar({required this.surah, required this.reciter});

  final Surah surah;
  final QuranicReciter? reciter;

  static const _kGreen = Color(0xFF34A853);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio      = ref.watch(audioProvider);
    final tts        = ref.watch(ttsProvider);
    final ttsEnabled = ref.watch(ttsEnabledProvider);
    final notifier   = ref.read(audioProvider.notifier);
    final colors     = Theme.of(context).colorScheme;

    final isThisSurah  = audio.surahNumber == surah.id;
    final audioPlaying = isThisSurah && audio.isPlaying;
    final audioActive  = isThisSurah && audio.isActive;
    final supportsVerse = reciter?.supportsVerseTracking ?? false;

    final ttsThisSurah = tts.surahNumber == surah.id;
    final ttsSpeaking  = ttsThisSurah && tts.isSpeaking;
    final ttsActive    = ttsThisSurah && tts.isActive;

    final showTts = ttsEnabled;

    final isAnyActive  = audioActive || ttsActive;
    final isAnyPlaying = audioPlaying || ttsSpeaking;

    final ayahLabel = showTts && ttsActive
        ? 'Ayah ${tts.currentAyahNumber} of ${surah.versesCount} · TTS'
        : audioActive && audio.currentAyahNumber != null
            ? 'Ayah ${audio.currentAyahNumber} of ${surah.versesCount}'
            : reciter?.name ?? 'No reciter selected';

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!showTts &&
                audioActive &&
                audio.duration > Duration.zero) ...[
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: audio.position.inMilliseconds
                      .clamp(0, audio.duration.inMilliseconds)
                      .toDouble(),
                  max: audio.duration.inMilliseconds.toDouble(),
                  onChanged: (v) =>
                      notifier.seekTo(Duration(milliseconds: v.round())),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(audio.position),
                        style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant)),
                    Text(_fmt(audio.duration),
                        style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    ayahLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                      fontWeight: isAnyActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.skip_previous_rounded,
                      color: isAnyActive ? _kGreen : null),
                  tooltip: 'Previous ayah',
                  onPressed: showTts
                      ? (ttsActive ? () => _ttsPrev(ref) : null)
                      : (audioActive && supportsVerse
                          ? () => notifier.previousAyah()
                          : null),
                ),
                FilledButton(
                  onPressed: showTts
                      ? () => _ttsToggle(ref)
                      : reciter == null
                          ? null
                          : audioActive
                              ? () => notifier.togglePlayPause()
                              : () {
                                  if (!supportsVerse) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                      content: Text(
                                        'This reciter only supports '
                                        'full-surah playback. Choose a '
                                        'reciter with verse tracking.',
                                      ),
                                    ));
                                    return;
                                  }
                                  notifier.playSurah(surah.id,
                                      reciter: reciter);
                                },
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        isAnyActive ? _kGreen : null,
                    foregroundColor:
                        isAnyActive ? Colors.white : null,
                    minimumSize: const Size(56, 44),
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: audio.status == AudioStatus.loading &&
                          isThisSurah &&
                          !ttsEnabled
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: audioActive
                                ? Colors.white
                                : colors.onPrimary,
                          ),
                        )
                      : Icon(
                          isAnyPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          size: 24,
                        ),
                ),
                IconButton(
                  icon: Icon(Icons.skip_next_rounded,
                      color: isAnyActive ? _kGreen : null),
                  tooltip: 'Next ayah',
                  onPressed: showTts
                      ? (ttsActive ? () => _ttsNext(ref) : null)
                      : (audioActive && supportsVerse
                          ? () => notifier.nextAyah()
                          : null),
                ),
                IconButton(
                  icon: Icon(Icons.stop_rounded,
                      color: isAnyActive ? _kGreen : null),
                  tooltip: 'Stop',
                  onPressed: isAnyActive
                      ? () {
                          notifier.stop();
                          ref.read(ttsProvider.notifier).stop();
                        }
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _ttsToggle(WidgetRef ref) {
    final tts = ref.read(ttsProvider);
    if (tts.isSpeaking) {
      ref.read(ttsProvider.notifier).stop();
    } else {
      final ayahN = tts.currentAyahNumber ?? 1;
      final ayahs =
          ref.read(_surahAyahsProvider(surah.id)).valueOrNull;
      if (ayahs == null) return;
      final ayah = ayahs.firstWhere(
        (a) => a.ayahNumber == ayahN,
        orElse: () => ayahs.first,
      );
      ref.read(ttsProvider.notifier).speakAyah(
        surah.id, ayah.ayahNumber, ayah.textUthmani,
      );
    }
  }

  void _ttsPrev(WidgetRef ref) {
    final curr = ref.read(ttsProvider).currentAyahNumber ?? 1;
    final ayahs = ref.read(_surahAyahsProvider(surah.id)).valueOrNull;
    if (ayahs == null) return;
    final idx = ayahs.indexWhere((a) => a.ayahNumber == curr);
    if (idx > 0) {
      final prev = ayahs[idx - 1];
      ref.read(ttsProvider.notifier).speakAyah(
        surah.id, prev.ayahNumber, prev.textUthmani,
      );
    }
  }

  void _ttsNext(WidgetRef ref) {
    final curr = ref.read(ttsProvider).currentAyahNumber ?? 0;
    final ayahs = ref.read(_surahAyahsProvider(surah.id)).valueOrNull;
    if (ayahs == null) return;
    final idx = ayahs.indexWhere((a) => a.ayahNumber == curr);
    if (idx >= 0 && idx + 1 < ayahs.length) {
      final next = ayahs[idx + 1];
      ref.read(ttsProvider.notifier).speakAyah(
        surah.id, next.ayahNumber, next.textUthmani,
      );
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Reciter picker button ─────────────────────────────────────────────────────

class _ReciterButton extends ConsumerWidget {
  const _ReciterButton({required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recitersAsync = ref.watch(recitersProvider);
    final selectedId = ref.watch(selectedReciterIdProvider);

    return recitersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (reciters) {
        final current = reciters.isEmpty
            ? null
            : (selectedId == null
                ? reciters.first
                : reciters.firstWhere((r) => r.id == selectedId,
                    orElse: () => reciters.first));
        return TextButton.icon(
          icon: const Icon(Icons.mic_none_rounded, size: 18),
          label: Text(
            current?.name ?? 'Reciter',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onPressed: () =>
              _showReciterSheet(context, ref, reciters, selectedId),
        );
      },
    );
  }

  void _showReciterSheet(
    BuildContext context,
    WidgetRef ref,
    List<QuranicReciter> reciters,
    int? selectedId,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, controller) => _ReciterSheet(
          reciters: reciters,
          selectedId: selectedId,
          onSelect: (r) {
            ref.read(selectedReciterIdProvider.notifier).state = r.id;
            ref.read(audioProvider.notifier).stop();
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }
}

class _ReciterSheet extends StatelessWidget {
  const _ReciterSheet({
    required this.reciters,
    required this.selectedId,
    required this.onSelect,
  });

  final List<QuranicReciter> reciters;
  final int? selectedId;
  final void Function(QuranicReciter) onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Text('Choose Reciter',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface)),
              const Spacer(),
              Icon(Icons.mic_rounded, color: colors.primary),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: reciters.length,
            itemBuilder: (_, i) {
              final r = reciters[i];
              final isSelected =
                  (selectedId == null && i == 0) || r.id == selectedId;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected
                      ? colors.primary
                      : colors.surfaceContainerHighest,
                  child: Text(
                    '${r.id}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? colors.onPrimary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
                title: Text(r.name,
                    style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal)),
                subtitle: Row(
                  children: [
                    if (r.arabicName != null)
                      Text(r.arabicName!,
                          style: TextStyle(
                            fontFamily: kArabicFont,
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          )),
                    if (r.style != null) ...[
                      if (r.arabicName != null)
                        Text(' · ',
                            style: TextStyle(
                                color: colors.outlineVariant)),
                      Text(r.style!,
                          style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant)),
                    ],
                  ],
                ),
                trailing: r.supportsVerseTracking
                    ? Tooltip(
                        message: 'Supports ayah-by-ayah tracking',
                        child: Icon(Icons.track_changes_rounded,
                            size: 16, color: colors.primary),
                      )
                    : null,
                selected: isSelected,
                onTap: () => onSelect(r),
              );
            },
          ),
        ),
      ],
    );
  }
}
