import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Clavier PIN 4 chiffres, 100% Flutter (aucune dépendance native).
/// [onComplete] est appelé automatiquement dès que 4 chiffres sont saisis.
class PinPad extends StatefulWidget {
  final String title;
  final String? subtitle;
  final ValueChanged<String> onComplete;
  final bool showError;

  const PinPad({
    super.key,
    required this.title,
    this.subtitle,
    required this.onComplete,
    this.showError = false,
  });

  @override
  State<PinPad> createState() => PinPadState();
}

class PinPadState extends State<PinPad> {
  String _pin = '';

  void reset() {
    if (mounted) setState(() => _pin = '');
  }

  void _addDigit(String d) {
    if (_pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length == 4) {
      final entered = _pin;
      Future.delayed(const Duration(milliseconds: 100), () => widget.onComplete(entered));
    }
  }

  void _removeDigit() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(widget.subtitle!, style: TextStyle(fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            final filled = i < _pin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? AppColors.gold : Colors.transparent,
                border: Border.all(color: widget.showError ? AppColors.danger : AppColors.gold, width: 1.5),
              ),
            );
          }),
        ),
        const SizedBox(height: 28),
        _keypadRow(['1', '2', '3']),
        const SizedBox(height: 14),
        _keypadRow(['4', '5', '6']),
        const SizedBox(height: 14),
        _keypadRow(['7', '8', '9']),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 64, height: 64),
            _digitButton('0'),
            SizedBox(
              width: 64,
              height: 64,
              child: IconButton(
                icon: const Icon(Icons.backspace_outlined),
                onPressed: _removeDigit,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _keypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map(_digitButton).toList(),
    );
  }

  Widget _digitButton(String d) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _addDigit(d),
          child: Center(child: Text(d, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600))),
        ),
      ),
    );
  }
}
