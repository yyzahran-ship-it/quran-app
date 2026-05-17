import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/quran_repository.dart';
import 'bookmarks_provider.dart';

/// Shows a bottom sheet to add or edit a note for an ayah.
Future<void> showNoteEditor(
  BuildContext context, {
  required int ayahId,
  required int surahNumber,
  required int ayahNumber,
  required String verseKey,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _NoteEditorSheet(
      ayahId: ayahId,
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      verseKey: verseKey,
    ),
  );
}

class _NoteEditorSheet extends ConsumerStatefulWidget {
  const _NoteEditorSheet({
    required this.ayahId,
    required this.surahNumber,
    required this.ayahNumber,
    required this.verseKey,
  });

  final int ayahId;
  final int surahNumber;
  final int ayahNumber;
  final String verseKey;

  @override
  ConsumerState<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends ConsumerState<_NoteEditorSheet> {
  late final TextEditingController _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final note = await ref
        .read(quranRepositoryProvider)
        .getNoteForAyah(widget.ayahId);
    if (mounted) {
      _controller.text = note?.body ?? '';
      setState(() => _loaded = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Icon(Icons.note_outlined, color: colors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Note — ${widget.verseKey}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_loaded && _controller.text.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: colors.error),
                    tooltip: 'Delete note',
                    onPressed: _delete,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _loaded
                ? TextField(
                    controller: _controller,
                    autofocus: true,
                    maxLines: 6,
                    minLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Type your note here…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loaded ? _save : null,
                child: const Text('Save'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final body = _controller.text.trim();
    if (body.isEmpty) {
      await ref.read(notesProvider.notifier).delete(widget.ayahId);
    } else {
      await ref.read(notesProvider.notifier).save(
            widget.ayahId,
            widget.surahNumber,
            widget.ayahNumber,
            body,
          );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await ref.read(notesProvider.notifier).delete(widget.ayahId);
    if (mounted) Navigator.pop(context);
  }
}
