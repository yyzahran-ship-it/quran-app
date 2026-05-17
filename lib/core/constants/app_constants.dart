// App-wide constants. Keep trivial; avoid premature abstraction.

// ayah = verse, surah = chapter, juz = 1/30 of the Quran, hizb = 1/60.
const int kTotalSurahs = 114;
const int kTotalAyahs = 6236;
const int kTotalJuzs = 30;
const int kTotalPages = 604; // standard Madinah Mushaf page count

// Arabic font family name (matches pubspec.yaml declaration).
// Using Amiri Quran — open-source, excellent Uthmani script rendering.
// Swap to 'UthmanicHafs' once KFGQPC font is licensed and bundled.
const String kArabicFont = 'AmiriQuran';

// Font scale limits (CLAUDE.md accessibility requirement).
const double kMinFontScale = 0.5;
const double kMaxFontScale = 2.0;
