import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mushaf_provider.dart';
import 'tafsir_repository.dart';
import 'translations_library.dart';

const _kBg     = Color(0xFF1A1A1A);
const _kHeader = Color(0xFF1E3232);
const _kCyan   = Color(0xFF4DD0E1);

class TranslationsScreen extends ConsumerWidget {
  const TranslationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tafsirsAsync      = ref.watch(availableTafsirsProvider);
    final translationsAsync = ref.watch(availableTranslationsProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Translations',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          // ── Downloaded ──────────────────────────────────────────────────
          _sectionHeader('DOWNLOADED'),
          for (final entry in kTranslationNames.entries)
            _downloadedTile(
              name: entry.value,
              subtitle: 'Bundled — always available offline',
            ),
          for (final t in kTafsirs)
            _downloadedTile(
              name: '${t.name}  •  ${t.language}',
              subtitle: 'Cached',
            ),

          // ── Available for download ──────────────────────────────────────
          _sectionHeader('AVAILABLE FOR DOWNLOAD'),

          _subLabel('Tafsirs'),
          ...tafsirsAsync.when(
            loading: () => [_loadingTile()],
            error: (_, __) => [_errorTile()],
            data: (items) => items
                .map((t) => _availableTile(context, t.name, t.authorName, t.languageName))
                .toList(),
          ),

          _subLabel('Translations'),
          ...translationsAsync.when(
            loading: () => [_loadingTile()],
            error: (_, __) => [_errorTile()],
            data: (items) => items
                .map((t) => _availableTile(context, t.name, t.authorName, t.languageName))
                .toList(),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) => Container(
        width: double.infinity,
        color: _kHeader,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: Colors.white,
          ),
        ),
      );

  Widget _subLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.45),
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _downloadedTile({required String name, required String subtitle}) =>
      ListTile(
        tileColor: _kBg,
        leading: const Icon(Icons.translate_rounded, color: _kCyan, size: 22),
        title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 15)),
        subtitle: Text(
          subtitle,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
        ),
        trailing: const Icon(Icons.check_circle, color: _kCyan, size: 18),
      );

  Widget _availableTile(
      BuildContext context, String name, String author, String language) {
    final sub = [
      if (author.isNotEmpty) author,
      if (language.isNotEmpty) _cap(language),
    ].join('  •  ');

    return ListTile(
      tileColor: _kBg,
      leading:
          const Icon(Icons.language_rounded, color: Colors.white54, size: 22),
      title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 15)),
      subtitle: sub.isNotEmpty
          ? Text(sub,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45), fontSize: 12))
          : null,
      trailing:
          const Icon(Icons.file_download_outlined, color: Colors.white54, size: 22),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloading additional content coming soon'),
          duration: Duration(seconds: 2),
        ),
      ),
    );
  }

  Widget _loadingTile() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: CircularProgressIndicator(color: _kCyan, strokeWidth: 2)),
      );

  Widget _errorTile() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Text(
          'Could not load list — check your internet connection',
          style:
              TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
        ),
      );

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
