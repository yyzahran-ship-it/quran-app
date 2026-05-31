import { create } from 'zustand';
import type { Bookmark, LastRead } from '../types/quran';
import { getDb } from '../services/db';

interface BookmarkState {
  bookmarks: Bookmark[];
  lastReads: LastRead[];
  collections: string[];

  loadBookmarks: () => Promise<void>;
  addBookmark: (ayahId: number, collection?: string, note?: string) => Promise<void>;
  removeBookmark: (id: number) => Promise<void>;
  updateNote: (id: number, note: string) => Promise<void>;
  updateLastRead: (surahId: number, ayahId: number) => Promise<void>;
  getBookmarkForAyah: (ayahId: number) => Bookmark | undefined;
}

export const useBookmarkStore = create<BookmarkState>((set, get) => ({
  bookmarks: [],
  lastReads: [],
  collections: ['Favourites'],

  loadBookmarks: async () => {
    const db = await getDb();
    const bookmarks = await db.getAllAsync<Bookmark>(
      `SELECT * FROM bookmarks ORDER BY created_at DESC`
    );
    const lastReads = await db.getAllAsync<LastRead>(
      `SELECT * FROM last_reads ORDER BY timestamp DESC`
    );
    const colRows = await db.getAllAsync<{ collection_name: string }>(
      `SELECT DISTINCT collection_name FROM bookmarks`
    );
    const collections = ['Favourites', ...colRows
      .map((r) => r.collection_name)
      .filter((c) => c !== 'Favourites')];

    set({ bookmarks, lastReads, collections });
  },

  addBookmark: async (ayahId, collection = 'Favourites', note) => {
    const db = await getDb();
    await db.runAsync(
      `INSERT OR IGNORE INTO bookmarks(ayah_id, collection_name, note) VALUES(?,?,?)`,
      [ayahId, collection, note ?? null]
    );
    await get().loadBookmarks();
  },

  removeBookmark: async (id) => {
    const db = await getDb();
    await db.runAsync(`DELETE FROM bookmarks WHERE id=?`, [id]);
    set((s) => ({ bookmarks: s.bookmarks.filter((b) => b.id !== id) }));
  },

  updateNote: async (id, note) => {
    const db = await getDb();
    await db.runAsync(`UPDATE bookmarks SET note=? WHERE id=?`, [note, id]);
    set((s) => ({
      bookmarks: s.bookmarks.map((b) => (b.id === id ? { ...b, note } : b)),
    }));
  },

  updateLastRead: async (surahId, ayahId) => {
    const db = await getDb();
    await db.runAsync(
      `INSERT OR REPLACE INTO last_reads(surah_id, ayah_id, timestamp)
       VALUES(?,?,datetime('now'))`,
      [surahId, ayahId]
    );
    await get().loadBookmarks();
  },

  getBookmarkForAyah: (ayahId) =>
    get().bookmarks.find((b) => b.ayah_id === ayahId),
}));
