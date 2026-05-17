import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../mushaf_provider.dart';

/// Modal bottom sheet listing all 30 juzs. Tapping one jumps the reader.
Future<void> showJuzJumpDialog(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _JuzJumpSheet(),
  );
}

class _JuzJumpSheet extends ConsumerWidget {
  const _JuzJumpSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final currentJuz = ref.watch(mushafProvider).ayahs.firstOrNull?.juzNumber;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Icon(Icons.format_list_numbered, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  'Jump to Juz',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: GridView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.1,
              ),
              itemCount: 30,
              itemBuilder: (context, index) {
                final juzNumber = index + 1;
                final isSelected = juzNumber == currentJuz;
                return _JuzCell(
                  juzNumber: juzNumber,
                  isSelected: isSelected,
                  onTap: () {
                    Navigator.pop(context);
                    ref
                        .read(mushafProvider.notifier)
                        .navigateToJuz(juzNumber);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _JuzCell extends StatelessWidget {
  const _JuzCell({
    required this.juzNumber,
    required this.isSelected,
    required this.onTap,
  });

  final int juzNumber;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$juzNumber',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? colors.onPrimary : colors.onSurfaceVariant,
              ),
            ),
            Text(
              'Juz',
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? colors.onPrimary.withValues(alpha: 0.8)
                    : colors.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
