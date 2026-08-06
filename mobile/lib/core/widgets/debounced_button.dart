import 'package:flutter/material.dart';
import 'primary_button.dart';

/// Enveloppe PrimaryButton pour empêcher un double-appui pendant qu'une
/// action asynchrone tourne déjà — critique pour tout bouton "Payer":
/// sans ça, un appui rapide en double (le temps que la première requête
/// parte) déclenche deux paiements distincts. Le bouton se désactive et
/// affiche un spinner dès le premier appui, jusqu'à la fin de [onPressed].
class DebouncedButton extends StatefulWidget {
  final String label;
  final Future<void> Function() onPressed;
  final bool outlined;
  final IconData? icon;

  const DebouncedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.icon,
  });

  @override
  State<DebouncedButton> createState() => _DebouncedButtonState();
}

class _DebouncedButtonState extends State<DebouncedButton> {
  bool _busy = false;

  Future<void> _handleTap() async {
    if (_busy) return; // ignore tout appui supplémentaire pendant l'action en cours
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      label: widget.label,
      loading: _busy,
      outlined: widget.outlined,
      icon: widget.icon,
      onPressed: _busy ? null : _handleTap,
    );
  }
}
