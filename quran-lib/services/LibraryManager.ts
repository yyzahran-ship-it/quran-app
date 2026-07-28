/**
 * LibraryManager — download, delete, and query translation/tafsir packs.
 */

import { getDb, batchInsert } from './db';
import { TRANSLATIONS, TAFSIRS, ALQURAN_BASE, QURANENC_BASE } from '../constants/catalog';
import type { TranslationCatalogEntry, TafsirCatalogEntry, DownloadState } from '../types/quran';

export { TRANSLATIONS, TAFSIRS };

type ProgressCallback = (state: DownloadState) => void;

// Cancellation tokens — keyed by pack id
const cancelTokens: Map<string, boolean> = new Map();

// ── Translation packs ──────────────────────────────────────────────────────────

export async function downloadTranslation(
  entry: TranslationCatalogEntry,
  onProgress?: ProgressCallback
): Promise<void> {
  cancelTokens.set(entry.id, false);
  const db = await getDb();

  onProgress?.({ status: 'downloading', progress: 0, total: 6236 });

  // Ensure edition registered
  let editionId: number;
  const existing = await db.getFirstAsync<{ id: number }>(
    `SELECT id FROM translation_editions WHERE slug=?`, [entry.id]
  );
  if (existing) {
    editionId = existing.id;
  } else {
    const result = await db.runAsync(
      `INSERT INTO translation_editions(slug, language_code, name, translator, direction)
       VALUES(?,?,?,?,?)`,
      [entry.id, entry.language, entry.name, entry.translator, entry.direction]
    );
    editionId = result.lastInsertRowId;
  }

  // Fetch full Quran with this edition
  let res: Response;
  try {
    res = await fetch(`${ALQURAN_BASE}/quran/${entry.apiIdentifier}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
  } catch (e) {
    onProgress?.({ status: 'error', progress: 0, total: 6236, error: String(e) });
    return;
  }

  const data = await res.json();
  const surahs: AlquranSurah[] = data.data.surahs;
  const rows: unknown[][] = [];
  let done = 0;

  for (const surah of surahs) {
    if (cancelTokens.get(entry.id)) {
      onProgress?.({ status: 'cancelled', progress: done, total: 6236 });
      cancelTokens.delete(entry.id);
      return;
    }
    for (const ayah of surah.ayahs) {
      rows.push([ayah.number, editionId, ayah.text]);
      done++;
    }
    onProgress?.({ status: 'downloading', progress: done, total: 6236 });
  }

  await batchInsert(db, 'translations', ['ayah_id', 'edition_id', 'text'], rows);

  // Rebuild FTS
  await db.execAsync(`INSERT OR REPLACE INTO fts_translations(fts_translations) VALUES('rebuild')`);

  cancelTokens.delete(entry.id);
  onProgress?.({ status: 'complete', progress: 6236, total: 6236 });
}

export async function deleteTranslation(slug: string): Promise<void> {
  const db = await getDb();
  await db.withTransactionAsync(async () => {
    const edition = await db.getFirstAsync<{ id: number }>(
      `SELECT id FROM translation_editions WHERE slug=?`, [slug]
    );
    if (!edition) return;
    await db.runAsync(`DELETE FROM translations WHERE edition_id=?`, [edition.id]);
    await db.runAsync(`DELETE FROM translation_editions WHERE id=?`, [edition.id]);
    await db.execAsync(`INSERT OR REPLACE INTO fts_translations(fts_translations) VALUES('rebuild')`);
  });
}

export async function getDownloadedTranslationSlugs(): Promise<string[]> {
  const db = await getDb();
  const rows = await db.getAllAsync<{ slug: string }>(
    `SELECT DISTINCT te.slug
     FROM translation_editions te
     INNER JOIN translations t ON t.edition_id = te.id
     LIMIT 1`
  );
  // We need slugs that have at least some translations
  const all = await db.getAllAsync<{ slug: string; cnt: number }>(
    `SELECT te.slug, COUNT(t.id) as cnt
     FROM translation_editions te
     LEFT JOIN translations t ON t.edition_id = te.id
     GROUP BY te.id`
  );
  return all.filter((r) => r.cnt > 0).map((r) => r.slug);
}

// ── Tafsir packs ───────────────────────────────────────────────────────────────

export async function downloadTafsir(
  entry: TafsirCatalogEntry,
  onProgress?: ProgressCallback
): Promise<void> {
  cancelTokens.set(entry.id, false);
  const db = await getDb();

  onProgress?.({ status: 'downloading', progress: 0, total: 6236 });

  let sourceId: number;
  const existing = await db.getFirstAsync<{ id: number }>(
    `SELECT id FROM tafsir_sources WHERE slug=?`, [entry.id]
  );
  if (existing) {
    sourceId = existing.id;
  } else {
    const result = await db.runAsync(
      `INSERT INTO tafsir_sources(slug, name, author, language, description) VALUES(?,?,?,?,?)`,
      [entry.id, entry.name, entry.author, entry.language, '']
    );
    sourceId = result.lastInsertRowId;
  }

  const rows: unknown[][] = [];
  let done = 0;

  for (let surahNum = 1; surahNum <= 114; surahNum++) {
    if (cancelTokens.get(entry.id)) {
      onProgress?.({ status: 'cancelled', progress: done, total: 6236 });
      cancelTokens.delete(entry.id);
      return;
    }

    try {
      const res = await fetch(
        `${QURANENC_BASE}/translation/sura/${entry.apiIdentifier}/${surahNum}`
      );
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      const ayahs: QuranEncAyah[] = data.result ?? [];

      for (const ayah of ayahs) {
        const globalId = await db.getFirstAsync<{ id: number }>(
          `SELECT id FROM ayahs WHERE surah_id=? AND ayah_number=?`, [surahNum, ayah.aya]
        );
        if (globalId) {
          rows.push([globalId.id, sourceId, ayah.translation, entry.language]);
          done++;
        }
      }

      onProgress?.({ status: 'downloading', progress: done, total: 6236 });
    } catch (e) {
      console.warn(`Tafsir ${entry.id} surah ${surahNum} failed:`, e);
    }
  }

  await batchInsert(db, 'tafsirs', ['ayah_id', 'source_id', 'text', 'language'], rows);

  cancelTokens.delete(entry.id);
  onProgress?.({ status: 'complete', progress: done, total: 6236 });
}

export async function deleteTafsir(slug: string): Promise<void> {
  const db = await getDb();
  await db.withTransactionAsync(async () => {
    const source = await db.getFirstAsync<{ id: number }>(
      `SELECT id FROM tafsir_sources WHERE slug=?`, [slug]
    );
    if (!source) return;
    await db.runAsync(`DELETE FROM tafsirs WHERE source_id=?`, [source.id]);
    await db.runAsync(`DELETE FROM tafsir_sources WHERE id=?`, [source.id]);
  });
}

export async function getDownloadedTafsirSlugs(): Promise<string[]> {
  const db = await getDb();
  const rows = await db.getAllAsync<{ slug: string; cnt: number }>(
    `SELECT ts.slug, COUNT(t.id) as cnt
     FROM tafsir_sources ts
     LEFT JOIN tafsirs t ON t.source_id = ts.id
     GROUP BY ts.id`
  );
  return rows.filter((r) => r.cnt > 0).map((r) => r.slug);
}

// ── Cancel ─────────────────────────────────────────────────────────────────────

export function cancelDownload(packId: string): void {
  cancelTokens.set(packId, true);
}

// ── Active selections ──────────────────────────────────────────────────────────

export async function getActiveTranslations(slugs: string[]): Promise<TranslationCatalogEntry[]> {
  return TRANSLATIONS.filter((t) => slugs.includes(t.id));
}

export async function getActiveTafsirs(slugs: string[]): Promise<TafsirCatalogEntry[]> {
  return TAFSIRS.filter((t) => slugs.includes(t.id));
}

// ── Local API types ────────────────────────────────────────────────────────────

interface AlquranAyah {
  number: number;
  numberInSurah: number;
  text: string;
  juz: number;
  hizbQuarter: number;
  sajda: boolean | object;
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
