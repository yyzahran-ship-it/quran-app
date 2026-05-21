import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

// ─── Persistence ──────────────────────────────────────────────────────────────

const _kGoalDateKey = 'khatma_goal_date'; // stored as ISO-8601 date

class KhatmaGoalNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kGoalDateKey);
    if (s != null) state = DateTime.tryParse(s);
  }

  Future<void> setGoal(DateTime date) async {
    state = date;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGoalDateKey, date.toIso8601String());
  }

  Future<void> clearGoal() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kGoalDateKey);
  }
}

final khatmaGoalProvider =
    NotifierProvider<KhatmaGoalNotifier, DateTime?>(KhatmaGoalNotifier.new);

// ─── Helper ───────────────────────────────────────────────────────────────────

int _daysUntil(DateTime target) {
  final today = DateTime.now();
  final diff = DateTime(target.year, target.month, target.day)
      .difference(DateTime(today.year, today.month, today.day));
  return diff.inDays;
}

// ─── Khatma goal banner (shown on dashboard when a goal is set) ───────────────

class KhatmaGoalBanner extends ConsumerWidget {
  const KhatmaGoalBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(khatmaGoalProvider);
    if (goal == null) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final daysLeft = _daysUntil(goal);
    final overdue = daysLeft < 0;
    final pagesPerDay = daysLeft > 0 ? kTotalPages / daysLeft : null;
    final ayahsPerDay = daysLeft > 0 ? kTotalAyahs / daysLeft : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: overdue
            ? colors.errorContainer.withValues(alpha: 0.5)
            : colors.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: overdue
              ? colors.error.withValues(alpha: 0.3)
              : colors.tertiary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Text(overdue ? '⏰' : '📖', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  overdue
                      ? 'Khatma goal passed'
                      : '$daysLeft day${daysLeft == 1 ? '' : 's'} to complete the Quran',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: overdue ? colors.onErrorContainer : colors.onTertiaryContainer,
                  ),
                ),
                if (!overdue && pagesPerDay != null)
                  Text(
                    '${pagesPerDay.toStringAsFixed(1)} pages/day'
                    ' · ${ayahsPerDay!.toStringAsFixed(0)} ayahs/day',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onTertiaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                if (overdue)
                  Text(
                    'Goal was ${goal.day}/${goal.month}/${goal.year}',
                    style: TextStyle(
                        fontSize: 12,
                        color: colors.onErrorContainer.withValues(alpha: 0.7)),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Change goal',
            onPressed: () => _openPlanner(context, ref),
          ),
        ],
      ),
    );
  }

  void _openPlanner(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => KhatmaPlannerSheet(ref: ref),
    );
  }
}

// ─── Planner sheet ────────────────────────────────────────────────────────────

class KhatmaPlannerSheet extends ConsumerStatefulWidget {
  const KhatmaPlannerSheet({super.key, required this.ref});
  final WidgetRef ref;

  @override
  ConsumerState<KhatmaPlannerSheet> createState() => _KhatmaPlannerSheetState();
}

class _KhatmaPlannerSheetState extends ConsumerState<KhatmaPlannerSheet> {
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.ref.read(khatmaGoalProvider);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected ?? now.add(const Duration(days: 30)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
      helpText: 'Set Khatma completion date',
    );
    if (picked != null) setState(() => _selected = picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final daysLeft = _selected != null ? _daysUntil(_selected!) : null;
    final pagesPerDay =
        (daysLeft != null && daysLeft > 0) ? kTotalPages / daysLeft : null;
    final ayahsPerDay =
        (daysLeft != null && daysLeft > 0) ? kTotalAyahs / daysLeft : null;
    final hasExisting = ref.watch(khatmaGoalProvider) != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Khatma Planner',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Set a date to complete the full Quran (${kTotalAyahs} ayahs, $kTotalPages pages).',
            style: TextStyle(fontSize: 13, color: colors.outline),
          ),
          const SizedBox(height: 20),
          // Date selector
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              _selected != null
                  ? '${_selected!.day}/${_selected!.month}/${_selected!.year}'
                  : 'Pick a date',
              style: const TextStyle(fontSize: 15),
            ),
            onPressed: _pickDate,
          ),
          // Preview calculation
          if (pagesPerDay != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _CalcRow(
                    label: 'Days remaining',
                    value: '$daysLeft',
                    colors: colors,
                  ),
                  const Divider(height: 16),
                  _CalcRow(
                    label: 'Pages per day',
                    value: pagesPerDay.toStringAsFixed(1),
                    colors: colors,
                    highlight: true,
                  ),
                  const SizedBox(height: 4),
                  _CalcRow(
                    label: 'Ayahs per day',
                    value: ayahsPerDay!.toStringAsFixed(0),
                    colors: colors,
                    highlight: true,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _selected != null
                ? () {
                    ref.read(khatmaGoalProvider.notifier).setGoal(_selected!);
                    Navigator.of(context).pop();
                  }
                : null,
            child: const Text('Save goal'),
          ),
          if (hasExisting) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                ref.read(khatmaGoalProvider.notifier).clearGoal();
                Navigator.of(context).pop();
              },
              child: Text('Remove goal',
                  style: TextStyle(color: colors.error)),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalcRow extends StatelessWidget {
  const _CalcRow(
      {required this.label,
      required this.value,
      required this.colors,
      this.highlight = false});
  final String label;
  final String value;
  final ColorScheme colors;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            color: highlight ? colors.primary : colors.onSurface,
          ),
        ),
      ],
    );
  }
}
