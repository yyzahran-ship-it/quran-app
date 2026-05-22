import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/ayah.dart';
import '../../audio/audio_provider.dart';

// ─── Arabic-Indic numeral helper ──────────────────────────────────────────────
// The King Fahad Mushaf uses Arabic-Indic numerals (١٢٣) inside the
// ornamental end markers, matching the printed Mushaf exactly.

String _toArabicIndic(int n) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().split('').map((c) => digits[int.parse(c)]).join();
}

/// Renders one ayah in King Fahad Mushaf complex style:
///   • Warm cream (parchment) background with gold border
///   • Arabic text justified RTL in UthmanicHafs, line height 2.2
///   • Ornamental ۝ end marker with Arabic-Indic verse number
///   • Gold highlight border when the ayah is currently playing
///   • Optional English translation below
class AyahTile extends ConsumerWidget {
  const AyahTile({
    super.key,
    required this.ayah,
    this.arabicFontSize = 28.0,
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Parchment / dark background
    final tileBg = isDark
        ? (isHighlighted
            ? const Color(0xFF1E3A1E)
            : const Color(0xFF161E16))
        : (isHighlighted
            ? const Color(0xFFF5EDD0)
            : kMushafahCream);

    final borderColor = isHighlighted ? kMushafahGoldLight : kMushafahGold;
    final borderWidth = isHighlighted ? 1.5 : 0.8;

    final arabicTextColor =
        isDark ? Colors.white : const Color(0xFF1A1A1A);
    final translationColor =
        isDark ? Colors.white70 : const Color(0xFF4A4A4A);

    // Arabic text with ornamental end marker appended inline
    final arabicWithMarker =
        '${ayah.textUthmani}\u202F\u06DD${_toArabicIndic(ayah.ayahNumber)}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: kMushafahGold.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Arabic text block ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Text(
                arabicWithMarker,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.justify,
                style: TextStyle(
                  fontFamily: kArabicFont,
                  fontSize: arabicFontSize,
                  height: 2.2, // accommodates stacked tashkeel
                  color: arabicTextColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

            // ── Translation (optional) ───────────────────────────────────
            if (translationText != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 1, right: 1),
                child: Divider(
                  height: 1,
                  thickness: 0.5,
                  color: kMushafahGold.withValues(alpha: 0.4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Verse reference label
                    Text(
                      '${ayah.surahNumber}:${ayah.ayahNumber}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kMushafahGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        translationText!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: translationColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
