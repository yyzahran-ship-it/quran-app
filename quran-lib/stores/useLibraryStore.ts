import { create } from 'zustand';
import type { DownloadState } from '../types/quran';
import { DEFAULT_TRANSLATION_IDS, DEFAULT_TAFSIR_IDS } from '../constants/catalog';

interface LibraryState {
  activeTranslationIds: string[];
  activeTafsirIds: string[];
  downloads: Record<string, DownloadState>;

  setActiveTranslations: (ids: string[]) => void;
  toggleTranslation: (id: string) => void;
  setActiveTafsirs: (ids: string[]) => void;
  toggleTafsir: (id: string) => void;
  setDownloadState: (packId: string, state: DownloadState) => void;
  clearDownload: (packId: string) => void;
}

export const useLibraryStore = create<LibraryState>((set) => ({
  activeTranslationIds: DEFAULT_TRANSLATION_IDS,
  activeTafsirIds: DEFAULT_TAFSIR_IDS,
  downloads: {},

  setActiveTranslations: (ids) => set({ activeTranslationIds: ids }),

  toggleTranslation: (id) =>
    set((s) => ({
      activeTranslationIds: s.activeTranslationIds.includes(id)
        ? s.activeTranslationIds.filter((x) => x !== id)
        : [...s.activeTranslationIds, id],
    })),

  setActiveTafsirs: (ids) => set({ activeTafsirIds: ids }),

  toggleTafsir: (id) =>
    set((s) => ({
      activeTafsirIds: s.activeTafsirIds.includes(id)
        ? s.activeTafsirIds.filter((x) => x !== id)
        : [...s.activeTafsirIds, id],
    })),

  setDownloadState: (packId, state) =>
    set((s) => ({ downloads: { ...s.downloads, [packId]: state } })),

  clearDownload: (packId) =>
    set((s) => {
      const { [packId]: _, ...rest } = s.downloads;
      return { downloads: rest };
    }),
}));
