import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../audio/audio_provider.dart';
import 'fsrs.dart';
import 'hifz_provider.dart';

class HifzReviewScreen extends ConsumerStatefulWidget {
  const HifzReviewScreen({super.key});

  @override
  ConsumerState<HifzReviewScreen> createState() => _HifzReviewScreenState();
}

class _HifzReviewScreenState extends ConsumerState<HifzReviewScreen> {
  // Session-local toggle — persisted only while this screen is open.
  bool _audioMode = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(hifzProvider.notifier).startSession());
  }

  // Play the audio for the current review card.
  void _playCurrentCard(ReviewItem item) {
    ref
        .read(audioProvider.notifier)
        .playAyah(item.ayah.surahNumber, item.ayah.ayahNumber);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(hifzProvider);
    final colors = Theme.of(context).colorScheme;

    // Whenever audio mode is on and a new (unrevealed) card appears, auto-play.
    ref.listen<HifzSession>(hifzProvider, (prev, next) {
      if (_audioMode &&
          next.hasCards &&
          !next.done &&
          !next.revealed &&
          next.current != null) {
        // Only auto-play when the card index actually changed (or it's the
        // first card) — avoids re-triggering on unrelated state changes.
        final prevIndex = prev?.currentIndex ?? -1;
        if (next.currentIndex != prevIndex) {
          _playCurrentCard(next.current!);
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        actions: [
          // Audio mode toggle — always visible so the user can switch any time.
          IconButton(
            tooltip: _audioMode ? 'Audio mode: ON' : 'Audio mode: OFF',
            icon: Icon(
              Icons.headphones,
              color: _audioMode ? colors.primary : colors.onSurfaceVariant,
            ),
            onPressed: () {
              setState(() => _audioMode = !_audioMode);
              // If we just turned audio mode on and there is an unrevealed card,
              // start playing immediately.
              if (_audioMode &&
                  session.hasCards &&
                  !session.done &&
                  !session.revealed &&
                  session.current != null) {
                _playCurrentCard(session.current!);
              }
            },
          ),
          if (session.hasCards && !session.done)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${session.currentIndex + 1} / ${session.queue.length}',
                  style: TextStyle(
                      color: colors.onSurfaceVariant, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(session, colors),
    );
  }

  Widget _buildBody(HifzSession session, ColorScheme colors) {
    if (!session.hasCards && !session.done) {
      return const Center(child: CircularProgressIndicator());
    }

    if (session.done) {
      return _DoneScreen(
        onClose: () => Navigator.pop(context),
        onRestart: () =>
            ref.read(hifzProvider.notifier).startSession(),
      );
    }

    final item = session.current!;
    final ayah = item.ayah;

    return Column(
      children: [
        // Progress bar.
        LinearProgressIndicator(
          value: session.currentIndex / session.queue.length,
          minHeight: 3,
          backgroundColor: colors.surfaceContainerHighest,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Verse reference chip.
                Center(
                  child: Chip(
                    label: Text(
                      ayah.verseKey,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colors.onPrimaryContainer),
                    ),
                    backgroundColor: colors.primaryContainer,
                  ),
                ),
                const SizedBox(height: 24),
                // Arabic text card — replaced by audio hint when audio mode is on
                // and the card has not yet been revealed.
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: session.revealed
                      ? _RevealedAyah(
                          text: ayah.textUthmani,
                          colors: colors,
                        )
                      : (_audioMode
                          ? _AudioModeHint(colors: colors)
                          : _HiddenAyah(
                              hint: _firstWord(ayah.textUthmani),
                              colors: colors,
                              onReveal: () =>
                                  ref.read(hifzProvider.notifier).reveal(),
                            )),
                ),
                if (session.revealed) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Surah ${ayah.surahNumber}, Ayah ${ayah.ayahNumber}',
                      style: TextStyle(
                          fontSize: 12, color: colors.outlineVariant),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Lapse count hint.
                if (item.card.lapses > 0)
                  Center(
                    child: Text(
                      '${item.card.lapses} lapse${item.card.lapses > 1 ? 's' : ''}',
                      style: TextStyle(
                          fontSize: 12, color: colors.outline),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Rating buttons — only visible after reveal.
        if (session.revealed)
          _RatingBar(
            onRate: (r) => ref.read(hifzProvider.notifier).rate(r),
            colors: colors,
          )
        else
          _RevealButton(
            onReveal: () => ref.read(hifzProvider.notifier).reveal(),
            colors: colors,
          ),
      ],
    );
  }

  String _firstWord(String text) {
    final parts = text.trim().split(' ');
    return parts.isNotEmpty ? parts.first : text;
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

/// Shown in place of the Arabic text when audio mode is active and the card
/// has not yet been revealed.  The user is expected to listen to the audio and
/// recall the ayah before tapping "Show Ayah".
class _AudioModeHint extends StatelessWidget {
  const _AudioModeHint({required this.colors});
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Icon(
          Icons.headphones,
          size: 64,
          color: colors.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Listen carefully…',
          style: TextStyle(
            fontSize: 16,
            color: colors.onSurface,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _HiddenAyah extends StatelessWidget {
  const _HiddenAyah({
    required this.hint,
    required this.colors,
    required this.onReveal,
  });
  final String hint;
  final ColorScheme colors;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Show only the first word as a hint.
        Text(
          hint,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: kArabicFont,
            fontSize: 28,
            height: 2.0,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '· · · · · · · · · ·',
              style: TextStyle(
                  fontSize: 20,
                  letterSpacing: 4,
                  color: colors.outlineVariant),
            ),
          ),
        ),
      ],
    );
  }
}

class _RevealedAyah extends StatelessWidget {
  const _RevealedAyah({required this.text, required this.colors});
  final String text;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontFamily: kArabicFont,
        fontSize: 26,
        height: 2.0,
        color: colors.onSurface,
      ),
    );
  }
}

class _RevealButton extends StatelessWidget {
  const _RevealButton({required this.onReveal, required this.colors});
  final VoidCallback onReveal;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: onReveal,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Show Ayah'),
          ),
        ),
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.onRate, required this.colors});
  final void Function(FsrsRating) onRate;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border(
              top: BorderSide(color: colors.outlineVariant, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How well did you recall it?',
              style:
                  TextStyle(fontSize: 12, color: colors.outlineVariant),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _RatingButton(
                  label: 'Again',
                  sublabel: 'Forgot',
                  color: colors.errorContainer,
                  textColor: colors.onErrorContainer,
                  onTap: () => onRate(FsrsRating.again),
                ),
                const SizedBox(width: 8),
                _RatingButton(
                  label: 'Hard',
                  sublabel: 'Struggled',
                  color: colors.tertiaryContainer,
                  textColor: colors.onTertiaryContainer,
                  onTap: () => onRate(FsrsRating.hard),
                ),
                const SizedBox(width: 8),
                _RatingButton(
                  label: 'Good',
                  sublabel: 'Recalled',
                  color: colors.primaryContainer,
                  textColor: colors.onPrimaryContainer,
                  onTap: () => onRate(FsrsRating.good),
                ),
                const SizedBox(width: 8),
                _RatingButton(
                  label: 'Easy',
                  sublabel: 'Perfect',
                  color: colors.secondaryContainer,
                  textColor: colors.onSecondaryContainer,
                  onTap: () => onRate(FsrsRating.easy),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.textColor,
    required this.onTap,
  });
  final String label;
  final String sublabel;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor)),
              Text(sublabel,
                  style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoneScreen extends StatelessWidget {
  const _DoneScreen({required this.onClose, required this.onRestart});
  final VoidCallback onClose;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 72, color: colors.primary),
            const SizedBox(height: 16),
            Text('Session Complete!',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'All due cards reviewed. Come back tomorrow for the next batch.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.outline),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: onClose, child: const Text('Done')),
            ),
          ],
        ),
      ),
    );
  }
}
