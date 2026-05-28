import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Draws the toric IOL axis overlay on top of the camera preview.
///
/// Coordinate convention (TABO / ophthalmology standard):
///   0°  = 3 o'clock (right)   — counterclockwise to
///  90°  = 12 o'clock (top)
/// 180°  = 9 o'clock (left)
///
/// The overlay is rotated by −tiltDegrees so it stays referenced to true
/// horizontal even when the phone is slightly tilted.
class EyeOverlayPainter extends CustomPainter {
  final double targetAxis; // TABO meridian 0–180°
  final double tiltDegrees; // current phone roll (+ = clockwise)
  final bool isLevel;

  const EyeOverlayPainter({
    required this.targetAxis,
    required this.tiltDegrees,
    required this.isLevel,
  });

  // ── Geometry helpers ──────────────────────────────────────────────────────

  /// Screen point for a TABO meridian angle at radius r from (cx, cy).
  Offset _pt(double cx, double cy, double r, double taboDeg) {
    final rad = taboDeg * math.pi / 180;
    return Offset(cx + r * math.cos(rad), cy - r * math.sin(rad));
  }

  // ── Paint helpers ─────────────────────────────────────────────────────────

  Paint _strokePaint(Color color, double width) =>
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..isAntiAlias = true;

  // ── Main paint ────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Outer guide circle = 42 % of width; inner (pupil) = 15 %
    final outerR = size.width * 0.42;
    final innerR = size.width * 0.15;

