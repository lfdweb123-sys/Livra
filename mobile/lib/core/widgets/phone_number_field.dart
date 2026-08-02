import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

const Map<String, String> countryCallingCodes = {
  'Bénin': '+229',
  'Togo': '+228',
  "Côte d'Ivoire": '+225',
  'Congo Brazzaville': '+242',
  'Sénégal': '+221',
  'Burkina Faso': '+226',
  'Mali': '+223',
};

/// Champ numéro de téléphone avec l'indicatif intégré DANS le champ (à
/// gauche, compact), pas comme une case séparée à côté — évite les
/// paiements Mobile Money qui échouent faute d'indicatif correctement
/// formaté. Le numéro local doit être saisi complet (avec son 0 initial :
/// FeexPay l'exige ainsi, ex: 229 + 0166000000).
class PhoneNumberField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String initialCountry;
  final String? initialValue; // numéro complet E.164 (ex: +2290166000000), pré-remplit pays+champ

  const PhoneNumberField({super.key, required this.onChanged, this.initialCountry = 'Bénin', this.initialValue});

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
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      for (final entry in countryCallingCodes.entries) {
        if (widget.initialValue!.startsWith(entry.value)) {
          _country = entry.key;
          _localCtrl.text = widget.initialValue!.substring(entry.value.length);
          break;
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
    }
  }

  void _emit() {
    final code = countryCallingCodes[_country]!;
    final local = _localCtrl.text.trim();
    widget.onChanged(local.isEmpty ? '' : '$code$local');
  }

  Future<void> _pickCountry() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: countryCallingCodes.entries
              .map((e) => ListTile(
                    title: Text(e.key),
                    trailing: Text(e.value, style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                    onTap: () => Navigator.pop(context, e.key),
                  ))
              .toList(),
        ),
      ),
    );
    if (selected != null) {
      setState(() => _country = selected);
      _emit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _localCtrl,
      keyboardType: TextInputType.phone,
      onChanged: (_) => _emit(),
      decoration: InputDecoration(
        hintText: 'Numéro complet (avec le 0)',
        prefixIcon: InkWell(
          onTap: _pickCountry,
          child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(countryCallingCodes[_country]!, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold, fontSize: 13)),
                Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 18),
              ],
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
  }
}
