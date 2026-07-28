import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_models.dart';
import 'audio_repository.dart';

// Fetches the full reciter list from QuranicAudio once per session, sorted A–Z.
final recitersProvider = FutureProvider<List<QuranicReciter>>((ref) async {
  final list = List.of(await ref.read(quranicAudioRepositoryProvider).fetchReciters());
  list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
});

// ID of the reciter the user has chosen (null = use first in list).
final selectedReciterIdProvider = StateProvider<int?>((ref) => null);

// Resolved reciter object — falls back to first available if none chosen.
final selectedReciterProvider = Provider<QuranicReciter?>((ref) {
  final id = ref.watch(selectedReciterIdProvider);
  final reciters = ref.watch(recitersProvider).valueOrNull ?? [];
  if (reciters.isEmpty) return null;
  if (id == null) return reciters.first;
  return reciters.firstWhere((r) => r.id == id, orElse: () => reciters.first);
});
