import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dhikr_data.dart';
import 'dhikr_detail_screen.dart';
import 'dhikr_provider.dart';
import 'tasbih_screen.dart';

class DhikrScreen extends ConsumerWidget {
  const DhikrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFF0A3D2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Dhikr & Athkar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Arabic title
          const Text(
            'الأذكار',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 20,
              fontFamily: 'UthmanicHafs',
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Collections grid
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.1,
            children: dhikrCollections
                .map((col) => _CollectionCard(collection: col))
                .toList(),
          ),

          const SizedBox(height: 20),

          // Tasbih counter
          _TasbihCard(),
        ],
      ),
    );
  }
}

// ─── Collection card ──────────────────────────────────────────────────────────

class _CollectionCard extends ConsumerWidget {
  const _CollectionCard({required this.collection});

  final DhikrCollection collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dhikrProgressProvider);
    final completed =
        ref.read(dhikrProgressProvider.notifier).completedInCategory(collection.category);
    final total = collection.items.length;
    final isDone = completed == total;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DhikrDetailScreen(collection: collection),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDone
                ? [const Color(0xFF1B6B3A), const Color(0xFF0A7B83)]
                : [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.04),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone
                ? const Color(0xFFD4AF37).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CategoryIcon(icon: collection.icon, isDone: isDone),
                const Spacer(),
                if (isDone)
                  const Icon(Icons.check_circle,
                      color: Color(0xFFD4AF37), size: 18),
              ],
            ),
            const Spacer(),
            Text(
              collection.titleAr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontFamily: 'UthmanicHafs',
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 2),
            Text(
              collection.titleEn,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: total > 0 ? completed / total : 0,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFD4AF37),
                ),
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$completed / $total done',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.icon, required this.isDone});

  final IconCategory icon;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    IconData data;
    switch (icon) {
      case IconCategory.sun:
        data = Icons.wb_sunny_outlined;
      case IconCategory.moon:
        data = Icons.nights_stay_outlined;
      case IconCategory.prayer:
        data = Icons.mosque_outlined;
      case IconCategory.heart:
        data = Icons.favorite_border;
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone
            ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.1),
      ),
      child: Icon(
        data,
        color: isDone ? const Color(0xFFD4AF37) : Colors.white60,
        size: 18,
      ),
    );
  }
}

// ─── Tasbih card (links to TasbihScreen) ─────────────────────────────────────

class _TasbihCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(tasbihProvider);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TasbihScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A7B83), Color(0xFF0A3D2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.touch_app_outlined,
                  color: Color(0xFFD4AF37), size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tasbih Counter',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'المسبحة الرقمية',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontFamily: 'UthmanicHafs',
                      fontSize: 13,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white38),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
