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
//
// Shows all 30 Juzs as sticky section headers, each with 8 rub' (quarter-hizb)
// entries below it. The pie-chart circle shows which quarter of the hizb the
// entry is; the hizb number is printed inside for Q1 entries (hizb starts).
// Tapping any row navigates directly to that page in the Mushaf.

// One navigable entry within a Juz.
class _RubEntry {
  const _RubEntry({
    required this.juz,
    required this.hizb,
    required this.quarter,
    required this.surahNumber,
    required this.ayahNumber,
    required this.surahName,
    required this.arabicText,
    required this.pageNumber,
  });

  final int juz;
  final int hizb;
  final int quarter; // 1-4
  final int surahNumber;
  final int ayahNumber;
  final String surahName;
  final String arabicText;
  final int pageNumber;
}

// Compute (surahNumber, ayahNumber) from a 1-based global ayah ID.
(int, int) _surahAyahFromGlobalId(int globalId) {
  int remaining = globalId;
  for (int s = 0; s < kSurahVerseCounts.length; s++) {
    if (remaining <= kSurahVerseCounts[s]) return (s + 1, remaining);
    remaining -= kSurahVerseCounts[s];
  }
  return (114, 1);
}

// Builds 8 rub' page anchors for a given Juz by dividing its page range
// into 8 equal slices, then snapping to the first ayah on each slice's page.
final juzBrowserProvider = FutureProvider<List<_RubEntry>>((ref) async {
  final repo = ref.read(quranRepositoryProvider);

  // Collect the 240 page anchors (1 per rub') and their global ayah IDs.
  final pageAnchors = <int>[];     // page number per rub'
  final globalIds   = <int>[];     // global ayah ID per rub'

  for (int juz = 1; juz <= 30; juz++) {
    final startPage = kJuzStartPages[juz - 1];
    final endPage   = juz < 30 ? kJuzStartPages[juz] - 1 : 604;
    final total     = endPage - startPage + 1;
    for (int i = 0; i < 8; i++) {
      final page     = startPage + (i * total ~/ 8);
      final globalId = kPageFirstAyah[page - 1];
      pageAnchors.add(page);
      globalIds.add(globalId);
    }
  }

  // Batch-fetch all 240 Arabic texts in one DB query.
  final texts     = await repo.getAyahTextsByIds(globalIds.toSet().toList());
  final surahRows = await repo.getAllSurahs();
  final surahNames = {for (final s in surahRows) s.id: s.nameSimple};

  final entries = <_RubEntry>[];
  for (int idx = 0; idx < 240; idx++) {
    final juz     = idx ~/ 8 + 1;
    final hizb    = idx ~/ 4 + 1;   // hizb 1-60
    final quarter = idx  % 4 + 1;   // quarter 1-4
    final gId     = globalIds[idx];
    final page    = pageAnchors[idx];
    final (surahNum, ayahNum) = _surahAyahFromGlobalId(gId);

    entries.add(_RubEntry(
      juz:        juz,
      hizb:       hizb,
      quarter:    quarter,
      surahNumber: surahNum,
      ayahNumber:  ayahNum,
      surahName:   surahNames[surahNum] ?? 'Surah $surahNum',
      arabicText:  texts[gId] ?? '',
      pageNumber:  page,
    ));
  }
  return entries;
});

class _JuzTab extends ConsumerWidget {
  const _JuzTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(juzBrowserProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (err, __) => Center(child: Text('Juz load error: $err')),
      data:    (entries) => _JuzBrowserList(entries: entries),
    );
  }
}

// Data bundle passed to each Juz section header.
class _JuzHeaderData {
  const _JuzHeaderData({
    required this.juzNumber,
    required this.startPage,
    required this.endPage,
    required this.startSurahName,
    required this.startAyahNumber,
  });

  final int juzNumber;
  final int startPage;
  final int endPage;
  final String startSurahName;
  final int startAyahNumber;
}

