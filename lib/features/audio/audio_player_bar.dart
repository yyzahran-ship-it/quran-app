import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../mushaf/mushaf_provider.dart';
import 'audio_provider.dart';
import 'reciter_provider.dart';
import 'quran_foundation_repository.dart';

/// Q4A-style persistent player bar shown at the bottom of the Mushaf screen.
///
/// Layout (matches Quran for Android):
/// ┌───────────────────────────────────────────────┐
/// │  [thin progress bar]                          │
/// │  Surah Name     [◀] [▶/‖/●] [▶]       [×]   │
/// │  Ayah X / Y  ·  Reciter Name  [AB] [1×]      │
/// └───────────────────────────────────────────────┘
class AudioPlayerBar extends ConsumerWidget {
  const AudioPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    if (!audio.hasAudio) return const SizedBox.shrink();

    final colors   = Theme.of(context).colorScheme;
    final notifier = ref.read(audioProvider.notifier);
    final surahs   = ref.watch(mushafProvider.select((s) => s.surahs));

    final surahName = (audio.surahNumber != null &&
            surahs.isNotEmpty &&
            audio.surahNumber! <= surahs.length)
        ? surahs[audio.surahNumber! - 1].nameSimple
        : 'Surah ${audio.surahNumber}';

    // Resolve reciter display name
    final qaReciters = ref.watch(reciterListProvider);
    final qfAsync    = ref.watch(qfRecitationsProvider);
    String reciterName = reciterDisplayName(qaReciters, audio.reciter);
    if (audio.isQFReciter) {
      final id = audio.qfRecitationId;
      if (id != null) {
        final qf = qfAsync.valueOrNull ?? [];
        for (final r in qf) {
          if (r.id == id) {
            reciterName = r.name;
            break;
          }
        }
      }
    }

    // Progress fraction: 0.0 → 1.0 through the surah
    final progress = audio.ayahCount > 0
        ? (audio.currentAyahIndex + 1) / audio.ayahCount
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        border: Border(
          top: BorderSide(color: colors.primary.withValues(alpha: 0.25)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Progress bar ────────────────────────────────────────────────
          LinearProgressIndicator(
            value: progress,
            minHeight: 2,
            backgroundColor: colors.primary.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Top row: surah name + controls + close ───────────────
                Row(
                  children: [
                    // Surah name
                    Expanded(
                      child: Text(
                        surahName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.onPrimaryContainer,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // A-B loop
                    _LoopButton(
                      audio: audio,
                      colors: colors,
                      onTap: notifier.tapLoopButton,
                    ),
                    // Previous
                    _ControlButton(
                      icon: Icons.skip_previous,
                      size: 22,
                      color: colors.onPrimaryContainer,
                      tooltip: 'Previous ayah',
                      onPressed: audio.isLoading ? null : notifier.previousAyah,
                    ),
                    // Play / Pause / Loading / Error
                    _PlayButton(audio: audio, colors: colors, notifier: notifier),
                    // Next
                    _ControlButton(
                      icon: Icons.skip_next,
                      size: 22,
                      color: colors.onPrimaryContainer,
                      tooltip: 'Next ayah',
                      onPressed: audio.isLoading ? null : notifier.nextAyah,
                    ),
                    // Close
                    _ControlButton(
                      icon: Icons.close,
                      size: 18,
                      color: colors.onPrimaryContainer.withValues(alpha: 0.6),
                      tooltip: 'Stop',
                      onPressed: notifier.stop,
                    ),
                  ],
                ),
                // ── Bottom row: ayah counter + reciter name + speed ──────
                Row(
                  children: [
                    Text(
                      'Ayah ${audio.currentAyahNumber} / ${audio.ayahCount}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onPrimaryContainer.withValues(alpha: 0.65),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '·',
                        style: TextStyle(
                          color: colors.onPrimaryContainer.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        reciterName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.onPrimaryContainer.withValues(alpha: 0.75),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _SpeedButton(audio: audio, colors: colors, onTap: notifier.cycleSpeed),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Play / pause / loading / error button ────────────────────────────────────

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.audio,
    required this.colors,
    required this.notifier,
  });

  final AudioState audio;
  final ColorScheme colors;
  final AudioNotifier notifier;

  @override
  Widget build(BuildContext context) {
    if (audio.isLoading) {
      return Semantics(
        label: 'Loading audio',
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colors.primary,
              ),
            ),
          ),
        ),
      );
    }
    if (audio.hasError) {
      return Tooltip(
        message: 'Network error — tap to retry',
        child: IconButton(
          icon: const Icon(Icons.wifi_off),
          color: colors.error,
          iconSize: 24,
          onPressed: notifier.retryCurrentAyah,
        ),
      );
    }
    return IconButton(
      icon: Icon(
        audio.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
      ),
      color: colors.primary,
      iconSize: 32,
      tooltip: audio.isPlaying ? 'Pause' : 'Play',
      onPressed: notifier.togglePlayPause,
    );
  }
}

// ─── Generic icon button helper ───────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.size,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final double size;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      color: color,
      iconSize: size,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}

// ─── A-B loop button ──────────────────────────────────────────────────────────

class _LoopButton extends StatelessWidget {
  const _LoopButton(
      {required this.audio, required this.colors, required this.onTap});

  final AudioState audio;
  final ColorScheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color iconColor;
    final String tooltip;
    final IconData icon;

    if (audio.loopActive) {
      icon = Icons.repeat_one;
      iconColor = colors.primary;
      tooltip = 'A-B repeat on — tap to clear';
    } else if (audio.loopASet) {
      icon = Icons.repeat_one_outlined;
      iconColor = Colors.amber.shade600;
      tooltip = 'A set (ayah ${audio.loopStart! + 1}) — tap to set B';
    } else {
      icon = Icons.repeat_one_outlined;
      iconColor = colors.onPrimaryContainer.withValues(alpha: 0.35);
      tooltip = 'A-B repeat — tap to set start';
    }

    return IconButton(
      icon: Icon(icon, size: 18),
      color: iconColor,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }
}

// ─── Speed button ─────────────────────────────────────────────────────────────

class _SpeedButton extends StatelessWidget {
  const _SpeedButton(
      {required this.audio, required this.colors, required this.onTap});

  final AudioState audio;
  final ColorScheme colors;
  final VoidCallback onTap;

  String get _label {
    final s = audio.speed;
    if ((s - 1.0).abs() < 0.01) return '1×';
    return '${s.toString().replaceAll(RegExp(r'\.?0+$'), '')}×';
  }

  @override
  Widget build(BuildContext context) {
    final isAltered = (audio.speed - 1.0).abs() > 0.01;
    return Tooltip(
      message: 'Playback speed — tap to cycle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            _label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isAltered
                  ? Colors.amber.shade600
                  : colors.onPrimaryContainer.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
