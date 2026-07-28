import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mushaf_provider.dart';
import 'tafsir_repository.dart';
import 'tafsir_download_provider.dart';
import 'translations_library.dart';

const _kBg       = Color(0xFF0A0A0A);
const _kGold     = Color(0xFFC9A84C);
const _kGoldDim  = Color(0xFF8A6518);

class TranslationsScreen extends ConsumerWidget {
  const TranslationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tafsirsAsync      = ref.watch(availableTafsirsProvider);
    final translationsAsync = ref.watch(availableTranslationsProvider);
    final downloadState     = ref.watch(tafsirDownloadProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        foregroundColor: _kGold,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _kGold),
        title: const Text(
          'الترجمات',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: _kGold,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        children: [
          // ── Downloaded ──────────────────────────────────────────────────
          _sectionHeader('محمّلة'),
          for (final entry in kTranslationNames.entries)
            _downloadedTile(
                name: entry.value,
                subtitle: 'مدمجة — متاحة دائماً بلا إنترنت'),
          for (final t in kTafsirs)
            _downloadedTile(
                name: '${t.name}  •  ${t.language}',
                subtitle: 'مخزّنة مؤقتاً'),
          for (final entry in downloadState.entries)
            if (entry.value.completed &&
                !kTafsirs.any((t) => t.id == entry.key))
              _downloadedTile(
                name: 'Tafsir #${entry.key}',
                subtitle: 'محمّلة',
              ),

          // ── Available for download ──────────────────────────────────────
          _sectionHeader('متاحة للتنزيل'),

          _subLabel('التفسير'),
          ...tafsirsAsync.when(
            loading: () => [_loadingTile()],
            error: (_, __) => [_errorTile()],
            data: (items) => items
                .map((t) => _tafsirTile(context, ref, t, downloadState))
                .toList(),
          ),

          _subLabel('الترجمات'),
          ...translationsAsync.when(
            loading: () => [_loadingTile()],
            error: (_, __) => [_errorTile()],
            data: (items) =>
                items.map((t) => _translationTile(context, t)).toList(),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Tile builders ──────────────────────────────────────────────────────────

  Widget _sectionHeader(String label) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: const BoxDecoration(
          color: _kBg,
          border: Border(
            bottom: BorderSide(color: _kGoldDim, width: .8),
          ),
        ),
        child: Text(
          label,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: .5,
            color: _kGold,
          ),
        ),
      );

  Widget _subLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(
          label,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _kGoldDim.withValues(alpha: 0.7),
            letterSpacing: 0.4,
          ),
        ),
      );

  Widget _downloadedTile({required String name, required String subtitle}) =>
      ListTile(
        tileColor: _kBg,
        leading: const Icon(Icons.language, color: _kGold, size: 22),
        title: Text(name,
            style: const TextStyle(color: _kGold, fontSize: 15)),
        subtitle: Text(
          subtitle,
          textDirection: TextDirection.rtl,
          style:
              TextStyle(color: _kGoldDim.withValues(alpha: 0.7), fontSize: 12),
        ),
        trailing: const Icon(Icons.check_circle, color: _kGold, size: 18),
      );

  Widget _tafsirTile(
    BuildContext context,
    WidgetRef ref,
    ApiTranslationInfo info,
    Map<int, TafsirDownloadInfo> downloadState,
  ) {
    final dlInfo        = downloadState[info.id];
    final isCompleted   = dlInfo?.completed == true;
    final isDownloading =
        dlInfo != null && !dlInfo.completed && dlInfo.error == null;
    final hasError      = dlInfo?.error != null;
    final progress      = dlInfo?.progress ?? 0.0;

    final sub = _joinParts(info.authorName, _cap(info.languageName));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          tileColor: _kBg,
          leading: Icon(Icons.language,
              color: isCompleted ? _kGold : const Color(0xFF333333), size: 22),
          title: Text(
            info.name,
            style: TextStyle(
              color: isCompleted ? _kGold : const Color(0xFF888888),
              fontSize: 15,
            ),
          ),
          subtitle: sub.isNotEmpty
              ? Text(sub,
                  style: TextStyle(
                      color: isCompleted
                          ? _kGoldDim
                          : const Color(0xFF444444),
                      fontSize: 12))
              : null,
          trailing: _tafsirTrailing(
            context: context,
            ref: ref,
            info: info,
            isCompleted: isCompleted,
            isDownloading: isDownloading,
            hasError: hasError,
            progress: progress,
          ),
          onTap: (isCompleted || isDownloading)
              ? null
              : () => ref
                  .read(tafsirDownloadProvider.notifier)
                  .startDownload(info.id),
        ),
        if (isDownloading)
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(_kGold),
            minHeight: 2,
          ),
      ],
    );
  }

  Widget _tafsirTrailing({
    required BuildContext context,
    required WidgetRef ref,
    required ApiTranslationInfo info,
    required bool isCompleted,
    required bool isDownloading,
    required bool hasError,
    required double progress,
  }) {
    if (isCompleted) {
      return const Icon(Icons.check_circle, color: _kGold, size: 22);
    }
    if (isDownloading) {
      return SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              color: _kGold,
              strokeWidth: 2.5,
            ),
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                fontSize: 9,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    if (hasError) {
      return GestureDetector(
        onTap: () =>
            ref.read(tafsirDownloadProvider.notifier).startDownload(info.id),
        child: Icon(Icons.error_outline, color: Colors.red[300], size: 22),
      );
    }
    return const Icon(Icons.file_download_outlined,
        color: Color(0xFF333333), size: 22);
  }

  Widget _translationTile(BuildContext context, ApiTranslationInfo info) {
    final sub = _joinParts(info.authorName, _cap(info.languageName));
    return ListTile(
      tileColor: _kBg,
      leading: const Icon(Icons.language, color: Color(0xFF333333), size: 22),
      title: Text(info.name,
          style: const TextStyle(color: Color(0xFF888888), fontSize: 15)),
      subtitle: sub.isNotEmpty
          ? Text(sub,
              style: const TextStyle(color: Color(0xFF444444), fontSize: 12))
          : null,
      trailing: const Icon(Icons.file_download_outlined,
          color: Color(0xFF333333), size: 22),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تنزيل الترجمة المجمّعة قريباً'),
          duration: Duration(seconds: 2),
        ),
      ),
    );
  }

  Widget _loadingTile() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: CircularProgressIndicator(color: _kGold, strokeWidth: 2)),
      );

  Widget _errorTile() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Text(
          'تعذّر التحميل — تحقق من اتصالك بالإنترنت',
          textDirection: TextDirection.rtl,
          style: const TextStyle(color: Color(0xFF444444), fontSize: 13),
        ),
      );

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _joinParts(String a, String b) {
    if (a.isEmpty && b.isEmpty) return '';
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return '$a  •  $b';
  }
}
