import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dhikr_provider.dart';

class TasbihScreen extends ConsumerWidget {
  const TasbihScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(tasbihProvider);
    final notifier = ref.read(tasbihProvider.notifier);

    // Milestone labels
    final milestone = _milestone(count);

    return Scaffold(
      backgroundColor: const Color(0xFF0A3D2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Tasbih Counter',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Reset counter',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF1B2A1B),
                  title: const Text('Reset Counter',
                      style: TextStyle(color: Colors.white)),
                  content: const Text('Reset to zero?',
                      style: TextStyle(color: Colors.white60)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.white54)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        notifier.reset();
                        HapticFeedback.mediumImpact();
                      },
                      child: const Text('Reset',
                          style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          notifier.increment();
          HapticFeedback.lightImpact();
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Arabic dhikr suggestion
              Text(
                _arabicFor(count),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontFamily: 'UthmanicHafs',
                  height: 1.8,
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _translitFor(count),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 56),

              // Count display
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0A7B83), Color(0xFF1B6B3A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A7B83).withValues(alpha: 0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Tap anywhere',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Milestone badge
              if (milestone != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    milestone,
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                Text(
                  _nextMilestoneText(count),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _arabicFor(int count) {
    if (count < 33) return 'سُبْحَانَ اللَّهِ';
    if (count < 66) return 'الْحَمْدُ لِلَّهِ';
    if (count < 99) return 'اللَّهُ أَكْبَرُ';
    return 'لَا إِلَهَ إِلَّا اللَّهُ';
  }

  String _translitFor(int count) {
    if (count < 33) return 'Subhanallah';
    if (count < 66) return 'Alhamdulillah';
    if (count < 99) return 'Allahu Akbar';
    return 'La ilaha illa Allah';
  }

  String? _milestone(int count) {
    if (count == 33) return '33 — Subhanallah complete ✓';
    if (count == 66) return '66 — Alhamdulillah complete ✓';
    if (count == 99) return '99 — Allahu Akbar complete ✓';
    if (count == 100) return '100 — Complete set! ✓';
    if (count > 0 && count % 100 == 0) return '$count — Masha\'Allah!';
    return null;
  }

  String _nextMilestoneText(int count) {
    if (count < 33) return '${33 - count} until Subhanallah complete';
    if (count < 66) return '${66 - count} until Alhamdulillah complete';
    if (count < 99) return '${99 - count} until Allahu Akbar complete';
    if (count < 100) return '1 more to complete the set';
    return '${100 - (count % 100)} until next 100';
  }
}
