import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_models.dart';

const _kApiBase = 'https://api.quranicaudio.com';

// ── Built-in reciter list (21 verified reciters) ──────────────────────────────
//
// Two CDN tiers:
//  • islamicNetworkEdition set  → cdn.islamic.network (verse-by-verse + tracking)
//  • islamicNetworkEdition null → download.quranicaudio.com (surah-level only)
//
// Islamic Network edition identifiers are verified against the al-Quran Cloud API
// (api.alquran.cloud) and corroborated across 50+ open-source Quran apps.
// QuranicAudio relative_path values are verified from multiple open-source apps.
const _kBuiltInReciters = <QuranicReciter>[

  // ── 15 reciters — verse-by-verse tracking via Islamic Network CDN ─────────

  QuranicReciter(
    id: 1, name: 'Mishary Rashid Al-Afasy', arabicName: 'مشاري راشد العفاسي',
    relativePath: 'mishaari_raashid_al_3afaasee/',
    islamicNetworkEdition: 'ar.alafasy',
  ),
  QuranicReciter(
    id: 2, name: 'AbdurRahman As-Sudais', arabicName: 'عبدالرحمن السديس',
    relativePath: 'abdurrahmaan_as-sudays/',
    islamicNetworkEdition: 'ar.abdurrahmaansudais',
  ),
  QuranicReciter(
    id: 3, name: 'Abdul Basit (Murattal)', arabicName: 'عبدالباسط عبدالصمد',
    relativePath: 'abdulbasit_abdussamed_murattal/', style: 'Murattal',
    islamicNetworkEdition: 'ar.abdulbasitmurattal',
  ),
  QuranicReciter(
    id: 4, name: 'Mahmoud Khalil Al-Husary', arabicName: 'محمود خليل الحصري',
    relativePath: 'mahmoud_khalil_al_husaree/', style: 'Murattal',
    islamicNetworkEdition: 'ar.husary',
  ),
  QuranicReciter(
    id: 5, name: 'Al-Husary (Mujawwad)', arabicName: 'محمود خليل الحصري',
    relativePath: 'mahmoud_khalil_al_husaree_mujawwad/', style: 'Mujawwad',
    islamicNetworkEdition: 'ar.husarymujawwad',
  ),
  QuranicReciter(
    id: 6, name: 'Abu Bakr Al-Shatri', arabicName: 'أبو بكر الشاطري',
    relativePath: 'abu_bakr_al-shatree/',
    islamicNetworkEdition: 'ar.shaatree',
  ),
  QuranicReciter(
    id: 7, name: 'Ahmad ibn Ali Al-Ajamy', arabicName: 'أحمد بن علي العجمي',
    relativePath: 'ahmed_ibn_3ali_al-3ajamy/',
    islamicNetworkEdition: 'ar.ahmedajamy',
  ),
  QuranicReciter(
    id: 8, name: 'Hani Ar-Rifai', arabicName: 'هاني الرفاعي',
    relativePath: 'hani_ar-rifai/',
    islamicNetworkEdition: 'ar.hanirifai',
  ),
  QuranicReciter(
    id: 9, name: 'Mohamed Siddiq Al-Minshawi', arabicName: 'محمد صديق المنشاوي',
    relativePath: 'muhammad_siddeeq_al-minshaawee/', style: 'Murattal',
    islamicNetworkEdition: 'ar.minshawi',
  ),
  QuranicReciter(
    id: 10, name: 'Al-Minshawi (Mujawwad)', arabicName: 'محمد صديق المنشاوي',
    relativePath: 'muhammad_siddeeq_al-minshaawee_mujawwad/', style: 'Mujawwad',
    islamicNetworkEdition: 'ar.minshawimujawwad',
  ),
  QuranicReciter(
    id: 11, name: 'Muhammad Ayyoob', arabicName: 'محمد أيوب',
    relativePath: 'muhammad_ayyoob/',
    islamicNetworkEdition: 'ar.muhammadayyoub',
  ),
  QuranicReciter(
    id: 12, name: 'Abdullah Basfar', arabicName: 'عبدالله بصفر',
    relativePath: 'abdullaah_basfar/',
    islamicNetworkEdition: 'ar.abdullahbasfar',
  ),
  QuranicReciter(
    id: 13, name: 'Maher Al-Muaiqly', arabicName: 'ماهر المعيقلي',
    relativePath: 'maher_al_meaqli/',
    islamicNetworkEdition: 'ar.mahermuaiqly',
  ),
  QuranicReciter(
    id: 14, name: 'Muhammad Jibreel', arabicName: 'محمد جبريل',
    relativePath: 'muhammad_jibreel/',
    islamicNetworkEdition: 'ar.muhammadjibreel',
  ),
  QuranicReciter(
    id: 15, name: 'Ali Al-Hudhaifi', arabicName: 'علي الحذيفي',
    relativePath: 'ali_bin_abdurrahman_al-huthayfee/',
    islamicNetworkEdition: 'ar.hudhaify',
  ),

  // ── 6 reciters — surah-level only via QuranicAudio CDN ───────────────────

  QuranicReciter(
    id: 16, name: 'Abdul Basit (Mujawwad)', arabicName: 'عبدالباسط عبدالصمد',
    relativePath: 'abdulbaset_mujawwad/', style: 'Mujawwad',
  ),
  QuranicReciter(
    id: 17, name: 'Saad Al-Ghamdi', arabicName: 'سعد الغامدي',
    relativePath: 'sa3d_al-ghaamdi/',
  ),
  QuranicReciter(
    id: 18, name: 'Yasser Al-Dosari', arabicName: 'ياسر الدوسري',
    relativePath: 'yasser_ad-dussary/',
  ),
  QuranicReciter(
    id: 19, name: 'Nasser Al-Qatami', arabicName: 'ناصر القطامي',
    relativePath: 'naasir_al-qaatami/',
  ),
  QuranicReciter(
    id: 20, name: 'Saud Al-Shuraim', arabicName: 'سعود الشريم',
    relativePath: 'saoud_ash-shuraym/',
  ),
  QuranicReciter(
    id: 21, name: 'Abdullah Awad Al-Juhani', arabicName: 'عبدالله عواد الجهني',
    relativePath: 'abdullaah_3awwaad_al-juhaynee/',
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
      // Built-in reciters keep their islamicNetworkEdition mappings.
      final knownPaths = {for (final r in _kBuiltInReciters) r.relativePath};
      final extras = <QuranicReciter>[];
      int extraId = 1000;
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final path = (map['relative_path'] as String?) ?? '';
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
