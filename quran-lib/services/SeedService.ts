/**
 * SeedService — populates the local SQLite database on first launch.
 *
 * Seeding order:
 *   1. surahs + ayahs (Arabic text from alquran.cloud quran-uthmani edition)
 *   2. translation_editions + translations (Sahih Int'l, Pickthall, Muyassar)
 *   3. tafsir_sources + tafsirs (Ibn Kathir EN, Al-Sa'di AR)
 *   4. FTS population
 *
 * Re-runs are skipped via the `seed_version` metadata key.
 */

import type { SQLiteDatabase } from 'expo-sqlite';
import { getDb, batchInsert } from './db';
import { ALQURAN_BASE, QURANENC_BASE } from '../constants/catalog';

const SEED_VERSION = '3'; // bump to force re-seed

export type SeedProgress = {
  stage: string;
  done: number;
  total: number;
};

type ProgressCallback = (p: SeedProgress) => void;

// ── Public API ─────────────────────────────────────────────────────────────────

export async function needsSeeding(): Promise<boolean> {
  const db = await getDb();
  try {
    const row = await db.getFirstAsync<{ value: string }>(
      `SELECT value FROM metadata WHERE key='seed_version'`
    );
    return !row || row.value !== SEED_VERSION;
  } catch {
    return true;
  }
}

export async function runSeed(onProgress?: ProgressCallback): Promise<void> {
  const db = await getDb();

  onProgress?.({ stage: 'Fetching Quran text…', done: 0, total: 6236 });
  await seedQuranText(db, onProgress);

  onProgress?.({ stage: 'Seeding translations…', done: 0, total: 6236 * 2 });
  await seedDefaultTranslations(db, onProgress);

  onProgress?.({ stage: 'Seeding tafsir…', done: 0, total: 6236 });
  await seedDefaultTafsirs(db, onProgress);

  onProgress?.({ stage: 'Building search index…', done: 0, total: 1 });
  await populateFts(db);

  await db.runAsync(
    `INSERT OR REPLACE INTO metadata(key, value) VALUES('seed_version', ?)`,
    [SEED_VERSION]
  );

  onProgress?.({ stage: 'Complete', done: 1, total: 1 });
}

// ── Quran text seeding ─────────────────────────────────────────────────────────

async function seedQuranText(db: SQLiteDatabase, onProgress?: ProgressCallback): Promise<void> {
  // Check if already seeded
  const count = await db.getFirstAsync<{ c: number }>(`SELECT COUNT(*) as c FROM ayahs`);
  if (count && count.c >= 6236) return;

  // Fetch the full Quran in one call (quran-uthmani edition)
  const res = await fetchWithRetry(`${ALQURAN_BASE}/quran/quran-uthmani`);
  const data = await res.json();
  const surahs: AlquranSurah[] = data.data.surahs;

  const surahRows: unknown[][] = [];
  const ayahRows: unknown[][] = [];

  let ayahGlobalId = 0;

  for (const surah of surahs) {
    surahRows.push([
      surah.number,
      surah.name,
      surah.englishName,
      surah.englishNameTranslation,
      surah.revelationType,
      surah.numberOfAyahs,
      1, // juz_start — approximate, updated below
      1, // page_start — approximate
    ]);

    for (const ayah of surah.ayahs) {
      ayahGlobalId++;
      const clean = stripDiacritics(ayah.text);
      ayahRows.push([
        ayah.number, // global ayah number as id
        surah.number,
        ayah.numberInSurah,
        ayah.text,
        clean,
        0, // page — enriched in a second pass if needed
        ayah.juz,
        ayah.hizbQuarter,
        ayah.sajda ? 1 : 0,
        ayah.numberInSurah === 1 && surah.number !== 1 && surah.number !== 9 ? 1 : 0,
      ]);

      if (ayahGlobalId % 200 === 0) {
        onProgress?.({ stage: 'Fetching Quran text…', done: ayahGlobalId, total: 6236 });
      }
    }
  }

  await batchInsert(db, 'surahs', [
    'id', 'name_arabic', 'name_english', 'name_transliteration',
    'revelation_type', 'ayah_count', 'juz_start', 'page_start',
  ], surahRows);

  await batchInsert(db, 'ayahs', [
    'id', 'surah_id', 'ayah_number', 'text_uthmani', 'text_clean',
    'page', 'juz', 'hizb', 'sajdah', 'is_basmala',
  ], ayahRows);
}

// ── Translation seeding ────────────────────────────────────────────────────────

const DEFAULT_EDITIONS = [
  { slug: 'en.sahih',    name: 'Saheeh International', language: 'en', direction: 'ltr', translator: 'Saheeh International' },
  { slug: 'en.pickthall', name: 'Pickthall',           language: 'en', direction: 'ltr', translator: 'M. M. Pickthall' },
  { slug: 'ar.muyassar', name: 'Al-Muyassar',          language: 'ar', direction: 'rtl', translator: 'King Fahd Complex' },
];

