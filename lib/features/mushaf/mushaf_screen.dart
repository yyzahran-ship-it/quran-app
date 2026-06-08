import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/theme_provider.dart';
import '../../core/theme/dyslexia_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/surah.dart';
import '../bookmarks/bookmarks_provider.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../bookmarks/note_editor_dialog.dart';
import 'mushaf_provider.dart';
import 'mushaf_download_provider.dart';
import 'search_screen.dart';
import 'ayah_coords_provider.dart';
import 'second_translation_provider.dart';
import 'tafsir_repository.dart';
import 'tafsir_sheet.dart';
import 'translations_library.dart';
import 'translations_screen.dart';
import 'widgets/juz_jump_dialog.dart';
import '../settings/settings_screen.dart';
import '../audio/audio_provider.dart';
import '../audio/audio_player_bar.dart';
import '../audio/local_word_timing_repository.dart';
import '../audio/reciter_provider.dart';
import '../audio/reciter_picker_sheet.dart';
import '../audio/word_timing_repository.dart';
import '../../domain/entities/quran_word.dart';

// CDN base URLs for King Fahad Mushaf page images, tried in order.
// The GitHub raw URL is a fallback served from GitHub's CDN (Fastly/Azure)
// which is on a completely different IP range from cdn.qurancdn.com and is
// not blocked by carriers that block quran.com. The mushaf-pages branch is
// populated by running the "Setup Mushaf Pages Branch" GitHub Actions workflow.
const _kPageCdnBases = [
  'https://cdn.qurancdn.com/images/quran/pages/page',
  'https://qurancdn.com/images/quran/pages/page',
  'https://static.qurancdn.com/images/quran/pages/page',
  'https://raw.githubusercontent.com/yyzahran-ship-it/quran-app/mushaf-pages/pages/page',
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

// ─── Screen actions (overflow menu) ──────────────────────────────────────────

enum _AppAction { search, juzJump, toggleTranslation, bookmarks, settings }

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
      case _AppAction.search:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SearchScreen()));
      case _AppAction.juzJump:
        showJuzJumpDialog(context);
      case _AppAction.toggleTranslation:
        ref.read(mushafProvider.notifier).toggleTranslation();
      case _AppAction.bookmarks:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const BookmarksScreen()));
      case _AppAction.settings:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mushafProvider);
    final pageDownload = ref.watch(mushafDownloadProvider);

    final themeMode = ref.watch(themeProvider);
    // highContrast renders as light (white background, black text).
    // inverted renders as dark (pure black background, white text).
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
        toolbarHeight: 52,
        title: _AppBarTitle(state: state),
        titleSpacing: 16,
        actions: [
          // Small spinner while Mushaf page images are being downloaded.
          if (pageDownload.isRunning)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message:
                    'Downloading pages ${pageDownload.cached}/$kTotalMushafPages',
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    value: pageDownload.progress,
                    strokeWidth: 2,
                    color: isLight ? const Color(0xFF1A1A1A) : null,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.bookmark_border, size: 22,
                color: isLight ? const Color(0xFF1A1A1A) : null),
            tooltip: 'Bookmarks',
            onPressed: () => _handleAction(_AppAction.bookmarks),
          ),
          IconButton(
            icon: Icon(Icons.language, size: 22,
                color: isLight ? const Color(0xFF1A1A1A) : null),
            tooltip: 'Translations & Tafsir',
            onPressed: () {
              final verseKey = state.ayahs.isNotEmpty
                  ? state.ayahs.first.verseKey
                  : '1:1';
              _showTranslationPanel(context, verseKey);
            },
          ),
          PopupMenuButton<_AppAction>(
            icon: Icon(Icons.more_vert,
                color: isLight ? const Color(0xFF1A1A1A) : null),
            tooltip: 'More options',
            onSelected: _handleAction,
            itemBuilder: (_) => [
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
                  const Icon(Icons.language),
                  const SizedBox(width: 12),
                  Text(state.showTranslation
                      ? 'Hide translation'
                      : 'Show translation'),
                ]),
              ),
              const PopupMenuItem(
                value: _AppAction.bookmarks,
                child: Row(children: [
                  Icon(Icons.bookmark_outline),
                  SizedBox(width: 12),
                  Text('Bookmarks'),
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
                  // RTL: swipe right → next page, swipe left → previous page.
                  onHorizontalDragEnd: (details) {
                    final v = details.primaryVelocity;
                    if (v == null) return;
                    if (v > 300) {
                      ref.read(mushafProvider.notifier).nextPage();
                      _scrollToTop();
                    } else if (v < -300) {
                      ref.read(mushafProvider.notifier).previousPage();
                      _scrollToTop();
                    }
                  },
                  child: _buildReader(state),
                ),
      bottomNavigationBar: state.ayahs.isEmpty
          ? null
          : const _BottomArea(),
    );
  }

  // ── King Fahad page image view ──────────────────────────────────────────────

  Widget _buildReader(MushafState state) {
    final themeMode = ref.watch(themeProvider);
    // isDark controls the color-invert matrix on the Mushaf page image.
    // highContrast is a light mode (white background), so isDark = false there.
    final isDark = themeMode == AppThemeMode.dark ||
        themeMode == AppThemeMode.inverted;

    final showTx = state.showTranslation && state.translations.isNotEmpty;

    final secondTxId = ref.watch(secondTranslationProvider);
    // Second translation fetched from api.quran.com, cached after first load.
    final secondTxAsync = secondTxId > 0
        ? ref.watch(secondTranslationPageProvider(
            (translationId: secondTxId, page: state.currentPage)))
        : null;
    final secondTranslations = secondTxAsync?.valueOrNull ?? {};

    // Text-based fallback (used when CDN is unreachable) includes translations
    // inline, so _PageTranslations is only attached to the image path.
    final textFallback = _TextFallbackView(
      ayahs: state.ayahs,
      surahFor: state.surahFor,
      translations: showTx ? state.translations : {},
      secondTranslations: showTx ? secondTranslations : {},
      isDark: isDark,
      pageNumber: state.currentPage,
    );

    return SingleChildScrollView(
      controller: _scrollController,
      child: _MushafPageLoader(
        pageNum: state.currentPage,
        isDark: isDark,
        textFallback: textFallback,
        imageAyahOverlay: state.ayahs.isNotEmpty
            ? _AyahImageOverlay(
                ayahs: state.ayahs,
                isDark: isDark,
                page: state.currentPage,
              )
            : null,
        imageTranslations: showTx
            ? _PageTranslations(
                ayahs: state.ayahs,
                translations: state.translations,
                secondTranslations: secondTranslations,
                isDark: isDark,
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
    this.imageAyahOverlay,
  });

  final int pageNum;
  final bool isDark;
  final Widget? textFallback;
  final Widget? imageTranslations;
  // Transparent per-ayah tap zones stacked over the image.
  final Widget? imageAyahOverlay;

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

    // 1. Load from bundled assets (no network, always works).
    //    CI downloads all 604 pages at build time; they ship inside the APK.
    //    Try both .webp (preferred, smaller) and .png (PNG fallback if webp
    //    conversion failed in CI).
    for (final ext in ['webp', 'png']) {
      try {
        final data = await rootBundle.load(
            'assets/quran/pages/page$padded.$ext');
        final bytes = data.buffer.asUint8List();
        if (bytes.length > 5 * 1024 && mounted && _loadedFor == page) {
          setState(() {
            _bytes = bytes;
            _loading = false;
          });
          return;
        }
      } catch (_) {}
    }

    // 2. Serve from on-device disk cache (pages saved from previous CDN fetch).
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

    // 3. No bundled asset or disk-cached image.
    //    Show text immediately so the user can read right away, then try
    //    CDN in the background. If it succeeds the image replaces the text.
    if (mounted && _loadedFor == page) {
      setState(() { _loading = false; _failed = true; });
    }

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 12),
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
          try {
            await (await _cacheFileFor(page)).writeAsBytes(bytes);
          } catch (_) {}
          if (mounted && _loadedFor == page) {
            setState(() { _bytes = bytes; _failed = false; });
          }
          return;
        }
      } catch (_) {}
    }
  }

  static Future<File> _cacheFileFor(int page) =>
      mushafPageCacheFile(page);

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

    final imgWithBanner = widget.imageAyahOverlay != null
        ? Stack(
            children: [
              img,
              Positioned.fill(child: widget.imageAyahOverlay!),
            ],
          )
        : img;

    if (widget.imageTranslations != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          imgWithBanner,
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: widget.imageTranslations!,
          ),
        ],
      );
    }

    return imgWithBanner;
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
// Renders page ayahs as flowing Uthmanic Arabic text using the bundled font,
// styled to resemble the King Fahad Mushaf layout: gold-bordered surah header,
// centred bismillah, flowing right-to-left ayah text with end markers.
// Works fully offline — all data comes from the local SQLite database.

