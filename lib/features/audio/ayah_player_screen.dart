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
  // Map from ayahNumber → GlobalKey for auto-scroll.
  final Map<int, GlobalKey> _keys = {};
  int? _lastScrolledAyah;

  @override
  void dispose() {
    _scrollController.dispose();
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

  // Called when TTS finishes an ayah — speaks the next one automatically.
  void _ttsSpeakNextAfter(int? completedAyahNumber) {
    if (completedAyahNumber == null) return;
    final ayahs =
        ref.read(_surahAyahsProvider(widget.surah.id)).valueOrNull;
    if (ayahs == null) return;
    final idx = ayahs.indexWhere((a) => a.ayahNumber == completedAyahNumber);
    if (idx >= 0 && idx + 1 < ayahs.length) {
      final next = ayahs[idx + 1];
      ref
          .read(ttsProvider.notifier)
          .speakAyah(widget.surah.id, next.ayahNumber, next.textUthmani);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ayahsAsync = ref.watch(_surahAyahsProvider(widget.surah.id));
    final audioState = ref.watch(audioProvider);
    final ttsState   = ref.watch(ttsProvider);
    final ttsEnabled = ref.watch(ttsEnabledProvider);
    final reciter    = ref.watch(selectedReciterProvider);
    final colors     = Theme.of(context).colorScheme;

    // Auto-scroll: follows whichever engine is active.
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

    // TTS auto-advance: speak next ayah when current one finishes.
    ref.listen<TtsPlaybackState>(ttsProvider, (prev, curr) {
      if (!ref.read(ttsEnabledProvider)) return;
      if (prev?.isSpeaking == true && curr.status == TtsStatus.idle) {
        _ttsSpeakNextAfter(prev!.currentAyahNumber);
      }
    });

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
          // Debug strip — shows exact values _AyahRow uses so we can verify state.
          Builder(builder: (context) {
            final a = ref.watch(audioProvider);
            final active = a.surahNumber == widget.surah.id && a.isActive;
            return Container(
              width: double.infinity,
              color: active ? const Color(0xFF34A853) : Colors.grey.shade300,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                'status:${a.status.name} '
                'surah:${a.surahNumber}==${widget.surah.id}? '
                'ayah:${a.currentAyahNumber} '
                'active:$active',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : Colors.black54,
                ),
              ),
            );
          }),
          // TTS mode banner + toggle.
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
          // Animated toggle switch.
          GestureDetector(
            onTap: () {
              final enabled = ref.read(ttsEnabledProvider);
              if (enabled) {
                ref.read(ttsProvider.notifier).stop();
              } else {
                // Enabling TTS — stop any running audio to avoid overlap.
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
                  margin:
                      const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black26, blurRadius: 2)
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

// Minimal props — no audio/TTS state here. Each _AyahRow watches providers
// directly (via select) so Riverpod pushes updates to the row. GlobalKey on
// each row keeps the element stable and subscriptions alive across scrolling.
class _AyahList extends StatelessWidget {
  const _AyahList({
    required this.surah,
    required this.ayahs,
    required this.reciter,
    required this.scrollController,
    required this.keys,
  });

  final Surah surah;
  final List<Ayah> ayahs;
  final QuranicReciter? reciter;
  final ScrollController scrollController;
  final Map<int, GlobalKey> keys;

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
        );
      },
    );
  }
}

// ── Ayah row ──────────────────────────────────────────────────────────────────

// Watches audioProvider + ttsProvider via select so Riverpod pushes updates
// directly to this widget. GlobalKey (set by _AyahList) keeps the element
// stable across scrolling, so subscriptions are never lost.
// AnimatedContainer is the ROOT widget so its tween runs cleanly.
class _AyahRow extends ConsumerWidget {
  const _AyahRow({
    super.key,
    required this.ayah,
    required this.reciter,
    required this.surah,
  });

  final Ayah ayah;
  final QuranicReciter? reciter;
  final Surah surah;

  static const _kGreen   = Color(0xFF34A853);
  static const _kGreenBg = Color(0xFFE6F4EA);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    // Watch full state — no select — so any state change triggers rebuild.
    // Each row only re-renders if isActive/isPlaying actually changed, since
    // AnimatedContainer only repaints when its props differ.
    final audio      = ref.watch(audioProvider);
    final tts        = ref.watch(ttsProvider);
    final ttsEnabled = ref.watch(ttsEnabledProvider);

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── TEMP DIAGNOSTIC ── remove once shading is confirmed ───────────
        Container(
          color: isAudioActive ? Colors.green : Colors.red.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            'row${ayah.ayahNumber}: audioSurah=${audio.surahNumber}/${surah.id} '
            'audioAyah=${audio.currentAyahNumber}/${ayah.ayahNumber} '
            'status=${audio.status.name} active=$isAudioActive',
            style: const TextStyle(fontSize: 9, color: Colors.black87),
          ),
        ),
        // ─────────────────────────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: isActive
              ? const BoxDecoration(
                  color: _kGreenBg,
                  border: Border(
                      left: BorderSide(color: _kGreen, width: 3)),
                )
              : const BoxDecoration(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(isActive ? 13 : 16, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge: number → play/pause/waveform depending on state.
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
                          'This reciter only supports full-surah playback. '
                          'Choose a reciter with verse tracking.',
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
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: _WordDisplay(ayah: ayah, surah: surah)),
          ],
        ),
      ),
    ),  // AnimatedContainer
    ],  // Column children (diagnostic + AnimatedContainer)
    );
  }
}

// ── Waveform animation (TTS speaking indicator) ───────────────────────────────

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

// Watches both audioProvider (proportional timing) and ttsProvider (exact word
// boundary from setProgressHandler). TTS takes priority when active.
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
      // Exact word index from TTS progress callback.
      activeIdx = tts.currentWordIndex.clamp(-1, n - 1);
    } else if (isAudioAyah && audio.duration != Duration.zero) {
      // Proportional estimate from playback position.
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

    // TTS bar takes over when TTS mode is on.
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
            // Progress slider — audio only (TTS has no seekable position).
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
                // Previous ayah.
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
                // Play / Pause.
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
                                        'This reciter only supports full-surah playback. '
                                        'Choose a reciter with verse tracking.',
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
                // Next ayah.
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
                // Stop.
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
    final ayahs =
        ref.read(_surahAyahsProvider(surah.id)).valueOrNull;
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
    final ayahs =
        ref.read(_surahAyahsProvider(surah.id)).valueOrNull;
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
