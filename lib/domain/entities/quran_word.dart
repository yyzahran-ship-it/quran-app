// A single Quranic word with playback timestamps.
// Mirrors the Kotlin data class: data class QuranWord(id, text, startTime, endTime).
// Timing data comes from the Quran.com QDC segments API.
class QuranWord {
  const QuranWord({
    required this.position,
    required this.text,
    required this.startTime,
    required this.endTime,
  });

  final int position;  // 1-based word index within the ayah
  final String text;   // Arabic word text (Uthmani script)
  final int startTime; // ms from start of the verse audio clip
  final int endTime;   // ms from start of the verse audio clip

  // True while the audio position is inside this word's span.
  bool isActiveAt(int positionMs) =>
      positionMs >= startTime && positionMs < endTime;
}
