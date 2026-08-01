import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

const Map<String, String> countryCallingCodes = {
  'Bénin (+229)': '+229',
  'Togo (+228)': '+228',
  "Côte d'Ivoire (+225)": '+225',
  'Congo Brazzaville (+242)': '+242',
  'Sénégal (+221)': '+221',
  'Burkina Faso (+226)': '+226',
  'Mali (+223)': '+223',
};

/// Champ numéro de téléphone avec indicatif pays sélectionné automatiquement
/// et composé avec le numéro local — évite les paiements Mobile Money qui
/// échouent silencieusement faute d'indicatif (+229, +225...) correctement
/// formaté.
class PhoneNumberField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String initialCountry;

  const PhoneNumberField({super.key, required this.onChanged, this.initialCountry = 'Bénin (+229)'});

  @override
  State<PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<PhoneNumberField> {
  late String _country;
  final _localCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _country = widget.initialCountry;
  }

  void _emit() {
    final code = countryCallingCodes[_country]!;
    final local = _localCtrl.text.trim().replaceAll(RegExp(r'^0+'), '');
    widget.onChanged(local.isEmpty ? '' : '$code$local');
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: DropdownButtonFormField<String>(
            value: _country,
            isExpanded: true,
            dropdownColor: AppColors.surfaceElevated,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            items: countryCallingCodes.keys
                .map((c) => DropdownMenuItem(value: c, child: Text(countryCallingCodes[c]!, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) {
              setState(() => _country = v ?? _country);
              _emit();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _localCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: 'Numéro (sans le 0 initial)'),
            onChanged: (_) => _emit(),
          ),
        ),
      ],
    );
  }
}