// Gold tone matching the King Fahad Mushaf ornamental borders.
const _kMushafGold = Color(0xFFA67C00);

class _TextFallbackView extends ConsumerWidget {
  const _TextFallbackView({
    required this.ayahs,
    required this.surahFor,
    required this.translations,
    required this.isDark,
    this.secondTranslations = const {},
    this.pageNumber,
  });

  final List<Ayah> ayahs;
  final Surah? Function(int) surahFor;
  final Map<int, String> translations;
  final Map<int, String> secondTranslations;
  final bool isDark;
  final int? pageNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ayahs.isEmpty) return const SizedBox.shrink();

    // dyslexia_font applies monospace + extra spacing to translation text only.
    final dyslexiaFont = ref.watch(dyslexiaFontProvider);
    // Bookmarked ayah IDs — read once for the whole page build.
    final bookmarkedIds = ref.watch(
        bookmarksProvider.select((bms) => bms.map((b) => b.ayahId).toSet()));

    final bg = isDark ? const Color(0xFF1C1C1C) : Colors.white;
    final textColor = isDark ? const Color(0xFFEEEEEE) : const Color(0xFF1A1A1A);

    final children = <Widget>[];

    int lastSurah = -1;
    for (final ayah in ayahs) {
      if (ayah.surahNumber != lastSurah) {
        lastSurah = ayah.surahNumber;
        final surah = surahFor(ayah.surahNumber);
        children.add(_MushafSurahHeader(surah: surah, textColor: textColor));
        if (surah != null && surah.bismillahPre) {
          children.add(_MushafBismillah(textColor: textColor));
        }
      }
      children.add(_MushafAyahText(
        ayah: ayah,
        translation: translations[ayah.id],
        secondTranslation: secondTranslations[ayah.id],
        textColor: textColor,
        isDark: isDark,
        isBookmarked: bookmarkedIds.contains(ayah.id),
        dyslexiaFont: dyslexiaFont,
      ));
    }

    // King Fahad page number footer + offline note.
    final gold = isDark ? const Color(0xFFD4A017) : _kMushafGold;
    children.add(
      Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 4),
        child: Column(
          children: [
            if (pageNumber != null)
              Text(
                '﴾  $pageNumber  ﴿',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: gold,
                  letterSpacing: 1,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded, size: 10,
                    color: isDark ? Colors.white24 : Colors.black26),
                const SizedBox(width: 4),
                Text(
                  'Text view — page scan unavailable',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _MushafSurahHeader extends StatelessWidget {
  const _MushafSurahHeader({required this.surah, required this.textColor});

  final Surah? surah;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final place = surah?.revelationPlace == 'makkah' ? 'Makkah' : 'Madinah';
    final count = surah?.versesCount;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: _kMushafGold, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // Outer decorative rule
          Container(height: 3, color: _kMushafGold),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              children: [
                Text(
                  surah?.nameArabic ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'UthmanicHafs',
                    fontSize: 26,
                    height: 1.6,
                    color: _kMushafGold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  surah != null && count != null
                      ? '${surah!.nameSimple}  •  $count verses  •  $place'
                      : '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withAlpha(153),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 3, color: _kMushafGold),
        ],
      ),
    );
  }
}

class _MushafBismillah extends StatelessWidget {
  const _MushafBismillah({required this.textColor});

  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'UthmanicHafs',
          fontSize: 22,
          height: 2.0,
          color: textColor,
        ),
      ),
    );
  }
}

class _MushafAyahText extends ConsumerWidget {
  const _MushafAyahText({
    required this.ayah,
    required this.translation,
    required this.textColor,
    required this.isDark,
    this.isBookmarked = false,
    this.secondTranslation,
    this.dyslexiaFont = false,
  });

  final Ayah ayah;
  final String? translation;
  final String? secondTranslation;
  final Color textColor;
  final bool isDark;
  final bool isBookmarked;
  // When true, translation text uses monospace font + extra spacing/height
  // to aid readability for users with dyslexia. Arabic text is unaffected.
  final bool dyslexiaFont;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playingAyahId =
        ref.watch(audioProvider.select((s) => s.currentPlayingAyahId));
    final isPlaying = playingAyahId != null && ayah.id == playingAyahId;

