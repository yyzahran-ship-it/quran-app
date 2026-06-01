// Reciter data from the QuranicAudio API (api.quranicaudio.com).
// Audio files live at:
//   https://download.quranicaudio.com/quran/{relativePath}{surah:03d}.mp3
class QuranicReciter {
  const QuranicReciter({
    required this.id,
    required this.name,
    this.arabicName,
    required this.relativePath,
    this.style,
  });

  final int id;
  final String name;
  final String? arabicName;
  final String relativePath; // e.g. "mishaari_raashid_al_3afaasee/"
  final String? style; // "Murattal" | "Mujawwad" | null

  String surahAudioUrl(int surahNumber) {
    final padded = surahNumber.toString().padLeft(3, '0');
    return 'https://download.quranicaudio.com/quran/$relativePath$padded.mp3';
  }

  factory QuranicReciter.fromJson(Map<String, dynamic> json) => QuranicReciter(
        id: (json['id'] as num).toInt(),
        name: (json['name'] as String?)?.trim() ?? 'Unknown',
        arabicName: json['arabic_name'] as String?,
        relativePath: (json['relative_path'] as String?) ?? '',
        style: json['style'] as String?,
      );

  @override
  bool operator ==(Object other) => other is QuranicReciter && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'QuranicReciter($id, $name)';
}
