import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/theme_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/surah.dart';
import '../audio/audio_player_bar.dart';
import '../audio/audio_provider.dart';
import '../audio/audio_repository.dart';
import 'mushaf_provider.dart';
import 'search_screen.dart';
import 'widgets/juz_jump_dialog.dart';
import '../settings/settings_screen.dart';

// CDN base URLs for King Fahad Mushaf page images, tried in order.
const _kPageCdnBases = [
  'https://cdn.qurancdn.com/images/quran/pages/page',
  'https://quran.com/images/quran/pages/page',
];

// ─── Helper: page number for a given surah + ayah ────────────────────────────

int _ayahGlobalPage(int surahNumber, int ayahNumber) {
  int globalId = 1;
  for (int i = 0; i < surahNumber - 1; i++) {
    globalId += kSurahVerseCounts[i];
  }
  globalId += ayahNumber - 1;
  if (globalId < 1 || globalId > kTotalAyahs) return 1;
  return kAyahPages[globalId - 1];
}

// ─── Helper: hizb number (1–60) for a given Mushaf page ──────────────────────
// The Quran has 60 hizbs (2 per juz). The second hizb of each juz starts at
// the midpoint of that juz's page range.

int _pageHizb(int page) {
  int juz = 30;
  for (int i = 0; i < kJuzStartPages.length - 1; i++) {
    if (page < kJuzStartPages[i + 1]) {
      juz = i + 1;
      break;
    }
  }
  final juzStart = kJuzStartPages[juz - 1];
  final juzEnd =
      juz < kJuzStartPages.length ? kJuzStartPages[juz] - 1 : kTotalPages;
  final isSecondHizb = page >= (juzStart + juzEnd + 1) ~/ 2;
  return (juz - 1) * 2 + (isSecondHizb ? 2 : 1);
}

// ─── Screen actions (overflow menu) ──────────────────────────────────────────

enum _AppAction { playPause, search, juzJump, toggleTranslation, settings }

// ─── Screen ───────────────────────────────────────────────────────────────────

class MushafScreen extends ConsumerStatefulWidget {
  const MushafScreen({super.key});

