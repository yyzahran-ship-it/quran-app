import 'dart:math' as math;
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../prayer_times/prayer_times_provider.dart';

class QiblaScreen extends ConsumerWidget {
  const QiblaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerState = ref.watch(prayerTimesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double? qiblaBearing;
    if (prayerState.latitude != null && prayerState.longitude != null) {
      final coords =
          Coordinates(prayerState.latitude!, prayerState.longitude!);
      qiblaBearing = Qibla(coords).direction;
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFF0A3D2E),
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
      ),
      body: Center(
        child: prayerState.isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : prayerState.latitude == null
                ? _NoLocationView(
                    onRefresh: () =>
                        ref.read(prayerTimesProvider.notifier).refresh(),
                  )
                : _CompassView(qiblaBearing: qiblaBearing!),
      ),
    );
  }
}

// ─── Compass with live heading ────────────────────────────────────────────────

class _CompassView extends StatelessWidget {
  const _CompassView({required this.qiblaBearing});

  final double qiblaBearing;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snapshot) {
        final heading = snapshot.data?.heading;
        final arrowAngle = heading != null
            ? (qiblaBearing - heading) * (math.pi / 180)
            : null;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'القبلة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
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
            const SizedBox(height: 48),
            // Compass ring + arrow
            SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Compass ring
                  _CompassRing(deviceHeading: heading),
                  // Qibla arrow (rotates with compass)
                  if (arrowAngle != null)
                    Transform.rotate(
                      angle: arrowAngle,
                      child: _KaabaArrow(),
                    )
                  else
                    _StaticArrow(bearing: qiblaBearing),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Bearing text
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    '${qiblaBearing.toStringAsFixed(1)}°',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _bearingLabel(qiblaBearing),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (heading == null) ...[
              const SizedBox(height: 16),
              Text(
                'Compass sensor not available on this device',
                style: TextStyle(
                  color: Colors.orange.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      },
    );
  }

  String _bearingLabel(double deg) {
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

// ─── Compass ring showing N/S/E/W ────────────────────────────────────────────

class _CompassRing extends StatelessWidget {
  const _CompassRing({this.deviceHeading});

  final double? deviceHeading;

  @override
  Widget build(BuildContext context) {
    final angle =
        deviceHeading != null ? -deviceHeading! * (math.pi / 180) : 0.0;

    return Transform.rotate(
      angle: angle,
      child: CustomPaint(
        size: const Size(260, 260),
        painter: _RingPainter(),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Outer ring
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, ringPaint);

    // Tick marks
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.5;
    for (int i = 0; i < 72; i++) {
      final angle = i * (math.pi * 2 / 72);
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
    const goldColor = Color(0xFFD4AF37);

    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final (label, deg) in labels) {
      final rad = (deg - 90) * math.pi / 180;
      final pos = center +
          Offset(
            math.cos(rad) * (radius - 32),
            math.sin(rad) * (radius - 32),
          );
      tp.text = TextSpan(
        text: label,
        style: TextStyle(
          color: label == 'N' ? goldColor : Colors.white.withValues(alpha: 0.8),
          fontSize: label == 'N' ? 16 : 13,
          fontWeight:
              label == 'N' ? FontWeight.bold : FontWeight.normal,
        ),
      );
      tp.layout();
      tp.paint(
        canvas,
        pos - Offset(tp.width / 2, tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => false;
}

// ─── Kaaba arrow (green gradient, points to Qibla) ───────────────────────────

class _KaabaArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(40, 80),
          painter: _ArrowPainter(),
        ),
        const SizedBox(height: 4),
        const Icon(Icons.mosque, color: Color(0xFFD4AF37), size: 26),
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

// Static bearing display when no compass available
class _StaticArrow extends StatelessWidget {
  const _StaticArrow({required this.bearing});

  final double bearing;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: (bearing - 90) * (math.pi / 180),
      child: Icon(
        Icons.navigation,
        color: const Color(0xFF0A7B83),
        size: 64,
      ),
    );
  }
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
