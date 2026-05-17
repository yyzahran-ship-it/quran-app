class Note {
  const Note({
    required this.id,
    required this.ayahId,
    required this.surahNumber,
    required this.ayahNumber,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int ayahId;
  final int surahNumber;
  final int ayahNumber;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get verseKey => '$surahNumber:$ayahNumber';
}
