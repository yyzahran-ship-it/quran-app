import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../audio/audio_player_bar.dart';
import '../audio/audio_provider.dart';
import '../bookmarks/bookmarks_provider.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../bookmarks/note_editor_dialog.dart';
import '../../data/repositories/quran_repository.dart';
import '../memorization/hifz_dashboard.dart';
import '../memorization/hifz_provider.dart';
import '../settings/settings_screen.dart';
import 'widgets/juz_jump_dialog.dart';
import 'mushaf_provider.dart';
import 'search_screen.dart';
import 'widgets/ayah_tile.dart';
import 'widgets/surah_header.dart';
import 'widgets/surah_index_drawer.dart';

enum _MenuAction { hifz, bookmarks, settings }

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mushafProvider);

    return Scaffold(
      drawer: const SurahIndexDrawer(),
      appBar: AppBar(
        title: state.currentSurah == null
            ? const Text('Quran')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.currentSurah!.nameSimple,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    state.currentSurah!.nameEnglish,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
        actions: [
          // Search
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          // Juz jump
          IconButton(
            icon: const Icon(Icons.format_list_numbered_outlined),
            tooltip: 'Jump to Juz',
            onPressed: () => showJuzJumpDialog(context),
          ),
          // Translation toggle
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
          // Overflow menu: Hifz, Bookmarks, Settings
          PopupMenuButton<_MenuAction>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More',
            onSelected: (action) {
              switch (action) {
                case _MenuAction.hifz:
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HifzDashboard()));
                case _MenuAction.bookmarks:
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const BookmarksScreen()));
                case _MenuAction.settings:
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _MenuAction.hifz,
                child: ListTile(
                  leading: Icon(Icons.psychology_outlined),
                  title: Text('Hifz'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _MenuAction.bookmarks,
                child: ListTile(
                  leading: Icon(Icons.bookmarks_outlined),
                  title: Text('Bookmarks'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _MenuAction.settings,
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
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
    final fontSize = ref.watch(fontSizeProvider);
    final surah = state.currentSurah!;

    return ListView.builder(
      controller: _scrollController,
      itemCount: state.ayahs.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return SurahHeader(surah: surah);
        final ayah = state.ayahs[index - 1];

        // RepaintBoundary isolates each tile's repaint from its neighbours.
        return RepaintBoundary(
          child: AyahTile(
            ayah: ayah,
            arabicFontSize: fontSize,
            translationText: state.showTranslation
                ? state.translations[ayah.id]
                : null,
            onTap: () => _showAyahMenu(context, ayah),
          ),
        );
      },
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
            Text(
              'Could not load Quran data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The database may not have finished setting up. Tap Retry.',
              textAlign: TextAlign.center,
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

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showAyahMenu(BuildContext context, dynamic ayah) {
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Ayah $ayahKey',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const Divider(height: 1),
            // Play / pause
            ListTile(
              leading: Icon(
                isThisAyahPlaying
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
              ),
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
            // Bookmark toggle
            ListTile(
              leading: Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              ),
              title: Text(isBookmarked ? 'Remove bookmark' : 'Bookmark'),
              onTap: () {
                Navigator.pop(context);
                ref.read(bookmarksProvider.notifier).toggle(
                      ayahId: ayahId,
                      surahNumber: surahNumber,
                      ayahNumber: ayahNumber,
                    );
              },
            ),
            // Note
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
            // Hifz
            ListTile(
              leading: Icon(
                isInHifz
                    ? Icons.psychology
                    : Icons.psychology_outlined,
              ),
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
                // Invalidate so inHifzProvider refreshes.
                ref.invalidate(inHifzProvider(ayahId));
                ref.invalidate(hifzStatsProvider);
              },
            ),
            // Share
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share'),
              onTap: () => Navigator.pop(context),
            ),
          ],
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
        _BottomSurahNav(
          surahId: surahId,
          onPrevious: onPrevious,
          onNext: onNext,
        ),
      ],
    );
  }
}

// ─── Bottom surah navigation ──────────────────────────────────────────────────

class _BottomSurahNav extends StatelessWidget {
  const _BottomSurahNav({
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
