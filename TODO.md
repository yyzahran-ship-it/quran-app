# TODO — Build Order

> Top of list = work on this next. Move done items to bottom under "Done".
> Claude updates this file as work progresses.

## Now (current sprint)

### Foundation
- [x] Scaffold Flutter project (`flutter create`)
- [x] Set up folder structure per CLAUDE.md
- [x] Add core dependencies (Riverpod, Drift, just_audio, dio)
- [x] Set up theming (light/dark/inverted, font scaling)
- [x] Set up Riverpod root + error boundary
- [ ] Run on real device successfully (the "hello world" milestone)

### Phase 1 — Data layer (Week 1-2)
- [x] Download Tanzil Uthmani text + bundle as asset (verses_uthmani.json, surahs.json, juzs.json)
- [x] Define Drift schema: surahs, ayahs, juzs (quran_database.dart + generated .g.dart)
- [x] Seed database from Tanzil on first launch (QuranSeeder)
- [x] Create QuranRepository with read methods (getSurah, getAyah, getSurahAyahs, getJuzAyahs, searchAyahs, getAllSurahs, getAllJuzs)
- [x] Unit tests for repository (12/12 passing)
- [x] Bundle Arabic Quran font (AmiriQuran.ttf — open-source, excellent Uthmani rendering)

### Phase 1 — Mushaf reader (Week 2-3)
- [x] Surah-based scrollable reader (MushafScreen + MushafProvider)
- [x] Render Arabic text with proper RTL + diacritics (AyahTile, AmiriQuran font, height:2.0)
- [x] Tap-an-ayah → context menu (AyahActionSheet — audio/bookmark/note stubbed, share live)
- [x] Surah index drawer (SurahIndexDrawer — all 114, search, tap to jump)
- [x] Previous/Next surah bottom nav
- [x] Theme toggle (light/dark/inverted) in app bar
- [x] Font size +/- controls in app bar
- [x] Juz jump dialog (30-juz grid sheet)
- [x] Search screen (Arabic full-text search across all 6236 ayahs)
- [ ] Page-accurate 604-page Mushaf layout (requires page boundary data — Phase 2)

### Phase 1 — Audio (Week 3-4)
- [x] Stream verse-level audio (everyayah.com CDN — Mishary Alafasy)
- [x] Integrate `just_audio` + background playback + lock-screen controls
- [x] Verse highlighting synced to playback position
- [x] A-B repeat, speed control (loop button + speed cycle in AudioPlayerBar)
- [x] Reciter picker — persistent strip at bottom of every page + modal sheet

### Phase 1 — Translations + Tafsir (Week 4-5)
- [x] Import Sahih International translation (6236 entries bundled as asset)
- [x] Toggle translation display under each ayah
- [ ] Multi-translation side-by-side view
- [x] Tafsir reader screen (DraggableScrollableSheet, tafsir switcher dropdown)
- [x] Tafsir caching — cached to SharedPreferences after first load (offline after 1st view)
- [ ] Bundle tafsir data as local asset (full offline on first install)

### Phase 1 — Bookmarks + Notes (Week 5)
- [x] Unlimited bookmarks with date + optional tag
- [x] Notes per ayah (freeform text, upsert)
- [x] Bookmarks list view with swipe-to-delete, tap-to-navigate
- [ ] Export bookmarks as JSON/PDF

### Phase 1 — Accessibility (Week 5-6)
- [x] Font scaling 50%-200% on Arabic AND translation independently
- [ ] True inverted night mode (white-on-black)
- [ ] Dyslexia-friendly font option for translation
- [ ] High-contrast mode
- [x] VoiceOver/TalkBack labels on key interactive elements (reciter strip, audio bar, progress bars)

### Phase 4 — Memorization engine (Week 6-9)
- [x] FSRS-4.5 algorithm (pure Dart — stability, difficulty, retrievability, intervals)
- [x] Hifz queue: due cards, mature count, total
- [x] Review session screen (show first word → reveal → Again/Hard/Good/Easy)
- [x] Hifz dashboard with Start Review CTA
- [x] "Add to Hifz" / "Remove from Hifz" in ayah action sheet
- [ ] Audio-only recall mode
- [x] Khatma planner (set goal date → pages/day + ayahs/day calculation, banner on dashboard)
- [x] Hifz streak / progress charts

### Phase 1 — Polish (Week 9-10)
- [x] Onboarding flow (3 skip-able screens, shown once on first launch)
- [x] Settings screen (theme, font size slider persisted, reciter picker, privacy section)
- [x] Empty states: search no-results, bookmarks empty, hifz empty
- [x] Error states: audio network failure shown in player bar
- [x] AppBar decluttered: 3 primary icons + overflow menu
- [x] Splash screen with app icon + name during first-launch seed
- [ ] Performance pass: cold start <2s, page swipe 60fps

### Pre-launch
- [ ] Beta test with 10 users (huffaz, students, casual readers)
- [ ] Privacy policy + terms (zero-tracking commitment)
- [ ] App Store + Play Store listings
- [ ] Submit to both stores

---

## Backlog (after MVP)

- Multi-script support (IndoPak, Naskh, Warsh, Qaloon)
- Additional reciters (10+)
- Word-by-word translation + grammar (i'rab) from Quranic Arabic Corpus
- Thematic/topical search ("verses about patience")
- Tafsir comparison (3-4 side by side)
- Apple Watch / Wear OS companion
- Web version (Flutter web)
- Arabic UI translation (currently English only)

---

## Phase 3+ (months 6+, separate project)

- Tajweed AI letter-level feedback
- Halaqa/teacher mode
- Shazam-for-Quran identification
- Live khutbah translation

---

## Done

_Nothing yet._
