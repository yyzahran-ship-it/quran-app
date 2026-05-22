import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/surah.dart';

/// Surah header styled after the King Fahad Quran Printing Complex (KFGQPC)
/// printed Mushaf:
///   • Double-line gold ornamental border frame
///   • Arabic surah name in UthmanicHafs 34 px
///   • Makkiyyah / Madaniyyah chip in gold palette
///   • Verse count and surah number chips
///   • Gold divider + centred Bismillah (omitted for At-Tawbah, surah 9)
class SurahHeader extends StatelessWidget {
  const SurahHeader({super.key, required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Parchment background for the header block
    final headerBg = isDark ? const Color(0xFF1A2A1A) : kMushafahCream;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subTextColor =
        isDark ? Colors.white70 : const Color(0xFF3E3E3E);

    return Container(
      width: double.infinity,
      // Outer gold border
      decoration: BoxDecoration(
        color: headerBg,
        border: Border.all(color: kMushafahGold, width: 2),
      ),
      child: Container(
        // Inner gold border — double-frame effect of the printed Mushaf
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: kMushafahGoldLight, width: 0.8),
        ),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          children: [
            // ── Arabic surah name ──────────────────────────────────────────
            Text(
              surah.nameArabic,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kArabicFont,
                fontSize: 34,
                fontWeight: FontWeight.w400,
                height: 1.8,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),

            // ── English name · transliteration ────────────────────────────
            Text(
              '${surah.nameSimple}  ·  ${surah.nameEnglish}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: subTextColor,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),

            // ── Metadata chips ─────────────────────────────────────────────
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                _GoldChip(
                  label: surah.revelationPlace == 'makkah'
                      ? 'مكية  Makkiyyah'
                      : 'مدنية  Madaniyyah',
                  isDark: isDark,
                ),
                _GoldChip(
                    label: '${surah.versesCount} verses', isDark: isDark),
                _GoldChip(label: 'Surah ${surah.id}', isDark: isDark),
              ],
            ),

            // ── Bismillah (omitted for At-Tawbah, surah 9) ────────────────
            if (surah.bismillahPre) ...[
              const SizedBox(height: 14),
              // Gold ornamental divider line
              Row(
                children: [
                  Expanded(child: Container(height: 0.8, color: kMushafahGold)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(
                      Icons.brightness_1,
                      size: 6,
                      color: kMushafahGold,
                    ),
                  ),
                  Expanded(child: Container(height: 0.8, color: kMushafahGold)),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kArabicFont,
                  fontSize: 26,
                  fontWeight: FontWeight.w400,
                  height: 2.0,
                  color: textColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Gold ornamental chip ─────────────────────────────────────────────────────

class _GoldChip extends StatelessWidget {
  const _GoldChip({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A3A2A)
            : const Color(0xFFF5E6C8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kMushafahGold, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? kMushafahGoldLight : kMushafahGreen,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
