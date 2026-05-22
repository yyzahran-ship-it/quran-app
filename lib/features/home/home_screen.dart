import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/quran_repository.dart';
import '../../domain/entities/juz.dart';
import '../../domain/entities/surah.dart';
import '../bookmarks/bookmarks_provider.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../memorization/hifz_dashboard.dart';
import '../mushaf/mushaf_provider.dart';
import '../mushaf/mushaf_screen.dart';
import '../mushaf/search_screen.dart';
import '../settings/settings_screen.dart';

// ─── Juz list provider ────────────────────────────────────────────────────────

final juzsProvider = FutureProvider<List<Juz>>((ref) {
  return ref.read(quranRepositoryProvider).getAllJuzs();
});

// ─── Home screen ──────────────────────────────────────────────────────────────

enum _MenuAction { hifz, settings }

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Quran',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
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
            PopupMenuButton<_MenuAction>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More',
              onSelected: (action) {
                switch (action) {
                  case _MenuAction.hifz:
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const HifzDashboard()));
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
          bottom: const TabBar(
            tabs: [
              Tab(text: 'SURAHS'),
              Tab(text: "JUZ'"),
              Tab(text: 'BOOKMARKS'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SurahsTab(),
            _JuzTab(),
            _BookmarksTab(),
          ],
        ),
      ),
    );
  }
}

// ─── Surahs tab ───────────────────────────────────────────────────────────────

class _SurahsTab extends ConsumerWidget {
  const _SurahsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surahs = ref.watch(mushafProvider.select((s) => s.surahs));
    final juzsAsync = ref.watch(juzsProvider);

    if (surahs.isEmpty) return const Center(child: CircularProgressIndicator());

    return juzsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _SurahListView(surahs: surahs, juzs: const []),
      data: (juzs) => _SurahListView(surahs: surahs, juzs: juzs),
    );
  }
}

class _SurahListView extends ConsumerWidget {
  const _SurahListView({required this.surahs, required this.juzs});

  final List<Surah> surahs;
  final List<Juz> juzs;

  // Interleave juz-separator rows with surah rows.
  // A juz separator appears before the first surah that starts at or after
  // the juz boundary — this matches the printed Mushaf index style where
  // consecutive juz boundaries inside a long surah are shown between surahs.
  List<Object> _buildItems() {
    final items = <Object>[];
    int verseId = 0;
    int juzIdx = 0;

    for (final surah in surahs) {
      final surahFirst = verseId + 1;
      while (juzIdx < juzs.length &&
          juzs[juzIdx].firstVerseId <= surahFirst) {
        items.add(juzs[juzIdx]);
        juzIdx++;
      }
      items.add(surah);
      verseId += surah.versesCount;
    }
    return items;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _buildItems();
    final colors = Theme.of(context).colorScheme;

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        if (item is Juz) {
          return _JuzSeparatorRow(juz: item, colors: colors);
        }
        final surah = item as Surah;
        return _SurahRow(
          surah: surah,
          page: kSurahStartPages[surah.id - 1],
          onTap: () {
            ref.read(mushafProvider.notifier).navigateToSurah(surah.id);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MushafScreen()),
            );
          },
        );
      },
    );
  }
}

class _JuzSeparatorRow extends StatelessWidget {
  const _JuzSeparatorRow({required this.juz, required this.colors});