    // U+06DD = ARABIC END OF AYAH ornament + Arabic-Indic numeral
    final marker = '۝${_toArabicNumerals(ayah.ayahNumber)}';

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${ayah.textUthmani} $marker',
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'UthmanicHafs',
            fontSize: 24,
            height: 2.5,
            color: textColor,
          ),
        ),
        if (translation != null)
          Padding(
            padding: EdgeInsets.only(bottom: secondTranslation != null ? 4 : 10),
            child: Text(
              '${ayah.verseKey}  $translation',
              style: TextStyle(
                fontFamily: dyslexiaFont ? 'monospace' : null,
                fontSize: 12,
                color: textColor.withAlpha(178),
                height: dyslexiaFont ? 1.8 : 1.5,
                letterSpacing: dyslexiaFont ? 1.0 : null,
              ),
            ),
          ),
        if (secondTranslation != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              secondTranslation!,
              style: TextStyle(
                fontFamily: dyslexiaFont ? 'monospace' : null,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: textColor.withAlpha(140),
                height: dyslexiaFont ? 1.8 : 1.5,
                letterSpacing: dyslexiaFont ? 1.0 : null,
              ),
            ),
          ),
      ],
    );

    if (isPlaying) {
      content = AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1B4332).withAlpha(180)
              : const Color(0xFFD1FAE5),
          border: Border(
            left: BorderSide(color: Colors.green.shade600, width: 3),
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(4),
            bottomRight: Radius.circular(4),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 2, 6, 2),
        child: content,
      );
    } else if (isBookmarked) {
      // Amber shade for bookmarked ayahs — same shade as Quran for Android.
      content = Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.amber.withAlpha(38)
              : Colors.amber.withAlpha(30),
          border: Border(
            left: BorderSide(
              color: Colors.amber.shade600,
              width: 3,
            ),
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(4),
            bottomRight: Radius.circular(4),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 2, 6, 2),
        child: content,
      );
    }

    Offset tapPos = Offset.zero;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => tapPos = d.globalPosition,
      onTap: () async {
        // Pass the ayah widget's top Y so the popup appears strictly above it,
        // not anchored to wherever the user's finger landed.
        final box = context.findRenderObject() as RenderBox?;
        final ayahTopY = (box != null && box.hasSize)
            ? box.localToGlobal(Offset.zero).dy
            : tapPos.dy;
        final result = await _showAyahPopup(context, ref, ayah, isDark,
            Offset(tapPos.dx, ayahTopY));
        if (result == 'tafsir' && context.mounted) {
          _showTranslationPanel(context, ayah.verseKey);
        } else if (result == 'tag' && context.mounted) {
          _showTagPickerFor(context, ref, ayah);
        }
      },
      child: content,
    );
  }
}

// ─── Full-ayah highlight overlay on the page image ───────────────────────────
//
// When audio is playing, fills + borders every line-rect of the active ayah
// directly on the Mushaf page scan. Uses the ayah-level bounding boxes from
// ayahcoords.db (already loaded by _AyahImageOverlay). Only rebuilds when the
// playing ayah changes — not on every 100 ms position tick.

// The ayahcoords.db was built from images that lack the decorative surah-title
// banner present in the qurancdn.com PNG files.  Pages 1 & 2 have this banner
// (~90 px + whitespace) which pushes every text line 103 px down in the
// 1024×1634 DB coordinate space.  Pages 3 onward have no such banner.
const double _kPage12YOffset = 103.0;

double _pageYOffset(int page) => page <= 2 ? _kPage12YOffset : 0.0;

class _AyahHighlightPainter extends CustomPainter {
  const _AyahHighlightPainter({
    required this.rects,
    required this.xScale,
    required this.yScale,
    required this.yOffset,
  });

  final List<Rect>? rects;
  final double xScale;
  final double yScale;
  final double yOffset;

  static const _kGreen = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final rs = rects;
    if (rs == null || rs.isEmpty) return;

    final fillPaint = Paint()
      ..color = _kGreen.withAlpha(56)   // ~22 % — matches demo default
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = _kGreen.withAlpha(210)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final r in rs) {
      final scaled = Rect.fromLTWH(
        r.left              * xScale,
        (r.top + yOffset)   * yScale,
        r.width             * xScale,
        r.height            * yScale,
      );
      final rr = RRect.fromRectAndRadius(scaled.inflate(2), const Radius.circular(4));
      canvas.drawRRect(rr, fillPaint);
      canvas.drawRRect(rr, borderPaint);
    }
  }

  @override
  bool shouldRepaint(_AyahHighlightPainter old) =>
      old.rects   != rects   ||
      old.xScale  != xScale  ||
      old.yScale  != yScale  ||
      old.yOffset != yOffset;
}

class _AyahHighlightLayer extends ConsumerWidget {
  const _AyahHighlightLayer({
    required this.ayahs,
    required this.coordsMap,
    required this.xScale,
    required this.yScale,
    required this.page,
  });

  final List<Ayah> ayahs;
  // Already-loaded page coords map passed from _AyahImageOverlay — no extra provider watch.
  final PageCoordsMap coordsMap;
  final double xScale;
  final double yScale;
  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilds only when the playing ayah ID changes — not every 100 ms tick.
    final playingId = ref.watch(
        audioProvider.select((s) => s.isActive ? s.currentPlayingAyahId : null));
    if (playingId == null) return const SizedBox.shrink();

    Ayah? playingAyah;
    for (final a in ayahs) {
      if (a.id == playingId) { playingAyah = a; break; }
    }
    if (playingAyah == null) return const SizedBox.shrink();

    final mapKey = playingAyah.surahNumber * 10000 + playingAyah.ayahNumber;
    final rects  = coordsMap[mapKey];

