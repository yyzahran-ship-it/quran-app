import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tafsir_repository.dart';
import 'translations_library.dart';

const _kGold    = Color(0xFFC9A84C);
const _kGoldDim = Color(0xFF8A6518);
const _kBg      = Color(0xFF000000);
const _kSurface = Color(0xFF0A0A0A);

class TafsirLibraryScreen extends ConsumerStatefulWidget {
  const TafsirLibraryScreen({super.key});

  @override
  ConsumerState<TafsirLibraryScreen> createState() =>
      _TafsirLibraryScreenState();
}

class _TafsirLibraryScreenState extends ConsumerState<TafsirLibraryScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TafsirInfo> get _filtered {
    if (_query.isEmpty) return kTafsirs;
    final q = _query.toLowerCase();
    return kTafsirs.where((t) =>
        t.name.toLowerCase().contains(q) ||
        t.author.toLowerCase().contains(q) ||
        t.language.toLowerCase().contains(q) ||
        t.langCode.contains(q)).toList();
  }

  // Build ordered list of (langCode, items) sections.
  List<({String langCode, List<TafsirInfo> items})> _sections(
      List<TafsirInfo> filtered) {
    final map = <String, List<TafsirInfo>>{};
    for (final t in filtered) {
      map.putIfAbsent(t.langCode, () => []).add(t);
    }
    final ordered = kTafsirLangOrder
        .where(map.containsKey)
        .map((l) => (langCode: l, items: map[l]!))
        .toList();
    // Append any languages not in the order list.
    for (final l in map.keys) {
      if (!kTafsirLangOrder.contains(l)) {
        ordered.add((langCode: l, items: map[l]!));
      }
    }
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedTafsirsProvider);
    final sections = _sections(_filtered);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kGold),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'مكتبة التفاسير',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: _kGold,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kGold),
        ),
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              textDirection: TextDirection.rtl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ابحث عن تفسير...',
                hintStyle:
                    const TextStyle(color: Color(0xFF555555), fontSize: 14),
                hintTextDirection: TextDirection.rtl,
                filled: true,
                fillColor: const Color(0xFF111111),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                prefixIcon:
                    const Icon(Icons.search, color: Color(0xFF555555), size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF333333)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF333333)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kGold),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          // ── Selected count strip ───────────────────────────────────────────
          if (selected.isNotEmpty)
            Container(
              width: double.infinity,
              color: const Color(0xFF0D0900),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: Text(
                '${selected.length} تفسير مختار',
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontSize: 12, color: _kGold),
              ),
            ),
          // ── Tafsir list ────────────────────────────────────────────────────
          Expanded(
            child: sections.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد نتائج',
                      style: TextStyle(color: Color(0xFF444444), fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    itemCount: sections.length,
                    itemBuilder: (_, i) =>
                        _LangSection(
                          items: sections[i].items,
                          selected: selected,
                          onToggle: (id) => ref
                              .read(selectedTafsirsProvider.notifier)
                              .toggle(id),
                        ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Language section widget ───────────────────────────────────────────────────

class _LangSection extends StatelessWidget {
  const _LangSection({
    required this.items,
    required this.selected,
    required this.onToggle,
  });

  final List<TafsirInfo> items;
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header
        Container(
          color: _kSurface,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Text(
                '${items.length}',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF444444)),
              ),
              const Spacer(),
              Text(
                items.first.language,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF888888),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        // Rows
        for (int i = 0; i < items.length; i++) ...[
          _TafsirRow(
            info: items[i],
            isSelected: selected.contains(items[i].id),
            onTap: () => onToggle(items[i].id),
          ),
          if (i < items.length - 1)
            const Divider(
                height: 1,
                indent: 52,
                endIndent: 0,
                color: Color(0xFF111111)),
        ],
      ],
    );
  }
}

// ─── Individual tafsir row ─────────────────────────────────────────────────────

class _TafsirRow extends StatelessWidget {
  const _TafsirRow({
    required this.info,
    required this.isSelected,
    required this.onTap,
  });

  final TafsirInfo info;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? const Color(0xFF0D0900) : Colors.transparent,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            // Gold checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? _kGold : Colors.transparent,
                border: Border.all(
                  color: isSelected ? _kGold : const Color(0xFF333333),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.black)
                  : null,
            ),
            const SizedBox(width: 14),
            // Name + author
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    info.name,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 15,
                      color: isSelected ? _kGold : Colors.white,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (info.author.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        info.author,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? _kGoldDim
                              : const Color(0xFF555555),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
