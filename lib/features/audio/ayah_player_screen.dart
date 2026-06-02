import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/quran_repository.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/surah.dart';
import 'audio_models.dart';
import 'audio_provider.dart';
import 'reciter_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final ayahsAsync = ref.watch(_surahAyahsProvider(widget.surah.id));
    final audioState = ref.watch(audioProvider);
    final reciter = ref.watch(selectedReciterProvider);
    final colors = Theme.of(context).colorScheme;

    // Auto-scroll whenever the playing ayah changes.
    final currentAyah = audioState.surahNumber == widget.surah.id
        ? audioState.currentAyahNumber
        : null;
    if (currentAyah != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToAyah(currentAyah);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.surah.nameSimple,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
        actions: [
          _ReciterButton(surah: widget.surah),
        ],
      ),
      body: Column(
        children: [
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

// ── Ayah list ─────────────────────────────────────────────────────────────────

// Watches audioProvider directly so it rebuilds immediately on audio changes,
// then passes isActive/isPlaying as props so rows never need their own watch.
class _AyahList extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    return ListView.builder(
      controller: scrollController,
      itemCount: ayahs.length,
      padding: const EdgeInsets.only(bottom: 8),
      itemBuilder: (context, i) {
        final ayah = ayahs[i];
        keys.putIfAbsent(ayah.ayahNumber, GlobalKey.new);
        final isPlaying = audio.surahNumber == surah.id &&
            audio.currentAyahNumber == ayah.ayahNumber &&
            audio.isPlaying;
        final isActive = audio.surahNumber == surah.id &&
            audio.currentAyahNumber == ayah.ayahNumber &&
            audio.isActive;
        return _AyahRow(
          key: ValueKey(ayah.ayahNumber),
          ayah: ayah,
          isPlaying: isPlaying,
          isActive: isActive,
          reciter: reciter,
          surah: surah,
          scrollKey: keys[ayah.ayahNumber]!,
        );
      },
    );
  }
}

// ── Ayah row ──────────────────────────────────────────────────────────────────

class _AyahRow extends ConsumerWidget {
  const _AyahRow({
    super.key,
    required this.ayah,
    required this.isPlaying,
    required this.isActive,
    required this.reciter,
    required this.surah,
    required this.scrollKey,
  });

  final Ayah ayah;
  final bool isPlaying;
  final bool isActive;
  final QuranicReciter? reciter;
  final Surah surah;
  final GlobalKey scrollKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    const _kGreen = Color(0xFF34A853);
    const _kGreenBg = Color(0xFFE6F4EA);

    return AnimatedContainer(
      key: scrollKey,
      duration: const Duration(milliseconds: 250),
      decoration: isActive
          ? const BoxDecoration(
              color: _kGreenBg,
              border: Border(
                left: BorderSide(color: _kGreen, width: 3),
              ),
            )
          : const BoxDecoration(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(isActive ? 13 : 16, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ayah number badge / play button.
            GestureDetector(
              onTap: reciter == null
                  ? null
                  : () {
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
                  child: isPlaying
                      ? const Icon(Icons.pause, size: 18, color: Colors.white)
                      : isActive
                          ? const Icon(Icons.play_arrow, size: 18, color: Colors.white)
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
            // Arabic text.
            Expanded(
              child: Text(
                ayah.textUthmani,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: kArabicFont,
                  fontSize: 22,
                  height: 1.8,
                  color: colors.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Player control bar ────────────────────────────────────────────────────────

class _PlayerBar extends ConsumerWidget {
  const _PlayerBar({required this.surah, required this.reciter});

  final Surah surah;
  final QuranicReciter? reciter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    final notifier = ref.read(audioProvider.notifier);
    final colors = Theme.of(context).colorScheme;

    final isThisSurah = audio.surahNumber == surah.id;
    final isPlaying = isThisSurah && audio.isPlaying;
    final isActive = isThisSurah && audio.isActive;
    final supportsVerse = reciter?.supportsVerseTracking ?? false;

    // Progress info.
    final ayahLabel = isActive && audio.currentAyahNumber != null
        ? 'Ayah ${audio.currentAyahNumber} of ${surah.versesCount}'
        : reciter?.name ?? 'No reciter selected';

    const _kGreen = Color(0xFF34A853);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar (only when playing and duration is known).
            if (isActive && audio.duration > Duration.zero) ...[
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
                            fontSize: 11, color: colors.onSurfaceVariant)),
                    Text(_fmt(audio.duration),
                        style: TextStyle(
                            fontSize: 11, color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                // Reciter / status label.
                Expanded(
                  child: Text(
                    ayahLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Previous ayah.
                IconButton(
                  icon: Icon(Icons.skip_previous_rounded,
                      color: isActive ? _kGreen : null),
                  tooltip: 'Previous ayah',
                  onPressed: isActive && supportsVerse
                      ? () => notifier.previousAyah()
                      : null,
                ),
                // Play / Pause.
                FilledButton(
                  onPressed: reciter == null
                      ? null
                      : isActive
                          ? () => notifier.togglePlayPause()
                          : () {
                              if (!supportsVerse) {
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
                              notifier.playSurah(surah.id, reciter: reciter);
                            },
                  style: FilledButton.styleFrom(
                    backgroundColor: isActive ? _kGreen : null,
                    foregroundColor: isActive ? Colors.white : null,
                    minimumSize: const Size(56, 44),
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: audio.status == AudioStatus.loading && isThisSurah
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isActive ? Colors.white : colors.onPrimary,
                          ),
                        )
                      : Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 24),
                ),
                // Next ayah.
                IconButton(
                  icon: Icon(Icons.skip_next_rounded,
                      color: isActive ? _kGreen : null),
                  tooltip: 'Next ayah',
                  onPressed: isActive && supportsVerse
                      ? () => notifier.nextAyah()
                      : null,
                ),
                // Stop.
                IconButton(
                  icon: Icon(Icons.stop_rounded,
                      color: isActive ? _kGreen : null),
                  tooltip: 'Stop',
                  onPressed: isActive ? () => notifier.stop() : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
          onPressed: () => _showReciterSheet(context, ref, reciters, selectedId),
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
            // Stop current playback when switching reciters.
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
              final isSelected = (selectedId == null && i == 0) ||
                  r.id == selectedId;
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
                            style: TextStyle(color: colors.outlineVariant)),
                      Text(r.style!,
                          style: TextStyle(
                              fontSize: 12, color: colors.onSurfaceVariant)),
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
