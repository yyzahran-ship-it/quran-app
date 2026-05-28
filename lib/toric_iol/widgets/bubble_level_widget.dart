import 'package:flutter/material.dart';

/// Visual spirit-level widget driven by the phone's accelerometer tilt reading.
///
/// The bubble moves left/right inside a circular container to show roll tilt.
/// It turns green when the phone is level within tolerance.
class BubbleLevelWidget extends StatelessWidget {
  final double tiltDegrees; // phone roll in degrees (+ = clockwise)
  final bool isLevel;

  static const _size = 72.0;
  static const _bubbleD = 18.0;
  // Max pixel offset of bubble centre from container centre
  static const _maxOff = (_size / 2) - (_bubbleD / 2) - 4;

  const BubbleLevelWidget({
    super.key,
    required this.tiltDegrees,
    required this.isLevel,
  });

  Color get _color {
    final a = tiltDegrees.abs();
    if (a < 2) return const Color(0xFF66BB6A);
    if (a < 5) return const Color(0xFFFFB300);
    return const Color(0xFFEF5350);
  }

  @override
  Widget build(BuildContext context) {
    final offset = (tiltDegrees / 10.0 * _maxOff).clamp(-_maxOff, _maxOff);
    final c = _color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _size,
          height: _size,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Container ring
              Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: c.withOpacity(0.7), width: 1.5),
                ),
              ),
              // Guide rings + crosshair
              CustomPaint(
                size: const Size(_size, _size),
                painter: _GuidePainter(),
              ),
              // Bubble — AnimatedPositioned for smooth movement
              AnimatedPositioned(
                duration: const Duration(milliseconds: 80),
                curve: Curves.easeOut,
                left: (_size / 2) + offset - (_bubbleD / 2),
                top: (_size / 2) - (_bubbleD / 2),
                child: Container(
                  width: _bubbleD,
                  height: _bubbleD,
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.85),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          isLevel ? 'LEVEL' : '${tiltDegrees.abs().toStringAsFixed(1)}°',
          style: TextStyle(
            color: c,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

class _GuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final p = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawCircle(Offset(cx, cy), size.width * 0.38, p);
    canvas.drawCircle(Offset(cx, cy), size.width * 0.18, p);
    canvas.drawLine(Offset(6, cy), Offset(size.width - 6, cy), p);
    canvas.drawLine(Offset(cx, 6), Offset(cx, size.height - 6), p);
  }

  @override
  bool shouldRepaint(_GuidePainter _) => false;
}
