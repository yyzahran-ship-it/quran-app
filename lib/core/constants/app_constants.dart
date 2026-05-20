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

// Start page for each of the 114 surahs in the standard Madinah Mushaf (604 pp).
// Index 0 = Surah 1 (Al-Fatihah).
const List<int> kSurahStartPages = [
  1,   2,   50,  77,  106, 128, 151, 177, 187, 208, // 1–10
  221, 235, 249, 255, 262, 267, 282, 293, 305, 312, // 11–20
  322, 332, 342, 350, 359, 367, 377, 385, 396, 404, // 21–30
  411, 415, 418, 428, 434, 440, 446, 453, 458, 467, // 31–40
  477, 483, 489, 496, 499, 502, 507, 511, 515, 518, // 41–50
  520, 523, 526, 528, 531, 534, 537, 542, 545, 549, // 51–60
  551, 553, 554, 556, 558, 560, 562, 564, 566, 568, // 61–70
  570, 572, 574, 575, 577, 578, 580, 582, 583, 585, // 71–80
  586, 587, 587, 589, 590, 591, 591, 592, 593, 594, // 81–90
  595, 596, 596, 597, 597, 598, 598, 598, 599, 599, // 91–100
  600, 601, 601, 601, 601, 602, 602, 602, 603, 603, // 101–110
  603, 604, 604, 604,                                // 111–114
];

// Start page for each of the 30 juzs.
// Index 0 = Juz 1.
const List<int> kJuzStartPages = [
  1,   22,  42,  62,  82,  102, 121, 142, 162, 182, // 1–10
  201, 221, 241, 261, 281, 301, 321, 341, 361, 381, // 11–20
  399, 417, 435, 453, 469, 483, 495, 507, 519, 531, // 21–30
];
