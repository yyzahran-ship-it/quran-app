// Pure domain entity — no Drift/Flutter imports. Safe to use in tests.
class Surah {
  const Surah({
    required this.id,
    required this.nameArabic,
    required this.nameSimple,
    required this.nameComplex,
    required this.nameEnglish,
    required this.revelationPlace,
    required this.versesCount,
    required this.bismillahPre,
  });

  final int id;
  final String nameArabic;
  final String nameSimple;
  final String nameComplex;
  final String nameEnglish;

  // "makkah" or "madinah" — where this surah was revealed
  final String revelationPlace;
  final int versesCount;

  // Whether this surah is preceded by Bismillah (all except At-Tawbah, surah 9)
  final bool bismillahPre;

  @override
  String toString() => 'Surah($id: $nameSimple, $versesCount verses)';
}
