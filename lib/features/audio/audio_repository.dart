import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_models.dart';

const _kApiBase = 'https://api.quranicaudio.com';

// ── Verified reciter list (35 reciters) ───────────────────────────────────────
//
// Sources used for verification:
//  • Islamic Network edition codes: faha1999/al-quran-database editions.json
//    (cross-checked against alquran.cloud API)
//  • QuranicAudio paths: spa5k/quran-timings-api data/reciters.json
//    (actual API response data)
//
// Two CDN tiers:
//  • islamicNetworkEdition set  → cdn.islamic.network (verse-by-verse + tracking)
//  • islamicNetworkEdition null → download.quranicaudio.com (surah-level only)

const _kBuiltInReciters = <QuranicReciter>[

  // ── 18 reciters — verse-by-verse tracking via Islamic Network CDN ─────────

  // qdcReciterId values verified against spa5k/quran-timings-api + quran.com API
  // QDC IDs 1-12 are the full set with confirmed word-by-word timing data.

  QuranicReciter(
    id: 1, name: 'Mishary Rashid Al-Afasy', arabicName: 'مشاري راشد العفاسي',
    relativePath: 'mishari_rashid_al_afasy/',
    islamicNetworkEdition: 'ar.alafasy',
    qdcReciterId: 7,
  ),
  QuranicReciter(
    id: 2, name: 'AbdurRahman As-Sudais', arabicName: 'عبدالرحمن السديس',
    relativePath: 'abdurrahmaan_as-sudays/',
    islamicNetworkEdition: 'ar.abdurrahmaansudais',
    qdcReciterId: 3,
  ),
  QuranicReciter(
    id: 3, name: 'Abdul Basit (Murattal)', arabicName: 'عبدالباسط عبدالصمد',
    relativePath: 'abdul_basit_murattal/', style: 'Murattal',
    islamicNetworkEdition: 'ar.abdulbasitmurattal',
    qdcReciterId: 2,
  ),
  QuranicReciter(
    id: 4, name: 'Abdul Basit (Abdul Samad)', arabicName: 'عبدالباسط عبدالصمد',
    relativePath: 'abdulbasit_abdussamed/', style: 'Murattal',
    islamicNetworkEdition: 'ar.abdulsamad',
    qdcReciterId: 1,
  ),
  QuranicReciter(
    id: 5, name: 'Mahmoud Khalil Al-Husary', arabicName: 'محمود خليل الحصري',
    relativePath: 'mahmoud_khalil_al_husaree/', style: 'Murattal',
    islamicNetworkEdition: 'ar.husary',
    qdcReciterId: 6,
  ),
  QuranicReciter(
    id: 6, name: 'Al-Husary (Mujawwad)', arabicName: 'محمود خليل الحصري',
    relativePath: 'mahmoud_khalil_al_husaree_mujawwad/', style: 'Mujawwad',
    islamicNetworkEdition: 'ar.husarymujawwad',
    qdcReciterId: 12,
  ),
  QuranicReciter(
    id: 7, name: 'Abu Bakr Al-Shatri', arabicName: 'أبو بكر الشاطري',
    relativePath: 'abu_bakr_ash-shaatree/',
    islamicNetworkEdition: 'ar.shaatree',
    qdcReciterId: 4,
  ),
  QuranicReciter(
    id: 8, name: 'Ahmad ibn Ali Al-Ajamy', arabicName: 'أحمد بن علي العجمي',
    relativePath: 'ahmed_ibn_3ali_al-3ajamy/',
    islamicNetworkEdition: 'ar.ahmedajamy',
  ),
  QuranicReciter(
    id: 9, name: 'Hani Ar-Rifai', arabicName: 'هاني الرفاعي',
    relativePath: 'hani_ar-rifai/',
    islamicNetworkEdition: 'ar.hanirifai',
    qdcReciterId: 5,
  ),
  QuranicReciter(
    id: 10, name: 'Mohamed Siddiq Al-Minshawi', arabicName: 'محمد صديق المنشاوي',
    relativePath: 'siddiq_al-minshawi/', style: 'Murattal',
    islamicNetworkEdition: 'ar.minshawi',
    qdcReciterId: 8,
  ),
  QuranicReciter(
    id: 11, name: 'Al-Minshawi (Mujawwad)', arabicName: 'محمد صديق المنشاوي',
    relativePath: 'siddiq_al-minshawi/', style: 'Mujawwad',
    islamicNetworkEdition: 'ar.minshawimujawwad',
    qdcReciterId: 9,
  ),
  QuranicReciter(
    id: 12, name: 'Muhammad Ayyoob', arabicName: 'محمد أيوب',
    relativePath: 'muhammad_ayyoob/',
    islamicNetworkEdition: 'ar.muhammadayyoub',
  ),
  QuranicReciter(
    id: 13, name: 'Abdullah Basfar', arabicName: 'عبدالله بصفر',
    relativePath: 'abdullaah_basfar/',
    islamicNetworkEdition: 'ar.abdullahbasfar',
  ),
  QuranicReciter(
    id: 14, name: 'Maher Al-Muaiqly', arabicName: 'ماهر المعيقلي',
    relativePath: 'maher_al_muaiqly/',
    islamicNetworkEdition: 'ar.mahermuaiqly',
  ),
  QuranicReciter(
    id: 15, name: 'Muhammad Jibreel', arabicName: 'محمد جبريل',
    relativePath: 'muhammad_jibreel/',
    islamicNetworkEdition: 'ar.muhammadjibreel',
  ),
  QuranicReciter(
    id: 16, name: 'Ali Al-Hudhaifi', arabicName: 'علي الحذيفي',
    relativePath: 'huthayfi/',
    islamicNetworkEdition: 'ar.hudhaify',
  ),
  QuranicReciter(
    id: 17, name: 'Ibrahim Akhdar', arabicName: 'إبراهيم الأخضر',
    relativePath: 'ibrahim_al-akhdar/',
    islamicNetworkEdition: 'ar.ibrahimakhbar',
  ),
  QuranicReciter(
    id: 18, name: 'Saud Al-Shuraim', arabicName: 'سعود الشريم',
    relativePath: 'saoud_ash-shuraim/',
    islamicNetworkEdition: 'ar.saoodshuraym',
    qdcReciterId: 10,
  ),

  // ── 17 reciters — upgraded to verse-by-verse via everyAyah.com ───────────
  // Previously surah-level only (no ayah tracking, no word highlighting).
  // everyayahSubfolder verified from spa5k/quran-timings-api data/reciters.json.
  // URL: https://everyayah.com/data/{everyayahSubfolder}/{surah:3d}{ayah:3d}.mp3
  // Reciters without a confirmed everyayah path remain surah-level (no everyayahSubfolder).

  QuranicReciter(
    id: 19, name: 'Abdul Basit (Mujawwad)', arabicName: 'عبدالباسط عبدالصمد',
    relativePath: 'abdulbaset_mujawwad/', style: 'Mujawwad',
    everyayahSubfolder: 'Abdul_Basit_Mujawwad_128kbps',
  ),
  QuranicReciter(
    id: 20, name: 'Saad Al-Ghamdi', arabicName: 'سعد الغامدي',
    relativePath: 'sa3d_al-ghaamdi/',
    everyayahSubfolder: 'Ghamadi_40kbps',
  ),
  QuranicReciter(
    id: 21, name: 'Yasser Al-Dosari', arabicName: 'ياسر الدوسري',
    relativePath: 'yasser_ad_dussary/',
    everyayahSubfolder: 'Yasser_Ad-Dussary_128kbps',
  ),
  QuranicReciter(
    id: 22, name: 'Nasser Al-Qatami', arabicName: 'ناصر القطامي',
    relativePath: 'nasser_al-qatami/',
    everyayahSubfolder: 'Nasser_Alqatami_128kbps',
  ),
  QuranicReciter(
    id: 23, name: 'Abdullah Awad Al-Juhani', arabicName: 'عبدالله عواد الجهني',
    relativePath: 'abdullaah_3awwaad_al-juhaynee/',
    everyayahSubfolder: 'Abdullaah_3awwaad_Al-Juhaynee_128kbps',
  ),
  QuranicReciter(
    id: 24, name: 'Al-Husary (Muallam)', arabicName: 'محمود خليل الحصري',
    relativePath: 'husary_muallim/', style: 'Teaching',
    everyayahSubfolder: 'Husary_Muallim_128kbps',
  ),
  QuranicReciter(
    id: 25, name: 'Imad Zuhair Hafez', arabicName: 'عماد زهير حافظ',
    relativePath: 'imad_zuhair_hafez/',
    // No confirmed everyayah path — remains surah-level.
  ),
  QuranicReciter(
    id: 26, name: 'Fares Abbad', arabicName: 'فارس عباد',
    relativePath: 'fares/',
    everyayahSubfolder: 'Fares_Abbad_64kbps',
  ),
  QuranicReciter(
    id: 27, name: 'Ibrahim Al-Jibrin', arabicName: 'إبراهيم الجبرين',
    relativePath: 'jibreen/',
    // No confirmed everyayah path — remains surah-level.
  ),
  QuranicReciter(
    id: 28, name: 'Muhammad Al-Tablawi', arabicName: 'محمد الطبلاوي',
    relativePath: 'muhammad_al_tablawi/',
    everyayahSubfolder: 'Mohammad_al_Tablaway_128kbps',
    qdcReciterId: 11,
  ),
  QuranicReciter(
    id: 29, name: 'Salah Al-Budair', arabicName: 'صلاح البدير',
    relativePath: 'salah_al_budair/',
    everyayahSubfolder: 'Salah_Al_Budair_128kbps',
  ),
  QuranicReciter(
    id: 30, name: 'Sudais and Shuraim', arabicName: 'السديس والشريم',
    relativePath: 'sudais_and_shuraim/',
    // Combined reciter — no single everyayah path. Remains surah-level.
  ),
  QuranicReciter(
    id: 31, name: 'AbdulAzeez Al-Ahmad', arabicName: 'عبدالعزيز الأحمد',
    relativePath: 'abdulazeez_al-ahmad/',
    // No confirmed everyayah path — remains surah-level.
  ),
  QuranicReciter(
    id: 32, name: 'Abdur-Razaq Al-Dulaimi', arabicName: 'عبدالرزاق بن عبطان الدليمي',
    relativePath: 'abdulrazaq_bin_abtan_al_dulaimi/', style: 'Mujawwad',
    // No confirmed everyayah path — remains surah-level.
  ),
  QuranicReciter(
    id: 33, name: "Al-Hussayni (with Children)", arabicName: "الحسيني العزازي",
    relativePath: 'alhusaynee_al3azazee_with_children/',
    // No confirmed everyayah path — remains surah-level.
  ),
  QuranicReciter(
    id: 34, name: 'Salaah Abu Ismail', arabicName: 'صلاح أبو إسماعيل',
    relativePath: 'salaah_abu_ismail/',
    // No confirmed everyayah path — remains surah-level.
  ),
  QuranicReciter(
    id: 35, name: 'Hamad Sinan', arabicName: 'حمد سنان',
    relativePath: 'hamad_sinan/',
    // No confirmed everyayah path — remains surah-level.
  ),

  // ── Additional reciters — upgraded to verse-by-verse via everyAyah.com ──────
  // Sourced from quran/quran_android readers.xml + spa5k/quran-timings-api.

  QuranicReciter(
    id: 36, name: 'Aziz Alili', arabicName: 'عزيز عليلي',
    relativePath: 'aziz_alili/',
    everyayahSubfolder: 'aziz_alili_128kbps',
  ),
  QuranicReciter(
    id: 37, name: 'Mostafa Ismaeel', arabicName: 'مصطفى إسماعيل',
    relativePath: 'mostafa_ismaeel/',
    everyayahSubfolder: 'Mustafa_Ismail_48kbps',
  ),
  QuranicReciter(
    id: 38, name: 'Wadee Al-Yamani', arabicName: 'وديع اليماني',
    relativePath: 'wadee_hammadi_al-yamani/',
    // No confirmed everyayah path — remains surah-level.
  ),
  QuranicReciter(
    id: 39, name: 'Tawfeeq as-Sawaigh', arabicName: 'توفيق الصايغ',
    relativePath: 'tawfeeq_bin_saeed-as-sawaaigh/',
    // No confirmed everyayah path — remains surah-level.
  ),
  QuranicReciter(
    id: 40, name: 'Akram Al-Alaqmi',
    relativePath: 'akram_al_alaqmi/',
    everyayahSubfolder: 'Akram_AlAlaqimy_128kbps',
  ),
  QuranicReciter(
    id: 41, name: 'Alzain Mohammad Ahmad',
    relativePath: 'alzain_mohammad_ahmad/',
    // No confirmed everyayah path — remains surah-level.
  ),
  QuranicReciter(
    id: 42, name: 'Muhammad Al-Luhaidan', arabicName: 'محمد اللحيدان',
    relativePath: 'muhammad_al-luhaidan/',
    // No confirmed everyayah path — remains surah-level.
  ),
  QuranicReciter(
    id: 43, name: 'AbdulHadi Kanakeri',
    relativePath: 'abdulhadi_kanakeri/',
    // No confirmed everyayah path — remains surah-level.
  ),
  QuranicReciter(
    id: 44, name: 'Bandar Baleela', arabicName: 'بندر بليلة',
    relativePath: 'bandar_baleela/complete/',
    // No confirmed everyayah path — remains surah-level.
  ),

  // ── 1 English reciter — verse-by-verse tracking via Islamic Network CDN ──────
  // en.walk is a confirmed Islamic Network audio edition.
  QuranicReciter(
    id: 45, name: 'Ibrahim Walk (English)',
    relativePath: 'ibrahim_walk_saheeh_intl/',
    islamicNetworkEdition: 'en.walk',
  ),
];

