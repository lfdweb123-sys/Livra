import 'package:flutter/material.dart';
import '../services/api/api_client.dart';
import '../theme/app_colors.dart';
import '../constants/status_labels.dart';
import '../services/friendly_error.dart';

/// Détail complet d'une commande ou d'une course — sert de preuve
/// tangible et de traçabilité complète : articles commandés, adresses,
/// contacts (vendeur/client/livreur), ventilation exacte du prix, moyen
/// de paiement, et historique de chaque changement de statut.
class OrderDetailScreen extends StatefulWidget {
  final String id;
  final String type; // 'order' | 'ride'
  const OrderDetailScreen({super.key, required this.id, required this.type});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final path = widget.type == 'order' ? '/api/orders/${widget.id}' : '/api/rides/${widget.id}';
      final res = await ApiClient.instance.get(path);
      if (mounted) setState(() => _data = res);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOrder = widget.type == 'order';
    return Scaffold(
      appBar: AppBar(title: Text(isOrder ? 'Détail de la commande' : 'Détail de la course')),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
          : _data == null
              ? Center(child: CircularProgressIndicator(color: AppColors.gold))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: isOrder ? _buildOrderContent(_data!) : _buildRideContent(_data!),
                ),
    );
  }

  List<Widget> _buildOrderContent(Map<String, dynamic> o) {
    final items = (o['items'] as List?) ?? [];
    final breakdown = o['priceBreakdown'] as Map<String, dynamic>? ?? {};
    final vendorInfo = o['vendorInfo'] as Map<String, dynamic>?;
    final clientInfo = o['clientInfo'] as Map<String, dynamic>?;
    final driverInfo = o['driverInfo'] as Map<String, dynamic>?;
    return [
      _statusHeader(orderStatusDisplayFr(o)),
      const SizedBox(height: 20),
      _sectionTitle('Identifiant'),
      _infoRow('N° de commande', o['id'] ?? widget.id),
      _infoRow('Type', ORDER_TYPE_LABELS_FR[o['type']] ?? o['type'] ?? '—'),
      if (items.isNotEmpty) ...[
        const SizedBox(height: 20),
        _sectionTitle('Articles commandés'),
        ...items.map((it) => _itemRow(it)),
      ],
      const SizedBox(height: 20),
      _sectionTitle('Paiement'),
      _infoRow('Sous-total', '${breakdown['subtotal'] ?? 0} XOF'),
      if ((breakdown['deliveryFee'] ?? 0) > 0) _infoRow('Frais de livraison', '${breakdown['deliveryFee']} XOF'),
      _infoRow('Frais de service (${breakdown['serviceFeePercent'] ?? 5}%)', '${breakdown['serviceFee'] ?? 0} XOF'),
      _infoRow('Total', '${breakdown['total'] ?? 0} XOF', bold: true),
      _infoRow('Moyen de paiement', _paymentMethodLabel(o['paymentMethod'])),
      _infoRow('Statut du paiement', PAYMENT_STATUS_LABELS_FR[o['paymentStatus']] ?? o['paymentStatus'] ?? '—'),
      const SizedBox(height: 20),
      _sectionTitle('Adresses'),
      if (o['pickupAddress']?['label'] != null) _infoRow('Collecte', o['pickupAddress']['label']),
      if (o['deliveryAddress']?['label'] != null) _infoRow('Livraison', o['deliveryAddress']['label']),
      if (o['offPlatformDriverPhone'] != null) ...[
        const SizedBox(height: 20),
        _sectionTitle('Livreur hors application'),
        _infoRow('Numéro déclaré', o['offPlatformDriverPhone']),
      ],
      if (vendorInfo != null || clientInfo != null || driverInfo != null) ...[
        const SizedBox(height: 20),
        _sectionTitle('Contacts'),
        if (vendorInfo != null) _infoRow('Vendeur', '${vendorInfo['businessName'] ?? '—'}${vendorInfo['phone'] != null ? ' — ${vendorInfo['phone']}' : ''}'),
        if (clientInfo != null) _infoRow('Client', '${clientInfo['name'] ?? '—'}${clientInfo['phone'] != null ? ' — ${clientInfo['phone']}' : ''}'),
        if (driverInfo != null) _infoRow('Livreur', '${driverInfo['name'] ?? '—'}${driverInfo['phone'] != null ? ' — ${driverInfo['phone']}' : ''}'),
      ],
      if ((o['statusHistory'] as List?)?.isNotEmpty == true) ...[
        const SizedBox(height: 20),
        _sectionTitle('Historique'),
        ..._statusHistoryTimeline(o['statusHistory']),
      ],
    ];
  }

  List<Widget> _buildRideContent(Map<String, dynamic> r) {
    final clientInfo = r['clientInfo'] as Map<String, dynamic>?;
    final driverInfo = r['driverInfo'] as Map<String, dynamic>?;
    return [
      _statusHeader(statusLabelFr(r['status'])),
      const SizedBox(height: 20),
      _sectionTitle('Identifiant'),
      _infoRow('N° de course', r['id'] ?? widget.id),
      _infoRow('Véhicule', r['vehicleType'] ?? '—'),
      if (r['distanceKm'] != null) _infoRow('Distance', '${r['distanceKm']} km'),
      const SizedBox(height: 20),
      _sectionTitle('Paiement'),
      _infoRow('Prix de base', '${r['basePrice'] ?? 0} XOF'),
      _infoRow('Frais de service (${r['serviceFeePercent'] ?? 5}%)', '${r['serviceFee'] ?? 0} XOF'),
      _infoRow('Total', '${r['price'] ?? 0} XOF', bold: true),
      _infoRow('Moyen de paiement', _paymentMethodLabel(r['paymentMethod'])),
      _infoRow('Statut du paiement', PAYMENT_STATUS_LABELS_FR[r['paymentStatus']] ?? r['paymentStatus'] ?? '—'),
      const SizedBox(height: 20),
      _sectionTitle('Trajet'),
      if (r['pickupLocation']?['label'] != null) _infoRow('Départ', r['pickupLocation']['label']),
      if (r['dropoffLocation']?['label'] != null) _infoRow('Destination', r['dropoffLocation']['label']),
      if (r['offPlatformDriverPhone'] != null) ...[
        const SizedBox(height: 20),
        _sectionTitle('Chauffeur hors application'),
        _infoRow('Numéro déclaré', r['offPlatformDriverPhone']),
      ],
      if (clientInfo != null || driverInfo != null) ...[
        const SizedBox(height: 20),
        _sectionTitle('Contacts'),
        if (clientInfo != null) _infoRow('Client', '${clientInfo['name'] ?? '—'}${clientInfo['phone'] != null ? ' — ${clientInfo['phone']}' : ''}'),
        if (driverInfo != null) _infoRow('Chauffeur', '${driverInfo['name'] ?? '—'}${driverInfo['phone'] != null ? ' — ${driverInfo['phone']}' : ''}'),
      ],
    ];
  }

  Widget _statusHeader(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(Icons.receipt_long_rounded, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Statut actuel', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title.toUpperCase(), style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );

  Widget _infoRow(String label, dynamic value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
            Expanded(
              flex: 3,
              child: Text(
                '$value',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
              ),
            ),
          ],
        ),
      );

  Widget _itemRow(dynamic it) {
    final name = it['name'] ?? 'Article';
    final qty = it['qty'] ?? it['quantity'] ?? 1;
    final price = it['price'] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text('${qty}x $name', style: const TextStyle(fontSize: 13))),
          Text('$price XOF', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  List<Widget> _statusHistoryTimeline(List history) {
    return history.map((h) {
      final at = h['at'];
      String formatted = '';
      if (at != null) {
        try {
          final dt = DateTime.parse(at).toLocal();
          formatted = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } catch (_) {
          formatted = at.toString();
        }
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.circle, size: 8, color: AppColors.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(statusLabelFr(h['status']), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  if (formatted.isNotEmpty) Text(formatted, style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  String _paymentMethodLabel(String? method) {
    switch (method) {
      case 'cash':
        return 'Espèces à la livraison';
      case 'wallet':
        return 'Portefeuille Livra';
      case 'feexpay':
        return 'Mobile Money (Feexpay)';
      case 'verzapay':
        return 'Carte bancaire / International (Verzapay)';
      default:
        return method ?? 'Non renseigné';
    }
  }
}
