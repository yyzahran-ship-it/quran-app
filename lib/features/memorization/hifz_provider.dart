import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/quran_repository.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/hifz_card.dart';
import 'fsrs.dart';

// ─── Session state ────────────────────────────────────────────────────────────

class ReviewItem {
  const ReviewItem({required this.card, required this.ayah});
  final HifzCard card;
  final Ayah ayah;
}

class HifzSession {
  const HifzSession({
    this.queue = const [],
    this.currentIndex = 0,
    this.revealed = false,
    this.done = false,
  });

  final List<ReviewItem> queue;
  final int currentIndex;
  final bool revealed; // whether the answer is shown
  final bool done;     // session complete

  bool get hasCards => queue.isNotEmpty;
  ReviewItem? get current =>
      (hasCards && currentIndex < queue.length) ? queue[currentIndex] : null;

  int get remaining => queue.length - currentIndex;

  HifzSession copyWith({
    List<ReviewItem>? queue,
    int? currentIndex,
    bool? revealed,
    bool? done,
  }) =>
      HifzSession(
        queue: queue ?? this.queue,
        currentIndex: currentIndex ?? this.currentIndex,
        revealed: revealed ?? this.revealed,
        done: done ?? this.done,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class HifzNotifier extends Notifier<HifzSession> {
  @override
  HifzSession build() => const HifzSession();

  QuranRepository get _repo => ref.read(quranRepositoryProvider);

  /// Load all due cards and build a review queue.
  Future<void> startSession() async {
    final cards = await _repo.getDueCards();
    if (cards.isEmpty) {
      state = const HifzSession(done: true);
      return;
    }

    final items = <ReviewItem>[];
    for (final card in cards) {
      final ayah = await _repo.getAyah(card.surahNumber, card.ayahNumber);
      items.add(ReviewItem(card: card, ayah: ayah));
    }

    state = HifzSession(queue: items, currentIndex: 0);
  }

  void reveal() {
    state = state.copyWith(revealed: true);
  }

  Future<void> rate(FsrsRating rating) async {
    final item = state.current;
    if (item == null) return;

    final card = item.card;

    // Compute elapsed days since last review (0 for first review).
    final elapsed = card.lastReviewAt == null
        ? 0
        : DateTime.now().difference(card.lastReviewAt!).inDays;

    final schedule = FSRS.schedule(
      rating: rating,
      stability: card.stability,
      difficulty: card.difficulty,
      elapsedDays: elapsed,
      lapses: card.lapses,
      reps: card.reps,
    );

    await _repo.updateHifzCard(
      ayahId: card.ayahId,
      stability: schedule.stability,
      difficulty: schedule.difficulty,
      scheduledDays: schedule.scheduledDays,
      reps: card.reps + 1,
      lapses: schedule.lapses,
    );

    // If Again, re-queue the card at the end for another attempt this session.
    final nextIndex = state.currentIndex + 1;
    var newQueue = state.queue;
    if (rating == FsrsRating.again) {
      // Re-fetch the updated card and append to queue.
      final updated = await _repo.getHifzCard(card.ayahId);
      if (updated != null) {
        newQueue = [
          ...state.queue,
          ReviewItem(card: updated, ayah: item.ayah),
        ];
      }
    }

    if (nextIndex >= newQueue.length) {
      state = state.copyWith(
          queue: newQueue, currentIndex: nextIndex, done: true, revealed: false);
    } else {
      state = state.copyWith(
          queue: newQueue, currentIndex: nextIndex, revealed: false);
    }
  }
}

final hifzProvider =
    NotifierProvider<HifzNotifier, HifzSession>(HifzNotifier.new);

// ─── Dashboard stats ──────────────────────────────────────────────────────────

class HifzStats {
  const HifzStats({
    required this.dueCount,
    required this.total,
    required this.matureCount,
  });
  final int dueCount;
  final int total;
  final int matureCount;
}

final hifzStatsProvider = FutureProvider<HifzStats>((ref) async {
  // Depend on hifzProvider so stats refresh after a review session.
  ref.watch(hifzProvider);
  final repo = ref.read(quranRepositoryProvider);
  final all = await repo.getAllHifzCards();
  final due = await repo.getDueCount();
  final mature = all.where((c) => c.isMature).length;
  return HifzStats(dueCount: due, total: all.length, matureCount: mature);
});

// Per-ayah in-hifz check (refreshes when hifzProvider changes).
final inHifzProvider = FutureProvider.family<bool, int>((ref, ayahId) async {
  ref.watch(hifzProvider);
  return ref.read(quranRepositoryProvider).isInHifz(ayahId);
});
