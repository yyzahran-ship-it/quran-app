import { create } from 'zustand';
import type { Theme } from '../types/quran';

interface SettingsState {
  theme: Theme;
  arabicFont: string;
  uiLanguage: string;
  autoScroll: boolean;
  wordByWordMode: boolean;

  setTheme: (theme: Theme) => void;
  setArabicFont: (font: string) => void;
  setUiLanguage: (lang: string) => void;
  toggleAutoScroll: () => void;
  toggleWordByWord: () => void;
}

export const useSettingsStore = create<SettingsState>((set) => ({
  theme: 'dark',
  arabicFont: 'KFGQPC-Uthmanic',
  uiLanguage: 'en',
  autoScroll: false,
  wordByWordMode: false,

  setTheme: (theme) => set({ theme }),
  setArabicFont: (arabicFont) => set({ arabicFont }),
  setUiLanguage: (uiLanguage) => set({ uiLanguage }),
  toggleAutoScroll: () => set((s) => ({ autoScroll: !s.autoScroll })),
  toggleWordByWord: () => set((s) => ({ wordByWordMode: !s.wordByWordMode })),
}));
