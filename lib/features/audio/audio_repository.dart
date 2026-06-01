import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_models.dart';

// QuranicAudio public API — no API key required.
// Docs: https://quranicaudio.com
const _kApiBase = 'https://api.quranicaudio.com';

class QuranicAudioRepository {
  QuranicAudioRepository(this._dio);
  final Dio _dio;

  Future<List<QuranicReciter>> fetchReciters() async {
    final response = await _dio.get(
      '$_kApiBase/quran/reciters',
      options: Options(
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      ),
    );
    final list = response.data as List<dynamic>;
    return list
        .map((e) => QuranicReciter.fromJson(e as Map<String, dynamic>))
        .where((r) => r.relativePath.isNotEmpty)
        .toList();
  }
}

final quranicAudioRepositoryProvider = Provider<QuranicAudioRepository>((ref) {
  return QuranicAudioRepository(Dio());
});
