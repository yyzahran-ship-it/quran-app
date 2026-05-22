import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../mushaf/mushaf_provider.dart';
import 'bookmarks_provider.dart';

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  String? _filterTag;

  @override
  Widget build(BuildContext context) {
    final allBookmarks = ref.watch(bookmarksProvider);
    final colors = Theme.of(context).colorScheme;

    // Collect distinct tags.
    final tags = allBookmarks
        .map((b) => b.tag)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

    final shown = _filterTag == null
        ? allBookmarks
        : allBookmarks.where((b) => b.tag == _filterTag).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        actions: [
          if (allBookmarks.isNotEmpty) ...[
            IconButton(
              tooltip: 'Export bookmarks',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => _exportBookmarks(context, allBookmarks),
            ),
            TextButton(
              onPressed: () => _confirmClearAll(context, ref),
              child: const Text('Clear all'),
            ),
          ],
        ],
      ),
      body: allBookmarks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_border,
                      size: 64, color: colors.outlineVariant),
                  const SizedBox(height: 12),
                  Text('No bookmarks yet',
                      style: TextStyle(color: colors.outline)),
                  const SizedBox(height: 4),
                  Text(
                    'Tap any ayah to bookmark it',
                    style:
                        TextStyle(fontSize: 12, color: colors.outlineVariant),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                if (tags.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: _filterTag == null,
                          onSelected: (_) =>
                              setState(() => _filterTag = null),
                        ),
                        ...tags.map((tag) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: FilterChip(
                                label: Text(tag),
                                selected: _filterTag == tag,
                                onSelected: (_) => setState(
                                    () => _filterTag =
                                        _filterTag == tag ? null : tag),
                              ),
                            )),
                      ],
                    ),
                  ),
                Expanded(
                  child: shown.isEmpty
                      ? Center(
                          child: Text('No bookmarks tagged "$_filterTag"',
                              style: TextStyle(color: colors.outline)),
                        )
                      : ListView.builder(
                          itemCount: shown.length,
                          itemBuilder: (context, index) {
                            final bm = shown[index];
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
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(_formatDate(bm.createdAt),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: colors.outlineVariant)),
                                trailing: bm.tag != null
                                    ? Chip(
                                        label: Text(bm.tag!,
                                            style: const TextStyle(
                                                fontSize: 11)),
                                        padding: EdgeInsets.zero,
                                        visualDensity:
                                            VisualDensity.compact,
                                      )
                                    : null,
                                onTap: () {
                                  ref
                                      .read(mushafProvider.notifier)
                                      .navigateToAyah(
                                          bm.surahNumber, bm.ayahNumber);
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  /// Build a date string in YYYY-MM-DD format for the JSON export.
  String _isoDate(DateTime dt) {
    return '${dt.year}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  /// Export all bookmarks as a JSON file and open the system share sheet.
  Future<void> _exportBookmarks(
      BuildContext context, List<dynamic> bookmarks) async {
    try {
      // Build the JSON payload.
      final list = bookmarks.map((bm) {
        return {
          'verse': bm.verseKey,             // e.g. "2:255"
          'surah': bm.surahNumber,
          'ayah': bm.ayahNumber,
          'tag': bm.tag ?? '',
          'saved': _isoDate(bm.createdAt),  // e.g. "2026-05-22"
        };
      }).toList();

      final jsonString = const JsonEncoder.withIndent('  ').convert(list);

      // Write to a temp file.
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/quran_bookmarks.json');
      await file.writeAsString(jsonString);

      // Open system share sheet.
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Quran Bookmarks',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all bookmarks?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear all')),
        ],
      ),
    );
    if (confirmed == true) {
      final bms = ref.read(bookmarksProvider);
      for (final bm in bms) {
        await ref.read(bookmarksProvider.notifier).toggle(
              ayahId: bm.ayahId,
              surahNumber: bm.surahNumber,
              ayahNumber: bm.ayahNumber,
            );
      }
    }
  }
}
