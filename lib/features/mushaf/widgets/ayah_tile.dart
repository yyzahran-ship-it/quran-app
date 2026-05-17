import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/ayah.dart';
import '../../audio/audio_provider.dart';

/// Renders one ayah: Arabic text (RTL) with its number badge on the left.
/// Subscribes to [audioProvider] via select() so only this tile rebuilds
/// when its own highlight state changes — not the entire list.
class AyahTile extends ConsumerWidget {
  const AyahTile({
    super.key,
    required this.ayah,
    this.arabicFontSize = 26.0,
    this.translationText,
    this.onTap,
  });

  final Ayah ayah;
  final double arabicFontSize;
  final String? translationText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHighlighted = ref.watch(
      audioProvider.select((audio) =>
          audio.surahNumber == ayah.surahNumber &&
          audio.currentAyahNumber == ayah.ayahNumber),
    );
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isHighlighted
              ? colors.primaryContainer.withValues(alpha: 0.4)
              : colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isHighlighted ? colors.primary : colors.outlineVariant,
            width: isHighlighted ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ayah number badge
            _AyahNumberBadge(number: ayah.ayahNumber, colors: colors),
            const SizedBox(width: 12),
            // Arabic text + optional translation — RTL, full-width
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    ayah.textUthmani,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: kArabicFont,
                      fontSize: arabicFontSize,
                      height: 2.0, // generous line height for diacritics
                      color: colors.onSurface,
                    ),
                  ),
                  if (translationText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      translationText!,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AyahNumberBadge extends StatelessWidget {
  const _AyahNumberBadge({required this.number, required this.colors});

  final int number;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primaryContainer,
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.onPrimaryContainer,
        ),
      ),
    );
  }
}
