import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/quran_repository.dart';
import '../../domain/entities/surah.dart';
import '../mushaf/mushaf_provider.dart';
import 'audio_download_provider.dart';
import 'audio_provider.dart';
import 'quran_foundation_repository.dart';
import 'reciter_provider.dart';

const _kBg     = Color(0xFF0F1117);
const _kCard   = Color(0xFF1A1C24);
const _kGreen  = Color(0xFF2E7D52);
const _kCyan   = Color(0xFF4DD0E1);
const _kGold   = Color(0xFFD4A017);

// ─── Screen ───────────────────────────────────────────────────────────────────

class AudioLibraryScreen extends ConsumerStatefulWidget {
  const AudioLibraryScreen({super.key});

  @override
  ConsumerState<AudioLibraryScreen> createState() => _AudioLibraryScreenState();
}

class _AudioLibraryScreenState extends ConsumerState<AudioLibraryScreen> {
  // Which reciter's library is currently shown (defaults to selected reciter).
  String? _selectedSlug;

  @override
  Widget build(BuildContext context) {
    final audio        = ref.watch(audioProvider);
    final dlState      = ref.watch(audioDownloadProvider);
    final qaReciters   = ref.watch(reciterListProvider);
    final qfAsync      = ref.watch(qfRecitationsProvider);

    final activeSlug = _selectedSlug ?? audio.reciter;

    // Determine QF recitation ID for the active slug (null = everyayah reciter).
    int? activeQfId;
    if (activeSlug.startsWith('qf_')) {
      activeQfId = int.tryParse(activeSlug.substring(3));
    }

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Audio Library',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ── Reciter selector ──────────────────────────────────────────────
          _ReciterSelector(
            activeSlug: activeSlug,
            qaReciters: qaReciters,
            qfReciters: qfAsync.valueOrNull ?? [],
            onSelect: (slug) => setState(() => _selectedSlug = slug),
          ),
          const Divider(color: Color(0xFF2A2D36), height: 1),
          // ── Surah download list ───────────────────────────────────────────
          Expanded(
            child: _SurahDownloadList(
              reciterSlug: activeSlug,
              qfRecitationId: activeQfId,
              dlState: dlState[activeSlug] ?? {},
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reciter selector strip ───────────────────────────────────────────────────

class _ReciterSelector extends ConsumerWidget {
  const _ReciterSelector({
    required this.activeSlug,
    required this.qaReciters,
    required this.qfReciters,
    required this.onSelect,
  });

  final String activeSlug;
  final List<QAReciter> qaReciters;
  final List<QFRecitation> qfReciters;
  final void Function(String slug) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = <({String slug, String name, String style})>[
      for (final r in qaReciters) (slug: r.relativePath, name: r.name, style: r.style),
      for (final r in qfReciters) (slug: 'qf_${r.id}', name: r.name, style: r.style),
    ];

    return Container(
      color: _kCard,
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final r = all[i];
          final active = r.slug == activeSlug;
          return GestureDetector(
            onTap: () => onSelect(r.slug),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? _kGreen : const Color(0xFF252830),
                borderRadius: BorderRadius.circular(20),
                border: active
                    ? null
                    : Border.all(color: Colors.white12, width: 0.8),
              ),
              child: Text(
                r.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? Colors.white : Colors.white60,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Surah download list ──────────────────────────────────────────────────────

class _SurahDownloadList extends ConsumerWidget {
  const _SurahDownloadList({
    required this.reciterSlug,
    required this.qfRecitationId,
    required this.dlState,
  });

  final String reciterSlug;
  final int? qfRecitationId;
  final Map<int, SurahDownloadInfo> dlState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surahsAsync = ref.watch(_allSurahsProvider);
    return surahsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: _kCyan, strokeWidth: 2)),
      error: (_, __) => Center(
          child: Text('Could not load surah list',
              style: TextStyle(color: Colors.white.withAlpha(120)))),
      data: (surahs) => Column(
        children: [
          // Summary bar + download-all button
          _SummaryBar(
            surahs: surahs,
            reciterSlug: reciterSlug,
            qfRecitationId: qfRecitationId,
            dlState: dlState,
          ),
          const Divider(color: Color(0xFF2A2D36), height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: surahs.length,
              itemBuilder: (_, i) => _SurahTile(
                surah: surahs[i],
                reciterSlug: reciterSlug,
                qfRecitationId: qfRecitationId,
                info: dlState[surahs[i].id],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends ConsumerWidget {
  const _SummaryBar({
    required this.surahs,
    required this.reciterSlug,
    required this.qfRecitationId,
    required this.dlState,
  });

  final List<Surah> surahs;
  final String reciterSlug;
  final int? qfRecitationId;
  final Map<int, SurahDownloadInfo> dlState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedCount = dlState.values.where((i) => i.isComplete).length;
    final anyDownloading = dlState.values.any((i) => i.isDownloading);

    return Container(
      color: _kCard,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completedCount / 114 surahs downloaded',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                LinearProgressIndicator(
                  value: completedCount / 114,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(_kGreen),
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Download-all / cancel
          if (anyDownloading)
            TextButton.icon(
              onPressed: null,
              icon: const SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kCyan),
              ),
              label: const Text('Downloading…',
                  style: TextStyle(color: _kCyan, fontSize: 12)),
            )
          else if (completedCount < 114)
            TextButton.icon(
              onPressed: () => _downloadAll(ref, surahs),
              icon: const Icon(Icons.download_for_offline_outlined,
                  size: 18, color: _kGreen),
              label: const Text('All',
                  style: TextStyle(color: _kGreen, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  void _downloadAll(WidgetRef ref, List<Surah> surahs) {
    for (final surah in surahs) {
      ref.read(audioDownloadProvider.notifier).downloadSurah(
            reciterSlug: reciterSlug,
            surahNumber: surah.id,
            qfRecitationId: qfRecitationId,
          );
    }
  }
}

class _SurahTile extends ConsumerWidget {
  const _SurahTile({
    required this.surah,
    required this.reciterSlug,
    required this.qfRecitationId,
    required this.info,
  });

  final Surah surah;
  final String reciterSlug;
  final int? qfRecitationId;
  final SurahDownloadInfo? info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isComplete   = info?.isComplete == true;
    final isDownloading = info?.isDownloading == true;
    final hasError     = info?.error != null && !isComplete;
    final progress     = info?.progress ?? 0.0;

    return Column(
      children: [
        ListTile(
          tileColor: _kBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: isComplete
                ? _kGreen.withAlpha(60)
                : const Color(0xFF252830),
            child: Text(
              '${surah.id}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isComplete ? _kGreen : Colors.white60,
              ),
            ),
          ),
          title: Text(
            surah.nameSimple,
            style: TextStyle(
              color: isComplete ? Colors.white : Colors.white.withAlpha(200),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            '${surah.nameArabic}  ·  ${surah.versesCount} verses  ·  ${surah.revelationPlace}',
            style: TextStyle(
                color: Colors.white.withAlpha(90), fontSize: 11),
          ),
          trailing: _buildTrailing(context, ref),
          onTap: isComplete || isDownloading
              ? null
              : () => ref.read(audioDownloadProvider.notifier).downloadSurah(
                    reciterSlug: reciterSlug,
                    surahNumber: surah.id,
                    qfRecitationId: qfRecitationId,
                  ),
        ),
        // Thin progress bar while downloading
        if (isDownloading)
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(_kCyan),
            minHeight: 2,
          ),
      ],
    );
  }

  Widget _buildTrailing(BuildContext context, WidgetRef ref) {
    if (_isCurrentlyDownloading(info)) {
      final pct = ((info?.progress ?? 0) * 100).round();
      return SizedBox(
        width: 40, height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: info?.progress,
              color: _kCyan,
              strokeWidth: 2.5,
            ),
            Text('$pct%',
                style: const TextStyle(fontSize: 9, color: Colors.white70)),
          ],
        ),
      );
    }
    if (info?.isComplete == true) {
      return GestureDetector(
        onTap: () => _showDeleteConfirm(context, ref),
        child: const Icon(Icons.check_circle, color: _kGreen, size: 22),
      );
    }
    if (info?.error != null) {
      return GestureDetector(
        onTap: () => ref.read(audioDownloadProvider.notifier).downloadSurah(
              reciterSlug: reciterSlug,
              surahNumber: surah.id,
              qfRecitationId: qfRecitationId,
            ),
        child: Icon(Icons.error_outline, color: Colors.red[300], size: 22),
      );
    }
    return const Icon(Icons.download_outlined, color: Colors.white38, size: 22);
  }

  bool _isCurrentlyDownloading(SurahDownloadInfo? info) =>
      info?.isDownloading == true;

  void _showDeleteConfirm(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        title: Text('Delete ${surah.nameSimple}?',
            style: const TextStyle(color: Colors.white)),
        content: const Text(
          'This will remove the downloaded audio files for this surah.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(audioDownloadProvider.notifier).deleteSurah(
                    reciterSlug: reciterSlug,
                    surahNumber: surah.id,
                  );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ─── Provider for all surahs ──────────────────────────────────────────────────

final _allSurahsProvider = FutureProvider<List<Surah>>((ref) async {
  final repo = ref.read(quranRepositoryProvider);
  return repo.getAllSurahs();
});
