import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _axisController = TextEditingController(text: '0');
  final _patientController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  // Which eye is being marked
  String _selectedEye = 'OD';

  @override
  void dispose() {
    _axisController.dispose();
    _patientController.dispose();
    super.dispose();
  }

  void _startMarking() {
    if (!_formKey.currentState!.validate()) return;
    final axis = double.parse(_axisController.text);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          cameras: widget.cameras,
          targetAxis: axis,
          patientRef: _patientController.text,
          eye: _selectedEye,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _Header(),
                const SizedBox(height: 40),
                _AxisInput(controller: _axisController),
                const SizedBox(height: 32),
                _EyeSelector(
                  selected: _selectedEye,
                  onChanged: (v) => setState(() => _selectedEye = v),
                ),
                const SizedBox(height: 28),
                _PatientInput(controller: _patientController),
                const SizedBox(height: 40),
                _Instructions(),
                const SizedBox(height: 32),
                _StartButton(
                  enabled: widget.cameras.isNotEmpty,
                  onTap: _startMarking,
                ),
                if (widget.cameras.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(
                      child: Text(
                        'No camera detected on this device.',
                        style: TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF00BCD4).withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.25)),
          ),
          child: const Icon(Icons.remove_red_eye_outlined,
              color: Color(0xFF00BCD4), size: 30),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Toric IOL Marker',
              style: TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              'Pre-operative axis marking',
              style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }
}

class _AxisInput extends StatelessWidget {
  final TextEditingController controller;

  const _AxisInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Target Axis (TABO meridian)'),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large number input
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}\.?\d{0,1}')),
                ],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 2,
                ),
                decoration: InputDecoration(
                  suffixText: '°',
                  suffixStyle: const TextStyle(
                    color: Color(0xFF00BCD4),
                    fontSize: 48,
                    fontWeight: FontWeight.w200,
                  ),
                  hintText: '0',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.15),
                    fontSize: 48,
                    fontWeight: FontWeight.w200,
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00BCD4), width: 1),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00BCD4), width: 2),
                  ),
                  errorBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.redAccent, width: 2),
                  ),
                  focusedErrorBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.redAccent, width: 2),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter an axis';
                  final n = double.tryParse(v);
                  if (n == null || n < 0 || n > 180) return 'Must be 0 – 180';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            // Quick-select chips
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [0, 15, 45, 90, 135, 165, 180].map((deg) {
                    return _QuickChip(
                      label: '$deg°',
                      onTap: () => controller.text = '$deg',
                    );
                  }).toList(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.35)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF00BCD4), fontSize: 13),
        ),
      ),
    );
  }
}

class _EyeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _EyeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Eye'),
        const SizedBox(height: 10),
        Row(
          children: [
            _EyeChip(label: 'OD (Right)', value: 'OD', selected: selected, onTap: onChanged),
            const SizedBox(width: 12),
            _EyeChip(label: 'OS (Left)', value: 'OS', selected: selected, onTap: onChanged),
          ],
        ),
      ],
    );
  }
}

class _EyeChip extends StatelessWidget {
  final String label, value, selected;
  final ValueChanged<String> onTap;

  const _EyeChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00BCD4).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? const Color(0xFF00BCD4) : Colors.white24,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF00BCD4) : Colors.white54,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _PatientInput extends StatelessWidget {
  final TextEditingController controller;

  const _PatientInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Patient Reference (optional)'),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. Patient ID, initials',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _Instructions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const steps = [
      'Enter the target axis from keratometry / IOLMaster.',
      'Patient sits upright and looks straight ahead.',
      'Hold phone camera close to the eye.',
      'Centre the crosshair on the limbus.',
      'Wait for the bubble to turn green (phone level), then capture.',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HOW TO USE',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...steps.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${e.key + 1}. ',
                    style: const TextStyle(
                        color: Color(0xFF00BCD4), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Text(
                      e.value,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
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

class _StartButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _StartButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00BCD4),
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.white12,
          disabledForegroundColor: Colors.white30,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: const Text(
          'Open Camera',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.4),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 11,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
