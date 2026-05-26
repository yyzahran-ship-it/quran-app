import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
import '../../settings/settings_screen.dart';
import 'prayer_times_provider.dart';

class PrayerTimesScreen extends ConsumerStatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  ConsumerState<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends ConsumerState<PrayerTimesScreen> {
  late Timer _ticker;

  @override
  void initState() {
    super.initState();
    // Rebuild every 30 s to keep countdown fresh
    _ticker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(prayerTimesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFF0A3D2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Salatuk',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Refresh location',
            onPressed: () => ref.read(prayerTimesProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(prayerTimesProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  _HijriDateBanner(locationDenied: state.locationDenied),
                  const SizedBox(height: 12),
                  if (state.times != null) ...[
                    _NextPrayerHero(state: state),
                    const SizedBox(height: 20),
                    _PrayerList(state: state),
                  ],
                ],
              ),
            ),
    );
  }
}

// ─── Hijri date banner ────────────────────────────────────────────────────────

class _HijriDateBanner extends StatelessWidget {
  const _HijriDateBanner({required this.locationDenied});

  final bool locationDenied;

  @override
  Widget build(BuildContext context) {
    final hijri = HijriCalendar.now();
    final now = DateTime.now();

    final gregorian =
        '${_monthName(now.month)} ${now.day}, ${now.year}';
    final hijriStr =
        '${hijri.hDay} ${hijri.getLongMonthName()} ${hijri.hYear} AH';

    return Column(
      children: [
        const SizedBox(height: 4),
        Text(
          hijriStr,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          gregorian,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
          textAlign: TextAlign.center,
        ),
        if (locationDenied) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
            ),
            child: const Text(
              'Using Mecca — enable location for accurate times',
              style: TextStyle(color: Colors.orange, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  String _monthName(int month) {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[month];
  }
}

// ─── Next prayer hero card ────────────────────────────────────────────────────

class _NextPrayerHero extends StatelessWidget {
  const _NextPrayerHero({required this.state});

  final PrayerTimesState state;

  @override
  Widget build(BuildContext context) {
    final next = state.nextPrayer;
    final remaining = state.timeUntilNext;
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A7B83), Color(0xFF1B6B3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A7B83).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Next Prayer',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            prayerNameAr(next),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontFamily: 'UthmanicHafs',
            ),
            textDirection: TextDirection.rtl,
          ),
          Text(
            prayerName(next),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              hours > 0
                  ? '${hours}h ${minutes}m remaining'
                  : '${minutes}m remaining',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatTime(state.nextPrayerTime!),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Full prayer list ─────────────────────────────────────────────────────────

class _PrayerList extends StatelessWidget {
  const _PrayerList({required this.state});

  final PrayerTimesState state;

  @override
  Widget build(BuildContext context) {
    final times = state.times!;
    final current = state.currentPrayer;

    final prayers = [
      (Prayer.fajr, times.fajr),
      (Prayer.sunrise, times.sunrise),
      (Prayer.dhuhr, times.dhuhr),
      (Prayer.asr, times.asr),
      (Prayer.maghrib, times.maghrib),
      (Prayer.isha, times.isha),
    ];

    return Column(
      children: prayers.map((entry) {
        final (prayer, time) = entry;
        final isCurrent = prayer == current;
        final isPassed = time.toLocal().isBefore(DateTime.now()) && !isCurrent;

        return _PrayerRow(
          prayer: prayer,
          time: time,
          isCurrent: isCurrent,
          isPassed: isPassed,
        );
      }).toList(),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.prayer,
    required this.time,
    required this.isCurrent,
    required this.isPassed,
  });

  final Prayer prayer;
  final DateTime time;
  final bool isCurrent;
  final bool isPassed;

  @override
  Widget build(BuildContext context) {
    const goldColor = Color(0xFFD4AF37);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFF0A7B83).withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: isCurrent
            ? Border.all(color: const Color(0xFF0A7B83), width: 1.5)
            : Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Arabic name
          SizedBox(
            width: 56,
            child: Text(
              prayerNameAr(prayer),
              style: TextStyle(
                color: isCurrent
                    ? goldColor
                    : isPassed
                        ? Colors.white38
                        : Colors.white70,
                fontFamily: 'UthmanicHafs',
                fontSize: 16,
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          // English name
          Expanded(
            child: Text(
              prayerName(prayer),
              style: TextStyle(
                color: isCurrent
                    ? Colors.white
                    : isPassed
                        ? Colors.white38
                        : Colors.white70,
                fontSize: 15,
                fontWeight:
                    isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          // Time
          Text(
            _formatTime(time),
            style: TextStyle(
              color: isCurrent
                  ? goldColor
                  : isPassed
                      ? Colors.white30
                      : Colors.white60,
              fontSize: 15,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 8),
          // Status dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrent
                  ? goldColor
                  : isPassed
                      ? Colors.white15
                      : Colors.white24,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _formatTime(DateTime dt) {
  final local = dt.toLocal();
  final hour = local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$displayHour:$minute $period';
}
