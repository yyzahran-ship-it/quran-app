import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single reciter entry.
class QAReciter {
  const QAReciter({
    required this.name,
    required this.relativePath,
  });

  final String name;
  // Folder slug used in CDN URLs, e.g. "Alafasy_128kbps".
  final String relativePath;
}

// ─── Curated reciter list ──────────────────────────────────────────────────────
//
// Strategy mirrors Quran for Android (github.com/quran/quran_android):
//   - Hardcoded, no runtime API call.
//   - Every slug here is a verified folder name on everyayah.com /
//     mirrors.quranicaudio.com/everyayah — the same CDN Quran for Android uses.
//   - Only reciters with a complete Quran recording are included.
//   - Sorted alphabetically by English name.

const List<QAReciter> _kReciters = [
  QAReciter(name: 'Abdul Basit (Murattal)',      relativePath: 'Abdul_Basit_Murattal_192kbps'),
  QAReciter(name: 'Abdul Basit (Mujawwad)',      relativePath: 'Abdul_Basit_Mujawwad_128kbps'),
  QAReciter(name: 'Abdullah Basfar',             relativePath: 'Abdullah_Basfar_192kbps'),
  QAReciter(name: 'Abdurrahman As-Sudais',       relativePath: 'Abdurrahmaan_As-Sudais_192kbps'),
  QAReciter(name: 'Abu Bakr Ash-Shatri',         relativePath: 'Abu_Bakr_Ash-Shaatree_128kbps'),
  QAReciter(name: 'Ahmed ibn Ali Al-Ajamy',      relativePath: 'Ahmed_ibn_Ali_al-Ajamy_128kbps'),
  QAReciter(name: 'Ali Al-Huthaify',             relativePath: 'Ali_Abdur-Rahman_Al-Huthaify_192kbps'),
  QAReciter(name: 'Bandar Baleela',              relativePath: 'Bandar_Baleela'),
  QAReciter(name: 'Fares Abbad',                 relativePath: 'Fares_Abbad_128kbps'),
  QAReciter(name: 'Hani Rifai',                  relativePath: 'Hani_Rifai_192kbps'),
  QAReciter(name: 'Ibrahim Al-Dosary',           relativePath: 'Ibrahim_Al-Dosary_128kbps'),
  QAReciter(name: 'Khalifa Al-Tunaiji',          relativePath: 'Khalefa_Al_Tunaiji_128kbps'),
  QAReciter(name: 'Mahmoud Al-Husary',           relativePath: 'Husary_128kbps'),
  QAReciter(name: 'Maher Al Muaiqly',            relativePath: 'MaherAlMuaiqly128kbps'),
  QAReciter(name: 'Mishary Rashid Alafasy',      relativePath: 'Alafasy_128kbps'),
  QAReciter(name: 'Mohamed Siddiq Al-Minshawi',  relativePath: 'Minshawi_Murattal_128kbps'),
  QAReciter(name: 'Mohammad Al-Tablawi',         relativePath: 'Mohammad_al_Tablawi_128kbps'),
  QAReciter(name: 'Muhammad Jibreel',            relativePath: 'Muhammad_Jibreel_128kbps'),
  QAReciter(name: 'Nasser Al-Qatami',            relativePath: 'Nasser_Alqatami_128kbps'),
  QAReciter(name: "Sa'd Al-Ghamdi",              relativePath: 'Saad_Al-Ghamdi_128kbps'),
  QAReciter(name: "Sa'ud ash-Shuraym",           relativePath: 'Shuraim_128kbps'),
  QAReciter(name: 'Wadee Hammadi Al-Yamani',     relativePath: 'Wadee_Hammadi_Al_Yamani_128kbps'),
  QAReciter(name: 'Yasser Al-Dossary',           relativePath: 'Yasser_Ad-Dussary_128kbps'),
];

/// Synchronous provider — no network call, no caching, always ready.
final reciterListProvider = Provider<List<QAReciter>>((_) => _kReciters);

/// Returns the display name for [slug], searching the curated list first,
/// then a hardcoded fallback map for slugs not in the list.
String reciterDisplayName(List<QAReciter> reciters, String slug) {
  for (final r in reciters) {
    if (r.relativePath == slug) return r.name;
  }
  const fallback = {
    'Alafasy_128kbps':                       'Mishary Rashid Alafasy',
    'Abdul_Basit_Murattal_192kbps':          'Abdul Basit (Murattal)',
    'Minshawi_Murattal_128kbps':             'Mohamed Siddiq Al-Minshawi',
    'Husary_128kbps':                        'Mahmoud Al-Husary',
    'MaherAlMuaiqly128kbps':                'Maher Al Muaiqly',
    'Abdullah_Basfar_192kbps':              'Abdullah Basfar',
    'Shuraim_128kbps':                       "Sa'ud ash-Shuraym",
    'Bandar_Baleela':                        'Bandar Baleela',
    'Ali_Abdur-Rahman_Al-Huthaify_192kbps': 'Ali Al-Huthaify',
    'Fares_Abbad_128kbps':                  'Fares Abbad',
    'Ibrahim_Al-Dosary_128kbps':            'Ibrahim Al-Dosary',
    'Khalefa_Al_Tunaiji_128kbps':           'Khalifa Al-Tunaiji',
    'Muhammad_Jibreel_128kbps':             'Muhammad Jibreel',
    'Wadee_Hammadi_Al_Yamani_128kbps':      'Wadee Hammadi Al-Yamani',
  };
  return fallback[slug] ?? slug;
}