  @override
  ConsumerState<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends ConsumerState<MushafScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleAction(_AppAction action) {
    switch (action) {
      case _AppAction.playPause:
        final s = ref.read(mushafProvider);
        final a = ref.read(audioProvider);
        if (a.isPlaying) {
          ref.read(audioProvider.notifier).togglePlayPause();
        } else if (s.ayahs.isNotEmpty) {
          ref.read(audioProvider.notifier).playSurah(
                s.ayahs.first.surahNumber,
                startAyah: s.ayahs.first.ayahNumber,
              );
        }
      case _AppAction.search:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SearchScreen()));
      case _AppAction.juzJump:
        showJuzJumpDialog(context);
      case _AppAction.toggleTranslation:
        ref.read(mushafProvider.notifier).toggleTranslation();
      case _AppAction.settings:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mushafProvider);
    final audio = ref.watch(audioProvider);

    // Auto-navigate to the page that contains the currently playing ayah.
    ref.listen<AudioState>(audioProvider, (prev, next) {
      if (next.surahNumber == null || next.currentAyahNumber == null) return;
      if (prev?.surahNumber == next.surahNumber &&
          prev?.currentAyahIndex == next.currentAyahIndex) return;
      final targetPage =
          _ayahGlobalPage(next.surahNumber!, next.currentAyahNumber!);
      if (targetPage != ref.read(mushafProvider).currentPage) {
        ref
            .read(mushafProvider.notifier)
            .navigateToAyah(next.surahNumber!, next.currentAyahNumber!);
        _scrollToTop();
      }
    });

    final themeMode = ref.watch(themeProvider);
    final isLight = themeMode != AppThemeMode.dark &&
        themeMode != AppThemeMode.inverted;
    final bgColor = isLight ? Colors.white : null;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        // King Fahad Mushaf: plain white AppBar matching the printed page style
        // Surah name (left) · Juz number (right) — no color, no border
        backgroundColor: isLight ? Colors.white : null,
        foregroundColor: isLight ? const Color(0xFF1A1A1A) : null,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 44,
        title: _AppBarTitle(state: state),
        titleSpacing: 16,
        actions: [
          PopupMenuButton<_AppAction>(
            icon: Icon(Icons.more_vert,
                color: isLight ? const Color(0xFF1A1A1A) : null),
            tooltip: 'More options',
            onSelected: _handleAction,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _AppAction.playPause,
                child: Row(children: [
                  Icon(audio.isPlaying
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline),
                  const SizedBox(width: 12),
                  Text(audio.isPlaying ? 'Pause' : 'Play page audio'),
                ]),
              ),
              const PopupMenuItem(
                value: _AppAction.search,
                child: Row(children: [
                  Icon(Icons.search),
                  SizedBox(width: 12),
                  Text('Search'),
                ]),
              ),
              const PopupMenuItem(
                value: _AppAction.juzJump,
                child: Row(children: [
                  Icon(Icons.format_list_numbered_outlined),
                  SizedBox(width: 12),
                  Text('Jump to Juz'),
                ]),
              ),
              PopupMenuItem(
                value: _AppAction.toggleTranslation,
                child: Row(children: [
                  Icon(state.showTranslation
                      ? Icons.translate
                      : Icons.translate_outlined),
                  const SizedBox(width: 12),
                  Text(state.showTranslation
                      ? 'Hide translation'
                      : 'Show translation'),
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _AppAction.settings,
                child: Row(children: [
                  Icon(Icons.settings_outlined),
                  SizedBox(width: 12),
                  Text('Settings'),
                ]),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.ayahs.isEmpty
              ? _buildErrorState()
              : GestureDetector(
                  // Swipe left → next page, swipe right → previous page.
                  onHorizontalDragEnd: (details) {
                    final v = details.primaryVelocity;
                    if (v == null) return;
                    if (v < -300) {
                      ref.read(mushafProvider.notifier).nextPage();
                      _scrollToTop();
                    } else if (v > 300) {
                      ref.read(mushafProvider.notifier).previousPage();
                      _scrollToTop();
                    }
                  },
                  child: _buildReader(state),
                ),
      bottomNavigationBar: state.ayahs.isEmpty
          ? null
          : _BottomArea(currentPage: state.currentPage),
    );
  }

  // ── King Fahad page image view ──────────────────────────────────────────────

  Widget _buildReader(MushafState state) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == AppThemeMode.dark ||
        themeMode == AppThemeMode.inverted;

    final showTx = state.showTranslation && state.translations.isNotEmpty;

    // Text-based fallback (used when CDN is unreachable) includes translations
    // inline, so _PageTranslations is only attached to the image path.
    final textFallback = _TextFallbackView(
      ayahs: state.ayahs,
      surahFor: state.surahFor,
      translations: showTx ? state.translations : {},
      isDark: isDark,
    );

    return SingleChildScrollView(
      controller: _scrollController,
      child: _MushafPageLoader(
        pageNum: state.currentPage,
        isDark: isDark,
        textFallback: textFallback,
        imageTranslations: showTx
            ? _PageTranslations(
                ayahs: state.ayahs,
                translations: state.translations,
              )
            : null,
      ),
    );
  }

  Widget _buildErrorState() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: colors.error),
            const SizedBox(height: 16),
            const Text(
              'Could not load Quran data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap Retry to try again.',
              style: TextStyle(color: colors.outline),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.invalidate(mushafProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

}

// ─── Disk-caching Mushaf page loader ─────────────────────────────────────────
//
// Checks the on-device cache first so previously-viewed pages render instantly
// without any network. Falls back to trying each CDN in _kPageCdnBases so that
// if the primary CDN is blocked for the user's network another may succeed.
// Successfully downloaded pages are written to the temp-directory cache.

class _MushafPageLoader extends StatefulWidget {
  const _MushafPageLoader({
    required this.pageNum,
    required this.isDark,
    this.textFallback,
    this.imageTranslations,
  });

  final int pageNum;
  final bool isDark;
  // Shown instead of the "offline" message when CDN is unreachable.
  final Widget? textFallback;
  // Shown below the image when image loads successfully (and translations on).
  final Widget? imageTranslations;

  @override
  State<_MushafPageLoader> createState() => _MushafPageLoaderState();
}

class _MushafPageLoaderState extends State<_MushafPageLoader> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _failed = false;
  // Tracks which page was last requested so stale responses are ignored.
  int _loadedFor = -1;

  @override
  void initState() {
    super.initState();
    _load(widget.pageNum);
  }

  @override
  void didUpdateWidget(_MushafPageLoader old) {
    super.didUpdateWidget(old);
    if (old.pageNum != widget.pageNum) _load(widget.pageNum);
  }

  Future<void> _load(int page) async {
    setState(() {
      _loading = true;
      _failed = false;
      _bytes = null;
      _loadedFor = page;
    });

    final padded = page.toString().padLeft(3, '0');

    // 1. Serve from disk cache (instant, works fully offline).
    try {
      final file = await _cacheFileFor(page);
      if (await file.exists() && file.lengthSync() > 10 * 1024) {
        final bytes = await file.readAsBytes();
        if (mounted && _loadedFor == page) {
          setState(() {
            _bytes = bytes;
            _loading = false;
          });
          return;
        }
      }
    } catch (_) {}

    // 2. Download from CDN, trying each base URL in order.
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
    for (final base in _kPageCdnBases) {
      if (!mounted || _loadedFor != page) return;
      try {
        final resp = await dio.get<List<int>>(
          '$base$padded.png',
          options: Options(responseType: ResponseType.bytes),
        );
        if (resp.statusCode == 200 &&
            resp.data != null &&
            resp.data!.length > 10 * 1024) {
          final bytes = Uint8List.fromList(resp.data!);
          // Persist to cache for next time (and for offline use).
          try {
            await (await _cacheFileFor(page)).writeAsBytes(bytes);
          } catch (_) {}
          if (mounted && _loadedFor == page) {
            setState(() {
              _bytes = bytes;
              _loading = false;
            });
          }
          return;
        }
      } catch (_) {}
    }

    // 3. Nothing worked — show offline message.
    if (mounted && _loadedFor == page) {
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  static Future<File> _cacheFileFor(int page) async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/mushaf_pages');
    await cacheDir.create(recursive: true);
    return File('${cacheDir.path}/page${page.toString().padLeft(3, '0')}.png');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_failed || _bytes == null) {
      return widget.textFallback ?? _buildOfflineWidget(context);
    }

    Widget img = Image.memory(
      _bytes!,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      gaplessPlayback: true,
    );

    if (widget.isDark) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1,  0,  0, 0, 255,
           0, -1,  0, 0, 255,
           0,  0, -1, 0, 255,
           0,  0,  0, 1,   0,
        ]),
        child: img,
      );
    }

    // Wrap with translations below if provided.
    if (widget.imageTranslations != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          img,
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: widget.imageTranslations!,
          ),
        ],
      );
    }

    return img;
  }

  Widget _buildOfflineWidget(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 320,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: colors.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'Page not available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to the internet once to download\nthis page — it will be saved for offline use.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.outline),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _load(widget.pageNum),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ─── Arabic-Indic numeral helper ─────────────────────────────────────────────

// Converts e.g. 255 → ٢٥٥ — used in ayah end markers.
String _toArabicNumerals(int n) {
  const e = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((d) => e[int.parse(d)]).join();
}

// ─── Text fallback view (used when CDN images are unreachable) ─────────────────
//
// Renders page ayahs as flowing Uthmanic Arabic text using the bundled font.
// Works fully offline — text comes from the local SQLite DB.

class _TextFallbackView extends StatelessWidget {
  const _TextFallbackView({
    required this.ayahs,
    required this.surahFor,
    required this.translations,
    required this.isDark,
  });

  final List<Ayah> ayahs;
  final Surah? Function(int) surahFor;
  final Map<int, String> translations;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (ayahs.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];

    // Small banner so user knows why they're seeing text instead of the scan.
    children.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded, size: 13, color: colors.outline),
            const SizedBox(width: 6),
            Text(
              'Page image unavailable — showing text',
              style: TextStyle(fontSize: 11, color: colors.outline),
            ),
          ],
        ),
      ),
    );

    int lastSurah = -1;
    for (final ayah in ayahs) {
      if (ayah.surahNumber != lastSurah) {
        lastSurah = ayah.surahNumber;
        final surah = surahFor(ayah.surahNumber);
        children.add(_TextSurahHeader(surah: surah, colors: colors));
        if (surah != null && surah.bismillahPre) {
          children.add(_TextBismillah(colors: colors));
        }
      }
      children.add(_TextAyahLine(
        ayah: ayah,
        translation: translations[ayah.id],
        colors: colors,
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _TextSurahHeader extends StatelessWidget {
  const _TextSurahHeader({required this.surah, required this.colors});

  final Surah? surah;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            surah?.nameArabic ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'UthmanicHafs',
              fontSize: 22,
              height: 1.8,
              color: colors.onSurface,
            ),
          ),
          if (surah != null)
            Text(
              surah!.nameSimple,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: colors.outline),
            ),
        ],
      ),
    );
  }
}

