import 'package:flutter/material.dart';

/// Couleur de marque + libellé court par réseau — un cercle propre et
/// reconnaissable pour chaque moyen de paiement, sans fond désordonné.
class NetworkStyle {
  final Color bg;
  final Color fg;
  final String label;
  const NetworkStyle(this.bg, this.fg, this.label);
}

const Map<String, NetworkStyle> kNetworkStyles = {
  'mtn': NetworkStyle(Color(0xFFFFCC00), Colors.black, 'MTN'),
  'moov': NetworkStyle(Color(0xFF0072BC), Colors.white, 'Moov'),
  'celtiis_bj': NetworkStyle(Color(0xFF1B3B6F), Colors.white, 'Celtiis'),
  'coris': NetworkStyle(Color(0xFF00468C), Colors.white, 'Coris'),
  'mtn_ci': NetworkStyle(Color(0xFFFFCC00), Colors.black, 'MTN'),
  'orange_ci': NetworkStyle(Color(0xFFFF6600), Colors.white, 'Orange'),
  'moov_ci': NetworkStyle(Color(0xFF0072BC), Colors.white, 'Moov'),
  'wave_ci': NetworkStyle(Color(0xFF1DC8E0), Colors.black, 'Wave'),
  'togocom_tg': NetworkStyle(Color(0xFFFFD100), Colors.black, 'Togocom'),
  'moov_tg': NetworkStyle(Color(0xFF0072BC), Colors.white, 'Moov'),
  'orange_sn': NetworkStyle(Color(0xFFFF6600), Colors.white, 'Orange'),
  'free_sn': NetworkStyle(Color(0xFFCC0000), Colors.white, 'Free'),
  'wave_sn': NetworkStyle(Color(0xFF1DC8E0), Colors.black, 'Wave'),
  'mtn_cg': NetworkStyle(Color(0xFFFFCC00), Colors.black, 'MTN'),
  'moov_bf': NetworkStyle(Color(0xFF0072BC), Colors.white, 'Moov'),
  'orange_bf': NetworkStyle(Color(0xFFFF6600), Colors.white, 'Orange'),
  'wave_bf': NetworkStyle(Color(0xFF1DC8E0), Colors.black, 'Wave'),
  'orange_ml': NetworkStyle(Color(0xFFFF6600), Colors.white, 'Orange'),
  'mobicash_ml': NetworkStyle(Color(0xFFE30613), Colors.white, 'MobiCash'),
  'yas': NetworkStyle(Color(0xFFFFD100), Color(0xFF1B3B6F), 'Yas'),
  'visa': NetworkStyle(Color(0xFF1A1F71), Colors.white, 'VISA'),
  'mastercard': NetworkStyle(Color(0xFFEB001B), Colors.white, 'MC'),
};

/// Badge circulaire propre pour un réseau — remplace les puces texte
/// brutes par un rendu net et immédiatement reconnaissable.
class NetworkBadge extends StatelessWidget {
  final String network;
  final double size;
  final bool selected;
  const NetworkBadge({super.key, required this.network, this.size = 44, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final style = kNetworkStyles[network] ?? const NetworkStyle(Color(0xFF6B6B6F), Colors.white, '?');
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: style.bg,
        border: selected ? Border.all(color: Colors.black, width: 2.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      alignment: Alignment.center,
      child: Text(
        style.label.length > 6 ? style.label.substring(0, 5) : style.label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(color: style.fg, fontWeight: FontWeight.bold, fontSize: size * 0.22),
      ),
    );
  }
}

/// Sélecteur de réseau en rangée de badges circulaires — remplace les
/// Wrap(ChoiceChip) texte utilisés à plusieurs endroits de l'app pour le
/// choix du réseau Mobile Money.
class NetworkPicker extends StatelessWidget {
  final List<String> networks;
  final String selected;
  final ValueChanged<String> onChanged;
  const NetworkPicker({super.key, required this.networks, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      children: networks.map((n) {
        final style = kNetworkStyles[n] ?? const NetworkStyle(Color(0xFF6B6B6F), Colors.white, '?');
        return GestureDetector(
          onTap: () => onChanged(n),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NetworkBadge(network: n, selected: selected == n),
              const SizedBox(height: 4),
              SizedBox(
                width: 56,
                child: Text(
                  style.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
