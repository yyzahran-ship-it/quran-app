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
import '../audio/audio_player_bar.dart';
import '../audio/audio_provider.dart';
import '../audio/audio_repository.dart';
import '../audio/reciter_provider.dart';
import '../audio/quran_foundation_repository.dart';
import '../bookmarks/bookmarks_provider.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../bookmarks/note_editor_dialog.dart';
import 'mushaf_provider.dart';
import 'mushaf_download_provider.dart';
import 'search_screen.dart';
import 'ayah_coords_provider.dart';
import 'second_translation_provider.dart';
import 'tafsir_sheet.dart';
import 'widgets/juz_jump_dialog.dart';
import '../settings/settings_screen.dart';

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

enum _AppAction { playPause, search, juzJump, toggleTranslation, bookmarks, settings }

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
    final audio = ref.watch(audioProvider);
    final pageDownload = ref.watch(mushafDownloadProvider);

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
        toolbarHeight: 44,
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
          : _BottomArea(currentPage: state.currentPage),
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
        nowPlayingBanner: _NowPlayingBanner(ayahs: state.ayahs, isDark: isDark),
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
    this.nowPlayingBanner,
    this.imageTranslations,
    this.imageAyahOverlay,
  });

  final int pageNum;
  final bool isDark;
  final Widget? textFallback;
  final Widget? nowPlayingBanner;
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

    // Stack per-ayah overlay and now-playing banner on top of the image.
    final hasOverlay =
        widget.imageAyahOverlay != null || widget.nowPlayingBanner != null;
    final imgWithBanner = hasOverlay
        ? Stack(
            children: [
              img,
              if (widget.imageAyahOverlay != null)
                Positioned.fill(child: widget.imageAyahOverlay!),
              if (widget.nowPlayingBanner != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: widget.nowPlayingBanner!,
                ),
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

// ─── Now-playing banner (overlaid on bottom of page image while audio plays) ──
//
// Shows the current ayah key + first few words of Arabic text while audio
// is active. Tapping it opens the action sheet for that ayah so the user
// can access Tafsir, Bookmark, or Note without switching to text-fallback mode.

class _NowPlayingBanner extends ConsumerWidget {
  const _NowPlayingBanner({required this.ayahs, required this.isDark});

  final List<Ayah> ayahs;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    if (!audio.hasAudio) return const SizedBox.shrink();

    final currentAyah = ayahs
        .where((a) =>
            a.surahNumber == audio.surahNumber &&
            a.ayahNumber == audio.currentAyahNumber)
        .firstOrNull;

    if (currentAyah == null) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _showAyahActions(context, ref, currentAyah, isDark),
      child: Container(
        decoration: BoxDecoration(
          // Semi-transparent so the page image is partially visible behind.
          color: colors.primaryContainer.withAlpha(220),
          border: Border(
            top: BorderSide(
              color: colors.primary.withAlpha(80),
              width: 0.5,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              audio.isPlaying ? Icons.volume_up : Icons.pause_circle_outline,
              size: 16,
              color: colors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              currentAyah.verseKey,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                // Show first ~40 chars of Arabic so users can follow along.
                currentAyah.textUthmani.length > 40
                    ? '${currentAyah.textUthmani.substring(0, 40)}…'
                    : currentAyah.textUthmani,
                textDirection: TextDirection.rtl,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'UthmanicHafs',
                  fontSize: 14,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.menu_book_outlined, size: 16, color: colors.primary),
          ],
        ),
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

    final audio = ref.watch(audioProvider);
    // dyslexia_font applies monospace + extra spacing to translation text only.
    final dyslexiaFont = ref.watch(dyslexiaFontProvider);

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
      final isHighlighted = audio.surahNumber == ayah.surahNumber &&
          audio.currentAyahNumber == ayah.ayahNumber;
      children.add(_MushafAyahText(
        ayah: ayah,
        translation: translations[ayah.id],
        secondTranslation: secondTranslations[ayah.id],
        textColor: textColor,
        isDark: isDark,
        isHighlighted: isHighlighted,
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
    required this.isHighlighted,
    this.secondTranslation,
    this.dyslexiaFont = false,
  });

  final Ayah ayah;
  final String? translation;
  final String? secondTranslation;
  final Color textColor;
  final bool isDark;
  final bool isHighlighted;
  // When true, translation text uses monospace font + extra spacing/height
  // to aid readability for users with dyslexia. Arabic text is unaffected.
  final bool dyslexiaFont;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    if (isHighlighted) {
      content = Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withAlpha(120),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: content,
      );
    }

    Offset tapPos = Offset.zero;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => tapPos = d.globalPosition,
      onTap: () => _showAyahPopup(context, ref, ayah, isDark, tapPos),
      child: content,
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
          final topLocalY    = firstRect.top  * _yScale;
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
    await _showAyahPopup(context, ref, ayah, widget.isDark, anchor);
    if (mounted) setState(() => _highlightedId = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors     = Theme.of(context).colorScheme;
    final tapShade   = colors.primary.withAlpha(55);
    final playShade  = const Color(0xFF4CAF50).withAlpha(100); // apple green

    final audio      = ref.watch(audioProvider);
    final coordsAsync = ref.watch(ayahCoordsProvider(widget.page));
    final coordsMap   = coordsAsync.valueOrNull;

    bool isPlaying(Ayah ayah) =>
        (audio.isPlaying || audio.isLoading) &&
        !audio.hasError &&
        audio.surahNumber == ayah.surahNumber &&
        audio.currentAyahNumber == ayah.ayahNumber;

    // ── Primary: pixel-precise coords from bundled KingFahad1.db ────────────
    if (coordsMap != null && coordsMap.isNotEmpty) {
      return LayoutBuilder(builder: (ctx, box) {
        // Cache scales + map so _onTap can compute the ayah's global top edge.
        _xScale = box.maxWidth / kDbImageWidth;
        _yScale = box.maxHeight / kDbImageHeight;
        _localCoordsMap = coordsMap;

        final xScale = _xScale;
        final yScale = _yScale;

        final zones = <Widget>[];
        for (final ayah in widget.ayahs) {
          final key   = ayah.surahNumber * 10000 + ayah.ayahNumber;
          final rects = coordsMap[key];
          if (rects == null) continue;
          final playing = isPlaying(ayah);
          for (final r in rects) {
            zones.add(Positioned(
              left:   r.left   * xScale,
              top:    r.top    * yScale,
              width:  r.width  * xScale,
              height: r.height * yScale,
              child: _zone(ayah, tapShade, playShade, playing),
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
            child: _zone(ayah, tapShade, playShade, isPlaying(ayah)),
          ),
      ],
    );
  }

  Widget _zone(Ayah ayah, Color tapShade, Color playShade, bool playing) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (d) => _tapPos = d.globalPosition,
      onTap: () => _onTap(ayah),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _highlightedId == ayah.id
            ? tapShade
            : playing
                ? playShade
                : Colors.transparent,
      ),
    );
  }
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
                      IconButton(
                        icon: Icon(Icons.play_circle_outline,
                            color: colors.onSurfaceVariant, size: 20),
                        tooltip: 'Play',
                        onPressed: () {
                          Navigator.pop(context);
                          ref
                              .read(audioProvider.notifier)
                              .playAyah(ayah.surahNumber, ayah.ayahNumber);
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

Future<void> _showAyahPopup(
    BuildContext context, WidgetRef ref, Ayah ayah, bool isDark, Offset pos) {
  return showDialog<void>(
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

  static const _barH = 52.0;
  static const _arrow = 8.0;
  static const _barColor = Color(0xFF1B6B3A); // deep Quran-green

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screen = MediaQuery.of(context).size;
    final safePad = MediaQuery.of(context).padding;
    // Responsive width: ~88 % of the screen, clamped so it never clips on
    // very small or very wide screens.
    final barW = (screen.width * 0.88).clamp(240.0, 360.0);

    final isBookmarked = ref.watch(
        bookmarksProvider.select((bms) => bms.any((b) => b.ayahId == ayah.id)));

    // tapPos.dy = global top edge of the ayah. Place bar above; flip below if
    // there is no room above.
    final showAbove = tapPos.dy - _barH - _arrow - 8 > safePad.top + 8;
    final double top = showAbove
        ? tapPos.dy - _barH - _arrow - 4
        : tapPos.dy + 20;

    // tapPos.dx = right edge of the ayah's first line (beginning in RTL).
    // Right-align the bar to that point so the arrow sits at the ayah start.
    final double left =
        (tapPos.dx - barW).clamp(8.0, screen.width - barW - 8.0);

    // Arrow position relative to the bar's left edge — points at the beginning.
    final double arrowX =
        (tapPos.dx - left - _arrow).clamp(_arrow * 2, barW - _arrow * 4);

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
          Positioned(
            top: top,
            left: left,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toolbar row.
                Container(
                  width: barW,
                  height: _barH,
                  decoration: BoxDecoration(
                    color: _barColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x44000000),
                          blurRadius: 8,
                          offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _PopupBtn(
                        icon: isBookmarked
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        active: isBookmarked,
                        tooltip: isBookmarked ? 'Remove' : 'Bookmark',
                        onTap: () {
                          Navigator.pop(context);
                          ref.read(bookmarksProvider.notifier).toggle(
                                ayahId: ayah.id,
                                surahNumber: ayah.surahNumber,
                                ayahNumber: ayah.ayahNumber,
                              );
                        },
                      ),
                      _PopupBtn(
                        icon: Icons.label_outline,
                        tooltip: 'Tag',
                        onTap: () {
                          Navigator.pop(context);
                          _showTagPickerFor(context, ref, ayah);
                        },
                      ),
                      _PopupBtn(
                        icon: Icons.share_outlined,
                        tooltip: 'Share',
                        onTap: () {
                          Navigator.pop(context);
                          _shareAyah(ayah, ref);
                        },
                      ),
                      _PopupBtn(
                        icon: Icons.menu_book_outlined,
                        tooltip: 'Tafsir',
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
                            builder: (_) =>
                                TafsirSheet(verseKey: ayah.verseKey),
                          );
                        },
                      ),
                      _PopupBtn(
                        icon: Icons.play_circle_outline,
                        tooltip: 'Play',
                        onTap: () {
                          Navigator.pop(context);
                          ref
                              .read(audioProvider.notifier)
                              .playAyah(ayah.surahNumber, ayah.ayahNumber);
                        },
                      ),
                    ],
                  ),
                ),
                // Downward-pointing triangle (only shown when bar is above tap).
                if (showAbove)
                  Padding(
                    padding: EdgeInsets.only(left: arrowX),
                    child: CustomPaint(
                      size: const Size(_arrow * 2, _arrow),
                      painter: _DownArrowPainter(_barColor),
                    ),
                  ),
              ],
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
            color: active ? Colors.amber.shade300 : Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _DownArrowPainter extends CustomPainter {
  const _DownArrowPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DownArrowPainter old) => old.color != color;
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
    final audio = ref.watch(audioProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: colors.outlineVariant),
        const SizedBox(height: 4),
        for (final ayah in ayahs)
          if (translations[ayah.id] != null || secondTranslations[ayah.id] != null)
            _buildAyahRow(context, ref, ayah, audio, colors, dyslexiaFont),
      ],
    );
  }

  Widget _buildAyahRow(
    BuildContext context,
    WidgetRef ref,
    Ayah ayah,
    AudioState audio,
    ColorScheme colors,
    bool dyslexiaFont,
  ) {
    final isPlaying = audio.hasAudio &&
        audio.surahNumber == ayah.surahNumber &&
        audio.currentAyahNumber == ayah.ayahNumber;
    final highlightColor = isDark
        ? colors.primary.withAlpha(40)
        : colors.primary.withAlpha(20);

    // Capture position on tapDown; trigger popup on tap (so scroll still works).
    Offset tapPos = Offset.zero;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => tapPos = d.globalPosition,
      onTap: () => _showAyahPopup(context, ref, ayah, isDark, tapPos),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: isPlaying ? highlightColor : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        margin: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${ayah.verseKey}  ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isPlaying ? colors.primary : colors.primary.withAlpha(180),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
            if (isPlaying)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.volume_up_rounded,
                    size: 14, color: colors.primary),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom area: audio bar + reciter strip + page number ─────────────────────

class _BottomArea extends StatefulWidget {
  const _BottomArea({required this.currentPage});

  final int currentPage;

  @override
  State<_BottomArea> createState() => _BottomAreaState();
}

class _BottomAreaState extends State<_BottomArea> {
  bool _reciterVisible = true;

  @override
  Widget build(BuildContext context) {
    // SafeArea ensures the page number row is visible above the home indicator
    // or Android gesture bar — without it the bottom row hides under system UI.
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AudioPlayerBar(),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _reciterVisible
                ? _ReciterStrip(
                    onCollapse: () => setState(() => _reciterVisible = false),
                  )
                : const SizedBox.shrink(),
          ),
          _PageNav(
            currentPage: widget.currentPage,
            showExpand: !_reciterVisible,
            onExpand: () => setState(() => _reciterVisible = true),
          ),
        ],
      ),
    );
  }
}