class QuranicAudioRepository {
  QuranicAudioRepository(this._dio);
  final Dio _dio;

  Future<List<QuranicReciter>> fetchReciters() async {
    try {
      final response = await _dio.get(
        '$_kApiBase/quran/reciters',
        options: Options(
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
      );
      final list = response.data as List<dynamic>;
      // Append live-API reciters not already covered by the built-in list.
      // Built-in reciters keep their verified paths and islamicNetworkEdition.
      final knownPaths = {for (final r in _kBuiltInReciters) r.relativePath};
      final extras = <QuranicReciter>[];
      int extraId = 1000;
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final rawPath = (map['relative_path'] as String?) ?? '';
        // Normalise: ensure trailing slash.
        final path = rawPath.isEmpty
            ? ''
            : rawPath.endsWith('/')
                ? rawPath
                : '$rawPath/';
        if (path.isNotEmpty && !knownPaths.contains(path)) {
          extras.add(QuranicReciter(
            id: extraId++,
            name: (map['name'] as String?)?.trim() ?? 'Unknown',
            arabicName: map['arabic_name'] as String?,
            relativePath: path,
            style: map['style'] as String?,
          ));
        }
      }
      return [..._kBuiltInReciters, ...extras];
    } catch (_) {
      // API unreachable — built-in list only.
    }
    return _kBuiltInReciters;
  }
}

final quranicAudioRepositoryProvider = Provider<QuranicAudioRepository>((ref) {
  return QuranicAudioRepository(Dio());
});