    return RepaintBoundary(
      child: CustomPaint(
        painter: _AyahHighlightPainter(
          rects:   rects,
          xScale:  xScale,
          yScale:  yScale,
          yOffset: _pageYOffset(page),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ─── Per-ayah invisible tap overlay on the page image ────────────────────────
//
// The page is a flat raster image — individual ayah pixel positions are
// unknown.  We approximate by stacking transparent GestureDetector zones
// whose heights are proportional to each ayah's character count (a reasonable
// proxy for the number of lines it occupies on the page).
//
// Result: tapping anywhere in the rough area of an ayah shows that ayah's
// popup toolbar.

class _AyahImageOverlay extends ConsumerStatefulWidget {
  const _AyahImageOverlay({
    required this.ayahs,
    required this.isDark,
    required this.page,
  });

  final List<Ayah> ayahs;
  final bool isDark;
  final int page;

  @override
  ConsumerState<_AyahImageOverlay> createState() => _AyahImageOverlayState();
}

class _AyahImageOverlayState extends ConsumerState<_AyahImageOverlay> {
  int? _highlightedId;
  Offset _tapPos = Offset.zero;

  // Cached during build so _onTap can compute the ayah's global top edge.
  final _stackKey = GlobalKey();
  double _xScale = 1.0;
  double _yScale = 1.0;
  Map<int, List<Rect>>? _localCoordsMap;

  Future<void> _onTap(Ayah ayah) async {
    // Anchor the popup at the BEGINNING of the ayah — in RTL Arabic this is
    // the right edge of the topmost (first) line rect.
    Offset anchor = _tapPos;
    final coords = _localCoordsMap;
    if (coords != null) {
      final mapKey = ayah.surahNumber * 10000 + ayah.ayahNumber;
      final rects = coords[mapKey];
      if (rects != null && rects.isNotEmpty) {
        final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          final globalOrigin = box.localToGlobal(Offset.zero);
          // Topmost rect = first line of the ayah.
          final firstRect = rects
              .reduce((a, b) => a.top <= b.top ? a : b);
          final topLocalY    = (firstRect.top + _pageYOffset(widget.page)) * _yScale;
          // Right edge of the first rect = beginning of the ayah in RTL.
          final beginLocalX  = (firstRect.left + firstRect.width) * _xScale;
          anchor = Offset(
            globalOrigin.dx + beginLocalX,
            globalOrigin.dy + topLocalY,
          );
        }
      }
    }
    setState(() => _highlightedId = ayah.id);
    final result = await _showAyahPopup(context, ref, ayah, widget.isDark, anchor);
    if (mounted) setState(() => _highlightedId = null);
    if (result == 'tafsir' && mounted) {
      _showTranslationPanel(context, ayah.verseKey);
    } else if (result == 'tag' && mounted) {
      _showTagPickerFor(context, ref, ayah);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors     = Theme.of(context).colorScheme;
    final tapShade   = colors.primary.withAlpha(55);

    final coordsAsync = ref.watch(ayahCoordsProvider(widget.page));
    final coordsMap   = coordsAsync.valueOrNull;

    // ── Primary: pixel-precise coords from bundled KingFahad1.db ────────────
    if (coordsMap != null && coordsMap.isNotEmpty) {
      return LayoutBuilder(builder: (ctx, box) {
        _xScale = box.maxWidth / kDbImageWidth;
        _yScale = box.maxHeight / kDbImageHeight;
        _localCoordsMap = coordsMap;

        final xScale = _xScale;
        final yScale = _yScale;

        final yOff = _pageYOffset(widget.page);

        final zones = <Widget>[
          Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent)),
          // Full-ayah highlight (below tap zones so taps still register).
          Positioned.fill(
            child: _AyahHighlightLayer(
              ayahs:     widget.ayahs,
              coordsMap: coordsMap,
              xScale:    xScale,
              yScale:    yScale,
              page:      widget.page,
            ),
          ),
        ];
        for (final ayah in widget.ayahs) {
          final key   = ayah.surahNumber * 10000 + ayah.ayahNumber;
          final rects = coordsMap[key];
          if (rects == null) continue;
          for (final r in rects) {
            zones.add(Positioned(
              left:   r.left              * xScale,
              top:    (r.top + yOff)      * yScale,
              width:  r.width             * xScale,
              height: r.height            * yScale,
              child: _zone(ayah, tapShade),
            ));
          }
        }
        return Stack(key: _stackKey, children: zones);
      });
    }

    // ── Fallback: proportional zones based on character count ────────────────
    return Column(
      children: [
        for (final ayah in widget.ayahs)
          Expanded(
            flex: ayah.textUthmani.length.clamp(50, 99999),
            child: _zone(ayah, tapShade),
          ),
      ],
    );
  }

  Widget _zone(Ayah ayah, Color tapShade) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (d) => _tapPos = d.globalPosition,
      onTap: () => _onTap(ayah),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _highlightedId == ayah.id ? tapShade : Colors.transparent,
      ),
    );
  }
}

// ─── Translation + Tafsir panel (opened from reciter strip or ayah popup) ────

void _showTranslationPanel(BuildContext context, String verseKey) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1A1A1A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _TranslationPanelSheet(verseKey: verseKey),
    ),
  );
}

// ─── Page ayah picker (shown when user taps the page image) ──────────────────
//
// Since the page is a flat raster image we cannot detect which individual ayah
// was tapped.  Instead we show a compact list of all ayahs on the page so the
// user can pick one and act on it (bookmark / tafsir / play).

void _showPageAyahSheet(
    BuildContext context, WidgetRef ref, MushafState state, bool isDark) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _PageAyahSheet(state: state, isDark: isDark),
    ),
  );
}

class _PageAyahSheet extends ConsumerWidget {
  const _PageAyahSheet({required this.state, required this.isDark});
  final MushafState state;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final ayahs = state.ayahs;
    final translations = state.translations;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.92,
      minChildSize: 0.25,
      builder: (ctx, sc) => Column(
        children: [
          // Handle + header.
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Page ${state.currentPage}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      '${ayahs.length} ayahs',
                      style: TextStyle(
                          fontSize: 12, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: colors.outlineVariant),
              ],
            ),
          ),
          // Ayah list.
          Expanded(
            child: ListView.builder(
              controller: sc,
              itemCount: ayahs.length,
              itemBuilder: (_, i) {
                final ayah = ayahs[i];
                final tx = translations[ayah.id] ?? '';
                final snippet = tx.length > 60 ? '${tx.substring(0, 60)}…' : tx;
                final isBookmarked = ref.watch(bookmarksProvider
                    .select((bms) => bms.any((b) => b.ayahId == ayah.id)));

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: colors.primaryContainer,
                    child: Text(
                      '${ayah.ayahNumber}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  title: Text(
                    ayah.verseKey,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: snippet.isNotEmpty
                      ? Text(snippet,
                          style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant))
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: isBookmarked
                              ? colors.primary
                              : colors.onSurfaceVariant,
                          size: 20,
                        ),
                        tooltip: 'Bookmark',
                        onPressed: () {
                          ref.read(bookmarksProvider.notifier).toggle(
                                ayahId: ayah.id,
                                surahNumber: ayah.surahNumber,
                                ayahNumber: ayah.ayahNumber,
                              );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.menu_book_outlined,
                            color: colors.onSurfaceVariant, size: 20),
                        tooltip: 'Tafsir',
                        onPressed: () {
                          Navigator.pop(context);
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16)),
                            ),
                            builder: (_) =>
                                TafsirSheet(verseKey: ayah.verseKey),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ayah popup toolbar ───────────────────────────────────────────────────────
