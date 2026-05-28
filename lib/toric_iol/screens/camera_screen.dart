import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../widgets/bubble_level_widget.dart';
import '../widgets/eye_overlay_painter.dart';
import 'review_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final double targetAxis;
  final String patientRef;
  final String eye;

  const CameraScreen({
    super.key,
    required this.cameras,
    required this.targetAxis,
    required this.patientRef,
    required this.eye,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  // ── Camera ────────────────────────────────────────────────────────────────
  CameraController? _controller;
  bool _cameraReady = false;
  bool _flashOn = false;
  bool _isCapturing = false;

  // ── Sensors ───────────────────────────────────────────────────────────────
  double _tiltDegrees = 0;
  bool _isLevel = false;
  static const _levelThreshold = 2.0; // degrees
  StreamSubscription<AccelerometerEvent>? _accelSub;

  // ── Capture ───────────────────────────────────────────────────────────────
  final _captureKey = GlobalKey();

  // ── Zoom ──────────────────────────────────────────────────────────────────
  double _zoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 8.0;
  double _baseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _initSensors();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) return;
    final cam = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );
    final ctrl = CameraController(
      cam,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await ctrl.initialize();
      _minZoom = await ctrl.getMinZoomLevel();
      _maxZoom = await ctrl.getMaxZoomLevel();
      // Mild default zoom for close-up eye shots
      _zoom = (_minZoom * 1.5).clamp(_minZoom, _maxZoom);
      await ctrl.setZoomLevel(_zoom);
      if (mounted) setState(() { _controller = ctrl; _cameraReady = true; });
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  void _initSensors() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen((AccelerometerEvent ev) {
      if (!mounted) return;
      // Roll angle: phone tilted left/right when held portrait upright.
      // With phone screen facing the surgeon, camera facing the patient:
      //   ev.x ≈ 0 when level; positive when tilted clockwise.
      // tilt = atan2(x, -y) gives the roll in radians (y points up the phone).
      final tilt = math.atan2(ev.x, -ev.y) * 180 / math.pi;
      setState(() {
        _tiltDegrees = tilt;
        _isLevel = tilt.abs() < _levelThreshold;
      });
    });
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accelSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_cameraReady) return;
    if (state == AppLifecycleState.inactive) {
      _controller!.dispose();
      setState(() => _cameraReady = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    final next = !_flashOn;
    await _controller!.setFlashMode(next ? FlashMode.torch : FlashMode.off);
    if (mounted) setState(() => _flashOn = next);
  }

  Future<void> _capture() async {
    if (_isCapturing || !_cameraReady) return;
    setState(() => _isCapturing = true);
    try {
      final boundary =
          _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Render the widget (camera + overlay) to an image at 2× pixel ratio
      final uiImage = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewScreen(
              imageBytes: bytes,
              targetAxis: widget.targetAxis,
              patientRef: widget.patientRef,
              eye: widget.eye,
              tiltAtCapture: _tiltDegrees,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _onScaleStart(ScaleStartDetails d) => _baseZoom = _zoom;

  Future<void> _onScaleUpdate(ScaleUpdateDetails d) async {
    if (_controller == null) return;
    final z = (_baseZoom * d.scale).clamp(_minZoom, _maxZoom);
    await _controller!.setZoomLevel(z);
    setState(() => _zoom = z);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera + overlay (captured together) ────────────────────────
          RepaintBoundary(
            key: _captureKey,
            child: GestureDetector(
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_cameraReady)
                    CameraPreview(_controller!)
                  else
                    const _LoadingOverlay(),

                  if (_cameraReady)
                    CustomPaint(
                      painter: EyeOverlayPainter(
                        targetAxis: widget.targetAxis,
                        tiltDegrees: _tiltDegrees,
                        isLevel: _isLevel,
                      ),
                    ),

                  // Timestamp + labels burned into every capture
                  if (_cameraReady) _CaptureLabels(widget: widget),
                ],
              ),
            ),
          ),

          // ── HUD elements (NOT captured) ─────────────────────────────────
          if (_cameraReady) ...[
            // Level status bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 0,
              right: 0,
              child: Center(child: _LevelChip(tiltDegrees: _tiltDegrees, isLevel: _isLevel)),
            ),

            // Axis badge
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: _AxisBadge(axis: widget.targetAxis, eye: widget.eye),
            ),

            // Bubble level
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              right: 16,
              child: BubbleLevelWidget(
                tiltDegrees: _tiltDegrees,
                isLevel: _isLevel,
              ),
            ),

            // Zoom indicator
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 16,
              child: _ZoomBadge(zoom: _zoom),
            ),

            // Tilt hint
            if (!_isLevel)
              Positioned(
                bottom: 155,
                left: 0,
                right: 0,
                child: Center(child: _TiltHint(tiltDegrees: _tiltDegrees)),
              ),
          ],

          // ── Bottom controls ─────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomBar(
              flashOn: _flashOn,
              isLevel: _isLevel,
              isCapturing: _isCapturing,
              onFlash: _toggleFlash,
              onCapture: _capture,
              onBack: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFF00BCD4), strokeWidth: 2),
          SizedBox(height: 16),
          Text('Starting camera…', style: TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }
}

