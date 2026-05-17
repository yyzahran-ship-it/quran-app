import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/quran_repository.dart';
import '../../domain/entities/ayah.dart';
import 'mushaf_provider.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final _searchQueryProvider = StateProvider<String>((ref) => '');

final _searchResultsProvider = FutureProvider<List<Ayah>>((ref) async {
  final query = ref.watch(_searchQueryProvider);
  if (query.trim().length < 2) return [];
  final repo = ref.read(quranRepositoryProvider);
  return repo.searchAyahs(query.trim());
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field when screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_searchQueryProvider);
    final resultsAsync = ref.watch(_searchResultsProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: 'Search in Arabic…',
            hintTextDirection: TextDirection.rtl,
            border: InputBorder.none,
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      ref.read(_searchQueryProvider.notifier).state = '';
                    },
                  )
                : null,
          ),
          onChanged: (v) => ref.read(_searchQueryProvider.notifier).state = v,
        ),
      ),
      body: _buildBody(query, resultsAsync, colors),
    );
  }

  Widget _buildBody(
    String query,
    AsyncValue<List<Ayah>> resultsAsync,
    ColorScheme colors,
  ) {
    if (query.trim().length < 2) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: colors.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'Type Arabic to search',
              style: TextStyle(color: colors.outline),
            ),
            const SizedBox(height: 4),
            Text(
              'e.g. ٱلرَّحْمَـٰنِ',
              style: TextStyle(
                fontFamily: kArabicFont,
                fontSize: 20,
                color: colors.outlineVariant,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      );
    }

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: 12),
            Text('Search failed', style: TextStyle(color: colors.error)),
          ],
        ),
      ),
      data: (results) {
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off, size: 48, color: colors.outlineVariant),
                const SizedBox(height: 12),
                Text(
                  'No results for "$query"',
                  style: TextStyle(color: colors.outline),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${results.length}${results.length == 100 ? '+' : ''} result${results.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: colors.outline,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final ayah = results[index];
                  return _SearchResultTile(
                    ayah: ayah,
                    query: query,
                    onTap: () {
                      // Navigate the reader to this surah and pop search.
                      ref
                          .read(mushafProvider.notifier)
                          .navigateToSurah(ayah.surahNumber);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Result tile ──────────────────────────────────────────────────────────────

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.ayah,
    required this.query,
    required this.onTap,
  });

  final Ayah ayah;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      title: Text(
        ayah.textUthmani,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: kArabicFont,
          fontSize: 20,
          height: 2.0,
          color: colors.onSurface,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          ayah.verseKey,
          style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 14, color: colors.outline),
    );
  }
}
