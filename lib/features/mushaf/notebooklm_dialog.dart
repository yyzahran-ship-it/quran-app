import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const _notebookLmUrl = 'https://notebooklm.google.com/';

/// Formats a single ayah (with optional translation and note) for NotebookLM.
String formatAyahForNotebookLm({
  required String verseKey,
  required String surahName,
  required String arabicText,
  String? translation,
  String? note,
}) {
  final buf = StringBuffer();
  buf.writeln('Quran Study Note — $surahName ($verseKey)');
  buf.writeln('────────────────────────────');
  buf.writeln();
  buf.writeln('Arabic text:');
  buf.writeln(arabicText);
  if (translation != null && translation.isNotEmpty) {
    buf.writeln();
    buf.writeln('Translation (Sahih International):');
    buf.writeln(translation);
  }
  if (note != null && note.isNotEmpty) {
    buf.writeln();
    buf.writeln('My note:');
    buf.writeln(note);
  }
  return buf.toString().trim();
}

/// Formats an entire surah for NotebookLM.
String formatSurahForNotebookLm({
  required int surahNumber,
  required String surahName,
  required String surahNameEnglish,
  required String revelationPlace,
  required List<({String verseKey, String arabic, String? translation})> ayahs,
}) {
  final place = revelationPlace == 'makkah' ? 'Makkah' : 'Madinah';
  final buf = StringBuffer();
  buf.writeln(
      'Quran — Surah $surahNumber: $surahName ($surahNameEnglish)');
  buf.writeln('Revealed in $place · ${ayahs.length} verses');
  buf.writeln('═' * 50);
  buf.writeln();
  for (final ayah in ayahs) {
    buf.writeln('[${ayah.verseKey}]');
    buf.writeln(ayah.arabic);
    if (ayah.translation != null && ayah.translation!.isNotEmpty) {
      buf.writeln(ayah.translation);
    }
    buf.writeln();
  }
  return buf.toString().trim();
}

/// Shows a bottom sheet that previews the content, explains the 3-step
/// process, and copies to clipboard + opens NotebookLM on confirm.
Future<void> showShareToNotebookLm(
  BuildContext context, {
  required String content,
  required String label,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _NotebookLmSheet(content: content, label: label),
  );
}

class _NotebookLmSheet extends StatelessWidget {
  const _NotebookLmSheet({required this.content, required this.label});

  final String content;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.science_outlined, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Share to NotebookLM',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          // Content preview
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.outlineVariant),
            ),
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 140),
            child: SingleChildScrollView(
              child: Text(
                content,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Step(
            number: 1,
            text:
                'Tap the button below — the text is copied and NotebookLM opens in your browser.',
          ),
          const SizedBox(height: 8),
          _Step(
            number: 2,
            text: 'In NotebookLM, click "Add source" → "Copied text".',
          ),
          const SizedBox(height: 8),
          _Step(
            number: 3,
            text:
                'Paste and click "Insert" — the AI can now discuss this content with you.',
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Copy & Open NotebookLM'),
              onPressed: () => _copyAndOpen(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyAndOpen(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: content));
    try {
      await launchUrl(
        Uri.parse(_notebookLmUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Opening the browser failed — clipboard is still copied.
    }
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Copied to clipboard — paste in NotebookLM under "Add source"'),
        ),
      );
    }
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}
