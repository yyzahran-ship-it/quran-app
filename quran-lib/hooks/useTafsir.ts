import { useState, useEffect } from 'react';
import { getDb } from '../services/db';
import type { Tafsir, TafsirSource } from '../types/quran';

export function useTafsir(ayahId: number | null, sourceSlug: string | null) {
  const [tafsir, setTafsir] = useState<Tafsir | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!ayahId || !sourceSlug) { setTafsir(null); return; }
    setLoading(true);

    getDb()
      .then((db) =>
        db.getFirstAsync<Tafsir>(
          `SELECT t.* FROM tafsirs t
           JOIN tafsir_sources ts ON ts.id = t.source_id
           WHERE t.ayah_id=? AND ts.slug=?`,
          [ayahId, sourceSlug]
        )
      )
      .then((t) => setTafsir(t ?? null))
      .finally(() => setLoading(false));
  }, [ayahId, sourceSlug]);

  return { tafsir, loading };
}

export function useAvailableTafsirSources() {
  const [sources, setSources] = useState<TafsirSource[]>([]);

  useEffect(() => {
    getDb()
      .then((db) =>
        db.getAllAsync<TafsirSource & { ayah_count: number }>(
          `SELECT ts.*, COUNT(t.id) as ayah_count
           FROM tafsir_sources ts
           LEFT JOIN tafsirs t ON t.source_id = ts.id
           GROUP BY ts.id
           HAVING ayah_count > 0`
        )
      )
      .then(setSources);
  }, []);

  return sources;
}
