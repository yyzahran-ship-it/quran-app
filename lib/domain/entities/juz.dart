// juz = 1/30 of the Quran. Pure domain entity.
class Juz {
  const Juz({
    required this.juzNumber,
    required this.firstVerseId,
    required this.lastVerseId,
    required this.versesCount,
  });

  final int juzNumber; // 1–30
  final int firstVerseId;
  final int lastVerseId;
  final int versesCount;

  @override
  String toString() => 'Juz($juzNumber, verses $firstVerseId–$lastVerseId)';
}
