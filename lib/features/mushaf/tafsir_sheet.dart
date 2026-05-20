import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tafsir_repository.dart';

class TafsirSheet extends ConsumerWidget {
  const TafsirSheet({super.key, required this.verseKey});

  final String verseKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tafsirId = ref.watch(tafsirIdProvider);
    final tafsirKey = (tafsirId: tafsirId, verseKey: verseKey);
    final tafsirAsync = ref.watch(tafsirTextProvider(tafsirKey));
    final colors = Theme.of(context).colorScheme;

    final selectedTafsir = kTafsirs.firstWhere(
      (t) => t.id == tafsirId,
      orElse: () => kTafsirs.first,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tafsir — $verseKey',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DropdownButton<int>(
                    value: tafsirId,
                    underline: const SizedBox.shrink(),
                    items: kTafsirs
                        .map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                '${t.name} (${t.language})',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) ref.read(tafsirIdProvider.notifier).set(v);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Body
            Expanded(
              child: tafsirAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_outlined,
                            size: 48, color: colors.outlineVariant),
                        const SizedBox(height: 12),
                        const Text('Could not load tafsir'),
                        const SizedBox(height: 4),
                        Text(
                          'Check your internet connection',
                          style:
                              TextStyle(fontSize: 12, color: colors.outline),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () =>
                              ref.invalidate(tafsirTextProvider(tafsirKey)),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (text) => ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    Text(
                      text,
                      style: const TextStyle(fontSize: 14, height: 1.7),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '— ${selectedTafsir.name}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