// ─── Reciter strip ─────────────────────────────────────────────────────────────

class _ReciterStrip extends ConsumerWidget {
  const _ReciterStrip({this.onCollapse});

  final VoidCallback? onCollapse;

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      builder: (_) => const _ReciterPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio       = ref.watch(audioProvider);
    final qaReciters  = ref.watch(reciterListProvider);
    final qfAsync     = ref.watch(qfRecitationsProvider);
    final colors      = Theme.of(context).colorScheme;
    final isPlaying   = audio.isPlaying;
    final reciterSlug = audio.reciter;

    // Resolve display name from hardcoded list first, then QF list.
    String reciterName = reciterDisplayName(qaReciters, reciterSlug);
    if (reciterSlug.startsWith('qf_')) {
      final id = int.tryParse(reciterSlug.substring(3));
      if (id != null) {
        final qf = qfAsync.valueOrNull ?? [];
        for (final r in qf) {
          if (r.id == id) { reciterName = r.displayName; break; }
        }
      }
    }

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: colors.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Collapse button — separate tap zone so it never opens the picker.
          InkWell(
            onTap: onCollapse,
            child: SizedBox(
              width: 40,
              height: 44,
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          // Reciter name area — tap opens the picker.
          Expanded(
            child: Semantics(
              label: 'Reciter: $reciterName. Tap to change reciter.',
              button: true,
              child: InkWell(
                onTap: () => _showPicker(context),
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
                    const SizedBox(width: 12),
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

// ─── Reciter picker sheet ──────────────────────────────────────────────────────
//
// Shows two sections:
//   1. Curated list (hardcoded, always instant) — everyayah CDN
//   2. Quran Foundation reciters (fetched once from api.quran.com) — 40+

class _ReciterPickerSheet extends ConsumerWidget {
  const _ReciterPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio    = ref.watch(audioProvider);
    final reciters = ref.watch(reciterListProvider);
    final qfAsync  = ref.watch(qfRecitationsProvider);
    final notifier = ref.read(audioProvider.notifier);
    final colors   = Theme.of(context).colorScheme;

    // QF reciters de-duped against the hardcoded list by display name.
    final hardcodedNames = reciters.map((r) => r.name.toLowerCase()).toSet();
    final qfReciters = qfAsync.valueOrNull
        ?.where((r) => !hardcodedNames.contains(r.displayName.toLowerCase()))
        .toList() ?? [];

    Widget buildTile(String slug, String displayName) {
      final selected = audio.reciter == slug;
      return ListTile(
        title: Text(displayName),
        trailing: selected ? Icon(Icons.check, color: colors.primary) : null,
        selected: selected,
        onTap: () {
          notifier.setReciter(slug);
          Navigator.of(context).pop();
        },
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            height: 4,
            width: 36,
            decoration: BoxDecoration(
              color: colors.onSurfaceVariant.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                // ── Section 1: curated everyayah reciters ──────────────────
                for (final r in reciters)
                  buildTile(r.relativePath, r.name),

                // ── Section 2: Quran Foundation reciters ───────────────────
                if (qfAsync.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (qfReciters.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      'MORE RECITERS (quran.com)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  for (final r in qfReciters)
                    buildTile(r.slug, r.displayName),
                ] else if (qfAsync.hasError)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Could not load additional reciters — check your connection.',
                      style: TextStyle(fontSize: 12, color: colors.outline),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PageNav extends StatelessWidget {
  const _PageNav({
    required this.currentPage,
    this.showExpand = false,
    this.onExpand,
  });

  final int currentPage;
  final bool showExpand;
  final VoidCallback? onExpand;

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
          if (showExpand && onExpand != null)
            InkWell(
              onTap: onExpand,
              child: SizedBox(
                width: sideW,
                height: 36,
                child: Icon(Icons.keyboard_arrow_up,
                    size: 18, color: colors.onSurfaceVariant),
              ),
            )
          else
            const SizedBox(width: sideW),
        ],
      ),
    );
  }
}