//
// Green floating toolbar (bookmark / tag / share / tafsir / play) that appears
// above the tapped ayah — same UX pattern as Quran for Android.

Future<String?> _showAyahPopup(
    BuildContext context, WidgetRef ref, Ayah ayah, bool isDark, Offset pos) {
  return showDialog<String?>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _AyahPopupBar(ayah: ayah, isDark: isDark, tapPos: pos),
    ),
  );
}

class _AyahPopupBar extends ConsumerWidget {
  const _AyahPopupBar({
    required this.ayah,
    required this.isDark,
    required this.tapPos,
    super.key,
  });

  final Ayah ayah;
  final bool isDark;
  final Offset tapPos;

  static const _barH = 58.0;
  static const _borderW = 2.5; // gold bezel thickness

  // Metallic gold gradient — mimics a bevelled luxury-watch bezel.
  static const _goldBezel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF0D060),
      Color(0xFFC9A030),
      Color(0xFF7A5C10),
      Color(0xFFC9A030),
      Color(0xFFF0D060),
      Color(0xFFC9A030),
      Color(0xFF8A6518),
    ],
    stops: [0.0, 0.18, 0.38, 0.52, 0.65, 0.80, 1.0],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screen  = MediaQuery.of(context).size;
    final safePad = MediaQuery.of(context).padding;

    // Full-width pill, always horizontally centered — matches Q4A style.
    final barW   = (screen.width * 0.90).clamp(260.0, 420.0);
    final barLeft = (screen.width - barW) / 2;

    // Vertically: prefer just above the tapped ayah; flip below if too close
    // to the top of the safe area.
    final double barTop = tapPos.dy - _barH - 12 > safePad.top + 8
        ? tapPos.dy - _barH - 12
        : tapPos.dy + 24;

    final isBookmarked = ref.watch(
        bookmarksProvider.select((bms) => bms.any((b) => b.ayahId == ayah.id)));
    final reciter = ref.watch(selectedReciterProvider);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Tap-outside-to-dismiss barrier.
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
          // Floating toolbar — centered, no arrow/caret.
          Positioned(
            top: barTop,
            left: barLeft,
            // Outer shell — metallic gold gradient acts as the bezel border.
            child: Container(
              width: barW,
              height: _barH,
              padding: const EdgeInsets.all(_borderW),
              decoration: BoxDecoration(
                gradient: _goldBezel,
                borderRadius: BorderRadius.circular(29),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xCC000000),
                    blurRadius: 32,
                    offset: Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Color(0x40C9A030),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              // Inner shell — deep black with warm tint.
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF111008), Color(0xFF0A0A06)],
                  ),
                  borderRadius: BorderRadius.circular(29 - _borderW),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _PopupBtn(
                      icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      active: isBookmarked,
                      tooltip: isBookmarked ? 'Remove bookmark' : 'Bookmark',
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(bookmarksProvider.notifier).toggle(
                              ayahId: ayah.id,
                              surahNumber: ayah.surahNumber,
                              ayahNumber: ayah.ayahNumber,
                            );
                      },
                    ),
                    const _PopupSep(),
                    _PopupBtn(
                      icon: Icons.headphones_rounded,
                      tooltip: 'Play ayah',
                      onTap: () {
                        Navigator.pop(context);
                        if (reciter != null) {
                          ref.read(audioProvider.notifier).playAyah(
                                ayah.surahNumber,
                                ayah.ayahNumber,
                                reciter: reciter,
                              );
                        }
                      },
                    ),
                    const _PopupSep(),
                    _PopupBtn(
                      icon: Icons.label_outline,
                      tooltip: 'Tag',
                      onTap: () => Navigator.pop(context, 'tag'),
                    ),
                    const _PopupSep(),
                    _PopupBtn(
                      icon: Icons.share_outlined,
                      tooltip: 'Share',
                      onTap: () {
                        Navigator.pop(context);
                        _shareAyah(ayah, ref);
                      },
                    ),
                    const _PopupSep(),
                    _PopupBtn(
                      icon: Icons.language,
                      tooltip: 'Tafsir',
                      onTap: () => Navigator.pop(context, 'tafsir'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PopupBtn extends StatelessWidget {
  const _PopupBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Icon(
            icon,
            color: active ? const Color(0xFFF0C840) : const Color(0xFFC9A84C),
            size: 24,
          ),
        ),
      ),
    );
  }
}

// Thin vertical divider between popup buttons — gold-tinted.
class _PopupSep extends StatelessWidget {
  const _PopupSep();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      color: const Color(0x30C9A84C),
    );
  }
}

// Share ayah text + translation as plain text via system share sheet.
Future<void> _shareAyah(Ayah ayah, WidgetRef ref) async {
  final translations = ref.read(mushafProvider).translations;
  final translation = translations[ayah.id] ?? '';
  final text = '${ayah.textUthmani}\n\n${ayah.verseKey}  $translation'
      '\n\n— Quran App';
  await Share.share(text, subject: 'Quran ${ayah.verseKey}');
}

// Tag picker for the popup toolbar (re-uses the existing _TagPickerSheet).
void _showTagPickerFor(BuildContext context, WidgetRef ref, Ayah ayah) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _TagPickerForPopup(ayah: ayah),
    ),
  );
}

class _TagPickerForPopup extends ConsumerStatefulWidget {
  const _TagPickerForPopup({required this.ayah});
  final Ayah ayah;

  @override
  ConsumerState<_TagPickerForPopup> createState() => _TagPickerForPopupState();
}

class _TagPickerForPopupState extends ConsumerState<_TagPickerForPopup> {
  static const _tags = ['Favourite', 'Memorising', 'Daily Dhikr', 'Dua', 'Reflection'];
  String? _picked;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tag ${widget.ayah.verseKey}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) {
              final sel = _picked == tag;
              return FilterChip(
                label: Text(tag),
                selected: sel,
                onSelected: (_) => setState(() => _picked = sel ? null : tag),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                ref.read(bookmarksProvider.notifier).toggle(
                      ayahId: widget.ayah.id,
                      surahNumber: widget.ayah.surahNumber,
                      ayahNumber: widget.ayah.ayahNumber,
                      tag: _picked,
                    );
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                  backgroundColor: colors.primary),
              child: const Text('Save Bookmark'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ayah action sheet ────────────────────────────────────────────────────────

void _showAyahActions(
    BuildContext context, WidgetRef ref, Ayah ayah, bool isDark) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _AyahActionSheet(ayah: ayah),
    ),
  );
}

