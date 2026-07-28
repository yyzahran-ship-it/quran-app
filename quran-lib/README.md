# QuranLib

Cross-platform Quran Translation & Tafsir Library built with React Native + Expo.

## Quick start

```bash
cd quran-lib
npm install
npx expo start
```

Scan the QR code with Expo Go (iOS/Android) or press `w` for web.

On first launch the app auto-seeds itself:
1. Downloads all 6 236 ayahs (Arabic text) from alquran.cloud
2. Downloads 3 default translations (Sahih International, Pickthall, Al-Muyassar)
2. Downloads 2 default tafsirs (Ibn Kathir EN, Al-Sa'di AR)
3. Builds FTS5 search indexes

A loading screen shows seeding progress. The process takes ~2–4 minutes on first run (requires internet). All subsequent launches are instant — everything is local.

---

## Architecture

```
quran-lib/
├── app/
│   ├── _layout.tsx              Root layout — handles seeding splash
│   ├── (tabs)/
│   │   ├── index.tsx            Home: last read, daily ayah, quick-nav
│   │   ├── surah-list.tsx       Searchable, filterable 114-surah index
│   │   ├── search.tsx           FTS5 search across Arabic + translations
│   │   └── library.tsx          Bookmarks, collections, export
│   ├── (reader)/
│   │   └── [surah].tsx          Main reader — FlashList, tafsir sheet, word popup
│   └── settings/
│       ├── translations.tsx     Download/delete translation packs
│       ├── tafsirs.tsx          Download/delete tafsir packs
│       └── appearance.tsx       Font size, theme, display toggles
│
├── components/
│   ├── AyahRow.tsx              Renders one ayah: Arabic + translation + toolbar
│   ├── TafsirSheet.tsx          @gorhom/bottom-sheet tafsir panel
│   ├── WordPopup.tsx            Modal for word-by-word root/morphology data
│   ├── TranslationBadge.tsx     Language/edition label chip
│   └── PackDownloader.tsx       Download progress UI for packs
│
├── services/
│   ├── db.ts                    expo-sqlite setup, migrations, helpers
│   ├── SeedService.ts           First-launch data seeding with progress
│   ├── LibraryManager.ts        Pack download/delete/catalog
│   └── SearchService.ts         FTS5 full-text search
│
├── stores/
│   ├── useReaderStore.ts        currentSurah, fontSize, displayMode, …
│   ├── useLibraryStore.ts       activeTranslationIds, activeTafsirIds, downloads
│   ├── useBookmarkStore.ts      bookmarks, collections, lastReads
│   └── useSettingsStore.ts      theme, font, uiLanguage, autoScroll
│
├── hooks/
│   ├── useAyahs.ts              useSurahs, useSurah, useAyahs, useWords
│   ├── useTafsir.ts             useTafsir, useAvailableTafsirSources
│   └── useSearch.ts             debounced search hook
│
└── constants/
    ├── catalog.ts               15 translations + 6 tafsirs catalog
    └── themes.ts                dark / light / sepia colour tokens
```

---

## Database schema (SQLite / expo-sqlite)

| Table | Purpose |
|---|---|
| `surahs` | 114 surahs with Arabic/English names, revelation type |
| `ayahs` | 6 236 ayahs — Uthmani text, clean text, page/juz/hizb |
| `words` | Word-by-word with root, lemma, morphology, transliteration |
| `translation_editions` | Registry of downloaded editions (slug, language, direction) |
| `translations` | 6 236 rows per edition — actual translated text |
| `tafsir_sources` | Registry of downloaded tafsir sources |
| `tafsirs` | Tafsir text per ayah per source |
| `bookmarks` | User bookmarks with collection name + optional note |
| `last_reads` | One row per surah, auto-updated on scroll |
| `reading_plans` | Progress-tracked reading plans |
| `fts_ayahs` | FTS5 virtual table over `ayahs.text_clean` |
| `fts_translations` | FTS5 virtual table over `translations.text` |

Indexes: `ayah_id`, `surah_id`, `juz`, `page`, `edition_id`, `source_id`.

Schema migrations run automatically via `services/db.ts` using a `metadata.schema_version` key.

---

## Data sources

| Data | Source | License |
|---|---|---|
| Arabic text (Uthmani) | alquran.cloud API / Tanzil.net | Open |
| Translations | alquran.cloud (`/quran/{edition}`) | Open |
| Tafsir | quranenc.com (`/translation/sura/{id}/{surah}`) | Open |
| Word-by-word | quran.com public corpus | Open |

**No API keys required.**

---

## Translation library (15 editions)

| ID | Language | Name |
|---|---|---|
| `en.sahih` | English | Saheeh International |
| `en.pickthall` | English | Pickthall |
| `en.yusufali` | English | Yusuf Ali |
| `en.asad` | English | Muhammad Asad |
| `en.ahmedali` | English | Ahmed Ali |
| `en.hilali` | English | Muhsin Khan |
| `ar.muyassar` | Arabic | Al-Muyassar |
| `ar.jalalayn` | Arabic | Jalalayn |
| `fr.hamidullah` | French | Hamidullah |
| `ur.jalandhry` | Urdu | Jalandhry |
| `ur.maududi` | Urdu | Maududi |
| `de.bubenheim` | German | Bubenheim & Elyas |
| `es.asad` | Spanish | Asad |
| `id.indonesian` | Indonesian | Kemenag |
| `tr.diyanet` | Turkish | Diyanet İşleri |

---

## Tafsir library (6 sources)

| ID | Language | Name |
|---|---|---|
| `en.kathir` | English | Ibn Kathir |
| `ar.kathir` | Arabic | ابن كثير |
| `ar.tabari` | Arabic | الطبري |
| `ar.saadi` | Arabic | السعدي |
| `ar.muyassar` | Arabic | الميسر |
| `en.maariful` | English | Ma'ariful Quran |

---

## Features

- **Offline-first**: all data is local SQLite. Works with airplane mode after seeding.
- **3 themes**: dark, light, sepia — switchable in Settings → Appearance.
- **Arabic font scaling**: 18–36px. Translation font: 13–20px.
- **FlashList** rendering for smooth 60fps scrolling on long surahs.
- **FTS5 full-text search** across Arabic and all downloaded translations.
- **Tafsir bottom sheet**: long-press any ayah → tafsir panel with source switcher.
- **Word-by-word popup**: tap any word → root, lemma, morphology (when word data available).
- **Bookmarks**: unlimited, organized in named collections, with optional notes.
- **Export**: share a collection as plain text via native share sheet.
- **Pack manager**: download/delete any translation or tafsir on demand with progress indicator and cancellation support.
- **Last read**: auto-saved per surah on scroll, shown on home screen.

---

## Adding the Arabic font

1. Download `KFGQPC-Uthmanic-Script-Hafs.ttf` from the King Fahd Quran Complex website.
2. Place it in `assets/fonts/`.
3. In `app/_layout.tsx`, add:
   ```tsx
   const [fontsLoaded] = useFonts({ 'KFGQPC-Uthmanic': require('../assets/fonts/KFGQPC-Uthmanic-Script-Hafs.ttf') });
   ```
4. Uncomment the `fontFamily` line in `AyahRow.tsx`.
