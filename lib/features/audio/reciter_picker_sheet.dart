import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_models.dart';
import 'audio_provider.dart';
import 'reciter_provider.dart';

// Bottom sheet for selecting a reciter and starting playback.
// [surahNumber] is the surah that will start playing on selection.
class ReciterPickerSheet extends ConsumerWidget {
  const ReciterPickerSheet({super.key, required this.surahNumber});

  final int surahNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recitersAsync = ref.watch(recitersProvider);
    final selectedId = ref.watch(selectedReciterIdProvider);
    final colors = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            _handle(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.headphones, size: 20, color: colors.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Choose Reciter',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant),
            Expanded(
              child: recitersAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded,
                            size: 48, color: colors.outline),
                        const SizedBox(height: 12),
                        Text(
                          'Could not load reciters.\nCheck your internet connection.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          onPressed: () =>
                              ref.invalidate(recitersProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (reciters) => ListView.builder(
                  controller: scrollController,
                  itemCount: reciters.length,
                  itemBuilder: (ctx, i) {
                    final reciter = reciters[i];
                    final isSelected = selectedId == reciter.id ||
                        (selectedId == null && i == 0);
                    return _ReciterTile(
                      reciter: reciter,
                      isSelected: isSelected,
                      onTap: () {
                        ref.read(selectedReciterIdProvider.notifier).state =
                            reciter.id;
                        Navigator.of(context).pop();
                        ref
                            .read(audioProvider.notifier)
                            .playSurah(surahNumber, reciter: reciter);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _handle(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

class _ReciterTile extends StatelessWidget {
  const _ReciterTile({
    required this.reciter,
    required this.isSelected,
    required this.onTap,
  });

  final QuranicReciter reciter;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        isSelected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: isSelected ? colors.primary : colors.outline,
        size: 22,
      ),
      title: Row(
          children: [
            Flexible(
              child: Text(
                reciter.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? colors.primary : null,
                ),
              ),
            ),
            if (reciter.supportsVerseTracking) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '⟨ tracking ⟩',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      subtitle: reciter.style != null
          ? Text(
              reciter.style!,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            )
          : null,
      trailing: reciter.arabicName != null
          ? ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                reciter.arabicName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'AmiriQuran',
                  fontSize: 15,
                  color: colors.onSurfaceVariant,
                ),
              ),
            )
          : null,
      selected: isSelected,
      selectedTileColor: colors.primaryContainer.withAlpha(80),
      onTap: onTap,
    );
  }
}
