import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_provider.dart';

/// Slim persistent bar shown at the bottom of the screen while audio is active.
/// Hidden when no audio is loaded.
class AudioPlayerBar extends ConsumerWidget {
  const AudioPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    if (!audio.hasAudio) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final notifier = ref.read(audioProvider.notifier);

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        border:
            Border(top: BorderSide(color: colors.primary.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          // Surah + ayah label
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Surah ${audio.surahNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                Text(
                  'Ayah ${audio.currentAyahNumber} / ${audio.ayahCount}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          // A-B repeat
          _LoopButton(audio: audio, colors: colors, onTap: notifier.tapLoopButton),
          // Previous ayah
          IconButton(
            icon: const Icon(Icons.skip_previous),
            color: colors.onPrimaryContainer,
            iconSize: 22,
            tooltip: 'Previous ayah',
            onPressed: audio.isLoading
                ? null
                : () => notifier.previousAyah(),
          ),
          // Play / Pause / Loading / Error
          if (audio.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.onPrimaryContainer,
                ),
              ),
            )
          else if (audio.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Tooltip(
                message: 'Playback failed — check internet connection',
                child: Icon(Icons.wifi_off,
                    size: 24, color: colors.onPrimaryContainer),
              ),
            )
          else
            IconButton(
              icon: Icon(audio.isPlaying ? Icons.pause : Icons.play_arrow),
              color: colors.onPrimaryContainer,
              iconSize: 28,
              tooltip: audio.isPlaying ? 'Pause' : 'Play',
              onPressed: () => notifier.togglePlayPause(),
            ),
          // Next ayah
          IconButton(
            icon: const Icon(Icons.skip_next),
            color: colors.onPrimaryContainer,
            iconSize: 22,
            tooltip: 'Next ayah',
            onPressed: audio.isLoading ? null : () => notifier.nextAyah(),
          ),
          // Speed
          _SpeedButton(audio: audio, colors: colors, onTap: notifier.cycleSpeed),
          // Stop
          IconButton(
            icon: const Icon(Icons.close),
            color: colors.onPrimaryContainer,
            iconSize: 20,
            tooltip: 'Stop',
            onPressed: () => notifier.stop(),
          ),
          const SizedBox(width: 4),
        ],
      ),
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
      iconColor = colors.onPrimaryContainer;
      tooltip = 'A-B repeat on — tap to clear';
    } else if (audio.loopASet) {
      icon = Icons.repeat_one_outlined;
      iconColor = Colors.amber.shade600;
      tooltip = 'A is set (ayah ${audio.loopStart! + 1}) — tap to set B';
    } else {
      icon = Icons.repeat_one_outlined;
      iconColor = colors.onPrimaryContainer.withValues(alpha: 0.35);
      tooltip = 'A-B repeat — tap to set start (A)';
    }

    return IconButton(
      icon: Icon(icon, size: 20),
      color: iconColor,
      tooltip: tooltip,
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
    // Remove trailing zero: 0.75 → "0.75×", 1.25 → "1.25×", 1.5 → "1.5×"
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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Text(
            _label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isAltered
                  ? Colors.amber.shade600
                  : colors.onPrimaryContainer.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
