import type { TranslationCatalogEntry, TafsirCatalogEntry } from '../types/quran';

export const TRANSLATIONS: TranslationCatalogEntry[] = [
  {
    id: 'en.sahih',
    language: 'en',
    name: 'Saheeh International',
    translator: 'Saheeh International',
    direction: 'ltr',
    apiIdentifier: 'en.sahih',
  },
  {
    id: 'en.pickthall',
    language: 'en',
    name: 'Pickthall',
    translator: 'Mohammed Marmaduke William Pickthall',
    direction: 'ltr',
    apiIdentifier: 'en.pickthall',
  },
  {
    id: 'en.yusufali',
    language: 'en',
    name: 'Yusuf Ali',
    translator: 'Abdullah Yusuf Ali',
    direction: 'ltr',
    apiIdentifier: 'en.yusufali',
  },
  {
    id: 'en.asad',
    language: 'en',
    name: 'Muhammad Asad',
    translator: 'Muhammad Asad',
    direction: 'ltr',
    apiIdentifier: 'en.asad',
  },
  {
    id: 'en.ahmedali',
    language: 'en',
    name: 'Ahmed Ali',
    translator: 'Ahmed Ali',
    direction: 'ltr',
    apiIdentifier: 'en.ahmedali',
  },
  {
    id: 'en.hilali',
    language: 'en',
    name: 'Muhsin Khan',
    translator: 'Muhammad Taqi-ud-Din Al-Hilali and Muhammad Muhsin Khan',
    direction: 'ltr',
    apiIdentifier: 'en.hilali',
  },
  {
    id: 'ar.muyassar',
    language: 'ar',
    name: 'Al-Muyassar (التفسير الميسر)',
    translator: 'King Fahd Quran Complex',
    direction: 'rtl',
    apiIdentifier: 'ar.muyassar',
  },
  {
    id: 'ar.jalalayn',
    language: 'ar',
    name: 'Jalalayn (الجلالين)',
    translator: 'Al-Suyuti and Al-Mahalli',
    direction: 'rtl',
    apiIdentifier: 'ar.jalalayn',
  },
  {
    id: 'fr.hamidullah',
    language: 'fr',
    name: 'Hamidullah (Français)',
    translator: 'Muhammad Hamidullah',
    direction: 'ltr',
    apiIdentifier: 'fr.hamidullah',
  },
  {
    id: 'ur.jalandhry',
    language: 'ur',
    name: 'Jalandhry (اردو)',
    translator: 'Fateh Muhammad Jalandhry',
    direction: 'rtl',
    apiIdentifier: 'ur.jalandhry',
  },
  {
    id: 'ur.maududi',
    language: 'ur',
    name: 'Maududi (اردو)',
    translator: 'Abul Ala Maududi',
    direction: 'rtl',
    apiIdentifier: 'ur.maududi',
  },
  {
    id: 'de.bubenheim',
    language: 'de',
    name: 'Bubenheim & Elyas (Deutsch)',
    translator: 'Nadeem Elyas & Frank Bubenheim',
    direction: 'ltr',
    apiIdentifier: 'de.bubenheim',
  },
  {
    id: 'es.asad',
    language: 'es',
    name: 'Asad (Español)',
    translator: 'Muhammad Asad',
    direction: 'ltr',
    apiIdentifier: 'es.asad',
  },
  {
    id: 'id.indonesian',
    language: 'id',
    name: 'Indonesian (Bahasa)',
    translator: 'Indonesian Ministry of Religious Affairs',
    direction: 'ltr',
    apiIdentifier: 'id.indonesian',
  },
  {
    id: 'tr.diyanet',
    language: 'tr',
    name: 'Diyanet İşleri (Türkçe)',
    translator: 'Diyanet İşleri',
    direction: 'ltr',
    apiIdentifier: 'tr.diyanet',
  },
];

export const TAFSIRS: TafsirCatalogEntry[] = [
  {
    id: 'en.kathir',
    name: 'Ibn Kathir (English)',
    author: 'Ibn Kathir',
    language: 'en',
    apiSource: 'quranenc',
    apiIdentifier: 'english_ibn_katheer',
  },
  {
    id: 'ar.kathir',
    name: 'ابن كثير (عربي)',
    author: 'ابن كثير',
    language: 'ar',
    apiSource: 'quranenc',
    apiIdentifier: 'arabic_ibn_katheer',
  },
  {
    id: 'ar.tabari',
    name: 'الطبري',
    author: 'محمد بن جرير الطبري',
    language: 'ar',
    apiSource: 'quranenc',
    apiIdentifier: 'arabic_tabary',
  },
  {
    id: 'ar.saadi',
    name: 'تفسير السعدي',
    author: 'عبد الرحمن بن ناصر السعدي',
    language: 'ar',
    apiSource: 'quranenc',
    apiIdentifier: 'arabic_saadi',
  },
  {
    id: 'ar.muyassar',
    name: 'التفسير الميسر',
    author: 'نخبة من العلماء',
    language: 'ar',
    apiSource: 'quranenc',
    apiIdentifier: 'arabic_moyassar',
  },
  {
    id: 'en.maariful',
    name: "Ma'ariful Quran (English)",
    author: 'Mufti Muhammad Shafi Usmani',
    language: 'en',
    apiSource: 'quranenc',
    apiIdentifier: 'english_maarif',
  },
];

export const DEFAULT_TRANSLATION_IDS = ['en.sahih', 'ar.muyassar'];
export const DEFAULT_TAFSIR_IDS = ['en.kathir'];

// alquran.cloud base URL
export const ALQURAN_BASE = 'https://api.alquran.cloud/v1';
// quranenc base URL
export const QURANENC_BASE = 'https://quranenc.com/api/v1';
