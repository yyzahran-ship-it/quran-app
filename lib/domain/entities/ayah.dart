// ayah = verse. Pure domain entity.
class Ayah {
  const Ayah({
    required this.id,
    required this.surahNumber,
    required this.ayahNumber,
    required this.textUthmani,
    required this.juzNumber,
  });

  final int id; // global 1–6236
  final int surahNumber;
  final int ayahNumber;
  final String textUthmani; // Arabic text with Uthmani diacritics
  final int juzNumber; // which juz (1–30) this ayah belongs to

  // Human-readable key, e.g. "2:255"
  String get verseKey => '$surahNumber:$ayahNumber';

  @override
  String toString() => 'Ayah($verseKey)';
}
