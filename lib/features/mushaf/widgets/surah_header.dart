import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/surah.dart';

/// Displays the surah name, English translation, revelation place, and
/// the Bismillah line (omitted for At-Tawbah, surah 9).
class SurahHeader extends StatelessWidget {
  const SurahHeader({super.key, required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primaryContainer,
            colors.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Arabic surah name
          Text(
            surah.nameArabic,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: kArabicFont,
              fontSize: 32,
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          // English name + transliteration
          Text(
            '${surah.nameSimple} · ${surah.nameEnglish}',
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          // Metadata row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MetaChip(
                label: surah.revelationPlace == 'makkah' ? 'Makki' : 'Madani',
                colors: colors,
              ),
              const SizedBox(width: 8),
              _MetaChip(
                label: '${surah.versesCount} verses',
                colors: colors,
              ),
              const SizedBox(width: 8),
              _MetaChip(label: 'Surah ${surah.id}', colors: colors),
            ],
          ),
          // Bismillah — shown for all surahs except At-Tawbah (9)
          if (surah.bismillahPre) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text(
              'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: kArabicFont,
                fontSize: 24,
                color: colors.onPrimaryContainer,
                height: 2.0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.colors});

  final String label;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: colors.onPrimaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: colors.onPrimaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
