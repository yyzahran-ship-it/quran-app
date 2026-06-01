import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_models.dart';

// QuranicAudio public API — no API key required.
const _kApiBase = 'https://api.quranicaudio.com';

// Popular reciters with their QuranicAudio CDN paths.
// Used as the primary list when the API is reachable and as a fallback when not.
const _kFallbackReciters = <QuranicReciter>[
  QuranicReciter(id: 1,  name: 'Mishary Rashid Al-Afasy',       arabicName: 'مشاري راشد العفاسي',       relativePath: 'mishaari_raashid_al_3afaasee/'),
  QuranicReciter(id: 2,  name: 'Abdul Basit (Murattal)',         arabicName: 'عبد الباسط عبد الصمد',     relativePath: 'abdulbasit_abdussamed_murattal/', style: 'Murattal'),
  QuranicReciter(id: 3,  name: 'Abdul Basit (Mujawwad)',         arabicName: 'عبد الباسط عبد الصمد',     relativePath: 'abdulbaset_mujawwad/',           style: 'Mujawwad'),
  QuranicReciter(id: 4,  name: 'Mahmoud Khalil Al-Husary',       arabicName: 'محمود خليل الحصري',        relativePath: 'mahmoud_khalil_al_husaree/'),
  QuranicReciter(id: 5,  name: 'Saad Al-Ghamdi',                 arabicName: 'سعد الغامدي',              relativePath: 'sa3d_al-ghaamdi/'),
  QuranicReciter(id: 6,  name: 'Maher Al-Muaiqly',               arabicName: 'ماهر المعيقلي',            relativePath: 'maher_al_meaqli/'),
  QuranicReciter(id: 7,  name: 'Yasser Al-Dosari',               arabicName: 'ياسر الدوسري',             relativePath: 'yasser_ad-dussary/'),
  QuranicReciter(id: 8,  name: 'Nasser Al-Qatami',               arabicName: 'ناصر القطامي',             relativePath: 'nasser_alqatami/'),
  QuranicReciter(id: 9,  name: 'Saud Al-Shuraim',                arabicName: 'سعود الشريم',              relativePath: 'saud_al-shuraym/'),
  QuranicReciter(id: 10, name: 'Ali Al-Huthaifi',                arabicName: 'علي الحذيفي',              relativePath: 'ali_bin_abdurrahman_al-huthayfee/'),
  QuranicReciter(id: 11, name: 'Muhammad Ayyub',                 arabicName: 'محمد أيوب',                relativePath: 'muhammad_ayyoob/'),
  QuranicReciter(id: 12, name: 'Muhammad Al-Luhaidan',           arabicName: 'محمد اللحيدان',            relativePath: 'muhammad_jibreel/'),
  QuranicReciter(id: 13, name: 'Ibrahim Al-Akhdar',              arabicName: 'إبراهيم الأخضر',           relativePath: 'ibrahim_al-akhdar/'),
  QuranicReciter(id: 14, name: 'Hani Ar-Rifai',                  arabicName: 'هاني الرفاعي',             relativePath: 'hani_ar-rifai/'),
  QuranicReciter(id: 15, name: 'Khalifa Al-Tunaiji',             arabicName: 'خليفة الطنيجي',            relativePath: 'khalifa_al_tunaiji/'),
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
      final reciters = list
          .map((e) => QuranicReciter.fromJson(e as Map<String, dynamic>))
          .where((r) => r.relativePath.isNotEmpty)
          .toList();
      if (reciters.isNotEmpty) return reciters;
    } catch (_) {
      // API unreachable — fall through to hardcoded list
    }
    return _kFallbackReciters;
  }
}

final quranicAudioRepositoryProvider = Provider<QuranicAudioRepository>((ref) {
  return QuranicAudioRepository(Dio());
});
