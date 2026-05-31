import type { Theme } from '../types/quran';

export interface ThemeColors {
  background: string;
  surface: string;
  surfaceVariant: string;
  primary: string;
  onPrimary: string;
  text: string;
  textSecondary: string;
  arabicText: string;
  border: string;
  statusBar: 'light' | 'dark';
  bottomSheet: string;
  highlight: string;
  wordHighlight: string;
}

export const THEMES: Record<Theme, ThemeColors> = {
  dark: {
    background:     '#0f0f14',
    surface:        '#1a1a24',
    surfaceVariant: '#23232f',
    primary:        '#4CAF50',
    onPrimary:      '#ffffff',
    text:           '#e8e8ec',
    textSecondary:  '#9090a0',
    arabicText:     '#f5f0e8',
    border:         '#2e2e3e',
    statusBar:      'light',
    bottomSheet:    '#1a1a24',
    highlight:      '#4CAF5033',
    wordHighlight:  '#4CAF5066',
  },
  light: {
    background:     '#fafafa',
    surface:        '#ffffff',
    surfaceVariant: '#f3f4f6',
    primary:        '#2e7d32',
    onPrimary:      '#ffffff',
    text:           '#1a1a1a',
    textSecondary:  '#6b7280',
    arabicText:     '#1a1a1a',
    border:         '#e5e7eb',
    statusBar:      'dark',
    bottomSheet:    '#ffffff',
    highlight:      '#2e7d3222',
    wordHighlight:  '#2e7d3244',
  },
  sepia: {
    background:     '#f5ead8',
    surface:        '#fdf5e8',
    surfaceVariant: '#f0e4cc',
    primary:        '#7b5e3a',
    onPrimary:      '#ffffff',
    text:           '#3d2b1f',
    textSecondary:  '#7a6652',
    arabicText:     '#2c1c0f',
    border:         '#d4bc9a',
    statusBar:      'dark',
    bottomSheet:    '#fdf5e8',
    highlight:      '#7b5e3a22',
    wordHighlight:  '#7b5e3a44',
  },
};