class _AyahActionSheet extends ConsumerStatefulWidget {
  const _AyahActionSheet({required this.ayah});
  final Ayah ayah;

  @override
  ConsumerState<_AyahActionSheet> createState() => _AyahActionSheetState();
}

class _AyahActionSheetState extends ConsumerState<_AyahActionSheet> {
  static const _tags = ['Favourite', 'Memorising', 'Important', 'Ruqyah'];
  String? _pendingTag;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isBookmarkedAsync =
        ref.watch(bookmarkedAyahProvider(widget.ayah.id));
    final isBookmarked = isBookmarkedAsync.valueOrNull ?? false;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Verse key
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.ayah.verseKey,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colors.primary,
                ),
              ),
            ),
          ),
          // Arabic preview
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              widget.ayah.textUthmani.length > 120
                  ? '${widget.ayah.textUthmani.substring(0, 120)}…'
                  : widget.ayah.textUthmani,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontFamily: 'UthmanicHafs', fontSize: 16, height: 1.8),
            ),
          ),
          const Divider(height: 1),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  label: isBookmarked ? 'Bookmarked' : 'Bookmark',
                  active: isBookmarked,
                  onTap: () async {
                    await ref.read(bookmarksProvider.notifier).toggle(
                          ayahId: widget.ayah.id,
                          surahNumber: widget.ayah.surahNumber,
                          ayahNumber: widget.ayah.ayahNumber,
                          tag: isBookmarked ? null : _pendingTag,
                        );
                  },
                ),
              ),
              Expanded(
                child: _ActionBtn(
                  icon: Icons.menu_book_outlined,
                  label: 'Tafsir',
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      builder: (_) => ProviderScope(
                        parent: ProviderScope.containerOf(context),
                        child: TafsirSheet(verseKey: widget.ayah.verseKey),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: _ActionBtn(
                  icon: Icons.note_outlined,
                  label: 'Note',
                  onTap: () {
                    Navigator.pop(context);
                    showNoteEditor(
                      context,
                      ayahId: widget.ayah.id,
                      surahNumber: widget.ayah.surahNumber,
                      ayahNumber: widget.ayah.ayahNumber,
                      verseKey: widget.ayah.verseKey,
                    );
                  },
                ),
              ),
            ],
          ),
          // Tag chips (shown when not yet bookmarked)
          if (!isBookmarked) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tag (optional)',
                      style: TextStyle(fontSize: 12, color: colors.outline)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _tags.map((tag) {
                      final selected = _pendingTag == tag;
                      return FilterChip(
                        label: Text(tag),
                        selected: selected,
                        onSelected: (_) => setState(
                            () => _pendingTag = selected ? null : tag),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? colors.primary : colors.onSurface),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: active ? colors.primary : colors.onSurface,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          firstSurah?.nameSimple ?? 'Quran',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'Page ${state.currentPage}  ·  Juz\u2019 $juzNumber',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: textColor.withAlpha(140),
          ),
        ),
      ],
    );
  }
}

// ─── Word-by-word karaoke for a single ayah row ──────────────────────────────
//
// Shows the Uthmani Arabic text as individual tappable words. When this ayah is
// the currently-playing one, the word under the audio position is highlighted
// green. Other rows rebuild only when their ayah becomes active/inactive
// (select() returns null for non-playing ayahs → no position-tick rebuilds).

class _MushafWordKaraoke extends ConsumerWidget {
  const _MushafWordKaraoke({required this.ayah, required this.isDark});

  final Ayah ayah;
  final bool isDark;

  static const _kGreen = Color(0xFF34A853);

