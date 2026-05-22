import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/surah.dart';
import '../audio/audio_player_bar.dart';
import '../audio/audio_provider.dart';
import '../audio/audio_repository.dart';
import '../bookmarks/bookmarks_provider.dart';
import '../bookmarks/note_editor_dialog.dart';
import '../../data/repositories/quran_repository.dart';
import '../memorization/hifz_provider.dart';
import 'mushaf_provider.dart';
import 'search_screen.dart';
import 'tafsir_sheet.dart';
import 'widgets/juz_jump_dialog.dart';
import '../settings/settings_screen.dart';

// ─── Helper: convert Western numerals to Arabic-Indic numerals ───────────────
// The King Fahad Mushaf uses Arabic-Indic numerals (١٢٣) for verse numbers
// inside the decorative end markers, matching the printed Mushaf exactly.

String _toArabicNumerals(int n) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().split('').map((c) => digits[int.parse(c)]).join();
}

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

// ─── Helper: group page ayahs by surah ───────────────────────────────────────

class _SurahSection {
  _SurahSection(this.surah);
  final Surah surah;
  final List<Ayah> ayahs = [];
}

List<_SurahSection> _groupBySurah(List<Ayah> ayahs, MushafState state) {
  final sections = <_SurahSection>[];
  for (final ayah in ayahs) {
    final surah = state.surahFor(ayah.surahNumber);
    if (surah == null) continue;
    if (sections.isEmpty || sections.last.surah.id != ayah.surahNumber) {
      sections.add(_SurahSection(surah)..ayahs.add(ayah));
    } else {
      sections.last.ayahs.add(ayah);
    }
  }
  return sections;
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
    final pageNum = state.currentPage.toString().padLeft(3, '0');
    final imageUrl =
        'https://cdn.qurancdn.com/images/quran/pages/page$pageNum.png';

    // The page image is white-on-dark in the printed Mushaf; invert for
    // dark/inverted themes so the background matches the app theme.
    Widget pageImg = Image.network(
      imageUrl,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        );
      },
      errorBuilder: (context, error, _) => _buildTextFallback(state),
    );

    if (isDark) {
      pageImg = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1,  0,  0, 0, 255,
           0, -1,  0, 0, 255,
           0,  0, -1, 0, 255,
           0,  0,  0, 1,   0,
        ]),
        child: pageImg,
      );
    }

    // Translations shown as numbered list below the page image when enabled.
    final showTx = state.showTranslation && state.translations.isNotEmpty;

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pageImg,
          if (showTx) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _PageTranslations(
                ayahs: state.ayahs,
                translations: state.translations,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Text fallback (used when CDN is unreachable) ──────────────────────────
  //
  // Layout matches the King Fahad Mushaf page exactly:
  //   • Plain white background
  //   • Surah name + Juz header at top (plain text, no italic)
  //   • Continuous justified Arabic text with inline circular verse markers
  //   • Bismillah centred before the text block
  //   • Surah name ornamental box at the BOTTOM of the page (like printed Mushaf)
  //   • Page number centred at the very bottom

  Widget _buildTextFallback(MushafState state) {
    final fontSize = ref.watch(fontSizeProvider);
    final translationFontSize = ref.watch(translationFontSizeProvider);
    final audio = ref.watch(audioProvider);
    final sections = _groupBySurah(state.ayahs, state);
    final firstSurah = sections.isNotEmpty ? sections.first.surah : null;
    final juzNumber =
        state.ayahs.isNotEmpty ? state.ayahs.first.juzNumber : null;

    final isDarkFallback = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDarkFallback ? Colors.white : const Color(0xFF1A1A1A);

    return Container(
      color: isDarkFallback ? const Color(0xFF0D1117) : Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Running header: Surah name (left) · Juz (right) ──────────────
          if (firstSurah != null)
            _PageHeader(surah: firstSurah, juzNumber: juzNumber),
          const SizedBox(height: 32),

          // ── Surah sections ────────────────────────────────────────────────
          for (final section in sections) ...[
            // Bismillah centred above text (omit for At-Tawbah surah 9)
            if (section.surah.bismillahPre && section.surah.id != 1) ...[
              const _BismillahLine(),
              const SizedBox(height: 16),
            ],
            // Continuous flowing Arabic text — all ayahs in one paragraph
            _ContinuousText(
              ayahs: section.ayahs,
              fontSize: fontSize,
              translationFontSize: translationFontSize,
              translations: state.showTranslation
                  ? state.translations
                  : const {},
              onAyahMenu: (ayah) => _showAyahMenu(context, ayah),
              playingSurahNumber: audio.surahNumber,
              playingAyahNumber: audio.currentAyahNumber,
            ),
            const SizedBox(height: 24),
            // ── Surah name ornamental box at BOTTOM of page ───────────────
            // In the printed King Fahad Mushaf the surah name banner appears
            // at the bottom of the last page of that surah, not at the top.
            _SurahFooterBanner(surah: section.surah, textColor: textColor),
            const SizedBox(height: 20),
          ],

          // ── Page number centred at bottom ─────────────────────────────────
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${state.currentPage}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: isDarkFallback
                    ? Colors.white38
                    : const Color(0xFF888888),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
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

  void _showAyahMenu(BuildContext context, Ayah ayah) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _AyahActionSheet(
        ayahKey: ayah.verseKey,
        surahNumber: ayah.surahNumber,
        ayahNumber: ayah.ayahNumber,
        ayahId: ayah.id,
        textUthmani: ayah.textUthmani,
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

// ─── In-page running header ───────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.surah, required this.juzNumber});

  final Surah surah;
  final int? juzNumber;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white60 : const Color(0xFF2A2A2A);
    // Matches the King Fahad Mushaf running header:
    //   Surah Ash-Shu‘arāʼ  (left)          Juz’ 19  (right)
    // Plain, no italic, no decoration.
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: textColor,
    );
    return Row(
      children: [
        Text(surah.nameSimple, style: style),
        const Spacer(),
        if (juzNumber != null) Text("Juz\u2019 $juzNumber", style: style),
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

// ─── Thin decorative divider above page number ────────────────────────────────

class _PageDivider extends StatelessWidget {
  const _PageDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Divider(
        thickness: 0.5,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

// ─── Surah footer banner (bottom of page, matches King Fahad Mushaf) ─────────
//
// In the printed Mushaf the surah name appears in an ornamental bordered box
// at the BOTTOM of the last page of that surah — not at the top.
// The border uses a repeating geometric Islamic pattern (simulated with
// CustomPainter dashes) and the surah name is in the KFGQPC Uthmanic font.

class _SurahFooterBanner extends StatelessWidget {
  const _SurahFooterBanner({
    required this.surah,
    required this.textColor,
  });

  final Surah surah;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Outer border colour matches the dark ink of the printed Mushaf
    const borderColor = Color(0xFF2A2A2A);
    final darkBorderColor = Colors.white70;
    final bc = isDark ? darkBorderColor : borderColor;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : Colors.white,
        // Outer border — thick, matches the printed Mushaf frame
        border: Border.all(color: bc, width: 2.5),
      ),
      child: Container(
        // Inner border — thin, creates the double-frame effect
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          border: Border.all(color: bc, width: 1.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        child: Text(
          // Use the full Arabic surah name with "سُورَةُ" prefix
          'سُورَةُ ${surah.nameArabic}',
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kArabicFont,
            fontSize: 26,
            fontWeight: FontWeight.w400,
            height: 1.8,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// ─── Legacy _SurahBanner (kept for any remaining references) ──────────────────

class _SurahBanner extends StatelessWidget {
  const _SurahBanner({required this.surah});
  final Surah surah;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _SurahFooterBanner(
      surah: surah,
      textColor: isDark ? Colors.white : const Color(0xFF1A1A1A),
    );
  }
}

// ─── Bismillah line ───────────────────────────────────────────────────────────
//
// Matches the printed Mushaf: centred Arabic text, no decorative divider,
// same font and colour as the body text.

class _BismillahLine extends StatelessWidget {
  const _BismillahLine();
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: kArabicFont,
          fontSize: 26,
          height: 2.2,
          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
        ),
      ),
    );
  }
}

// ─── Continuous Mushaf text (all ayahs flow as one paragraph) ────────────────
//
// Uses Text.rich with per-ayah TapGestureRecognizer so multiple short ayahs
// can share a line — matching the visual style of a printed Mushaf page.

class _ContinuousText extends StatefulWidget {
  const _ContinuousText({
    required this.ayahs,
    required this.fontSize,
    required this.translationFontSize,
    required this.translations,
    required this.onAyahMenu,
    this.playingSurahNumber,
    this.playingAyahNumber,
  });

  final List<Ayah> ayahs;
  final double fontSize;
  final double translationFontSize;
  final Map<int, String> translations;
  final void Function(Ayah) onAyahMenu;
  final int? playingSurahNumber;
  final int? playingAyahNumber;

  @override
  State<_ContinuousText> createState() => _ContinuousTextState();
}

class _ContinuousTextState extends State<_ContinuousText> {
  // One recognizer per ayah — must be disposed to avoid leaks.
  late List<TapGestureRecognizer> _recognizers;

  @override
  void initState() {
    super.initState();
    _buildRecognizers();
  }

  void _buildRecognizers() {
    _recognizers = List.generate(
      widget.ayahs.length,
      (i) => TapGestureRecognizer()
        ..onTap = () => widget.onAyahMenu(widget.ayahs[i]),
    );
  }

  @override
  void didUpdateWidget(_ContinuousText old) {
    super.didUpdateWidget(old);
    if (widget.ayahs.length != _recognizers.length) {
      // Ayah count changed (new page) — rebuild all recognizers.
      for (final r in _recognizers) r.dispose();
      _buildRecognizers();
    } else {
      // Same count — update callbacks so closures capture the latest ayahs.
      for (int i = 0; i < _recognizers.length; i++) {
        _recognizers[i].onTap = () => widget.onAyahMenu(widget.ayahs[i]);
      }
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers) r.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ayahs.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Pure black on white — matches the printed Mushaf ink colour exactly
    final textColor = isDark ? Colors.white : const Color(0xFF0D0D0D);
    const playingColor = Color(0xFF1B6B3A);

    // Build a single flowing TextSpan for all ayahs in this surah section.
    // Short ayahs will naturally share lines, matching the printed Mushaf look.
    final spans = <InlineSpan>[];
    for (int i = 0; i < widget.ayahs.length; i++) {
      final ayah = widget.ayahs[i];
      final isPlaying = widget.playingSurahNumber != null &&
          ayah.surahNumber == widget.playingSurahNumber &&
          ayah.ayahNumber == widget.playingAyahNumber;

      spans.add(TextSpan(
        text: '${ayah.textUthmani} ',
        recognizer: _recognizers[i],
        style: TextStyle(
          color: isPlaying ? playingColor : textColor,
          fontWeight: isPlaying ? FontWeight.w700 : FontWeight.normal,
          backgroundColor:
              isPlaying ? playingColor.withValues(alpha: 0.08) : null,
        ),
      ));
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _AyahEndMarker(
          number: ayah.ayahNumber,
          onTap: () => widget.onAyahMenu(ayah),
          isPlaying: isPlaying,
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: spans,
            style: TextStyle(
              fontFamily: kArabicFont,
              fontSize: widget.fontSize,
              // Line height 2.4 matches the King Fahad Mushaf printed spacing —
              // the KFGQPC font has tall ascenders for diacritics (tashkeel)
              // and the printed Mushaf uses generous inter-line spacing.
              height: 2.4,
              color: textColor,
            ),
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.justify,
        ),
        // Translations shown below the Arabic block when enabled.
        if (widget.translations.isNotEmpty) ...[
          const SizedBox(height: 16),
          _TranslationBlock(
            ayahs: widget.ayahs,
            translations: widget.translations,
            fontSize: widget.translationFontSize,
            colors: Theme.of(context).colorScheme,
          ),
        ],
      ],
    );
  }
}

// ─── Translation block shown below each surah section ────────────────────────

class _TranslationBlock extends StatelessWidget {
  const _TranslationBlock({
    required this.ayahs,
    required this.translations,
    required this.fontSize,
    required this.colors,
  });

  final List<Ayah> ayahs;
  final Map<int, String> translations;
  final double fontSize;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final ayah in ayahs)
          if (translations[ayah.id] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ayah.ayahNumber}.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      translations[ayah.id]!,
                      style: TextStyle(
                        fontSize: fontSize,
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

// ─── Circular ayah end marker ─────────────────────────────────────────────────
//
// Matches the King Fahad Mushaf exactly:
//   • Circular badge with dark ink border (no fill colour — transparent)
//   • Arabic-Indic numerals (١٢٣) in KFGQPC Uthmanic font
//   • Size ~34px to be clearly readable inline with 28px Arabic text
//   • Playing ayah: green fill + white numeral

class _AyahEndMarker extends StatelessWidget {
  const _AyahEndMarker({
    required this.number,
    required this.onTap,
    this.isPlaying = false,
  });

  final int number;
  final VoidCallback onTap;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Ink colour matches the body text — dark on white, white on dark
    final inkColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    const playingColor = Color(0xFF1B6B3A);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Transparent fill — matches printed Mushaf (circle outline only)
          color: isPlaying ? playingColor : Colors.transparent,
          border: Border.all(
            color: isPlaying ? playingColor : inkColor,
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          _toArabicNumerals(number),
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: kArabicFont,
            fontSize: 11,
            height: 1.0,
            color: isPlaying ? Colors.white : inkColor,
          ),
        ),
      ),
    );
  }
}

// ─── Ayah action sheet ────────────────────────────────────────────────────────

class _AyahActionSheet extends ConsumerWidget {
  const _AyahActionSheet({
    required this.ayahKey,
    required this.surahNumber,
    required this.ayahNumber,
    required this.ayahId,
    required this.textUthmani,
  });

  final String ayahKey;
  final int surahNumber;
  final int ayahNumber;
  final int ayahId;
  final String textUthmani;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    final isThisAyahPlaying = audio.surahNumber == surahNumber &&
        audio.currentAyahNumber == ayahNumber &&
        audio.isPlaying;

    final isBookmarked =
        ref.watch(bookmarkedAyahProvider(ayahId)).valueOrNull ?? false;
    final isInHifz =
        ref.watch(inHifzProvider(ayahId)).valueOrNull ?? false;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Ayah $ayahKey',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(isThisAyahPlaying
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline),
                title: Text(isThisAyahPlaying ? 'Pause' : 'Play audio'),
                onTap: () {
                  Navigator.pop(context);
                  if (isThisAyahPlaying) {
                    ref.read(audioProvider.notifier).togglePlayPause();
                  } else {
                    ref
                        .read(audioProvider.notifier)
                        .playAyah(surahNumber, ayahNumber);
                  }
                },
              ),
              ListTile(
                leading: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border),
                title:
                    Text(isBookmarked ? 'Remove bookmark' : 'Bookmark'),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(bookmarksProvider.notifier).toggle(
                        ayahId: ayahId,
                        surahNumber: surahNumber,
                        ayahNumber: ayahNumber,
                      );
                },
              ),
              ListTile(
                leading: const Icon(Icons.note_add_outlined),
                title: const Text('Add / edit note'),
                onTap: () {
                  Navigator.pop(context);
                  showNoteEditor(
                    context,
                    ayahId: ayahId,
                    surahNumber: surahNumber,
                    ayahNumber: ayahNumber,
                    verseKey: ayahKey,
                  );
                },
              ),
              ListTile(
                leading: Icon(
                    isInHifz ? Icons.psychology : Icons.psychology_outlined),
                title: Text(isInHifz ? 'Remove from Hifz' : 'Add to Hifz'),
                subtitle: isInHifz
                    ? null
                    : const Text('Schedule for spaced-repetition review'),
                onTap: () async {
                  Navigator.pop(context);
                  final repo = ref.read(quranRepositoryProvider);
                  if (isInHifz) {
                    await repo.removeFromHifz(ayahId);
                  } else {
                    await repo.addToHifz(ayahId, surahNumber, ayahNumber);
                  }
                  ref.invalidate(inHifzProvider(ayahId));
                  ref.invalidate(hifzStatsProvider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Read Tafsir'),
                subtitle:
                    const Text('Ibn Kathir · Al-Muyassar · Al-Jalalayn'),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => TafsirSheet(verseKey: ayahKey),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                  final mushafState = ref.read(mushafProvider);
                  final translation = mushafState.translations[ayahId];
                  final buffer = StringBuffer();
                  buffer.writeln('﴿ $textUthmani ﴾');
                  if (translation != null) {
                    buffer.writeln();
                    buffer.writeln(translation);
                  }
                  buffer.writeln();
                  buffer.write('— Quran $ayahKey');
                  const MethodChannel('com.quranapp.quran_app/share')
                      .invokeMethod('share', {'text': buffer.toString()});
                },
              ),
            ],
          ),
        ),
      ),
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
