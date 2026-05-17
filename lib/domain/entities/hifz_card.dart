class HifzCard {
  const HifzCard({
    required this.id,
    required this.ayahId,
    required this.surahNumber,
    required this.ayahNumber,
    required this.stability,
    required this.difficulty,
    required this.scheduledDays,
    required this.reps,
    required this.lapses,
    required this.dueAt,
    this.lastReviewAt,
  });

  final int id;
  final int ayahId;
  final int surahNumber;
  final int ayahNumber;
  final double stability;
  final double difficulty;
  final int scheduledDays;
  final int reps;
  final int lapses;
  final DateTime dueAt;
  final DateTime? lastReviewAt;

  String get verseKey => '$surahNumber:$ayahNumber';

  bool get isDueNow => dueAt.isBefore(DateTime.now());

  bool get isMature => scheduledDays >= 21;
}
