import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/ayah.dart';

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
///   • Optional English translation below
class AyahTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tileBg = isDark ? const Color(0xFF161E16) : kMushafahCream;
    final borderColor = kMushafahGold;
    const borderWidth = 0.8;

    final arabicTextColor =
        isDark ? Colors.white : const Color(0xFF1A1A1A);
    final translationColor =
        isDark ? Colors.white70 : const Color(0xFF4A4A4A);

    final arabicWithMarker =
        '${ayah.textUthmani} ۝${_toArabicIndic(ayah.ayahNumber)}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: borderColor, width: borderWidth),
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
                  height: 2.2,
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
