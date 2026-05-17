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

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        border: Border(top: BorderSide(color: colors.primary.withValues(alpha: 0.3))),
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
          // Previous ayah
          IconButton(
            icon: const Icon(Icons.skip_previous),
            color: colors.onPrimaryContainer,
            iconSize: 22,
            tooltip: 'Previous ayah',
            onPressed: audio.isLoading
                ? null
                : () => ref.read(audioProvider.notifier).previousAyah(),
          ),
          // Play / Pause
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
              onPressed: () => ref.read(audioProvider.notifier).togglePlayPause(),
            ),
          // Next ayah
          IconButton(
            icon: const Icon(Icons.skip_next),
            color: colors.onPrimaryContainer,
            iconSize: 22,
            tooltip: 'Next ayah',
            onPressed: audio.isLoading
                ? null
                : () => ref.read(audioProvider.notifier).nextAyah(),
          ),
          // Stop
          IconButton(
            icon: const Icon(Icons.close),
            color: colors.onPrimaryContainer,
            iconSize: 20,
            tooltip: 'Stop',
            onPressed: () => ref.read(audioProvider.notifier).stop(),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