  final Juz juz;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          Text(
            "Juz' ${juz.juzNumber}",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            '${kJuzStartPages[juz.juzNumber - 1]}',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SurahRow extends StatelessWidget {
  const _SurahRow({
    required this.surah,
    required this.page,
    required this.onTap,
  });

  final Surah surah;
  final int page;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final revelation =
        surah.revelationPlace == 'makkah' ? 'Makki' : 'Madani';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceContainerHighest,
              ),
              alignment: Alignment.center,
              child: Text(
                '${surah.id}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surah.nameSimple,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$revelation · ${surah.versesCount} verses',
                    style: TextStyle(
                        fontSize: 12, color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(
              '$page',
              style:
                  TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Juz' tab ─────────────────────────────────────────────────────────────────

class _JuzTab extends ConsumerWidget {
  const _JuzTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final juzsAsync = ref.watch(juzsProvider);
    final colors = Theme.of(context).colorScheme;

    return juzsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          const Center(child: Text('Could not load juz list')),
      data: (juzs) => ListView.builder(
        itemCount: juzs.length,
        itemBuilder: (context, i) {
          final juz = juzs[i];
          return ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceContainerHighest,
              ),
              alignment: Alignment.center,
              child: Text(
                '${juz.juzNumber}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            title: Text(
              "Juz' ${juz.juzNumber}",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${juz.versesCount} verses',
              style:
                  TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            trailing: Text(
              'P. ${kJuzStartPages[juz.juzNumber - 1]}',
              style:
                  TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
            onTap: () {
              ref.read(mushafProvider.notifier).navigateToJuz(juz.juzNumber);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MushafScreen()),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Bookmarks tab ────────────────────────────────────────────────────────────
//
// Full-featured: tag filter chips, swipe-to-delete, export, navigate to ayah.
// Mirrors BookmarksScreen functionality directly inside the home tab so
// users don't have to open the Mushaf reader to manage their bookmarks.

class _BookmarksTab extends ConsumerStatefulWidget {
  const _BookmarksTab();

  @override
  ConsumerState<_BookmarksTab> createState() => _BookmarksTabState();
}

class _BookmarksTabState extends ConsumerState<_BookmarksTab> {
  String? _filterTag;

  @override
  Widget build(BuildContext context) {
    final allBookmarks = ref.watch(bookmarksProvider);
    final colors = Theme.of(context).colorScheme;

    final tags = allBookmarks
        .map((b) => b.tag)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

    final shown = _filterTag == null
        ? allBookmarks
        : allBookmarks.where((b) => b.tag == _filterTag).toList();

    if (allBookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: colors.outlineVariant),
            const SizedBox(height: 12),
            Text('No bookmarks yet', style: TextStyle(color: colors.outline)),
            const SizedBox(height: 4),
            Text(
              'Open a surah, tap any ayah, and press Bookmark',
              style: TextStyle(fontSize: 12, color: colors.outlineVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Tag filter row + export action.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _filterTag == null,
                        onSelected: (_) => setState(() => _filterTag = null),
                      ),
                      ...tags.map((tag) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: FilterChip(
                              label: Text(tag),
                              selected: _filterTag == tag,
                              onSelected: (_) => setState(
                                () => _filterTag =
                                    _filterTag == tag ? null : tag,
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              // Opens the full BookmarksScreen for export / clear-all.
              IconButton(
                icon: const Icon(Icons.more_horiz),
                tooltip: 'Manage bookmarks',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BookmarksScreen()),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text(
                    'No bookmarks tagged "$_filterTag"',
                    style: TextStyle(color: colors.outline),
                  ),
                )
              : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final bm = shown[i];
                    return Dismissible(
                      key: ValueKey(bm.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: colors.errorContainer,
                        child: Icon(Icons.delete_outline,
                            color: colors.onErrorContainer),
                      ),
                      onDismissed: (_) {
                        ref.read(bookmarksProvider.notifier).toggle(
                              ayahId: bm.ayahId,
                              surahNumber: bm.surahNumber,
                              ayahNumber: bm.ayahNumber,
                            );
                      },
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colors.primaryContainer,
                          child: Text(
                            '${bm.surahNumber}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                        ),
                        title: Text(bm.verseKey,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _formatDate(bm.createdAt),
                          style: TextStyle(
                              fontSize: 12, color: colors.outlineVariant),
                        ),
                        trailing: bm.tag != null
                            ? Chip(
                                label: Text(bm.tag!,
                                    style: const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              )
                            : null,
                        onTap: () {
                          // Navigate to the exact ayah, not just the surah.
                          ref
                              .read(mushafProvider.notifier)
                              .navigateToAyah(bm.surahNumber, bm.ayahNumber);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const MushafScreen()),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
