import 'package:flutter/material.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/services/friendly_error.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/debounced_button.dart';

/// Chaque livreur/coursier/chauffeur/taxi-moto fixe ses propres frais de
/// livraison selon l'adresse et la distance — soit il laisse Livra calculer
/// automatiquement (barème plateforme), soit il configure son propre tarif
/// (frais de base + prix au km + minimum garanti).
class DriverPricingScreen extends StatefulWidget {
  final String driverId;
  final String vehicleType;
  const DriverPricingScreen({super.key, required this.driverId, required this.vehicleType});

  @override
  State<DriverPricingScreen> createState() => _DriverPricingScreenState();
}

class _DriverPricingScreenState extends State<DriverPricingScreen> {
  bool _loading = true;
  bool _saving = false;
  String _mode = 'auto';
  final _baseFeeCtrl = TextEditingController();
  final _perKmCtrl = TextEditingController();
  final _minFeeCtrl = TextEditingController();
  Map<String, dynamic>? _suggestion;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final suggestion = await ApiClient.instance.get('/api/pricing/suggest', query: {'vehicleType': widget.vehicleType});
      final driver = await ApiClient.instance.get('/api/drivers/${widget.driverId}');
      final pc = driver['pricingConfig'] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _suggestion = suggestion;
          _mode = pc?['mode'] ?? 'auto';
          final defaults = suggestion['defaults'] as Map<String, dynamic>;
          _baseFeeCtrl.text = (pc?['baseFee'] ?? defaults['baseFee']).toString();
          _perKmCtrl.text = (pc?['perKm'] ?? defaults['perKm']).toString();
          _minFeeCtrl.text = (pc?['minFee'] ?? defaults['minFee']).toString();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final data = _mode == 'auto'
          ? {'pricingConfig': {'mode': 'auto'}}
          : {
              'pricingConfig': {
                'mode': 'custom',
                'baseFee': num.tryParse(_baseFeeCtrl.text) ?? 0,
                'perKm': num.tryParse(_perKmCtrl.text) ?? 0,
                'minFee': num.tryParse(_minFeeCtrl.text) ?? 0,
              }
            };
      await ApiClient.instance.patch('/api/drivers/${widget.driverId}', data: data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarif enregistré.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes tarifs de livraison')),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.gold))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  "Vous fixez vous-même vos frais de livraison selon l'adresse et la distance. "
                  "Vous pouvez laisser Livra calculer automatiquement, ou configurer votre propre tarif.",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'auto',
                  groupValue: _mode,
                  onChanged: (v) => setState(() => _mode = v!),
                  title: const Text('Calcul automatique'),
                  subtitle: Text('Livra calcule selon la distance (barème standard).', style: TextStyle(fontSize: 12)),
                  activeColor: AppColors.gold,
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'custom',
                  groupValue: _mode,
                  onChanged: (v) => setState(() => _mode = v!),
                  title: const Text('Mon propre tarif'),
                  subtitle: Text('Vous fixez vos frais de base, votre prix au km et votre minimum.', style: TextStyle(fontSize: 12)),
                  activeColor: AppColors.gold,
                ),
                if (_mode == 'auto' && _suggestion != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Exemples (calcul automatique)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 8),
                        ...((_suggestion!['examples'] as List).map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text('${e['km']} km  →  ${e['fee']} XOF', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                            ))),
                      ],
                    ),
                  ),
                ],
                if (_mode == 'custom') ...[
                  const SizedBox(height: 16),
                  Text('Frais de base (XOF)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(controller: _baseFeeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'ex: 300')),
                  const SizedBox(height: 14),
                  Text('Prix au km (XOF)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(controller: _perKmCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'ex: 150')),
                  const SizedBox(height: 14),
                  Text('Minimum garanti (XOF)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(controller: _minFeeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'ex: 300')),
                  const SizedBox(height: 10),
                  Text(
                    'Aperçu: 5 km → ${_previewFee(5)} XOF · 10 km → ${_previewFee(10)} XOF',
                    style: TextStyle(color: AppColors.gold, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 24),
                DebouncedButton(label: 'Enregistrer', onPressed: _save),
              ],
            ),
    );
  }

  num _previewFee(num km) {
    final base = num.tryParse(_baseFeeCtrl.text) ?? 0;
    final perKm = num.tryParse(_perKmCtrl.text) ?? 0;
    final minFee = num.tryParse(_minFeeCtrl.text) ?? 0;
    final fee = base + km * perKm;
    return fee < minFee ? minFee : (fee / 50).round() * 50;
  }
}
