import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_provider.dart';
import 'reciter_picker_sheet.dart';

// Compact bar shown above the page nav when audio is active.
class AudioPlayerBar extends ConsumerWidget {
  const AudioPlayerBar({super.key, required this.surahNumber});

  final int surahNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    final colors = Theme.of(context).colorScheme;
    final isLoading = audio.status == AudioStatus.loading;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        border: Border(
          top: BorderSide(color: colors.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            Icons.headphones_rounded,
            size: 18,
            color: colors.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  audio.reciter?.name ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.onPrimaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                _ProgressBar(audio: audio, colors: colors),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Play / Pause / Loading
          if (isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.onPrimaryContainer,
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(
                audio.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: colors.onPrimaryContainer,
              ),
              onPressed: () =>
                  ref.read(audioProvider.notifier).togglePlayPause(),
            ),
          // Stop
          IconButton(
            icon: Icon(Icons.stop_rounded, color: colors.onPrimaryContainer),
            onPressed: () => ref.read(audioProvider.notifier).stop(),
          ),
          // Change reciter
          IconButton(
            icon: Icon(Icons.queue_music_rounded,
                color: colors.onPrimaryContainer),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) =>
                  ReciterPickerSheet(surahNumber: surahNumber),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.audio, required this.colors});

  final AudioPlaybackState audio;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final total = audio.duration.inMilliseconds;
    final pos = audio.position.inMilliseconds;
    final value = (total > 0) ? (pos / total).clamp(0.0, 1.0) : null;

    return LinearProgressIndicator(
      value: value,
      minHeight: 2,
      backgroundColor: colors.onPrimaryContainer.withAlpha(40),
      color: colors.onPrimaryContainer,
    );
  }
}
