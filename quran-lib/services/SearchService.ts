/**
 * SearchService — FTS5-powered full-text search across Quran text + translations.
 */

import { getDb } from './db';
import type { SearchResult } from '../types/quran';

export interface SearchOptions {
  query: string;
  editionSlug?: string;   // limit to specific translation
  surahId?: number;        // limit to a surah
  limit?: number;
}

export async function searchQuran(opts: SearchOptions): Promise<SearchResult[]> {
  const { query, editionSlug, surahId, limit = 50 } = opts;
  if (!query.trim()) return [];

  const db = await getDb();
  const ftsQuery = prepareFtsQuery(query);

  // Detect if the query is likely Arabic
  const isArabic = /[؀-ۿ]/.test(query);

  if (isArabic) {
    return searchArabic(db, ftsQuery, surahId, limit);
  } else {
    return searchTranslations(db, ftsQuery, editionSlug, surahId, limit);
  }
}

async function searchArabic(
  db: Awaited<ReturnType<typeof getDb>>,
  ftsQuery: string,
  surahId: number | undefined,
  limit: number
): Promise<SearchResult[]> {
  const params: (string | number)[] = [ftsQuery, limit];
  const surahFilter = surahId ? 'AND a.surah_id = ?' : '';
  if (surahId) params.splice(1, 0, surahId);

  const rows = await db.getAllAsync<{
    ayah_id: number;
    surah_id: number;
    ayah_number: number;
    name_english: string;
    text_clean: string;
  }>(
    `SELECT a.id as ayah_id, a.surah_id, a.ayah_number,
            s.name_english, a.text_clean
     FROM fts_ayahs f
     JOIN ayahs a ON a.id = f.ayah_id
     JOIN surahs s ON s.id = a.surah_id
     WHERE fts_ayahs MATCH ?
     ${surahFilter}
     ORDER BY rank
     LIMIT ?`,
    params as import('expo-sqlite').SQLiteBindParams
  );

  return rows.map((r) => ({
    ayah_id: r.ayah_id,
    surah_id: r.surah_id,
    surah_name: r.name_english,
    ayah_number: r.ayah_number,
    arabic_snippet: r.text_clean,
    translation_snippet: '',
  }));
}

async function searchTranslations(
  db: Awaited<ReturnType<typeof getDb>>,
  ftsQuery: string,
  editionSlug: string | undefined,
  surahId: number | undefined,
  limit: number
): Promise<SearchResult[]> {
  const params: (string | number)[] = [ftsQuery];
  let editionFilter = '';
  let surahFilter = '';

  if (editionSlug) {
    editionFilter = 'AND te.slug = ?';
    params.push(editionSlug);
  }
  if (surahId) {
    surahFilter = 'AND a.surah_id = ?';
    params.push(surahId);
  }
  params.push(limit);

  const rows = await db.getAllAsync<{
    ayah_id: number;
    surah_id: number;
    ayah_number: number;
    name_english: string;
    text_clean: string;
    translation_text: string;
    edition_slug: string;
  }>(
    `SELECT a.id as ayah_id, a.surah_id, a.ayah_number,
            s.name_english, a.text_clean,
            t.text as translation_text,
            te.slug as edition_slug
     FROM fts_translations ft
     JOIN translations t   ON t.id = ft.translation_id
     JOIN translation_editions te ON te.id = t.edition_id
     JOIN ayahs a          ON a.id = t.ayah_id
     JOIN surahs s         ON s.id = a.surah_id
     WHERE fts_translations MATCH ?
     ${editionFilter}
     ${surahFilter}
     ORDER BY rank
     LIMIT ?`,
    params as import('expo-sqlite').SQLiteBindParams
  );

  return rows.map((r) => ({
    ayah_id: r.ayah_id,
    surah_id: r.surah_id,
    surah_name: r.name_english,
    ayah_number: r.ayah_number,
    arabic_snippet: r.text_clean,
    translation_snippet: r.translation_text,
    edition_slug: r.edition_slug,
  }));
}

export async function searchByRoot(root: string, limit = 50): Promise<SearchResult[]> {
  const db = await getDb();

  const rows = await db.getAllAsync<{
    ayah_id: number;
    surah_id: number;
    ayah_number: number;
    name_english: string;
    text_clean: string;
  }>(
    `SELECT DISTINCT a.id as ayah_id, a.surah_id, a.ayah_number,
            s.name_english, a.text_clean
     FROM words w
     JOIN ayahs a  ON a.id = w.ayah_id
     JOIN surahs s ON s.id = a.surah_id
     WHERE w.root = ?
     LIMIT ?`,
    [root, limit]
  );

  return rows.map((r) => ({
    ayah_id: r.ayah_id,
    surah_id: r.surah_id,
    surah_name: r.name_english,
    ayah_number: r.ayah_number,
    arabic_snippet: r.text_clean,
    translation_snippet: '',
  }));
}

// FTS5 query safety: escape special characters, add * for prefix matching
function prepareFtsQuery(raw: string): string {
  const escaped = raw.replace(/["]/g, '""').trim();
  // Wrap multi-word queries in quotes for phrase search
  if (escaped.includes(' ')) return `"${escaped}"`;
  return `${escaped}*`;
}
