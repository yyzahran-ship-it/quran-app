import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../mushaf/mushaf_provider.dart';
import 'bookmarks_provider.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        actions: [
          if (bookmarks.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClearAll(context, ref),
              child: const Text('Clear all'),
            ),
        ],
      ),
      body: bookmarks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_border,
                      size: 64, color: colors.outlineVariant),
                  const SizedBox(height: 12),
                  Text(
                    'No bookmarks yet',
                    style: TextStyle(color: colors.outline),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap any ayah and press Bookmark',
                    style:
                        TextStyle(fontSize: 12, color: colors.outlineVariant),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: bookmarks.length,
              itemBuilder: (context, index) {
                final bm = bookmarks[index];
                return Dismissible(
                  key: ValueKey(bm.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: colors.errorContainer,
                    child:
                        Icon(Icons.delete_outline, color: colors.onErrorContainer),
                  ),
                  onDismissed: (_) {
                    ref
                        .read(bookmarksProvider.notifier)
                        .toggle(
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
                    title: Text(
                      bm.verseKey,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _formatDate(bm.createdAt),
                      style:
                          TextStyle(fontSize: 12, color: colors.outlineVariant),
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
                      ref
                          .read(mushafProvider.notifier)
                          .navigateToAyah(bm.surahNumber, bm.ayahNumber);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
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