async function seedDefaultTranslations(db: SQLiteDatabase, onProgress?: ProgressCallback): Promise<void> {
  let totalDone = 0;

  for (const edition of DEFAULT_EDITIONS) {
    // Ensure edition registered
    const existing = await db.getFirstAsync<{ id: number }>(
      `SELECT id FROM translation_editions WHERE slug=?`, [edition.slug]
    );
    let editionId: number;
    if (existing) {
      editionId = existing.id;
    } else {
      const result = await db.runAsync(
        `INSERT INTO translation_editions (slug, language_code, name, translator, direction) VALUES (?,?,?,?,?)`,
        [edition.slug, edition.language, edition.name, edition.translator, edition.direction]
      );
      editionId = result.lastInsertRowId;
    }

    // Check if already seeded for this edition
    const cnt = await db.getFirstAsync<{ c: number }>(
      `SELECT COUNT(*) as c FROM translations WHERE edition_id=?`, [editionId]
    );
    if (cnt && cnt.c >= 6000) {
      totalDone += 6236;
      continue;
    }

    const res = await fetchWithRetry(`${ALQURAN_BASE}/quran/${edition.slug}`);
    const data = await res.json();
    const surahs: AlquranSurah[] = data.data.surahs;

    const rows: unknown[][] = [];
    for (const surah of surahs) {
      for (const ayah of surah.ayahs) {
        rows.push([ayah.number, editionId, ayah.text]);
        totalDone++;
        if (totalDone % 300 === 0) {
          onProgress?.({ stage: `Seeding ${edition.name}…`, done: totalDone, total: 6236 * DEFAULT_EDITIONS.length });
        }
      }
    }

    await batchInsert(db, 'translations', ['ayah_id', 'edition_id', 'text'], rows);
  }
}

// ── Tafsir seeding ─────────────────────────────────────────────────────────────

const DEFAULT_TAFSIRS = [
  { slug: 'en.kathir', name: 'Ibn Kathir (English)', author: 'Ibn Kathir', language: 'en', apiId: 'english_ibn_katheer' },
  { slug: 'ar.saadi',  name: 'السعدي',               author: 'السعدي',     language: 'ar', apiId: 'arabic_saadi' },
];

async function seedDefaultTafsirs(db: SQLiteDatabase, onProgress?: ProgressCallback): Promise<void> {
  let totalDone = 0;

  for (const tafsir of DEFAULT_TAFSIRS) {
    const existing = await db.getFirstAsync<{ id: number }>(
      `SELECT id FROM tafsir_sources WHERE slug=?`, [tafsir.slug]
    );
    let sourceId: number;
    if (existing) {
      sourceId = existing.id;
    } else {
      const result = await db.runAsync(
        `INSERT INTO tafsir_sources (slug, name, author, language, description) VALUES (?,?,?,?,?)`,
        [tafsir.slug, tafsir.name, tafsir.author, tafsir.language, '']
      );
      sourceId = result.lastInsertRowId;
    }

    const cnt = await db.getFirstAsync<{ c: number }>(
      `SELECT COUNT(*) as c FROM tafsirs WHERE source_id=?`, [sourceId]
    );
    if (cnt && cnt.c >= 6000) {
      totalDone += 6236;
      continue;
    }

    // Fetch surah by surah from quranenc
    const rows: unknown[][] = [];

    for (let surahNum = 1; surahNum <= 114; surahNum++) {
      try {
        const res = await fetchWithRetry(
          `${QURANENC_BASE}/translation/sura/${tafsir.apiId}/${surahNum}`
        );
        const data = await res.json();
        const translations: QuranEncAyah[] = data.result ?? [];

        for (const item of translations) {
          // Map to global ayah id — stored as (surah-1)*x + ayah but we need the global number
          const globalAyahId = await db.getFirstAsync<{ id: number }>(
            `SELECT id FROM ayahs WHERE surah_id=? AND ayah_number=?`,
            [surahNum, item.aya]
          );
          if (globalAyahId) {
            rows.push([globalAyahId.id, sourceId, item.translation, tafsir.language]);
            totalDone++;
          }
        }

        if (surahNum % 10 === 0) {
          onProgress?.({ stage: `Seeding ${tafsir.name} (${surahNum}/114)…`, done: totalDone, total: 6236 * DEFAULT_TAFSIRS.length });
        }
      } catch (e) {
        // Individual surah failure is not fatal — continue
        console.warn(`Tafsir fetch failed for surah ${surahNum}:`, e);
      }
    }

    await batchInsert(db, 'tafsirs', ['ayah_id', 'source_id', 'text', 'language'], rows);
  }
}

// ── FTS population ─────────────────────────────────────────────────────────────

async function populateFts(db: SQLiteDatabase): Promise<void> {
  // Rebuild FTS index from content tables
  await db.execAsync(`INSERT OR REPLACE INTO fts_ayahs(fts_ayahs) VALUES('rebuild')`);
  await db.execAsync(`INSERT OR REPLACE INTO fts_translations(fts_translations) VALUES('rebuild')`);
}

// ── Utilities ──────────────────────────────────────────────────────────────────

async function fetchWithRetry(url: string, retries = 3): Promise<Response> {
  for (let i = 0; i < retries; i++) {
    try {
      const res = await fetch(url);
      if (res.ok) return res;
      throw new Error(`HTTP ${res.status}`);
    } catch (e) {
      if (i === retries - 1) throw e;
      await sleep(1000 * (i + 1));
    }
  }
  throw new Error('All retries exhausted');
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

function stripDiacritics(text: string): string {
  // Remove Arabic diacritics (tashkeel) for clean text search
  return text.replace(/[ً-ٰٟۖ-ۜ۟-۪ۤۧۨ-ۭ]/g, '');
}

// ── API response types ─────────────────────────────────────────────────────────

interface AlquranAyah {
  number: number;
  numberInSurah: number;
  text: string;
  juz: number;
  hizbQuarter: number;
  sajda: boolean | { id: number; recommended: boolean; obligatory: boolean };
}

interface AlquranSurah {
  number: number;
  name: string;
  englishName: string;
  englishNameTranslation: string;
  revelationType: string;
  numberOfAyahs: number;
  ayahs: AlquranAyah[];
}

interface QuranEncAyah {
  aya: number;
  translation: string;
}
