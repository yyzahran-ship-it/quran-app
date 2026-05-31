import { useState, useEffect, useCallback } from 'react';
import { getDb } from '../services/db';
import type { Ayah, Surah, Word, AyahWithTranslations } from '../types/quran';

export function useSurahs() {
  const [surahs, setSurahs] = useState<Surah[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getDb()
      .then((db) => db.getAllAsync<Surah>(`SELECT * FROM surahs ORDER BY id`))
      .then(setSurahs)
      .finally(() => setLoading(false));
  }, []);

  return { surahs, loading };
}

export function useSurah(surahId: number) {
  const [surah, setSurah] = useState<Surah | null>(null);

  useEffect(() => {
    if (!surahId) return;
    getDb()
      .then((db) =>
        db.getFirstAsync<Surah>(`SELECT * FROM surahs WHERE id=?`, [surahId])
      )
      .then((s) => setSurah(s ?? null));
  }, [surahId]);

  return surah;
}

export function useAyahs(surahId: number, translationSlugs: string[]) {
  const [ayahs, setAyahs] = useState<AyahWithTranslations[]>([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (!surahId) return;
    setLoading(true);
    try {
      const db = await getDb();

      // Fetch base ayahs
      const rawAyahs = await db.getAllAsync<Ayah>(
        `SELECT * FROM ayahs WHERE surah_id=? ORDER BY ayah_number`,
        [surahId]
      );

      if (!rawAyahs.length) {
        setAyahs([]);
        return;
      }

      if (!translationSlugs.length) {
        setAyahs(rawAyahs.map((a) => ({ ...a, translations: [] })));
        return;
      }

      // Fetch translations for all ayahs in this surah at once
      const slugPlaceholders = translationSlugs.map(() => '?').join(',');
      const translations = await db.getAllAsync<{
        ayah_id: number;
        edition_slug: string;
        text: string;
      }>(
        `SELECT t.ayah_id, te.slug as edition_slug, t.text
         FROM translations t
         JOIN translation_editions te ON te.id = t.edition_id
         WHERE t.ayah_id IN (
           SELECT id FROM ayahs WHERE surah_id=?
         )
         AND te.slug IN (${slugPlaceholders})`,
        [surahId, ...translationSlugs]
      );

      // Group translations by ayah_id
      const tMap = new Map<number, Array<{ edition_slug: string; text: string }>>();
      for (const t of translations) {
        if (!tMap.has(t.ayah_id)) tMap.set(t.ayah_id, []);
        tMap.get(t.ayah_id)!.push({ edition_slug: t.edition_slug, text: t.text });
      }

      setAyahs(
        rawAyahs.map((a) => ({
          ...a,
          translations: tMap.get(a.id) ?? [],
        }))
      );
    } finally {
      setLoading(false);
    }
  }, [surahId, translationSlugs.join(',')]);

  useEffect(() => { load(); }, [load]);

  return { ayahs, loading, reload: load };
}

export function useWords(ayahId: number | null) {
  const [words, setWords] = useState<Word[]>([]);

  useEffect(() => {
    if (!ayahId) { setWords([]); return; }
    getDb()
      .then((db) =>
        db.getAllAsync<Word>(
          `SELECT * FROM words WHERE ayah_id=? ORDER BY position`, [ayahId]
        )
      )
      .then(setWords);
  }, [ayahId]);

  return words;
}