  static int _activeWord(
    int posMs,
    int durMs,
    List<QuranWord>? timings,
    int wordCount,
  ) {
    if (timings != null && timings.isNotEmpty) {
      int idx = timings.first.position - 1;
      for (final w in timings) {
        if (w.startTime <= posMs) {
          idx = w.position - 1;
        } else {
          break;
        }
      }
      return idx.clamp(0, wordCount - 1);
    }
    if (durMs <= 0) return 0;
    return (posMs / durMs * wordCount).floor().clamp(0, wordCount - 1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = ayah.textUthmani
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final n = words.length;
    if (n == 0) return const SizedBox.shrink();

    // Only receive position ticks for the currently-playing ayah.
    final posMs = ref.watch(audioProvider.select((s) {
      if (s.currentPlayingAyahId != ayah.id || !s.isActive) return null;
      return s.position.inMilliseconds;
    }));

    // Pre-load timing data so it's ready when this ayah starts.
    final reciter = ref.watch(selectedReciterProvider);
    final qdcId   = reciter?.qdcReciterId;
    final appId   = reciter?.id;

    final qdcMap   = qdcId != null
        ? ref.watch(surahWordTimingsProvider('$qdcId:${ayah.surahNumber}')).valueOrNull
        : null;
    final localMap = (qdcId == null && appId != null)
        ? ref.watch(localSurahWordTimingsProvider('$appId:${ayah.surahNumber}')).valueOrNull
        : null;

    final timings = qdcMap?[ayah.ayahNumber] ?? localMap?[ayah.ayahNumber];

    int activeIdx = -1;
    if (posMs != null) {
      final durMs = ref.read(audioProvider).duration.inMilliseconds;
      activeIdx = _activeWord(posMs, durMs, timings, n);
    }

    final baseColor = isDark
        ? const Color(0xFFD4C5A0)
        : const Color(0xFF3B2F2F);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        alignment: WrapAlignment.end,
        textDirection: TextDirection.rtl,
        spacing: 4,
        runSpacing: 2,
        children: List.generate(n, (i) {
          final isActive = i == activeIdx;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.symmetric(
              horizontal: isActive ? 5 : 0,
              vertical: isActive ? 1 : 0,
            ),
            decoration: isActive
                ? BoxDecoration(
                    color: _kGreen,
                    borderRadius: BorderRadius.circular(5),
                  )
                : null,
            child: Text(
              words[i],
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: kArabicFont,
                fontSize: 18,
                height: 1.8,
                color: isActive ? Colors.white : baseColor,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Translation list below King Fahad page image ────────────────────────────

class _PageTranslations extends ConsumerWidget {
  const _PageTranslations({
    required this.ayahs,
    required this.translations,
    required this.isDark,
    this.secondTranslations = const {},
  });

  final List<Ayah> ayahs;
  final Map<int, String> translations;
  final Map<int, String> secondTranslations;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final dyslexiaFont = ref.watch(dyslexiaFontProvider);
    final bookmarkedIds = ref.watch(
        bookmarksProvider.select((bms) => bms.map((b) => b.ayahId).toSet()));
    final playingAyahId =
        ref.watch(audioProvider.select((s) => s.currentPlayingAyahId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: colors.outlineVariant),
        const SizedBox(height: 4),
        for (final ayah in ayahs)
          if (translations[ayah.id] != null || secondTranslations[ayah.id] != null)
            _buildAyahRow(context, ref, ayah, colors, dyslexiaFont,
                bookmarkedIds.contains(ayah.id),
                isPlaying: ayah.id == playingAyahId),
      ],
    );
  }

  Widget _buildAyahRow(
    BuildContext context,
    WidgetRef ref,
    Ayah ayah,
    ColorScheme colors,
    bool dyslexiaFont,
    bool isBookmarked, {
    bool isPlaying = false,
  }) {
    final bookmarkColor = isDark
        ? Colors.amber.withAlpha(38)
        : Colors.amber.withAlpha(30);
    final playColor = isDark
        ? const Color(0xFF1B4332).withAlpha(200)  // deep green, dark mode
        : const Color(0xFFD1FAE5);               // light green, light mode

    // Capture position on tapDown; use ayah row's top edge for popup placement.
    Offset tapPos = Offset.zero;
    return Builder(
      builder: (rowCtx) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => tapPos = d.globalPosition,
      onTap: () async {
        final box = rowCtx.findRenderObject() as RenderBox?;
        final ayahTopY = (box != null && box.hasSize)
            ? box.localToGlobal(Offset.zero).dy
            : tapPos.dy;
        final result = await _showAyahPopup(context, ref, ayah, isDark,
            Offset(tapPos.dx, ayahTopY));
        if (result == 'tafsir' && context.mounted) {
          _showTranslationPanel(context, ayah.verseKey);
        } else if (result == 'tag' && context.mounted) {
          _showTagPickerFor(context, ref, ayah);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: isPlaying
            ? BoxDecoration(
                color: playColor,
                border: Border(
                  left: BorderSide(color: Colors.green.shade600, width: 3),
                ),
              )
            : isBookmarked
                ? BoxDecoration(
                    color: bookmarkColor,
                    border: Border(
                      left: BorderSide(
                          color: Colors.amber.shade600, width: 3),
                    ),
                  )
                : const BoxDecoration(),
        padding: EdgeInsets.fromLTRB(isPlaying || isBookmarked ? 7 : 4, 5, 4, 5),
        margin: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${ayah.verseKey}  ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isPlaying
                    ? Colors.green.shade700
                    : isBookmarked
                        ? Colors.amber.shade700
                        : colors.primary.withAlpha(180),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MushafWordKaraoke(ayah: ayah, isDark: isDark),
                  if (translations[ayah.id] != null)
                    Text(
                      translations[ayah.id]!,
                      style: TextStyle(
                        fontFamily: dyslexiaFont ? 'monospace' : null,
                        fontSize: 13,
                        height: dyslexiaFont ? 1.8 : 1.6,
                        letterSpacing: dyslexiaFont ? 1.0 : null,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  if (secondTranslations[ayah.id] != null)
                    Text(
                      secondTranslations[ayah.id]!,
                      style: TextStyle(
                        fontFamily: dyslexiaFont ? 'monospace' : null,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: dyslexiaFont ? 1.8 : 1.6,
                        letterSpacing: dyslexiaFont ? 1.0 : null,
                        color: colors.onSurfaceVariant.withAlpha(180),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    )); // closes GestureDetector and Builder
  }
}

// ─── Bottom area: page number ─────────────────────────────────────────────────

class _BottomArea extends ConsumerWidget {
  const _BottomArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPage = ref.watch(mushafProvider.select((s) => s.currentPage));
    // Only rebuild when audio active/inactive changes, not on every position tick.
    final isAudioActive =
        ref.watch(audioProvider.select((s) => s.isActive));
    final ayahs = ref.watch(mushafProvider.select((s) => s.ayahs));
    final surahNumber = ayahs.isNotEmpty ? ayahs.first.surahNumber : 1;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: isAudioActive
                ? AudioPlayerBar(surahNumber: surahNumber)
                : const SizedBox.shrink(),
          ),
          _PageNav(
            currentPage: currentPage,
            onAudioTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => ReciterPickerSheet(surahNumber: surahNumber),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageNav extends StatelessWidget {
  const _PageNav({required this.currentPage, this.onAudioTap});

  final int currentPage;
  final VoidCallback? onAudioTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold   = isDark ? const Color(0xFFD4A017) : _kMushafGold;
    final colors = Theme.of(context).colorScheme;
    const double sideW = 44;

    return Container(
      height: 36,
      color: colors.surface,
      foregroundDecoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: colors.outlineVariant, width: 0.5)),
      ),
      child: Row(
        children: [
          const SizedBox(width: sideW),
          Expanded(
            child: Center(
              // Single Text so the system font handles all glyphs reliably.
              child: Text(
                '﴾  $currentPage  ﴿',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: gold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          SizedBox(
            width: sideW,
            child: IconButton(
              icon: Icon(Icons.headphones_rounded, size: 18, color: gold),
              padding: EdgeInsets.zero,
              tooltip: 'Audio',
              onPressed: onAudioTap,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Translation & Tafsir panel ───────────────────────────────────────────────
//
// Four-tab bottom panel matching competitor Q4A UX:
//   Tab 0: collapse (dismiss sheet)
//   Tab 1: bookmark
//   Tab 2: translations / tafsir (default active)
//   Tab 3: audio / reciter

const _kPanelBg      = Color(0xFF0A0A0A);
const _kPanelGold    = Color(0xFFC9A84C);
const _kPanelGoldDim = Color(0xFF8A6518);

class _TranslationPanelSheet extends ConsumerStatefulWidget {
  const _TranslationPanelSheet({required this.verseKey});

  final String verseKey;

  @override
  ConsumerState<_TranslationPanelSheet> createState() =>
      _TranslationPanelSheetState();
}

class _TranslationPanelSheetState
    extends ConsumerState<_TranslationPanelSheet> {
  int _tab = 2; // translations tab active by default

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) => Container(
        color: _kPanelBg,
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _kPanelGoldDim.withAlpha(90),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Tab row
            _buildTabRow(context),
            Divider(height: 1, color: _kPanelGoldDim.withAlpha(40)),
            // Content
            Expanded(child: _buildContent(context, scrollController)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabRow(BuildContext context) {
    return Row(
      children: [
        _TabIcon(
          icon: Icons.keyboard_arrow_down_rounded,
          active: false,
          onTap: () => Navigator.pop(context),
        ),
        _TabIcon(
          icon: Icons.bookmark_border_rounded,
          active: _tab == 1,
          onTap: () => setState(() => _tab = 1),
        ),
        _TabIcon(
          icon: Icons.language,
          active: _tab == 2,
          onTap: () => setState(() => _tab = 2),
        ),
        _TabIcon(
          icon: Icons.play_arrow_rounded,
          active: _tab == 3,
          onTap: () => setState(() => _tab = 3),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, ScrollController sc) {
    if (_tab == 2) return _buildTranslationsTab(context, sc);
    if (_tab == 3) return _buildPlayTab();
    return _buildBookmarkTab();
  }

  Widget _buildTranslationsTab(BuildContext context, ScrollController sc) {
    final selectedIds = ref.watch(selectedTafsirsProvider);
    return ListView(
      controller: sc,
      padding: EdgeInsets.zero,
      children: [
        // ── "الترجمات" gold header ─────────────────────────────────────
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 2),
          child: Text(
            'الترجمات',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kPanelGold,
              letterSpacing: .02,
            ),
          ),
        ),
        // ── Tafsir pick list — gold checkboxes ────────────────────────
        for (final t in kTafsirs)
          _GoldCheckTile(
            label: t.name,
            sub: t.language,
            checked: selectedIds.contains(t.id),
            onTap: () =>
                ref.read(selectedTafsirsProvider.notifier).toggle(t.id),
          ),
        // ── "المزيد من الترجمات" link ──────────────────────────────────
        InkWell(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TranslationsScreen())),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(
              'المزيد من الترجمات...',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontSize: 13, color: _kPanelGoldDim, height: 1.4),
            ),
          ),
        ),
        // Gold shimmer divider
        Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.transparent,
              _kPanelGold,
              Colors.transparent,
            ]),
          ),
        ),
        // ── Verse key ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(
            widget.verseKey,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kPanelGold,
            ),
          ),
        ),
        for (final id in selectedIds) _buildTafsirBlock(id),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTafsirBlock(int tafsirId) {
    final info = kTafsirs.firstWhere(
      (t) => t.id == tafsirId,
      orElse: () => kTafsirs.first,
    );
    final key = (tafsirId: tafsirId, verseKey: widget.verseKey);
    final async = ref.watch(tafsirTextProvider(key));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF161008),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: _kPanelGoldDim.withAlpha(80), width: .8),
            ),
            child: Text(
              '${info.name}  •  ${info.language}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kPanelGold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          async.when(
            loading: () => const SizedBox(
              height: 40,
              child: Center(
                  child: CircularProgressIndicator(
                      color: _kPanelGold, strokeWidth: 2)),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Could not load — check your connection',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.45)),
              ),
            ),
            data: (text) => Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.75,
                color: Colors.white,
              ),
            ),
          ),
          Divider(height: 24, color: _kPanelGoldDim.withAlpha(30)),
        ],
      ),
    );
  }

