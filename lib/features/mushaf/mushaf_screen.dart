import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/surah.dart';
import '../audio/audio_player_bar.dart';
import '../audio/audio_provider.dart';
import '../audio/audio_repository.dart';
import 'mushaf_provider.dart';
import 'search_screen.dart';
import 'widgets/juz_jump_dialog.dart';

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

// ─── Helper: hizb number (1–60) for a given Mushaf page ──────────────────────
// The Quran has 60 hizbs (2 per juz). The second hizb of each juz starts at
// the midpoint of that juz's page range.

int _pageHizb(int page) {
  int juz = 30;
  for (int i = 0; i < kJuzStartPages.length - 1; i++) {
    if (page < kJuzStartPages[i + 1]) {
      juz = i + 1;
      break;
    }
  }
  final juzStart = kJuzStartPages[juz - 1];
  final juzEnd =
      juz < kJuzStartPages.length ? kJuzStartPages[juz] - 1 : kTotalPages;
  final isSecondHizb = page >= (juzStart + juzEnd + 1) ~/ 2;
  return (juz - 1) * 2 + (isSecondHizb ? 2 : 1);
}

// ─── Screen actions (overflow menu) ──────────────────────────────────────────

enum _AppAction { playPause, search, juzJump, toggleTranslation, settings }

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

  void _handleAction(_AppAction action) {
    switch (action) {
      case _AppAction.playPause:
        final s = ref.read(mushafProvider);
        final a = ref.read(audioProvider);
        if (a.isPlaying) {
          ref.read(audioProvider.notifier).togglePlayPause();
        } else if (s.ayahs.isNotEmpty) {
          ref.read(audioProvider.notifier).playSurah(
                s.ayahs.first.surahNumber,
                startAyah: s.ayahs.first.ayahNumber,
              );
        }
      case _AppAction.search:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SearchScreen()));
      case _AppAction.juzJump:
        showJuzJumpDialog(context);
      case _AppAction.toggleTranslation:
        ref.read(mushafProvider.notifier).toggleTranslation();
      case _AppAction.settings:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()));
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

    final themeMode = ref.watch(themeProvider);
    final isLight = themeMode != AppThemeMode.dark &&
        themeMode != AppThemeMode.inverted;
    final bgColor = isLight ? Colors.white : null;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        // King Fahad Mushaf: plain white AppBar matching the printed page style
        // Surah name (left) · Juz number (right) — no color, no border
        backgroundColor: isLight ? Colors.white : null,
        foregroundColor: isLight ? const Color(0xFF1A1A1A) : null,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 44,
        title: _AppBarTitle(state: state),
        titleSpacing: 16,
        actions: [
          PopupMenuButton<_AppAction>(
            icon: Icon(Icons.more_vert,
                color: isLight ? const Color(0xFF1A1A1A) : null),
            tooltip: 'More options',
            onSelected: _handleAction,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _AppAction.playPause,
                child: Row(children: [
                  Icon(audio.isPlaying
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline),
                  const SizedBox(width: 12),
                  Text(audio.isPlaying ? 'Pause' : 'Play page audio'),
                ]),
              ),
              const PopupMenuItem(
                value: _AppAction.search,
                child: Row(children: [
                  Icon(Icons.search),
                  SizedBox(width: 12),
                  Text('Search'),
                ]),
              ),
              const PopupMenuItem(
                value: _AppAction.juzJump,
                child: Row(children: [
                  Icon(Icons.format_list_numbered_outlined),
                  SizedBox(width: 12),
                  Text('Jump to Juz'),
                ]),
              ),
              PopupMenuItem(
                value: _AppAction.toggleTranslation,
                child: Row(children: [
                  Icon(state.showTranslation
                      ? Icons.translate
                      : Icons.translate_outlined),
                  const SizedBox(width: 12),
                  Text(state.showTranslation
                      ? 'Hide translation'
                      : 'Show translation'),
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _AppAction.settings,
                child: Row(children: [
                  Icon(Icons.settings_outlined),
                  SizedBox(width: 12),
                  Text('Settings'),
                ]),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.ayahs.isEmpty
              ? _buildErrorState()
              : GestureDetector(
                  // Swipe left → next page, swipe right → previous page.
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
          : _BottomArea(currentPage: state.currentPage),
    );
  }

  // ── King Fahad page image view ──────────────────────────────────────────────

  Widget _buildReader(MushafState state) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark ||
        themeMode == AppThemeMode.inverted;
    final pageNum = state.currentPage.toString().padLeft(3, '0');
    final imageUrl =
        'https://cdn.qurancdn.com/images/quran/pages/page$pageNum.png';

    // The page image is white-on-dark in the printed Mushaf; invert for
    // dark/inverted themes so the background matches the app theme.
    Widget pageImg = Image.network(
      imageUrl,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        );
      },
      errorBuilder: (context, error, _) => _buildOfflineMessage(),
    );

    if (isDark) {
      pageImg = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1,  0,  0, 0, 255,
           0, -1,  0, 0, 255,
           0,  0, -1, 0, 255,
           0,  0,  0, 1,   0,
        ]),
        child: pageImg,
      );
    }

    // Translations shown as numbered list below the page image when enabled.
    final showTx = state.showTranslation && state.translations.isNotEmpty;

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pageImg,
          if (showTx) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _PageTranslations(
                ayahs: state.ayahs,
                translations: state.translations,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOfflineMessage() {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 300,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: colors.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'No internet connection',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The Madinah Mushaf pages require an internet\nconnection to display.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.outline),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
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

}