class _JuzBrowserList extends StatelessWidget {
  const _JuzBrowserList({required this.entries});

  final List<_RubEntry> entries;

  @override
  Widget build(BuildContext context) {
    // Build a flat list of (header | entry) items.
    // A header row is emitted before the first entry of each Juz.
    final items = <Object>[];
    int lastJuz = 0;
    for (final e in entries) {
      if (e.juz != lastJuz) {
        final endPage = e.juz < 30 ? kJuzStartPages[e.juz] - 1 : 604;
        items.add(_JuzHeaderData(
          juzNumber: e.juz,
          startPage: kJuzStartPages[e.juz - 1],
          endPage: endPage,
          startSurahName: e.surahName,
          startAyahNumber: e.ayahNumber,
        ));
        lastJuz = e.juz;
      }
      items.add(e);
    }

    final colors = Theme.of(context).colorScheme;

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        if (item is _JuzHeaderData) {
          return _JuzHeader(data: item, colors: colors);
        }
        return _RubRow(entry: item as _RubEntry, colors: colors);
      },
    );
  }
}

// ── Juz section header ────────────────────────────────────────────────────────

class _JuzHeader extends StatelessWidget {
  const _JuzHeader({required this.data, required this.colors});

  final _JuzHeaderData data;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.85),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Juz' ${data.juzNumber}",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${data.startSurahName} ${data.startAyahNumber}',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'p.${data.startPage}–${data.endPage}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rub' entry row ────────────────────────────────────────────────────────────

class _RubRow extends ConsumerWidget {
  const _RubRow({required this.entry, required this.colors});

  final _RubEntry entry;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Truncate long Arabic text with ellipsis.
    final arabic = entry.arabicText.length > 35
        ? '${entry.arabicText.substring(0, 35)}...'
        : entry.arabicText;

    return InkWell(
      onTap: () {
        ref.read(mushafProvider.notifier).navigateToPage(entry.pageNumber);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MushafScreen()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _HizbPie(
              quarter: entry.quarter,
              hizbNumber: entry.quarter == 1 ? entry.hizb : null,
              color: colors.primary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    arabic,
                    textDirection: TextDirection.rtl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kArabicFont,
                      fontSize: 16,
                      height: 1.6,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Surah ${entry.surahName}, Ayah ${entry.ayahNumber}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${entry.pageNumber}',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hizb pie-chart circle ─────────────────────────────────────────────────────
//
// Quarter 1 (hizb start): shows hizb number + 1/4 filled arc.
// Quarter 2 (نصف):        half-filled arc.
// Quarter 3 (ثلاثة أرباع): 3/4-filled arc.
// Quarter 4 (end of hizb): fully-filled circle (no number).

class _HizbPie extends StatelessWidget {
  const _HizbPie({
    required this.quarter,
    required this.color,
    this.hizbNumber,
  });

  final int quarter;      // 1-4
  final Color color;
  final int? hizbNumber;  // non-null only for Q1 (hizb start)

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: CustomPaint(
        painter: _PiePainter(
          quarter: quarter,
          fillColor: color.withValues(alpha: 0.75),
          trackColor: color.withValues(alpha: 0.18),
        ),
        child: Center(
          child: hizbNumber != null
              ? Text(
                  '$hizbNumber',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  const _PiePainter({
    required this.quarter,
    required this.fillColor,
    required this.trackColor,
  });

  final int quarter;
  final Color fillColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = (size.width / 2) - 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Background track circle.
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = trackColor);

    // Filled arc — start at top (-π/2), sweep clockwise.
    final sweep = (quarter / 4) * 2 * 3.14159265;
    canvas.drawArc(
      rect,
      -3.14159265 / 2, // start at 12 o'clock
      sweep,
      true, // use centre (pie slice)
      Paint()..color = fillColor,
    );
  }

  @override
  bool shouldRepaint(_PiePainter old) =>
      old.quarter != quarter ||
      old.fillColor != fillColor ||
      old.trackColor != trackColor;
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