  Widget _buildBookmarkTab() {
    final mushafState = ref.watch(mushafProvider);
    final allBookmarks = ref.watch(bookmarksProvider);
    // Locate the ayah matching the verseKey this panel was opened for.
    final matches = mushafState.ayahs.where((a) => a.verseKey == widget.verseKey);
    final ayah = matches.isEmpty ? null : matches.first;

    if (ayah == null) {
      return Center(
        child: Text(
          'Ayah ${widget.verseKey} not on this page',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
        ),
      );
    }

    final isBookmarked = allBookmarks.any((b) => b.ayahId == ayah.id);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Ayah card with gold shade when bookmarked ─────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: isBookmarked
                  ? _kPanelGold.withAlpha(22)
                  : Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isBookmarked
                    ? _kPanelGold
                    : Colors.white.withValues(alpha: 0.12),
                width: isBookmarked ? 1.5 : 0.8,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              children: [
                // Verse key chip
                Text(
                  widget.verseKey,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: _kPanelGold,
                  ),
                ),
                const SizedBox(height: 14),
                // Arabic text
                Text(
                  ayah.textUthmani,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'UthmanicHafs',
                    fontSize: 22,
                    height: 2.1,
                    color: Colors.white,
                  ),
                ),
                if (isBookmarked) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bookmark, size: 14, color: _kPanelGold),
                      const SizedBox(width: 4),
                      const Text(
                        'Saved to bookmarks',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kPanelGold,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Bookmark toggle button ─────────────────────────────────────
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: () {
                ref.read(bookmarksProvider.notifier).toggle(
                      ayahId: ayah.id,
                      surahNumber: ayah.surahNumber,
                      ayahNumber: ayah.ayahNumber,
                    );
              },
              icon: Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                size: 20,
              ),
              label: Text(
                isBookmarked ? 'Remove Bookmark' : 'Bookmark this Ayah',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _kPanelGold,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Stub play tab — shows current playback state, wired up in a future task.
Widget _buildPlayTab() => const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'قريباً — التشغيل',
          style: TextStyle(color: _kPanelGoldDim, fontSize: 14),
        ),
      ),
    );

// Single icon tab button with gold active indicator.
class _TabIcon extends StatelessWidget {
  const _TabIcon({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? _kPanelGold : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Icon(
            icon,
            color: active
                ? _kPanelGold
                : const Color(0xFF444444),
            size: 24,
          ),
        ),
      ),
    );
  }
}

// Gold checkbox row used in the translation picker inside the panel.
class _GoldCheckTile extends StatelessWidget {
  const _GoldCheckTile({
    required this.label,
    required this.sub,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final String sub;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Gold checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: checked ? _kPanelGold : Colors.transparent,
                border: Border.all(
                  color: checked ? _kPanelGold : const Color(0xFF333333),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 14, color: Colors.black)
                  : null,
            ),
            const SizedBox(width: 14),
            // Name + language
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      color: checked ? _kPanelGold : const Color(0xFF888888),
                      fontWeight: checked ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 11,
                        color: checked
                            ? _kPanelGoldDim
                            : const Color(0xFF444444),
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
