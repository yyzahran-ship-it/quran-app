class Bookmark {
  const Bookmark({
    required this.id,
    required this.ayahId,
    required this.surahNumber,
    required this.ayahNumber,
    this.tag,
    required this.createdAt,
  });

  final int id;
  final int ayahId;
  final int surahNumber;
  final int ayahNumber;
  final String? tag;
  final DateTime createdAt;

  String get verseKey => '$surahNumber:$ayahNumber';
}
