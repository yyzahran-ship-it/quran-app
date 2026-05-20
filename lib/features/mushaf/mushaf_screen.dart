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
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: state.currentSurah == null
            ? const Text('Quran')
            : _SurahJuzTitle(
                surah: state.currentSurah!,
                juzNumber: state.ayahs.isNotEmpty
                    ? state.ayahs.first.juzNumber
                    : null,
              ),
        actions: [
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
                ? 'Hide translation'
                : 'Show translation',
            onPressed: () =>
                ref.read(mushafProvider.notifier).toggleTranslation(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.currentSurah == null
              ? _buildErrorState()
              : _buildReader(state),
      bottomNavigationBar: state.currentSurah == null
          ? null
          : _BottomArea(
              surahId: state.currentSurah!.id,
              onPrevious: () {
                ref.read(mushafProvider.notifier).previousSurah();
                _scrollToTop();
              },
              onNext: () {
                ref.read(mushafProvider.notifier).nextSurah();
                _scrollToTop();
              },
            ),
    );
  }

  Widget _buildReader(MushafState state) {
    final surah = state.currentSurah!;
    final fontSize = ref.watch(fontSizeProvider);
    final page = kSurahStartPages[surah.id - 1];
    final juzNumber =
        state.ayahs.isNotEmpty ? state.ayahs.first.juzNumber : null;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Running header: "Surah Name | Juz' N"
            _PageHeader(surah: surah, juzNumber: juzNumber),
            const SizedBox(height: 20),
            _SurahBanner(surah: surah),
            if (surah.bismillahPre && surah.id != 1) ...[
              const SizedBox(height: 4),
              const _BismillahLine(),
            ],
            const SizedBox(height: 12),
            _ContinuousText(
              ayahs: state.ayahs,
              fontSize: fontSize,
              translations: state.showTranslation
                  ? state.translations
                  : const {},
              onAyahTap: (ayah) => _showAyahMenu(context, ayah),
            ),
            const SizedBox(height: 28),
            const Center(
              child: _PageDivider(),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '$page',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF888888),
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

class _SurahJuzTitle extends StatelessWidget {
  const _SurahJuzTitle({required this.surah, required this.juzNumber});

  final Surah surah;
  final int? juzNumber;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            surah.nameSimple,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (juzNumber != null)
          Text(
            "Juz' $juzNumber",
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
          ),
      ],
    );
  }
}

// ─── In-page running header (mirrors reference image top line) ─────────────────

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.surah, required this.juzNumber});

  final Surah surah;
  final int? juzNumber;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 13,
      color: Color(0xFF666666),
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
      child: Divider(thickness: 0.5, color: Colors.black38),
    );
  }
}

// ─── Decorative surah banner ──────────────────────────────────────────────────

class _SurahBanner extends StatelessWidget {
  const _SurahBanner({required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF2C2C2C), width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border:
              Border.all(color: const Color(0xFF2C2C2C).withValues(alpha: 0.4), width: 0.5),
          borderRadius: BorderRadius.circular(1),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Text(
          surah.nameArabic,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: kArabicFont,
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
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
    return const Text(
      'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: kArabicFont,
        fontSize: 22,
        height: 2.2,
        color: Color(0xFF1A1A1A),
      ),
    );
  }
}

// ─── Continuous Mushaf text ───────────────────────────────────────────────────

class _ContinuousText extends ConsumerWidget {
  const _ContinuousText({
    required this.ayahs,
    required this.fontSize,
    required this.translations,
    required this.onAyahTap,
  });

  final List<Ayah> ayahs;
  final double fontSize;
  final Map<int, String> translations;
  final void Function(Ayah) onAyahTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ayahs.isEmpty) return const SizedBox.shrink();

    // Page content is always on a white/cream background — use hardcoded
    // dark colours so text is readable regardless of the app theme.
    const textColor = Color(0xFF1A1A1A);

    final spans = <InlineSpan>[];
    for (final ayah in ayahs) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () => onAyahTap(ayah),
            child: Text.rich(
              TextSpan(
                text: '${ayah.textUthmani} ',
                style: TextStyle(
                  fontFamily: kArabicFont,
                  fontSize: fontSize,
                  height: 2.2,
                  color: textColor,
                ),
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        ),
      );
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _AyahEndMarker(
            number: ayah.ayahNumber,
            onTap: () => onAyahTap(ayah),
          ),
        ),
      );
      spans.add(const TextSpan(text: ' '));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(children: spans),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.justify,
        ),
        // Translation block — shown below the Arabic text when enabled.
        if (translations.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFCCCCCC)),
          const SizedBox(height: 8),
          for (final ayah in ayahs)
            if (translations[ayah.id] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${ayah.ayahNumber}. ',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF555555),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        translations[ayah.id]!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: Color(0xFF444444),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ],
    );
  }
}

// ─── Circular ayah end marker ─────────────────────────────────────────────────

class _AyahEndMarker extends StatelessWidget {
  const _AyahEndMarker({required this.number, required this.onTap});

  final int number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF444444), width: 0.8),
        ),
        alignment: Alignment.center,
        child: Text(
          '$number',
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
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
              title: Text(
                  isBookmarked ? 'Remove bookmark' : 'Bookmark'),
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
              subtitle: const Text('Ibn Kathir · Al-Muyassar · Al-Jalalayn'),
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

// ─── Bottom area: audio bar + surah navigation ────────────────────────────────

class _BottomArea extends StatelessWidget {
  const _BottomArea({
    required this.surahId,
    required this.onPrevious,
    required this.onNext,
  });

  final int surahId;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AudioPlayerBar(),
        _SurahNav(
          surahId: surahId,
          onPrevious: onPrevious,
          onNext: onNext,
        ),
      ],
    );
  }
}

class _SurahNav extends StatelessWidget {
  const _SurahNav({
    required this.surahId,
    required this.onPrevious,
    required this.onNext,
  });

  final int surahId;
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
              onPressed: surahId > 1 ? onPrevious : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
            ),
          ),
          Container(width: 0.5, color: colors.outlineVariant),
          Expanded(
            child: TextButton.icon(
              onPressed: surahId < 114 ? onNext : null,
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