// ─── AppBar title ─────────────────────────────────────────────────────────────

// Matches the King Fahad Mushaf running header exactly:
//   Surah Ash-Shu‘arāʼ  (left, plain)          Juz’ 19  (right, plain)
class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.state});

  final MushafState state;

  @override
  Widget build(BuildContext context) {
    if (state.ayahs.isEmpty) return const Text('Quran');
    final firstSurah = state.surahFor(state.ayahs.first.surahNumber);
    final juzNumber = state.ayahs.first.juzNumber;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : const Color(0xFF2A2A2A);

    return Row(
      children: [
        // Surah transliteration name — left, plain, matches reference
        Expanded(
          child: Text(
            firstSurah?.nameSimple ?? 'Page ${state.currentPage}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: textColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Juz number — right, plain, matches reference
        Text(
          "Juz\u2019 $juzNumber",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

// ─── Translation list below King Fahad page image ────────────────────────────

class _PageTranslations extends StatelessWidget {
  const _PageTranslations({
    required this.ayahs,
    required this.translations,
  });

  final List<Ayah> ayahs;
  final Map<int, String> translations;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: colors.outlineVariant),
        const SizedBox(height: 4),
        for (final ayah in ayahs)
          if (translations[ayah.id] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ayah.verseKey}  ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
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

// ─── Bottom area: audio bar + reciter strip + page number ─────────────────────

class _BottomArea extends ConsumerWidget {
  const _BottomArea({required this.currentPage});

  final int currentPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AudioPlayerBar(),
        const _ReciterStrip(),
        _PageNav(currentPage: currentPage),
      ],
    );
  }
}

// ─── Reciter strip ─────────────────────────────────────────────────────────────

class _ReciterStrip extends ConsumerWidget {
  const _ReciterStrip();

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _ReciterPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    final colors = Theme.of(context).colorScheme;
    final isPlaying = audio.isPlaying;
    final reciterSlug = audio.reciter;
    final reciterName =
        AudioRepository.reciters[reciterSlug] ?? reciterSlug;

    return Semantics(
      label: 'Reciter: $reciterName. Tap to change reciter.',
      button: true,
      child: InkWell(
      onTap: () => _showPicker(context),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border(
            top: BorderSide(color: colors.outlineVariant, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              isPlaying ? Icons.volume_up : Icons.headphones,
              size: 18,
              color: colors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                reciterName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.expand_less,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ─── Reciter picker sheet ──────────────────────────────────────────────────────

class _ReciterPickerSheet extends ConsumerWidget {
  const _ReciterPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    final notifier = ref.read(audioProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final reciters = AudioRepository.reciters;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Select Reciter',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
          ),
          const Divider(height: 1),
          for (final entry in reciters.entries)
            ListTile(
              title: Text(entry.value),
              trailing: audio.reciter == entry.key
                  ? Icon(Icons.check, color: colors.primary)
                  : null,
              onTap: () {
                notifier.setReciter(entry.key);
                Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PageNav extends StatelessWidget {
  const _PageNav({required this.currentPage});

  final int currentPage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 36,
      alignment: Alignment.center,
      child: Text(
        '$currentPage',
        style: TextStyle(
          fontSize: 12,
          color: colors.outline,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
