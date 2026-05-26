import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dhikr_data.dart';

// Per-item counter state: how many times the user has tapped
class DhikrProgressNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => {};

  int countFor(String itemId) => state[itemId] ?? 0;

  bool isComplete(String itemId, int total) =>
      (state[itemId] ?? 0) >= total;

  void increment(String itemId) {
    state = {...state, itemId: (state[itemId] ?? 0) + 1};
  }

  void reset(String itemId) {
    final updated = Map<String, int>.from(state);
    updated.remove(itemId);
    state = updated;
  }

  void resetCategory(DhikrCategory category) {
    final collections = dhikrCollections
        .where((c) => c.category == category)
        .expand((c) => c.items)
        .map((i) => i.id)
        .toSet();
    final updated = Map<String, int>.from(state)
      ..removeWhere((k, _) => collections.contains(k));
    state = updated;
  }

  int completedInCategory(DhikrCategory category) {
    final collection =
        dhikrCollections.firstWhere((c) => c.category == category);
    return collection.items
        .where((item) => isComplete(item.id, item.count))
        .length;
  }
}

final dhikrProgressProvider =
    NotifierProvider<DhikrProgressNotifier, Map<String, int>>(
  DhikrProgressNotifier.new,
);

// Tasbih counter — simple persistent counter for free counting
class TasbihNotifier extends Notifier<int> {
  static const _key = 'tasbih_count';

  @override
  int build() {
    _load();
    return 0;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_key) ?? 0;
  }

  Future<void> increment() async {
    state = state + 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, state);
  }

  Future<void> reset() async {
    state = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, 0);
  }
}

final tasbihProvider = NotifierProvider<TasbihNotifier, int>(
  TasbihNotifier.new,
);
