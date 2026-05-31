// Core Quran data types for QuranLib

export interface Surah {
  id: number;
  name_arabic: string;
  name_english: string;
  name_transliteration: string;
  revelation_type: 'Meccan' | 'Medinan';
  ayah_count: number;
  juz_start: number;
  page_start: number;
}

export interface Ayah {
  id: number;
  surah_id: number;
  ayah_number: number;
  text_uthmani: string;
  text_clean: string;
  page: number;
  juz: number;
  hizb: number;
  sajdah: 0 | 1;
  is_basmala: 0 | 1;
}

export interface Word {
  id: number;
  ayah_id: number;
  position: number;
  text_arabic: string;
  root: string | null;
  lemma: string | null;
  morphology_tag: string | null;
  transliteration: string | null;
}

export interface Translation {
  id: number;
  ayah_id: number;
  edition_id: number;
  text: string;
}

export interface Tafsir {
  id: number;
  ayah_id: number;
  source_id: number;
  text: string;
  language: string;
}

export interface TafsirSource {
  id: number;
  slug: string;
  name: string;
  author: string;
  language: string;
  description: string;
}

export interface TranslationEdition {
  id: number;
  slug: string;
  language_code: string;
  name: string;
  translator: string;
  direction: 'ltr' | 'rtl';
}

export interface Bookmark {
  id: number;
  ayah_id: number;
  collection_name: string;
  note: string | null;
  created_at: string;
}

export interface LastRead {
  id: number;
  surah_id: number;
  ayah_id: number;
  timestamp: string;
}

export interface ReadingPlan {
  id: number;
  name: string;
  start_date: string;
  end_date: string;
  type: 'juz' | 'page' | 'surah' | 'custom';
  current_surah: number;
  current_ayah: number;
}

// Catalog types for LibraryManager

export interface TranslationCatalogEntry {
  id: string;       // e.g. 'en.sahih'
  language: string;
  name: string;
  translator: string;
  direction: 'ltr' | 'rtl';
  apiIdentifier: string;
}

export interface TafsirCatalogEntry {
  id: string;       // e.g. 'en.kathir'
  name: string;
  author: string;
  language: string;
  apiSource: 'alquran.cloud' | 'quranenc';
  apiIdentifier: string;
}

// Download state

export type DownloadStatus = 'idle' | 'downloading' | 'complete' | 'error' | 'cancelled';

export interface DownloadState {
  status: DownloadStatus;
  progress: number;   // 0–6236
  total: number;      // 6236
  error?: string;
}

// Reader display

export type DisplayMode = 'paragraph' | 'ayah-by-ayah';
export type Theme = 'light' | 'dark' | 'sepia';

export interface AyahWithTranslations extends Ayah {
  translations: Array<{ edition_slug: string; text: string }>;
  words?: Word[];
}

export interface SearchResult {
  ayah_id: number;
  surah_id: number;
  surah_name: string;
  ayah_number: number;
  arabic_snippet: string;
  translation_snippet: string;
  edition_slug?: string;
}
