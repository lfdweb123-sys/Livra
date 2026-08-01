import 'package:flutter/material.dart';
import '../../../../core/services/api/api_client.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';

class ApplyVendorScreen extends StatefulWidget {
  ApplyVendorScreen({super.key});
  @override
  State<ApplyVendorScreen> createState() => _ApplyVendorScreenState();
}

class _ApplyVendorScreenState extends State<ApplyVendorScreen> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _category = 'resto';
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final position = await LocationService().getCurrentPosition();
      await ApiClient.instance.post(ApiConstants.vendors, data: {
        'businessName': _nameCtrl.text.trim(),
        'category': _category,
        'address': _addressCtrl.text.trim(),
        'lat': position.latitude,
        'lng': position.longitude,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Candidature envoyée ! Vous pourrez publier votre catalogue dès validation.'),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Devenir vendeur')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(controller: _nameCtrl, decoration: InputDecoration(hintText: 'Nom de la boutique / restaurant')),
            SizedBox(height: 12),
            TextField(controller: _addressCtrl, decoration: InputDecoration(hintText: 'Adresse')),
            SizedBox(height: 16),
            Text('Catégorie', style: TextStyle(color: AppColors.textSecondary)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['resto', 'shop'].map((c) {
                final selected = _category == c;
                return ChoiceChip(
                  label: Text(c),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = c),
                  selectedColor: AppColors.gold,
                  labelStyle: TextStyle(color: selected ? Colors.black : AppColors.textPrimary),
                );
              }).toList(),
            ),
            SizedBox(height: 24),
            PrimaryButton(label: 'Envoyer ma candidature', onPressed: _submit, loading: _loading),
          ],
        ),
      ),
    );
  }
}
