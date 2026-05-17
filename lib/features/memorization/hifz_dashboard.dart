import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'hifz_provider.dart';
import 'hifz_review_screen.dart';

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
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stats) => _buildDashboard(context, ref, stats, colors),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    HifzStats stats,
    ColorScheme colors,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Due card — main CTA.
        _DueCard(stats: stats, colors: colors, context: context),
        const SizedBox(height: 20),
        // Stats grid.
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
              label: 'Learning',
              value: '${stats.total - stats.matureCount}',
              icon: Icons.school_outlined,
              colors: colors,
            ),
            const SizedBox(width: 12),
            _StatCard(
              label: 'Due now',
              value: '${stats.dueCount}',
              icon: Icons.schedule_outlined,
              colors: colors,
            ),
          ],
        ),
        const SizedBox(height: 32),
        // Info text.
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
                hasDue ? Icons.notifications_active_outlined : Icons.check_circle_outline,
                color: hasDue ? colors.onPrimary : colors.outline,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                hasDue ? '${stats.dueCount} card${stats.dueCount > 1 ? 's' : ''} due' : 'All caught up!',
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
