import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'streak_provider.dart';
import 'prayer_reminder_service.dart';

// Prayer names shown on the reminder chips
const _prayers = ['After Fajr', 'After Dhuhr', 'After Isha'];
const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reading Streak')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              _StreakHero(),
              SizedBox(height: 12),
              _WeekStrip(),
              SizedBox(height: 12),
              _StatsRow(),
              SizedBox(height: 12),
              _ReminderCard(),
              SizedBox(height: 16),
              _MarkTodayButton(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Streak hero ──────────────────────────────────────────────────────────────

class _StreakHero extends ConsumerWidget {
  const _StreakHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak  = ref.watch(currentStreakProvider);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1C1C19) : Colors.white;
    final border  = isDark ? const Color(0xFF2C2C28) : const Color(0xFFE0D9CC);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          const Text(
            'READING STREAK',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .14,
              color: kMushafahGreenLight,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$streak',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 72,
                  fontWeight: FontWeight.w700,
                  color: kMushafahGold,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'days',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'داوم على التلاوة',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Geeza Pro',
              color: kMushafahGold,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Keep reading daily',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 14),
          _FireDots(streak: streak),
        ],
      ),
    );
  }
}

class _FireDots extends StatelessWidget {
  const _FireDots({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(7, (i) {
        final lit = i < streak.clamp(0, 7);
        return Container(
          width: 6, height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: lit ? kMushafahGold : Colors.grey.shade700,
            boxShadow: lit
                ? [BoxShadow(color: kMushafahGold.withOpacity(.4), blurRadius: 4)]
                : null,
          ),
        );
      }),
    );
  }
}

// ─── Week strip ───────────────────────────────────────────────────────────────

class _WeekStrip extends ConsumerWidget {
  const _WeekStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dates  = ref.watch(streakProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1C1C19) : Colors.white;
    final border  = isDark ? const Color(0xFF2C2C28) : const Color(0xFFE0D9CC);

    // last 7 days: index 0 = 6 days ago, index 6 = today
    final days = List.generate(
      7, (i) => DateTime.now().subtract(Duration(days: 6 - i)),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'THIS WEEK',
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              letterSpacing: .12, color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((day) {
              final isToday = _sameDay(day, DateTime.now());
              final wasRead = dates.contains(StreakNotifier.dateKey(day));
              return _DayCircle(
                day: day,
                isToday: isToday,
                wasRead: wasRead,
                onTap: () => ref
                    .read(streakProvider.notifier)
                    .toggleDay(day),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DayCircle extends StatelessWidget {
  const _DayCircle({
    required this.day,
    required this.isToday,
    required this.wasRead,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday, wasRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMissed = !wasRead && day.isBefore(DateTime.now()) && !isToday;
    Color bg = Colors.grey.shade900;
    Color border = Colors.grey.shade700;
    Widget? child;

    if (wasRead) {
      bg = kMushafahGold;
      border = kMushafahGold;
      child = const Icon(Icons.check, size: 16, color: Colors.black);
    } else if (isMissed) {
      bg = Colors.red.withOpacity(.1);
      border = Colors.red.withOpacity(.3);
      child = const Text('·', style: TextStyle(fontSize: 20, color: Colors.red, height: .8));
    } else if (isToday) {
      border = kMushafahGold;
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            _dayNames[day.weekday % 7],
            style: const TextStyle(fontSize: 9, color: Colors.grey,
                fontWeight: FontWeight.w600, letterSpacing: .06),
          ),
          const SizedBox(height: 6),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg,
              border: Border.all(
                color: border,
                width: isToday && !wasRead ? 1.5 : 1,
              ),
              boxShadow: isToday && !wasRead
                  ? [BoxShadow(color: kMushafahGold.withOpacity(.25), blurRadius: 6)]
                  : null,
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentStreakProvider);
    final longest = ref.watch(longestStreakProvider);
    final month   = ref.watch(thisMonthCountProvider);

    return Row(
      children: [
        _StatCard(value: current, label: 'Current',    gold: true),
        const SizedBox(width: 10),
        _StatCard(value: longest, label: 'Longest',    gold: false),
        const SizedBox(width: 10),
        _StatCard(value: month,   label: 'This Month', gold: false),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, required this.gold});
  final int value;
  final String label;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1C1C19) : Colors.white;
    final border  = isDark ? const Color(0xFF2C2C28) : const Color(0xFFE0D9CC);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: gold ? kMushafahGold : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 9, color: Colors.grey,
                fontWeight: FontWeight.w600, letterSpacing: .1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reminder card ────────────────────────────────────────────────────────────

class _ReminderCard extends ConsumerWidget {
  const _ReminderCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs   = ref.watch(reminderPrefsProvider);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1C1C19) : Colors.white;
    final border  = isDark ? const Color(0xFF2C2C28) : const Color(0xFFE0D9CC);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Reminder',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text('Remind me at prayer time',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              Switch(
                value: prefs.enabled,
                activeColor: kMushafahGreen,
                onChanged: (v) => _onToggle(context, ref, v),
              ),
            ],
          ),
          if (prefs.enabled) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: List.generate(_prayers.length, (i) {
                final active = prefs.prayer == i;
                return FilterChip(
                  label: Text(_prayers[i],
                      style: TextStyle(
                          fontSize: 12,
                          color: active ? kMushafahGold : Colors.grey)),
                  selected: active,
                  onSelected: (_) => _onPrayerSelected(ref, i),
                  selectedColor: kMushafahGold.withOpacity(.12),
                  checkmarkColor: kMushafahGold,
                  side: BorderSide(
                    color: active ? kMushafahGold : Colors.grey.shade600,
                  ),
                  backgroundColor: Colors.transparent,
                  showCheckmark: false,
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onToggle(BuildContext ctx, WidgetRef ref, bool v) async {
    if (v) {
      final granted = await PrayerReminderService.requestPermissions();
      if (!granted) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
            content: Text('Location & notification permissions are required'),
          ));
        }
        return;
      }
      final prayer = ref.read(reminderPrefsProvider).prayer;
      await PrayerReminderService.scheduleForPrayer(prayer);
    } else {
      await PrayerReminderService.cancel();
    }
    await ref.read(reminderPrefsProvider.notifier).setEnabled(v);
  }

  Future<void> _onPrayerSelected(WidgetRef ref, int i) async {
    await ref.read(reminderPrefsProvider.notifier).setPrayer(i);
    final enabled = ref.read(reminderPrefsProvider).enabled;
    if (enabled) {
      await PrayerReminderService.scheduleForPrayer(i);
    }
  }
}

// ─── Mark today button ────────────────────────────────────────────────────────

class _MarkTodayButton extends ConsumerWidget {
  const _MarkTodayButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(todayReadProvider);

    return FilledButton(
      onPressed: done ? null : () => ref.read(streakProvider.notifier).markTodayRead(),
      style: FilledButton.styleFrom(
        backgroundColor: done ? Colors.grey.shade800 : kMushafahGreen,
        disabledBackgroundColor: Colors.grey.shade800,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        done ? '✓  Read today — JazakAllah khairan' : '📖  Mark Today as Read',
        style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: .04,
        ),
      ),
    );
  }
}

// ─── Helper ───────────────────────────────────────────────────────────────────

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
