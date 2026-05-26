import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dhikr_data.dart';
import 'dhikr_provider.dart';

class DhikrDetailScreen extends ConsumerStatefulWidget {
  const DhikrDetailScreen({super.key, required this.collection});

  final DhikrCollection collection;

  @override
  ConsumerState<DhikrDetailScreen> createState() => _DhikrDetailScreenState();
}

class _DhikrDetailScreenState extends ConsumerState<DhikrDetailScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DhikrItem get _currentItem =>
      widget.collection.items[_currentPage];

  void _next() {
    if (_currentPage < widget.collection.items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _showCompleteDialog();
    }
  }

  void _previous() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showCompleteDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B2A1B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 0.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle,
                color: Color(0xFFD4AF37), size: 52),
            const SizedBox(height: 12),
            const Text(
              'Adhkar Complete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have completed the ${widget.collection.titleEn}.',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done',
                style: TextStyle(color: Color(0xFFD4AF37))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(dhikrProgressProvider);
    final notifier = ref.read(dhikrProgressProvider.notifier);
    final items = widget.collection.items;
    final item = _currentItem;
    final currentCount = progress[item.id] ?? 0;
    final isItemDone = notifier.isComplete(item.id, item.count);

    return Scaffold(
      backgroundColor: const Color(0xFF0A3D2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Column(
          children: [
            Text(
              widget.collection.titleEn,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              '${_currentPage + 1} of ${items.length}',
              style:
                  const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Reset this dhikr',
            onPressed: () {
              notifier.reset(item.id);
              HapticFeedback.lightImpact();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top progress dots
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                items.length,
                (i) {
                  final done = notifier.isComplete(
                    items[i].id, items[i].count,
                  );
                  final isCurrent = i == _currentPage;
                  return Container(
                    width: isCurrent ? 20 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: done
                          ? const Color(0xFFD4AF37)
                          : isCurrent
                              ? Colors.white
                              : Colors.white24,
                    ),
                  );
                },
              ),
            ),
          ),

          // Page content
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: items.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (_, i) =>
                  _DhikrPage(item: items[i]),
            ),
          ),

          // Counter + navigation
          _BottomControls(
            currentCount: currentCount,
            totalCount: item.count,
            isDone: isItemDone,
            onTap: () {
              if (!isItemDone) {
                notifier.increment(item.id);
                HapticFeedback.lightImpact();
                if (notifier.isComplete(item.id, item.count)) {
                  HapticFeedback.mediumImpact();
                  Future.delayed(
                    const Duration(milliseconds: 200),
                    _next,
                  );
                }
              }
            },
            onPrevious: _currentPage > 0 ? _previous : null,
            onNext: _next,
          ),
        ],
      ),
    );
  }
}

// ─── Individual dhikr page ────────────────────────────────────────────────────

class _DhikrPage extends StatelessWidget {
  const _DhikrPage({required this.item});

  final DhikrItem item;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Arabic text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Text(
              item.arabic,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontFamily: 'UthmanicHafs',
                height: 2.0,
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          // Transliteration
          Text(
            item.transliteration,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Translation
          Text(
            item.translation,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          if (item.source != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.source!,
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 11,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Counter + navigation controls ───────────────────────────────────────────

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.currentCount,
    required this.totalCount,
    required this.isDone,
    required this.onTap,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentCount;
  final int totalCount;
  final bool isDone;
  final VoidCallback onTap;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Big counter tap area
            GestureDetector(
              onTap: onTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: isDone
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF1B6B3A),
                            Color(0xFF0A7B83),
                          ],
                        )
                      : const LinearGradient(
                          colors: [
                            Color(0xFF0A7B83),
                            Color(0xFF1B6B3A),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A7B83).withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: isDone
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle,
                              color: Color(0xFFD4AF37), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Complete — Tap to continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Text(
                            '$currentCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'of $totalCount',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            // Previous / Next row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPrevious,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onNext,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next'),
                    iconAlignment: IconAlignment.end,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
