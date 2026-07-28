import { create } from 'zustand';
import type { DisplayMode } from '../types/quran';

interface ReaderState {
  currentSurah: number;
  currentAyah: number;
  displayMode: DisplayMode;
  showTranslation: boolean;
  showTransliteration: boolean;
  fontSize: number;       // Arabic font size px (18–36)
  translationSize: number; // Translation font size px (13–20)

  setCurrentSurah: (surah: number) => void;
  setCurrentAyah: (ayah: number) => void;
  setDisplayMode: (mode: DisplayMode) => void;
  toggleTranslation: () => void;
  toggleTransliteration: () => void;
  setFontSize: (size: number) => void;
  setTranslationSize: (size: number) => void;
}

export const useReaderStore = create<ReaderState>((set) => ({
  currentSurah: 1,
  currentAyah: 1,
  displayMode: 'ayah-by-ayah',
  showTranslation: true,
  showTransliteration: false,
  fontSize: 24,
  translationSize: 15,

  setCurrentSurah: (surah) => set({ currentSurah: surah }),
  setCurrentAyah: (ayah) => set({ currentAyah: ayah }),
  setDisplayMode: (mode) => set({ displayMode: mode }),
  toggleTranslation: () => set((s) => ({ showTranslation: !s.showTranslation })),
  toggleTransliteration: () => set((s) => ({ showTransliteration: !s.showTransliteration })),
  setFontSize: (size) => set({ fontSize: Math.min(36, Math.max(18, size)) }),
  setTranslationSize: (size) => set({ translationSize: Math.min(20, Math.max(13, size)) }),
}));
