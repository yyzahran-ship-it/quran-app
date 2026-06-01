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

  QuranicReciter(
    id: 1, name: 'Mishary Rashid Al-Afasy', arabicName: 'مشاري راشد العفاسي',
    relativePath: 'mishari_rashid_al_afasy/',
    islamicNetworkEdition: 'ar.alafasy',
  ),
  QuranicReciter(
    id: 2, name: 'AbdurRahman As-Sudais', arabicName: 'عبدالرحمن السديس',
    relativePath: 'abdurrahmaan_as-sudays/',
    islamicNetworkEdition: 'ar.abdurrahmaansudais',
  ),
  QuranicReciter(
    id: 3, name: 'Abdul Basit (Murattal)', arabicName: 'عبدالباسط عبدالصمد',
    relativePath: 'abdul_basit_murattal/', style: 'Murattal',
    islamicNetworkEdition: 'ar.abdulbasitmurattal',
  ),
  QuranicReciter(
    id: 4, name: 'Abdul Basit (Abdul Samad)', arabicName: 'عبدالباسط عبدالصمد',
    relativePath: 'abdulbasit_abdussamed/', style: 'Murattal',
    islamicNetworkEdition: 'ar.abdulsamad',
  ),
  QuranicReciter(
    id: 5, name: 'Mahmoud Khalil Al-Husary', arabicName: 'محمود خليل الحصري',
    relativePath: 'mahmoud_khalil_al_husaree/', style: 'Murattal',
    islamicNetworkEdition: 'ar.husary',
  ),
  QuranicReciter(
    id: 6, name: 'Al-Husary (Mujawwad)', arabicName: 'محمود خليل الحصري',
    relativePath: 'mahmoud_khalil_al_husaree_mujawwad/', style: 'Mujawwad',
    islamicNetworkEdition: 'ar.husarymujawwad',
  ),
  QuranicReciter(
    id: 7, name: 'Abu Bakr Al-Shatri', arabicName: 'أبو بكر الشاطري',
    relativePath: 'abu_bakr_ash-shaatree/',
    islamicNetworkEdition: 'ar.shaatree',
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
  ),
  QuranicReciter(
    id: 10, name: 'Mohamed Siddiq Al-Minshawi', arabicName: 'محمد صديق المنشاوي',
    relativePath: 'siddiq_al-minshawi/', style: 'Murattal',
    islamicNetworkEdition: 'ar.minshawi',
  ),
  QuranicReciter(
    id: 11, name: 'Al-Minshawi (Mujawwad)', arabicName: 'محمد صديق المنشاوي',
    relativePath: 'siddiq_al-minshawi/', style: 'Mujawwad',
    islamicNetworkEdition: 'ar.minshawimujawwad',
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
  ),

  // ── 17 reciters — surah-level only via QuranicAudio CDN ──────────────────
  // Paths verified from spa5k/quran-timings-api data/reciters.json

  QuranicReciter(
    id: 19, name: 'Abdul Basit (Mujawwad)', arabicName: 'عبدالباسط عبدالصمد',
    relativePath: 'abdulbaset_mujawwad/', style: 'Mujawwad',
  ),
  QuranicReciter(
    id: 20, name: 'Saad Al-Ghamdi', arabicName: 'سعد الغامدي',
    relativePath: 'sa3d_al-ghaamdi/',
  ),
  QuranicReciter(
    id: 21, name: 'Yasser Al-Dosari', arabicName: 'ياسر الدوسري',
    relativePath: 'yasser_ad_dussary/',
  ),
  QuranicReciter(
    id: 22, name: 'Nasser Al-Qatami', arabicName: 'ناصر القطامي',
    relativePath: 'nasser_al-qatami/',
  ),
  QuranicReciter(
    id: 23, name: 'Abdullah Awad Al-Juhani', arabicName: 'عبدالله عواد الجهني',
    relativePath: 'abdullaah_3awwaad_al-juhaynee/',
  ),
  QuranicReciter(
    id: 24, name: 'Al-Husary (Muallam)', arabicName: 'محمود خليل الحصري',
    relativePath: 'husary_muallim/', style: 'Teaching',
  ),
  QuranicReciter(
    id: 25, name: 'Imad Zuhair Hafez', arabicName: 'عماد زهير حافظ',
    relativePath: 'imad_zuhair_hafez/',
  ),
  QuranicReciter(
    id: 26, name: 'Fares Abbad', arabicName: 'فارس عباد',
    relativePath: 'fares/',
  ),
  QuranicReciter(
    id: 27, name: 'Ibrahim Al-Jibrin', arabicName: 'إبراهيم الجبرين',
    relativePath: 'jibreen/',
  ),
  QuranicReciter(
    id: 28, name: 'Muhammad Al-Tablawi', arabicName: 'محمد الطبلاوي',
    relativePath: 'muhammad_al_tablawi/',
  ),
  QuranicReciter(
    id: 29, name: 'Salah Al-Budair', arabicName: 'صلاح البدير',
    relativePath: 'salah_al_budair/',
  ),
  QuranicReciter(
    id: 30, name: 'Sudais and Shuraim', arabicName: 'السديس والشريم',
    relativePath: 'sudais_and_shuraim/',
  ),
  QuranicReciter(
    id: 31, name: 'AbdulAzeez Al-Ahmad', arabicName: 'عبدالعزيز الأحمد',
    relativePath: 'abdulazeez_al-ahmad/',
  ),
  QuranicReciter(
    id: 32, name: 'Abdur-Razaq Al-Dulaimi', arabicName: 'عبدالرزاق بن عبطان الدليمي',
    relativePath: 'abdulrazaq_bin_abtan_al_dulaimi/', style: 'Mujawwad',
  ),
  QuranicReciter(
    id: 33, name: "Al-Hussayni (with Children)", arabicName: "الحسيني العزازي",
    relativePath: 'alhusaynee_al3azazee_with_children/',
  ),
  QuranicReciter(
    id: 34, name: 'Salaah Abu Ismail', arabicName: 'صلاح أبو إسماعيل',
    relativePath: 'salaah_abu_ismail/',
  ),
  QuranicReciter(
    id: 35, name: 'Hamad Sinan', arabicName: 'حمد سنان',
    relativePath: 'hamad_sinan/',
  ),

  // ── Additional gapless reciters — surah-level via QuranicAudio CDN ──────────
  // Sourced from quran/quran_android readers.xml + CDN path verification.
  // Verified = direct CDN URL evidence; high-conf = archive.org/search snippets.

  QuranicReciter(
    id: 36, name: 'Aziz Alili', arabicName: 'عزيز عليلي',
    relativePath: 'aziz_alili/',
  ),
  QuranicReciter(
    id: 37, name: 'Mostafa Ismaeel', arabicName: 'مصطفى إسماعيل',
    relativePath: 'mostafa_ismaeel/',
  ),
  QuranicReciter(
    id: 38, name: 'Wadee Al-Yamani', arabicName: 'وديع اليماني',
    relativePath: 'wadee_hammadi_al-yamani/',
  ),
  QuranicReciter(
    id: 39, name: 'Tawfeeq as-Sawaigh', arabicName: 'توفيق الصايغ',
    relativePath: 'tawfeeq_bin_saeed-as-sawaaigh/',
  ),
  QuranicReciter(
    id: 40, name: 'Akram Al-Alaqmi',
    relativePath: 'akram_al_alaqmi/',
  ),
  QuranicReciter(
    id: 41, name: 'Alzain Mohammad Ahmad',
    relativePath: 'alzain_mohammad_ahmad/',
  ),
  QuranicReciter(
    id: 42, name: 'Muhammad Al-Luhaidan', arabicName: 'محمد اللحيدان',
    relativePath: 'muhammad_al-luhaidan/',
  ),
  QuranicReciter(
    id: 43, name: 'AbdulHadi Kanakeri',
    relativePath: 'abdulhadi_kanakeri/',
  ),
  QuranicReciter(
    id: 44, name: 'Bandar Baleela', arabicName: 'بندر بليلة',
    relativePath: 'bandar_baleela/complete/',
  ),
  QuranicReciter(
    id: 45, name: 'Sahl Yaseen',
    relativePath: 'sahl_yaseen/',
  ),
  QuranicReciter(
    id: 46, name: 'Ahmad Nauina',
    relativePath: 'ahmad_nauina/',
  ),
  QuranicReciter(
    id: 47, name: 'Ali Hajjaj Alsouasi',
    relativePath: 'ali_hajjaj_alsouasi/',
  ),
  QuranicReciter(
    id: 48, name: 'Mahmoud Ali al-Bana', arabicName: 'محمود علي البنا',
    relativePath: 'mahmoud_ali_al_bana/',
  ),
  QuranicReciter(
    id: 49, name: 'Abdulrahman Al-Shahat',
    relativePath: 'abdulrahman_al-shahat/',
  ),
  QuranicReciter(
    id: 50, name: 'Abdur-Rashid Sufi',
    relativePath: 'abdur-rashid_sufi/',
  ),
  QuranicReciter(
    id: 51, name: 'Abdulaziz Az-Zahrani', arabicName: 'عبدالعزيز الزهراني',
    relativePath: 'abdulaziz_az-zahrani/',
  ),
  QuranicReciter(
    id: 52, name: 'Dr. Ayman Suwaid', arabicName: 'أيمن سويد',
    relativePath: 'ayman_suwaid/',
  ),
  QuranicReciter(
    id: 53, name: 'Mishari Al-Afasy (California)', arabicName: 'مشاري راشد العفاسي',
    relativePath: 'mishari_rashid_al_afasy_california/',
  ),
  QuranicReciter(
    id: 54, name: 'Ali Jaber', arabicName: 'علي جابر',
    relativePath: 'ali_jaber/',
  ),
  QuranicReciter(
    id: 55, name: 'Maher Al-Muaiqly (Haramain)', arabicName: 'ماهر المعيقلي',
    relativePath: 'maher_al_muaiqly_2012/',
  ),
  QuranicReciter(
    id: 56, name: 'AbdulMuhsin al-Qasim', arabicName: 'عبدالمحسن القاسم',
    relativePath: 'abdulmuhsin_al-qasim/',
  ),
  QuranicReciter(
    id: 57, name: 'Khalifa Altunaiji',
    relativePath: 'khalifa_altunaiji/',
  ),
  QuranicReciter(
    id: 58, name: 'Abdullah Matroud', arabicName: 'عبدالله مطرود',
    relativePath: 'abdullaah_matrood/',
  ),
  QuranicReciter(
    id: 59, name: 'Salah Bukhatir', arabicName: 'صلاح بوخاطر',
    relativePath: 'salah_bukhatir/',
  ),
  QuranicReciter(
    id: 60, name: 'Khalid Al-Qahtani', arabicName: 'خالد القحطاني',
    relativePath: 'khalid_al-qahtani/',
  ),
  QuranicReciter(
    id: 61, name: 'Abdulrahman Aloosi',
    relativePath: 'abdulrahman_aloosi/',
  ),
  QuranicReciter(
    id: 62, name: 'Muhammad Rashad Al-Shereef',
    relativePath: 'muhammad_rashad_al-shereef/',
  ),
  QuranicReciter(
    id: 63, name: 'Hady Toure', arabicName: 'هادي توري',
    relativePath: 'hady_toure/',
  ),
  QuranicReciter(
    id: 64, name: 'Khalid Al-Jalil', arabicName: 'خالد الجليل',
    relativePath: 'khalid_al-jalil/',
  ),
  QuranicReciter(
    id: 65, name: 'Nabil Ar-Rifai', arabicName: 'نبيل الرفاعي',
    relativePath: 'nabil_ar-rifai/',
  ),
  QuranicReciter(
    id: 66, name: 'Noreen Siddiq',
    relativePath: 'noreen_siddiq/',
  ),
  QuranicReciter(
    id: 67, name: 'Badr Al-Turki', arabicName: 'بدر التركي',
    relativePath: 'badr_al-turki/',
  ),
  QuranicReciter(
    id: 68, name: 'Idrees Abkar', arabicName: 'إدريس أبكر',
    relativePath: 'idrees_abkar/',
  ),
  QuranicReciter(
    id: 69, name: 'Raad Al-Kurdi', arabicName: 'رعد الكردي',
    relativePath: 'raad_al-kurdi/',
  ),
  QuranicReciter(
    id: 70, name: 'Ahmed Al-Nufais',
    relativePath: 'ahmed_al_nufais/',
  ),
  QuranicReciter(
    id: 71, name: 'Peshewa Qadir al-Kurdi',
    relativePath: 'peshawa_qadir_al-kurdi/',
  ),
  QuranicReciter(
    id: 72, name: 'Farman Shawani',
    relativePath: 'farman_shawani/',
  ),
  QuranicReciter(
    id: 73, name: 'Yasser Salama', style: 'Hadr',
    relativePath: 'yasser_salama/',
  ),
  QuranicReciter(
    id: 74, name: 'Ibrahim Walk (English)',
    relativePath: 'ibrahim_walk_saheeh_intl/',
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
