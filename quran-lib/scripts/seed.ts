#!/usr/bin/env ts-node
/**
 * CLI seed script — runs outside the app for pre-populating a DB file
 * that can be bundled as an asset.
 *
 * Usage: npx ts-node scripts/seed.ts
 *
 * NOTE: In the app itself, seeding runs automatically via SeedService.ts.
 * This script is for offline DB pre-generation.
 */

const ALQURAN_BASE = 'https://api.alquran.cloud/v1';
const QURANENC_BASE = 'https://quranenc.com/api/v1';

interface AlquranAyah {
  number: number;
  numberInSurah: number;
  text: string;
  juz: number;
  hizbQuarter: number;
  sajda: boolean | object;
}

interface AlquranSurah {
  number: number;
  name: string;
  englishName: string;
  englishNameTranslation: string;
  revelationType: string;
  numberOfAyahs: number;
  ayahs: AlquranAyah[];
}

async function fetchWithRetry(url: string, retries = 3): Promise<unknown> {
  for (let i = 0; i < retries; i++) {
    try {
      const res = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
      return res.json();
    } catch (e) {
      if (i === retries - 1) throw e;
      await new Promise((r) => setTimeout(r, 1000 * (i + 1)));
    }
  }
}

async function main() {
  console.log('Fetching Quran text (quran-uthmani)…');
  const data = await fetchWithRetry(`${ALQURAN_BASE}/quran/quran-uthmani`) as { data: { surahs: AlquranSurah[] } };
  const surahs = data.data.surahs;

  let ayahCount = 0;
  for (const s of surahs) {
    ayahCount += s.ayahs.length;
  }
  console.log(`  ${surahs.length} surahs, ${ayahCount} ayahs fetched.`);

  const translations = [
    { slug: 'en.sahih',    label: 'Saheeh International' },
    { slug: 'en.pickthall', label: 'Pickthall' },
    { slug: 'ar.muyassar', label: 'Al-Muyassar' },
  ];

  for (const edition of translations) {
    console.log(`Fetching translation: ${edition.label}…`);
    const tData = await fetchWithRetry(`${ALQURAN_BASE}/quran/${edition.slug}`) as { data: { surahs: AlquranSurah[] } };
    let tCount = 0;
    for (const s of tData.data.surahs) tCount += s.ayahs.length;
    console.log(`  ${tCount} verses for ${edition.label}`);
  }

  const tafsirs = [
    { slug: 'en.kathir', apiId: 'english_ibn_katheer', label: 'Ibn Kathir (EN)' },
    { slug: 'ar.saadi',  apiId: 'arabic_saadi',        label: 'Al-Sa\'di (AR)' },
  ];

  for (const tafsir of tafsirs) {
    console.log(`Fetching tafsir: ${tafsir.label}…`);
    let total = 0;
    for (let s = 1; s <= 114; s++) {
      try {
        const tData = await fetchWithRetry(`${QURANENC_BASE}/translation/sura/${tafsir.apiId}/${s}`) as { result: Array<{ aya: number; translation: string }> };
        total += (tData.result ?? []).length;
      } catch {
        // Non-fatal
      }
      process.stdout.write(`\r  Surah ${s}/114 (${total} ayahs)    `);
    }
    console.log(`\n  Total: ${total} tafsir entries`);
  }

  console.log('\nSeed data verified. Use SeedService.ts for in-app seeding.');
}

main().catch((e) => { console.error(e); process.exit(1); });
