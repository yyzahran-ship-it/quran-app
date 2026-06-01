import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_models.dart';

const _kApiBase = 'https://api.quranicaudio.com';

// ── Built-in reciter list ─────────────────────────────────────────────────────
//
// Two CDN tiers:
//  • islamicNetworkEdition set  → Islamic Network CDN (verse-by-verse + tracking)
//  • islamicNetworkEdition null → QuranicAudio CDN (surah-level only)
const _kBuiltInReciters = <QuranicReciter>[
  // ── Verse tracking enabled (Islamic Network CDN) ──────────────────────────
  QuranicReciter(id: 1,  name: 'Mishary Rashid Al-Afasy',      arabicName: 'مشاري راشد العفاسي',     relativePath: 'mishaari_raashid_al_3afaasee/',            islamicNetworkEdition: 'ar.alafasy'),
  QuranicReciter(id: 2,  name: 'AbdurRahman As-Sudais',        arabicName: 'عبدالرحمن السديس',       relativePath: 'abdurrahmaan_as-sudays/',                  islamicNetworkEdition: 'ar.abdurrahmaansudais'),
  QuranicReciter(id: 3,  name: 'Abdul Basit (Murattal)',        arabicName: 'عبدالباسط عبدالصمد',    relativePath: 'abdulbasit_abdussamed_murattal/',          style: 'Murattal', islamicNetworkEdition: 'ar.abdulsamad'),
  QuranicReciter(id: 4,  name: 'Mahmoud Khalil Al-Husary',     arabicName: 'محمود خليل الحصري',      relativePath: 'mahmoud_khalil_al_husaree/',               style: 'Murattal', islamicNetworkEdition: 'ar.husary'),
  QuranicReciter(id: 5,  name: 'Al-Husary (Mujawwad)',         arabicName: 'محمود خليل الحصري',      relativePath: 'mahmoud_khalil_al_husaree_mujawwad/',      style: 'Mujawwad', islamicNetworkEdition: 'ar.husarymujawwad'),
  QuranicReciter(id: 6,  name: 'Abu Bakr Al-Shatri',           arabicName: 'أبو بكر الشاطري',        relativePath: 'abu_bakr_al-shatree/',                     islamicNetworkEdition: 'ar.shaatree'),
  QuranicReciter(id: 7,  name: 'Ahmad ibn Ali Al-Ajamy',       arabicName: 'أحمد بن علي العجمي',    relativePath: 'ahmad_ibn_3ali_al-3ajamy/',                islamicNetworkEdition: 'ar.ahmedajamy'),
  QuranicReciter(id: 8,  name: 'Hani Ar-Rifai',                arabicName: 'هاني الرفاعي',           relativePath: 'hani_ar-rifai/',                           islamicNetworkEdition: 'ar.hanirifai'),
  QuranicReciter(id: 9,  name: 'Mohamed Siddiq Al-Minshawi',   arabicName: 'محمد صديق المنشاوي',    relativePath: 'muhammad_siddeeq_al-minshaawee/',          style: 'Murattal', islamicNetworkEdition: 'ar.minshawi'),
  QuranicReciter(id: 10, name: 'Al-Minshawi (Mujawwad)',        arabicName: 'محمد صديق المنشاوي',    relativePath: 'muhammad_siddeeq_al-minshaawee_mujawwad/', style: 'Mujawwad', islamicNetworkEdition: 'ar.minshawimujawwad'),
  QuranicReciter(id: 11, name: 'Muhammad Ayyoob',               arabicName: 'محمد أيوب',              relativePath: 'muhammad_ayyoob/',                         islamicNetworkEdition: 'ar.muhammadayyoub'),
  QuranicReciter(id: 12, name: 'Abdullah Basfar',               arabicName: 'عبدالله بصفر',           relativePath: 'abdullaah_basfar/',                        islamicNetworkEdition: 'ar.abdullahbasfar'),
  // ── Surah-level only (QuranicAudio CDN) ──────────────────────────────────
  QuranicReciter(id: 13, name: 'Abdul Basit (Mujawwad)',        arabicName: 'عبدالباسط عبدالصمد',    relativePath: 'abdulbaset_mujawwad/',                     style: 'Mujawwad'),
  QuranicReciter(id: 14, name: 'Saad Al-Ghamdi',                arabicName: 'سعد الغامدي',            relativePath: 'sa3d_al-ghaamdi/'),
  QuranicReciter(id: 15, name: 'Maher Al-Muaiqly',              arabicName: 'ماهر المعيقلي',          relativePath: 'maher_al_meaqli/'),
  QuranicReciter(id: 16, name: 'Yasser Al-Dosari',              arabicName: 'ياسر الدوسري',           relativePath: 'yasser_ad-dussary/'),
  QuranicReciter(id: 17, name: 'Nasser Al-Qatami',              arabicName: 'ناصر القطامي',           relativePath: 'naasir_al-qaatami/'),
  QuranicReciter(id: 18, name: 'Saud Al-Shuraim',               arabicName: 'سعود الشريم',            relativePath: 'saud_al-shuraym/'),
  QuranicReciter(id: 19, name: 'Ali Al-Huthaifi',               arabicName: 'علي الحذيفي',            relativePath: 'ali_bin_abdurrahman_al-huthayfee/'),
  QuranicReciter(id: 20, name: 'Muhammad Jibreel',              arabicName: 'محمد جبريل',             relativePath: 'muhammad_jibreel/'),
  QuranicReciter(id: 21, name: 'Abdullah Awad Al-Juhani',       arabicName: 'عبدالله عواد الجهني',   relativePath: 'abdullaah_3awwaad_al-juhaynee/'),
  QuranicReciter(id: 22, name: 'Khalid Al-Qahtani',             arabicName: 'خالد القحطاني',          relativePath: 'khaalid_al-qahtaanee/'),
  QuranicReciter(id: 23, name: 'Wadee Hammadi Al-Yamani',       arabicName: 'وديع حمادي اليماني',    relativePath: 'wadee3_hammadi_al-yamani/'),
  QuranicReciter(id: 24, name: 'Idris Abkar',                   arabicName: 'إدريس أبكر',             relativePath: 'idrees_abkr/'),
  QuranicReciter(id: 25, name: 'Bandar Baleela',                arabicName: 'بندر بليلة',             relativePath: 'bandar_baleelah/'),
  QuranicReciter(id: 26, name: 'Fares Abbad',                   arabicName: 'فارس عباد',              relativePath: 'faaris_3abbad/'),
  QuranicReciter(id: 27, name: 'Salah Bukhatir',                arabicName: 'صلاح بو خاطر',           relativePath: 'salaah_bukhaatir/'),
  QuranicReciter(id: 28, name: 'Akram Al-Alaqimy',              arabicName: 'أكرم العلاقمي',          relativePath: 'akram_al-3alaqimy/'),
  QuranicReciter(id: 29, name: 'Tawfeeq As-Sayegh',             arabicName: 'توفيق الصايغ',           relativePath: 'tawfeeq_as-saayigh/'),
  QuranicReciter(id: 30, name: 'Yusuf Bin Nuh Ahmad',           arabicName: 'يوسف بن نوح أحمد',      relativePath: 'yusuf_bin_noah_ahmad/'),
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
      // Keep built-in list (has islamicNetworkEdition mappings) but fill in
      // extra reciters from the live API that aren't in our built-in set.
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
      // API unreachable — return built-in list.
    }
    return _kBuiltInReciters;
  }
}

final quranicAudioRepositoryProvider = Provider<QuranicAudioRepository>((ref) {
  return QuranicAudioRepository(Dio());
});
