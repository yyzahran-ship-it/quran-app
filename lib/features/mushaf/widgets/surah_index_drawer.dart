import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/surah.dart';
import '../mushaf_provider.dart';

/// Side drawer listing all 114 surahs. Tapping one navigates the reader.
class SurahIndexDrawer extends ConsumerStatefulWidget {
  const SurahIndexDrawer({super.key});

  @override
  ConsumerState<SurahIndexDrawer> createState() => _SurahIndexDrawerState();
}

class _SurahIndexDrawerState extends ConsumerState<SurahIndexDrawer> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mushafProvider);
    final colors = Theme.of(context).colorScheme;

    final surahs = _query.isEmpty
        ? state.surahs
        : state.surahs
            .where((s) =>
                s.nameSimple.toLowerCase().contains(_query.toLowerCase()) ||
                s.nameEnglish.toLowerCase().contains(_query.toLowerCase()) ||
                s.id.toString() == _query.trim())
            .toList();

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.menu_book, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Surah Index',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search surahs…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const Divider(height: 1),
            // List
            Expanded(
              child: state.surahs.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: surahs.length,
                      itemBuilder: (context, index) {
                        return _SurahListTile(
                          surah: surahs[index],
                          isSelected:
                              surahs[index].id == state.currentSurah?.id,
                          onTap: () {
                            ref
                                .read(mushafProvider.notifier)
                                .navigateToSurah(surahs[index].id);
                            Navigator.of(context).pop(); // close drawer
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurahListTile extends StatelessWidget {
  const _SurahListTile({
    required this.surah,
    required this.isSelected,
    required this.onTap,
  });

  final Surah surah;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: colors.primaryContainer.withValues(alpha: 0.4),
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? colors.primary : colors.surfaceContainerHighest,
        ),
        alignment: Alignment.center,
        child: Text(
          '${surah.id}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? colors.onPrimary : colors.onSurfaceVariant,
          ),
        ),
      ),
      title: Text(
        surah.nameSimple,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        surah.nameEnglish,
        style: const TextStyle(fontSize: 11),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            surah.nameArabic,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: kArabicFont,
              fontSize: 16,
              color: colors.primary,
            ),
          ),
          Text(
            '${surah.versesCount} v',
            style: TextStyle(fontSize: 10, color: colors.outline),
          ),
        ],
      ),
    );
  }
}
