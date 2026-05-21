import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/surah.dart';
import '../audio/audio_player_bar.dart';
import '../audio/audio_provider.dart';
import '../bookmarks/bookmarks_provider.dart';
import '../bookmarks/note_editor_dialog.dart';
import '../../data/repositories/quran_repository.dart';
import '../memorization/hifz_provider.dart';
import 'mushaf_provider.dart';
import 'search_screen.dart';
import 'tafsir_sheet.dart';
import 'widgets/juz_jump_dialog.dart';
import '../settings/settings_screen.dart';

// ─── Helper: page number for a given surah + ayah ────────────────────────────

int _ayahGlobalPage(int surahNumber, int ayahNumber) {
  int globalId = 1;
  for (int i = 0; i < surahNumber - 1; i++) {
    globalId += kSurahVerseCounts[i];
  }
  globalId += ayahNumber - 1;
  if (globalId < 1 || globalId > kTotalAyahs) return 1;
  return kAyahPages[globalId - 1];
}

// ─── Helper: group page ayahs by surah ───────────────────────────────────────

class _SurahSection {
  _SurahSection(this.surah);
  final Surah surah;
  final List<Ayah> ayahs = [];
}

List<_SurahSection> _groupBySurah(List<Ayah> ayahs, MushafState state) {
  final sections = <_SurahSection>[];
  for (final ayah in ayahs) {
    final surah = state.surahFor(ayah.surahNumber);
    if (surah == null) continue;
    if (sections.isEmpty || sections.last.surah.id != ayah.surahNumber) {
      sections.add(_SurahSection(surah)..ayahs.add(ayah));
    } else {
      sections.last.ayahs.add(ayah);
    }
  }
  return sections;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class MushafScreen extends ConsumerStatefulWidget {
  const MushafScreen({super.key});

  @override
  ConsumerState<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends ConsumerState<MushafScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mushafProvider);
    final audio = ref.watch(audioProvider);

    // Auto-navigate to the page that contains the currently playing ayah.
    ref.listen<AudioState>(audioProvider, (prev, next) {
      if (next.surahNumber == null || next.currentAyahNumber == null) return;
      if (prev?.surahNumber == next.surahNumber &&
          prev?.currentAyahIndex == next.currentAyahIndex) return;
      final targetPage =
          _ayahGlobalPage(next.surahNumber!, next.currentAyahNumber!);
      if (targetPage != ref.read(mushafProvider).currentPage) {
        ref
            .read(mushafProvider.notifier)
            .navigateToAyah(next.surahNumber!, next.currentAyahNumber!);
        _scrollToTop();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: _AppBarTitle(state: state),
        actions: [
          // Play / pause button — most discoverable audio entry point.
          if (audio.isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(
                audio.isPlaying
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
              ),
              tooltip: audio.isPlaying ? 'Pause' : 'Play page audio',
              onPressed: () {
                if (audio.isPlaying) {
                  ref.read(audioProvider.notifier).togglePlayPause();
                } else if (state.ayahs.isNotEmpty) {
                  ref.read(audioProvider.notifier).playSurah(
                        state.ayahs.first.surahNumber,
                        startAyah: state.ayahs.first.ayahNumber,
                      );
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.format_list_numbered_outlined),
            tooltip: 'Jump to Juz',
            onPressed: () => showJuzJumpDialog(context),
          ),
          IconButton(
            icon: Icon(
              state.showTranslation
                  ? Icons.translate
                  : Icons.translate_outlined,
            ),
            tooltip: state.showTranslation
                ? 'Hide all translations'
                : 'Show all translations',
            onPressed: () =>
                ref.read(mushafProvider.notifier).toggleTranslation(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.ayahs.isEmpty
              ? _buildErrorState()
              : GestureDetector(
                  // Swipe left → next page, swipe right → previous page.
                  // The vertical scroll inside handles its own axis independently.
                  onHorizontalDragEnd: (details) {
                    final v = details.primaryVelocity;
                    if (v == null) return;
                    if (v < -300) {
                      ref.read(mushafProvider.notifier).nextPage();
                      _scrollToTop();
                    } else if (v > 300) {
                      ref.read(mushafProvider.notifier).previousPage();
                      _scrollToTop();
                    }
                  },
                  child: _buildReader(state),
                ),
      bottomNavigationBar: state.ayahs.isEmpty
          ? null
          : _BottomArea(
              currentPage: state.currentPage,
              onPrevious: () {
                ref.read(mushafProvider.notifier).previousPage();
                _scrollToTop();
              },
              onNext: () {
                ref.read(mushafProvider.notifier).nextPage();
                _scrollToTop();
              },
            ),
    );
  }

  Widget _buildReader(MushafState state) {
    final fontSize = ref.watch(fontSizeProvider);
    final audio = ref.watch(audioProvider);
    final sections = _groupBySurah(state.ayahs, state);
    final firstSurah = sections.isNotEmpty ? sections.first.surah : null;
    final juzNumber =
        state.ayahs.isNotEmpty ? state.ayahs.first.juzNumber : null;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (firstSurah != null)
              _PageHeader(surah: firstSurah, juzNumber: juzNumber),
            const SizedBox(height: 20),
            for (final section in sections) ...[
              _SurahBanner(surah: section.surah),
              if (section.surah.bismillahPre && section.surah.id != 1) ...[
                const SizedBox(height: 4),
                const _BismillahLine(),
              ],
              const SizedBox(height: 12),
              _ContinuousText(
                ayahs: section.ayahs,
                fontSize: fontSize,
                translations: state.showTranslation
                    ? state.translations
                    : const {},
                onAyahMenu: (ayah) => _showAyahMenu(context, ayah),
                playingSurahNumber: audio.surahNumber,
                playingAyahNumber: audio.currentAyahNumber,
              ),
              const SizedBox(height: 20),
            ],
            const SizedBox(height: 8),
            const Center(child: _PageDivider()),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${state.currentPage}',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: colors.error),
            const SizedBox(height: 16),
            const Text(
              'Could not load Quran data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap Retry to try again.',
              style: TextStyle(color: colors.outline),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.invalidate(mushafProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAyahMenu(BuildContext context, Ayah ayah) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _AyahActionSheet(
        ayahKey: ayah.verseKey,
        surahNumber: ayah.surahNumber,
        ayahNumber: ayah.ayahNumber,
        ayahId: ayah.id,
      ),
    );
  }
}

// ─── AppBar title ─────────────────────────────────────────────────────────────

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.state});

  final MushafState state;

  @override
  Widget build(BuildContext context) {
    if (state.ayahs.isEmpty) return const Text('Quran');
    final firstSurah = state.surahFor(state.ayahs.first.surahNumber);
    final juzNumber = state.ayahs.first.juzNumber;
    return Row(
      children: [
        Expanded(
          child: Text(
            firstSurah?.nameSimple ?? 'Page ${state.currentPage}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          "Juz' $juzNumber",
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}

// ─── In-page running header ───────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.surah, required this.juzNumber});

  final Surah surah;
  final int? juzNumber;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 13,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontStyle: FontStyle.italic,
    );
    return Row(
      children: [
        Text(surah.nameSimple, style: style),
        const Spacer(),
        if (juzNumber != null) Text("Juz' $juzNumber", style: style),
      ],
    );
  }
}

// ─── Thin decorative divider above page number ────────────────────────────────

class _PageDivider extends StatelessWidget {
  const _PageDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Divider(
        thickness: 0.5,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

// ─── Decorative surah banner ──────────────────────────────────────────────────

class _SurahBanner extends StatelessWidget {
  const _SurahBanner({required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(
              color: colors.outline.withValues(alpha: 0.4), width: 0.5),
          borderRadius: BorderRadius.circular(1),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Text(
          surah.nameArabic,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kArabicFont,
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
      ),
    );
  }
}

// ─── Bismillah line ───────────────────────────────────────────────────────────

class _BismillahLine extends StatelessWidget {
  const _BismillahLine();

  @override
  Widget build(BuildContext context) {
    return Text(
      'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: kArabicFont,
        fontSize: 22,
        height: 2.2,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

// ─── Continuous Mushaf text (all ayahs flow as one paragraph) ────────────────
//
// Uses Text.rich with per-ayah TapGestureRecognizer so multiple short ayahs
// can share a line — matching the visual style of a printed Mushaf page.

class _ContinuousText extends StatefulWidget {
  const _ContinuousText({
    required this.ayahs,
    required this.fontSize,
    required this.translations,
    required this.onAyahMenu,
    this.playingSurahNumber,
    this.playingAyahNumber,
  });

  final List<Ayah> ayahs;
  final double fontSize;
  final Map<int, String> translations;
  final void Function(Ayah) onAyahMenu;
  final int? playingSurahNumber;
  final int? playingAyahNumber;

  @override
  State<_ContinuousText> createState() => _ContinuousTextState();
}

class _ContinuousTextState extends State<_ContinuousText> {
  // One recognizer per ayah — must be disposed to avoid leaks.
  late List<TapGestureRecognizer> _recognizers;

  @override
  void initState() {
    super.initState();
    _buildRecognizers();
  }

  void _buildRecognizers() {
    _recognizers = List.generate(
      widget.ayahs.length,
      (i) => TapGestureRecognizer()
        ..onTap = () => widget.onAyahMenu(widget.ayahs[i]),
    );
  }

  @override
  void didUpdateWidget(_ContinuousText old) {
    super.didUpdateWidget(old);
    if (widget.ayahs.length != _recognizers.length) {
      // Ayah count changed (new page) — rebuild all recognizers.
      for (final r in _recognizers) r.dispose();
      _buildRecognizers();
    } else {
      // Same count — update callbacks so closures capture the latest ayahs.
      for (int i = 0; i < _recognizers.length; i++) {
        _recognizers[i].onTap = () => widget.onAyahMenu(widget.ayahs[i]);
      }
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers) r.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ayahs.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final textColor = colors.onSurface;
    const playingColor = Color(0xFF1B6B3A);

    // Build a single flowing TextSpan for all ayahs in this surah section.
    // Short ayahs will naturally share lines, matching the printed Mushaf look.
    final spans = <InlineSpan>[];
    for (int i = 0; i < widget.ayahs.length; i++) {
      final ayah = widget.ayahs[i];
      final isPlaying = widget.playingSurahNumber != null &&
          ayah.surahNumber == widget.playingSurahNumber &&
          ayah.ayahNumber == widget.playingAyahNumber;

      spans.add(TextSpan(
        text: '${ayah.textUthmani} ',
        recognizer: _recognizers[i],
        style: TextStyle(
          color: isPlaying ? playingColor : textColor,
          fontWeight: isPlaying ? FontWeight.w700 : FontWeight.normal,
          backgroundColor:
              isPlaying ? playingColor.withValues(alpha: 0.08) : null,
        ),
      ));
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _AyahEndMarker(
          number: ayah.ayahNumber,
          onTap: () => widget.onAyahMenu(ayah),
          isPlaying: isPlaying,
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: spans,
            style: TextStyle(
              fontFamily: kArabicFont,
              fontSize: widget.fontSize,
              height: 2.2,
              color: textColor,
            ),
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.justify,
        ),
        // Translations shown below the Arabic block when enabled.
        if (widget.translations.isNotEmpty) ...[
          const SizedBox(height: 16),
          _TranslationBlock(
            ayahs: widget.ayahs,
            translations: widget.translations,
            colors: colors,
          ),
        ],
      ],
    );
  }
}

// ─── Translation block shown below each surah section ────────────────────────

class _TranslationBlock extends StatelessWidget {
  const _TranslationBlock({
    required this.ayahs,
    required this.translations,
    required this.colors,
  });

  final List<Ayah> ayahs;
  final Map<int, String> translations;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final ayah in ayahs)
          if (translations[ayah.id] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ayah.ayahNumber}.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      translations[ayah.id]!,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

// ─── Circular ayah end marker ─────────────────────────────────────────────────

class _AyahEndMarker extends StatelessWidget {
  const _AyahEndMarker({
    required this.number,
    required this.onTap,
    this.isPlaying = false,
  });

  final int number;
  final VoidCallback onTap;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPlaying ? const Color(0xFF1B6B3A) : null,
          border: isPlaying
              ? null
              : Border.all(color: colors.outline, width: 0.8),
        ),
        alignment: Alignment.center,
        child: Text(
          '$number',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: isPlaying ? Colors.white : colors.onSurface,
          ),
        ),
      ),
    );
  }
}

// ─── Ayah action sheet ────────────────────────────────────────────────────────

class _AyahActionSheet extends ConsumerWidget {
  const _AyahActionSheet({
    required this.ayahKey,
    required this.surahNumber,
    required this.ayahNumber,
    required this.ayahId,
  });

  final String ayahKey;
  final int surahNumber;
  final int ayahNumber;
  final int ayahId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    final isThisAyahPlaying = audio.surahNumber == surahNumber &&
        audio.currentAyahNumber == ayahNumber &&
        audio.isPlaying;

    final isBookmarked =
        ref.watch(bookmarkedAyahProvider(ayahId)).valueOrNull ?? false;
    final isInHifz =
        ref.watch(inHifzProvider(ayahId)).valueOrNull ?? false;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Ayah $ayahKey',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(isThisAyahPlaying
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline),
                title: Text(isThisAyahPlaying ? 'Pause' : 'Play audio'),
                onTap: () {
                  Navigator.pop(context);
                  if (isThisAyahPlaying) {
                    ref.read(audioProvider.notifier).togglePlayPause();
                  } else {
                    ref
                        .read(audioProvider.notifier)
                        .playAyah(surahNumber, ayahNumber);
                  }
                },
              ),
              ListTile(
                leading: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border),
                title:
                    Text(isBookmarked ? 'Remove bookmark' : 'Bookmark'),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(bookmarksProvider.notifier).toggle(
                        ayahId: ayahId,
                        surahNumber: surahNumber,
                        ayahNumber: ayahNumber,
                      );
                },
              ),
              ListTile(
                leading: const Icon(Icons.note_add_outlined),
                title: const Text('Add / edit note'),
                onTap: () {
                  Navigator.pop(context);
                  showNoteEditor(
                    context,
                    ayahId: ayahId,
                    surahNumber: surahNumber,
                    ayahNumber: ayahNumber,
                    verseKey: ayahKey,
                  );
                },
              ),
              ListTile(
                leading: Icon(
                    isInHifz ? Icons.psychology : Icons.psychology_outlined),
                title: Text(isInHifz ? 'Remove from Hifz' : 'Add to Hifz'),
                subtitle: isInHifz
                    ? null
                    : const Text('Schedule for spaced-repetition review'),
                onTap: () async {
                  Navigator.pop(context);
                  final repo = ref.read(quranRepositoryProvider);
                  if (isInHifz) {
                    await repo.removeFromHifz(ayahId);
                  } else {
                    await repo.addToHifz(ayahId, surahNumber, ayahNumber);
                  }
                  ref.invalidate(inHifzProvider(ayahId));
                  ref.invalidate(hifzStatsProvider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Read Tafsir'),
                subtitle:
                    const Text('Ibn Kathir · Al-Muyassar · Al-Jalalayn'),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => TafsirSheet(verseKey: ayahKey),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bottom area: audio bar + page navigation ─────────────────────────────────

class _BottomArea extends StatelessWidget {
  const _BottomArea({
    required this.currentPage,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AudioPlayerBar(),
        _PageNav(
          currentPage: currentPage,
          onPrevious: onPrevious,
          onNext: onNext,
        ),
      ],
    );
  }
}

class _PageNav extends StatelessWidget {
  const _PageNav({
    required this.currentPage,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border:
            Border(top: BorderSide(color: colors.outlineVariant, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: currentPage > 1 ? onPrevious : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
            ),
          ),
          Text(
            '$currentPage / $kTotalPages',
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: currentPage < kTotalPages ? onNext : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Next'),
              iconAlignment: IconAlignment.end,
            ),
          ),
        ],
      ),
    );
  }
}
