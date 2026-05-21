import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import 'hifz_provider.dart';
import 'hifz_review_screen.dart';
import 'khatma_planner.dart';

class HifzDashboard extends ConsumerWidget {
  const HifzDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(hifzStatsProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hifz', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Memorization dashboard', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.calendar_month_outlined),
        label: const Text('Khatma planner'),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => KhatmaPlannerSheet(ref: ref),
        ),
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stats) => _buildDashboard(context, stats, colors),
      ),
    );
  }

  Widget _buildDashboard(
      BuildContext context, HifzStats stats, ColorScheme colors) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Khatma goal banner (visible when a goal is set).
        const KhatmaGoalBanner(),
        const SizedBox(height: 16),
        // Due card — main CTA.
        _DueCard(stats: stats, colors: colors, context: context),
        const SizedBox(height: 16),
        // Streak + stats row.
        Row(
          children: [
            _StreakCard(stats: stats, colors: colors),
            const SizedBox(width: 12),
            _StatCard(
              label: 'Mature',
              value: '${stats.matureCount}',
              icon: Icons.verified_outlined,
              colors: colors,
              highlight: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatCard(
              label: 'Total cards',
              value: '${stats.total}',
              icon: Icons.layers_outlined,
              colors: colors,
            ),
            const SizedBox(width: 12),
            _StatCard(
              label: 'Learning',
              value: '${stats.total - stats.matureCount}',
              icon: Icons.school_outlined,
              colors: colors,
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Quran progress bars.
        if (stats.total > 0) _ProgressSection(stats: stats, colors: colors),
        const SizedBox(height: 20),
        Text(
          'A card becomes "mature" after its interval reaches 21 days. '
          'Reviews are scheduled by the FSRS algorithm for maximum retention.',
          style: TextStyle(fontSize: 12, color: colors.outlineVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── Due card ─────────────────────────────────────────────────────────────────

class _DueCard extends StatelessWidget {
  const _DueCard(
      {required this.stats, required this.colors, required this.context});
  final HifzStats stats;
  final ColorScheme colors;
  final BuildContext context;

  @override
  Widget build(BuildContext c) {
    final hasDue = stats.dueCount > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasDue
              ? [colors.primary, colors.primary.withValues(alpha: 0.7)]
              : [colors.surfaceContainerHighest, colors.surfaceContainerHighest],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasDue
                    ? Icons.notifications_active_outlined
                    : Icons.check_circle_outline,
                color: hasDue ? colors.onPrimary : colors.outline,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                hasDue
                    ? '${stats.dueCount} card${stats.dueCount > 1 ? 's' : ''} due'
                    : 'All caught up!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: hasDue ? colors.onPrimary : colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasDue
                ? 'Your review session is ready.'
                : 'No cards are due right now. Add more ayahs or check back later.',
            style: TextStyle(
              fontSize: 13,
              color: hasDue
                  ? colors.onPrimary.withValues(alpha: 0.85)
                  : colors.outline,
            ),
          ),
          if (hasDue) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.onPrimary,
                  foregroundColor: colors.primary,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HifzReviewScreen()),
                ),
                child: const Text('Start Review'),
              ),
            ),
          ],
          if (stats.total == 0) ...[
            const SizedBox(height: 12),
            Text(
              'Tip: tap any ayah in the reader and press "Add to Hifz" to start.',
              style: TextStyle(fontSize: 12, color: colors.outlineVariant),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Streak card ──────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.stats, required this.colors});
  final HifzStats stats;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final streak = stats.currentStreak;
    final hasStreak = streak > 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hasStreak
              ? Colors.orange.shade50.withValues(alpha: 0.6)
              : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: hasStreak
              ? Border.all(
                  color: Colors.orange.shade300.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          children: [
            Text(
              hasStreak ? '🔥' : '💤',
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasStreak ? '$streak day${streak == 1 ? '' : 's'}' : 'No streak',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: hasStreak
                        ? Colors.orange.shade700
                        : colors.onSurface,
                  ),
                ),
                Text(
                  hasStreak
                      ? 'Best: ${stats.longestStreak}d'
                      : 'Review daily',
                  style: TextStyle(
                    fontSize: 11,
                    color: hasStreak
                        ? Colors.orange.shade600
                        : colors.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Progress section ─────────────────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.stats, required this.colors});
  final HifzStats stats;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final addedPct = (stats.quranProgress * 100).toStringAsFixed(1);
    final maturePct = (stats.quranMatureProgress * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress toward full Quran',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _ProgressRow(
            label: 'Added to Hifz',
            value: stats.total,
            total: kTotalAyahs,
            pct: addedPct,
            color: colors.primary,
            colors: colors,
          ),
          const SizedBox(height: 10),
          _ProgressRow(
            label: 'Mature (≥21 days)',
            value: stats.matureCount,
            total: kTotalAyahs,
            pct: maturePct,
            color: Colors.green.shade600,
            colors: colors,
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.total,
    required this.pct,
    required this.color,
    required this.colors,
  });
  final String label;
  final int value;
  final int total;
  final String pct;
  final Color color;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
            Text(
              '$value / $total  ($pct%)',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Semantics(
          label: '$label: $value of $total ($pct%)',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / total,
              minHeight: 8,
              backgroundColor: colors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Generic stat card ────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
    this.highlight = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final ColorScheme colors;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: highlight
              ? colors.secondaryContainer
              : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: highlight
                    ? colors.onSecondaryContainer
                    : colors.outline),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: highlight
                        ? colors.onSecondaryContainer
                        : colors.onSurface,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: highlight
                        ? colors.onSecondaryContainer.withValues(alpha: 0.7)
                        : colors.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
