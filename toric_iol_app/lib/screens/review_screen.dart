import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReviewScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final double targetAxis;
  final String patientRef;
  final String eye;
  final double tiltAtCapture;

  const ReviewScreen({
    super.key,
    required this.imageBytes,
    required this.targetAxis,
    required this.patientRef,
    required this.eye,
    required this.tiltAtCapture,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _isSaving = false;

  Future<void> _shareImage() async {
    setState(() => _isSaving = true);
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/toric_iol_$stamp.png');
      await file.writeAsBytes(widget.imageBytes);
      final xFile = XFile(file.path, mimeType: 'image/png');
      await Share.shareXFiles(
        [xFile],
        subject:
            'Toric IOL Marking — ${widget.eye} — ${widget.targetAxis.toStringAsFixed(0)}°',
        text: _shareText,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String get _shareText {
    final buf = StringBuffer('Toric IOL Pre-operative Marking\n');
    buf.write('Eye: ${widget.eye}\n');
    buf.write('Target axis: ${widget.targetAxis.toStringAsFixed(1)}°\n');
    if (widget.patientRef.isNotEmpty) buf.write('Patient: ${widget.patientRef}\n');
    buf.write('Tilt at capture: ${widget.tiltAtCapture.abs().toStringAsFixed(1)}°\n');
    buf.write('Captured: ${DateTime.now().toLocal()}');
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final tiltAbs = widget.tiltAtCapture.abs();
    final tiltOk = tiltAbs < 2.0;
    final tiltColor =
        tiltAbs < 2 ? const Color(0xFF66BB6A) : const Color(0xFFFFB300);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white70,
        title: const Text('Review Capture',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Image preview ────────────────────────────────────────────────
          Expanded(
            child: InteractiveViewer(
              child: Image.memory(
                widget.imageBytes,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // ── Metadata strip ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: const Color(0xFF111111),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MetaChip(
                      label: 'Eye',
                      value: widget.eye,
                      color: Colors.white70,
                    ),
                    _MetaChip(
                      label: 'Target axis',
                      value: '${widget.targetAxis.toStringAsFixed(0)}°',
                      color: const Color(0xFFFFD600),
                    ),
                    _MetaChip(
                      label: 'Tilt',
                      value: tiltOk
                          ? '${tiltAbs.toStringAsFixed(1)}° ✓'
                          : '${tiltAbs.toStringAsFixed(1)}° ⚠',
                      color: tiltColor,
                    ),
                  ],
                ),
                if (widget.patientRef.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Patient: ${widget.patientRef}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
                if (!tiltOk)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFFFB300), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Phone was tilted ${tiltAbs.toStringAsFixed(1)}° — consider retaking.',
                          style: const TextStyle(
                              color: Color(0xFFFFB300), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Action buttons ────────────────────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  // Retake
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retake'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Share / Save
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _shareImage,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.black, strokeWidth: 2),
                            )
                          : const Icon(Icons.share, size: 18),
                      label: Text(_isSaving ? 'Saving…' : 'Save / Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BCD4),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetaChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
              color: Colors.white30, fontSize: 9, letterSpacing: 0.8),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
