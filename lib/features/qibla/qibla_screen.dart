import 'dart:math' as math;
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../prayer_times/prayer_times_provider.dart';

class QiblaScreen extends ConsumerWidget {
  const QiblaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerState = ref.watch(prayerTimesProvider);

    double? qiblaBearing;
    if (prayerState.latitude != null && prayerState.longitude != null) {
      final coords =
          Coordinates(prayerState.latitude!, prayerState.longitude!);
      qiblaBearing = Qibla(coords).direction;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A3D2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Qibla',
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
            onPressed: () =>
                ref.read(prayerTimesProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Center(
        child: prayerState.isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : prayerState.latitude == null
                ? _NoLocationView(
                    onRefresh: () =>
                        ref.read(prayerTimesProvider.notifier).refresh(),
                  )
                : _QiblaView(bearing: qiblaBearing!),
      ),
    );
  }
}

// ─── Qibla direction display ──────────────────────────────────────────────────

class _QiblaView extends StatelessWidget {
  const _QiblaView({required this.bearing});

  final double bearing;

  @override
  Widget build(BuildContext context) {
    final direction = _compassLabel(bearing);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            // Arabic label
            const Text(
              'القبلة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontFamily: 'UthmanicHafs',
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 4),
            Text(
              'Direction to the Kaaba, Mecca',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 40),

            // Compass rose with Qibla arrow
            SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Static compass ring
                  CustomPaint(
                    size: const Size(260, 260),
                    painter: _CompassRosePainter(),
                  ),
                  // Qibla arrow pointing at the bearing
                  Transform.rotate(
                    angle: (bearing - 90) * math.pi / 180,
                    child: const _QiblaArrow(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Bearing card
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  Text(
                    '${bearing.toStringAsFixed(1)}°',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    direction,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Instruction
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFFD4AF37), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Face ${bearing.toStringAsFixed(0)}° clockwise from North. '
                      'Use your phone\'s compass app to find North, then turn to face the Qibla.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _compassLabel(double deg) {
    if (deg < 22.5 || deg >= 337.5) return 'from North';
    if (deg < 67.5) return 'North-East';
    if (deg < 112.5) return 'from East';
    if (deg < 157.5) return 'South-East';
    if (deg < 202.5) return 'from South';
    if (deg < 247.5) return 'South-West';
    if (deg < 292.5) return 'from West';
    return 'North-West';
  }
}

// ─── Compass rose (static) ────────────────────────────────────────────────────

class _CompassRosePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, ringPaint);

    // Tick marks
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.5;
    for (int i = 0; i < 72; i++) {
      final angle = i * (math.pi * 2 / 72) - math.pi / 2;
      final isCardinal = i % 18 == 0;
      final isMajor = i % 9 == 0;
      final inner = radius - (isCardinal ? 20 : isMajor ? 12 : 6);
      canvas.drawLine(
        center + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        center + Offset(math.cos(angle) * radius, math.sin(angle) * radius),
        tickPaint,
      );
    }

    // Cardinal labels
    const labels = [('N', 0.0), ('E', 90.0), ('S', 180.0), ('W', 270.0)];
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final (label, deg) in labels) {
      final rad = (deg - 90) * math.pi / 180;
      final pos = center +
          Offset(
            math.cos(rad) * (radius - 28),
            math.sin(rad) * (radius - 28),
          );
      tp.text = TextSpan(
        text: label,
        style: TextStyle(
          color: label == 'N'
              ? const Color(0xFFD4AF37)
              : Colors.white.withValues(alpha: 0.8),
          fontSize: label == 'N' ? 16 : 13,
          fontWeight:
              label == 'N' ? FontWeight.bold : FontWeight.normal,
        ),
      );
      tp.layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_CompassRosePainter old) => false;
}

// ─── Qibla arrow ─────────────────────────────────────────────────────────────

class _QiblaArrow extends StatelessWidget {
  const _QiblaArrow();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(36, 72),
          painter: _ArrowPainter(),
        ),
        const SizedBox(height: 2),
        const Icon(Icons.mosque, color: Color(0xFFD4AF37), size: 22),
      ],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0A7B83), Color(0xFF1B6B3A)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height * 0.5)
      ..lineTo(size.width * 0.6, size.height * 0.4)
      ..lineTo(size.width * 0.6, size.height)
      ..lineTo(size.width * 0.4, size.height)
      ..lineTo(size.width * 0.4, size.height * 0.4)
      ..lineTo(0, size.height * 0.5)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => false;
}

// ─── No location view ─────────────────────────────────────────────────────────

class _NoLocationView extends StatelessWidget {
  const _NoLocationView({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.location_off, color: Colors.white38, size: 64),
        const SizedBox(height: 16),
        const Text(
          'Location required for Qibla direction',
          style: TextStyle(color: Colors.white60, fontSize: 15),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.my_location),
          label: const Text('Enable Location'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0A7B83),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
