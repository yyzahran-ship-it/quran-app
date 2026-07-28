import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_models.dart';
import 'audio_provider.dart';
import 'reciter_provider.dart';

const _kBlack = Color(0xFF0A0A0A);
const _kGold = Color(0xFFC9A84C);
const _kGoldDim = Color(0xFF8A6D2A);
const _kDivider = Color(0xFF1A1A1A);
const _kSelectedBg = Color(0xFF161008);
const _kUnselectedName = Color(0xFFAAAAAA);
const _kUnselectedRadio = Color(0xFF444444);
const _kArabicUnsel = Color(0xFF555555);

// Bottom sheet for selecting a reciter and starting playback.
// [surahNumber] is the surah that will start playing on selection.
class ReciterPickerSheet extends ConsumerWidget {
  const ReciterPickerSheet({super.key, required this.surahNumber});

  final int surahNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recitersAsync = ref.watch(recitersProvider);
    final selectedId = ref.watch(selectedReciterIdProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: _kBlack,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _handle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.headphones, size: 20, color: _kGold),
                  const SizedBox(width: 10),
                  Text(
                    'Choose Reciter',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _kGold,
                          letterSpacing: 0.3,
                        ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _kDivider),
            Expanded(
              child: recitersAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: _kGold),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            size: 48, color: _kArabicUnsel),
                        const SizedBox(height: 12),
                        const Text(
                          'Could not load reciters.\nCheck your internet connection.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _kUnselectedName),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _kGold,
                            foregroundColor: _kBlack,
                          ),
                          onPressed: () => ref.invalidate(recitersProvider),
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

  Widget _handle() => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF333333),
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
    return InkWell(
      onTap: onTap,
      splashColor: _kGold.withAlpha(20),
      highlightColor: _kGold.withAlpha(10),
      child: Container(
        color: isSelected ? _kSelectedBg : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: const BoxConstraints(minHeight: 58),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? _kGold : _kUnselectedRadio,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          reciter.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected ? _kGold : _kUnselectedName,
                          ),
                        ),
                      ),
                      if (reciter.supportsVerseTracking) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: _kGold.withAlpha(38),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '⟨ tracking ⟩',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _kGold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (reciter.style != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      reciter.style!,
                      style: const TextStyle(
                          fontSize: 12, color: _kArabicUnsel),
                    ),
                  ],
                ],
              ),
            ),
            if (reciter.arabicName != null) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  reciter.arabicName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: 'AmiriQuran',
                    fontSize: 14,
                    color: isSelected ? _kGoldDim : _kArabicUnsel,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