class _CaptureLabels extends StatelessWidget {
  final CameraScreen widget;

  const _CaptureLabels({required this.widget});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final stamp =
        '${now.year}-${_p(now.month)}-${_p(now.day)}  ${_p(now.hour)}:${_p(now.minute)}';
    final patientLine =
        widget.patientRef.isNotEmpty ? '${widget.patientRef}  •  ' : '';

    return Positioned(
      bottom: 8,
      left: 12,
      right: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${patientLine}${widget.eye}',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          Text(
            'Axis: ${widget.targetAxis.toStringAsFixed(0)}°  •  $stamp',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}

class _LevelChip extends StatelessWidget {
  final double tiltDegrees;
  final bool isLevel;

  const _LevelChip({required this.tiltDegrees, required this.isLevel});

  @override
  Widget build(BuildContext context) {
    final tiltAbs = tiltDegrees.abs();
    final color = tiltAbs < 2
        ? const Color(0xFF66BB6A)
        : tiltAbs < 5
            ? const Color(0xFFFFB300)
            : const Color(0xFFEF5350);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            isLevel
                ? 'LEVEL'
                : '${tiltDegrees > 0 ? "↻" : "↺"} ${tiltAbs.toStringAsFixed(1)}°',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _AxisBadge extends StatelessWidget {
  final double axis;
  final String eye;

  const _AxisBadge({required this.axis, required this.eye});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD600).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${axis.toStringAsFixed(0)}°',
            style: const TextStyle(
                color: Color(0xFFFFD600), fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text(
            eye,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ZoomBadge extends StatelessWidget {
  final double zoom;

  const _ZoomBadge({required this.zoom});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${zoom.toStringAsFixed(1)}×',
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      ),
    );
  }
}

class _TiltHint extends StatelessWidget {
  final double tiltDegrees;

  const _TiltHint({required this.tiltDegrees});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        tiltDegrees > 0
            ? 'Tilt left ${tiltDegrees.abs().toStringAsFixed(1)}°'
            : 'Tilt right ${tiltDegrees.abs().toStringAsFixed(1)}°',
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool flashOn;
  final bool isLevel;
  final bool isCapturing;
  final VoidCallback onFlash;
  final VoidCallback onCapture;
  final VoidCallback onBack;

  const _BottomBar({
    required this.flashOn,
    required this.isLevel,
    required this.isCapturing,
    required this.onFlash,
    required this.onCapture,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundButton(
              icon: flashOn ? Icons.flash_on : Icons.flash_off,
              color: flashOn ? const Color(0xFFFFD600) : Colors.white54,
              onTap: onFlash,
              label: flashOn ? 'On' : 'Off',
            ),
            // Capture shutter
            GestureDetector(
              onTap: (isLevel && !isCapturing) ? onCapture : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCapturing
                      ? Colors.grey
                      : isLevel
                          ? const Color(0xFF00BCD4)
                          : Colors.white24,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: isLevel
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00BCD4).withOpacity(0.55),
                            blurRadius: 18,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                child: isCapturing
                    ? const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        ),
                      )
                    : const Icon(Icons.camera, color: Colors.white, size: 34),
              ),
            ),
            _RoundButton(
              icon: Icons.arrow_back,
              color: Colors.white54,
              onTap: onBack,
              label: 'Back',
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String label;

  const _RoundButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}