class _TextBismillah extends StatelessWidget {
  const _TextBismillah({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'UthmanicHafs',
          fontSize: 19,
          height: 2.0,
          color: colors.onSurface,
        ),
      ),
    );
  }
}

class _TextAyahLine extends StatelessWidget {
  const _TextAyahLine({
    required this.ayah,
    required this.translation,
    required this.colors,
  });

  final Ayah ayah;
  final String? translation;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    // U+06DD = ARABIC END OF AYAH circle glyph + Arabic-Indic ayah number
    final marker = '۝${_toArabicNumerals(ayah.ayahNumber)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${ayah.textUthmani} $marker',
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'UthmanicHafs',
            fontSize: 21,
            height: 2.2,
            color: colors.onSurface,
          ),
        ),
        if (translation != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${ayah.verseKey}  $translation',
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── AppBar title ─────────────────────────────────────────────────────────────

// Matches the King Fahad Mushaf running header exactly:
//   Surah Ash-Shu‘arāʼ  (left, plain)          Juz’ 19  (right, plain)
class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.state});

  final MushafState state;

  @override
  Widget build(BuildContext context) {
    if (state.ayahs.isEmpty) return const Text('Quran');
    final firstSurah = state.surahFor(state.ayahs.first.surahNumber);
    final juzNumber = state.ayahs.first.juzNumber;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : const Color(0xFF2A2A2A);

    return Row(
      children: [
        // Surah transliteration name — left, plain, matches reference
        Expanded(
          child: Text(
            firstSurah?.nameSimple ?? 'Page ${state.currentPage}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: textColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Juz number — right, plain, matches reference
        Text(
          "Juz\u2019 $juzNumber",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

// ─── Translation list below King Fahad page image ────────────────────────────

class _PageTranslations extends StatelessWidget {
  const _PageTranslations({
    required this.ayahs,
    required this.translations,
  });

  final List<Ayah> ayahs;
  final Map<int, String> translations;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: colors.outlineVariant),
        const SizedBox(height: 4),
        for (final ayah in ayahs)
          if (translations[ayah.id] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ayah.verseKey}  ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      translations[ayah.id]!,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

// ─── Bottom area: audio bar + reciter strip + page number ─────────────────────

class _BottomArea extends ConsumerWidget {
  const _BottomArea({required this.currentPage});

  final int currentPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AudioPlayerBar(),
        const _ReciterStrip(),
        _PageNav(currentPage: currentPage),
      ],
    );
  }
}

// ─── Reciter strip ─────────────────────────────────────────────────────────────

class _ReciterStrip extends ConsumerWidget {
  const _ReciterStrip();

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _ReciterPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    final colors = Theme.of(context).colorScheme;
    final isPlaying = audio.isPlaying;
    final reciterSlug = audio.reciter;
    final reciterName =
        AudioRepository.reciters[reciterSlug] ?? reciterSlug;

    return Semantics(
      label: 'Reciter: $reciterName. Tap to change reciter.',
      button: true,
      child: InkWell(
      onTap: () => _showPicker(context),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border(
            top: BorderSide(color: colors.outlineVariant, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              isPlaying ? Icons.volume_up : Icons.headphones,
              size: 18,
              color: colors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                reciterName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.expand_less,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ─── Reciter picker sheet ──────────────────────────────────────────────────────

class _ReciterPickerSheet extends ConsumerWidget {
  const _ReciterPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    final notifier = ref.read(audioProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final reciters = AudioRepository.reciters;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Select Reciter',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
          ),
          const Divider(height: 1),
          for (final entry in reciters.entries)
            ListTile(
              title: Text(entry.value),
              trailing: audio.reciter == entry.key
                  ? Icon(Icons.check, color: colors.primary)
                  : null,
              onTap: () {
                notifier.setReciter(entry.key);
                Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PageNav extends StatelessWidget {
  const _PageNav({required this.currentPage});

  final int currentPage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 36,
      alignment: Alignment.center,
      child: Text(
        '$currentPage',
        style: TextStyle(
          fontSize: 12,
          color: colors.outline,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