    // Rotate the whole overlay to compensate for phone tilt so that 0° always
    // points to the patient's true right.
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-tiltDegrees * math.pi / 180);
    canvas.translate(-cx, -cy);

    _drawOuterCircle(canvas, cx, cy, outerR);
    _drawInnerCircle(canvas, cx, cy, innerR);
    _drawDegreeMarks(canvas, cx, cy, outerR);
    _drawReferenceLines(canvas, cx, cy, outerR * 1.05);
    _drawTargetAxis(canvas, cx, cy, outerR);
    _drawCrosshair(canvas, cx, cy);

    canvas.restore();

    // Level-status ring around the outer circle (not rotated — visual feedback)
    _drawLevelRing(canvas, cx, cy, outerR);
  }

  // ── Layer drawing methods ─────────────────────────────────────────────────

  void _drawOuterCircle(Canvas canvas, double cx, double cy, double r) {
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      _strokePaint(Colors.white.withOpacity(0.55), 1.2),
    );
  }

  void _drawInnerCircle(Canvas canvas, double cx, double cy, double r) {
    // Dashed inner circle (pupil guide) — drawn as 36 small arcs
    const segments = 36;
    const gapFraction = 0.35;
    final paint = _strokePaint(Colors.white.withOpacity(0.25), 1.0);
    final segAngle = (2 * math.pi) / segments;
    final arcAngle = segAngle * (1 - gapFraction);
    for (var i = 0; i < segments; i++) {
      final start = i * segAngle - math.pi / 2;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start,
        arcAngle,
        false,
        paint,
      );
    }
  }

  void _drawDegreeMarks(Canvas canvas, double cx, double cy, double r) {
    final tickPaint = _strokePaint(Colors.white.withOpacity(0.6), 1.0);
    final majorPaint = _strokePaint(Colors.white.withOpacity(0.85), 1.5);

    // Draw marks from 0° to 350° (every 10°) using TABO convention.
    // Labels only for the top half (0–180°) to avoid clutter.
    for (var deg = 0; deg < 360; deg += 10) {
      final isMajor = deg % 30 == 0;
      final tickLen = isMajor ? r * 0.10 : r * 0.05;
      final outer = _pt(cx, cy, r, deg.toDouble());
      final inner = _pt(cx, cy, r - tickLen, deg.toDouble());

      canvas.drawLine(outer, inner, isMajor ? majorPaint : tickPaint);

      if (isMajor) {
        // Label: convert to TABO display value (0–180)
        final labelDeg = deg <= 180 ? deg : 360 - deg;
        _drawLabel(canvas, cx, cy, r + 18, deg.toDouble(), '$labelDeg°');
      }
    }
  }

  void _drawLabel(
    Canvas canvas,
    double cx,
    double cy,
    double r,
    double taboDeg,
    String text,
  ) {
    final pt = _pt(cx, cy, r, taboDeg);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pt - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawReferenceLines(Canvas canvas, double cx, double cy, double r) {
    final paint = _strokePaint(const Color(0xFF4FC3F7).withOpacity(0.45), 1.0);
    // Horizontal (0° ↔ 180°)
    canvas.drawLine(_pt(cx, cy, r, 0), _pt(cx, cy, r, 180), paint);
    // Vertical (90° ↔ 270°)
    canvas.drawLine(_pt(cx, cy, r, 90), _pt(cx, cy, r, 270), paint);
  }

  void _drawTargetAxis(Canvas canvas, double cx, double cy, double r) {
    // Bold gold line from axis° to axis+180° through centre
    final paint = _strokePaint(const Color(0xFFFFD600), 2.5);
    final p1 = _pt(cx, cy, r * 0.95, targetAxis);
    final p2 = _pt(cx, cy, r * 0.95, targetAxis + 180);
    canvas.drawLine(p1, p2, paint);

    _drawArrowHead(canvas, p1, targetAxis, paint);
    _drawArrowHead(canvas, p2, targetAxis + 180, paint);

    // Badge at the primary end of the axis (always the targetAxis° end)
    final labelPt = _pt(cx, cy, r + 28, targetAxis);
    _drawAxisBadge(canvas, labelPt, '${targetAxis.toStringAsFixed(0)}°');
  }

  /// Draws a two-arm arrowhead at [tip] pointing outward at TABO [taboDeg].
  /// The arms go backward from [tip] at ±22° spread.
  void _drawArrowHead(Canvas canvas, Offset tip, double taboDeg, Paint paint) {
    const len = 12.0;
    const spreadDeg = 22.0;
    for (final armAngle in [taboDeg + 180 - spreadDeg, taboDeg + 180 + spreadDeg]) {
      final rad = armAngle * math.pi / 180;
      final end = tip + Offset(len * math.cos(rad), -len * math.sin(rad));
      canvas.drawLine(tip, end, paint);
    }
  }

  void _drawAxisBadge(Canvas canvas, Offset center, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFFFFD600),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const pad = 6.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: tp.width + pad * 2,
        height: tp.height + pad,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.black54);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawCrosshair(Canvas canvas, double cx, double cy) {
    final paint = _strokePaint(Colors.white.withOpacity(0.7), 1.2);
    const len = 14.0;
    const gap = 5.0;
    // Horizontal
    canvas.drawLine(Offset(cx - len - gap, cy), Offset(cx - gap, cy), paint);
    canvas.drawLine(Offset(cx + gap, cy), Offset(cx + len + gap, cy), paint);
    // Vertical
    canvas.drawLine(Offset(cx, cy - len - gap), Offset(cx, cy - gap), paint);
    canvas.drawLine(Offset(cx, cy + gap), Offset(cx, cy + len + gap), paint);
    // Centre dot
    canvas.drawCircle(Offset(cx, cy), 2, Paint()..color = Colors.white70);
  }

  void _drawLevelRing(Canvas canvas, double cx, double cy, double r) {
    // Thin coloured arc that indicates level quality — not rotated with overlay
    final tiltAbs = tiltDegrees.abs();
    final Color ringColor;
    if (tiltAbs < 2) {
      ringColor = const Color(0xFF66BB6A); // green
    } else if (tiltAbs < 5) {
      ringColor = const Color(0xFFFFB300); // amber
    } else {
      ringColor = const Color(0xFFEF5350); // red
    }

    // Full ring, semi-transparent
    canvas.drawCircle(
      Offset(cx, cy),
      r + 3,
      _strokePaint(ringColor.withOpacity(0.35), 2.5),
    );
  }

  @override
  bool shouldRepaint(EyeOverlayPainter old) =>
      old.targetAxis != targetAxis ||
      old.tiltDegrees != tiltDegrees ||
      old.isLevel != isLevel;
}
