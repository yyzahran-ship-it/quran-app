import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Read-date store ──────────────────────────────────────────────────────────

class StreakNotifier extends Notifier<Set<String>> {
  static const _key = 'streak_read_dates';

  @override
  Set<String> build() {
    Future.microtask(_load);
    return {};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = (prefs.getStringList(_key) ?? []).toSet();
  }

  Future<void> markTodayRead() async {
    final updated = {...state, dateKey(DateTime.now())};
    state = updated;
    await _save(updated);
  }

  Future<void> toggleDay(DateTime date) async {
    final key = dateKey(date);
    final updated = Set<String>.from(state);
    if (updated.contains(key)) {
      updated.remove(key);
    } else {
      updated.add(key);
    }
    state = updated;
    await _save(updated);
  }

  Future<void> _save(Set<String> dates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, dates.toList());
  }

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final streakProvider =
    NotifierProvider<StreakNotifier, Set<String>>(StreakNotifier.new);

// ─── Derived providers ────────────────────────────────────────────────────────

final currentStreakProvider = Provider<int>((ref) {
  return _currentStreak(ref.watch(streakProvider));
});

final longestStreakProvider = Provider<int>((ref) {
  return _longestStreak(ref.watch(streakProvider));
});

final thisMonthCountProvider = Provider<int>((ref) {
  final now = DateTime.now();
  return ref.watch(streakProvider).where((d) {
    final p = DateTime.tryParse(d);
    return p != null && p.year == now.year && p.month == now.month;
  }).length;
});

final todayReadProvider = Provider<bool>((ref) {
  return ref
      .watch(streakProvider)
      .contains(StreakNotifier.dateKey(DateTime.now()));
});

// ─── Reminder prefs ───────────────────────────────────────────────────────────

typedef ReminderPrefs = ({bool enabled, int prayer});

class ReminderPrefsNotifier extends Notifier<ReminderPrefs> {
  static const _enabledKey = 'streak_reminder_enabled';
  static const _prayerKey  = 'streak_reminder_prayer';

  @override
  ReminderPrefs build() {
    Future.microtask(_load);
    return (enabled: false, prayer: 0);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = (
      enabled: prefs.getBool(_enabledKey) ?? false,
      prayer:  prefs.getInt(_prayerKey)   ?? 0,
    );
  }

  Future<void> setEnabled(bool v) async {
    state = (enabled: v, prayer: state.prayer);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, v);
  }

  Future<void> setPrayer(int v) async {
    state = (enabled: state.enabled, prayer: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prayerKey, v);
  }
}

final reminderPrefsProvider =
    NotifierProvider<ReminderPrefsNotifier, ReminderPrefs>(
  ReminderPrefsNotifier.new,
);

// ─── Pure helpers ─────────────────────────────────────────────────────────────

int _currentStreak(Set<String> dates) {
  if (dates.isEmpty) return 0;
  int streak = 0;
  DateTime day = DateTime.now();
  if (!dates.contains(StreakNotifier.dateKey(day))) {
    day = day.subtract(const Duration(days: 1));
  }
  while (dates.contains(StreakNotifier.dateKey(day))) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

int _longestStreak(Set<String> dates) {
  if (dates.isEmpty) return 0;
  final sorted = dates.toList()..sort();
  int longest = 1, current = 1;
  for (int i = 1; i < sorted.length; i++) {
    final prev = DateTime.parse(sorted[i - 1]);
    final curr = DateTime.parse(sorted[i]);
    if (curr.difference(prev).inDays == 1) {
      current++;
      if (current > longest) longest = current;
    } else {
      current = 1;
    }
  }
  return longest;
}
