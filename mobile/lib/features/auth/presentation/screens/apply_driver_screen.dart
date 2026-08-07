import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/services/api/api_client.dart';
import '../../../../core/services/storage/upload_service.dart';
import '../../../../core/services/storage/image_compression_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';

class ApplyDriverScreen extends StatefulWidget {
  final String? initialVehicleType;
  const ApplyDriverScreen({super.key, this.initialVehicleType});
  @override
  State<ApplyDriverScreen> createState() => _ApplyDriverScreenState();
}

class _ApplyDriverScreenState extends State<ApplyDriverScreen> {
  late String _vehicleType = widget.initialVehicleType ?? 'moto';
  final Map<String, File> _docs = {};
  bool _loading = false;
  String? _compressingKey;

  // Chaque type de véhicule a ses propres documents requis — un permis de
  // conduire ou une assurance n'a pas de sens pour un taxi-moto ou un
  // coursier à pied/vélo, et inversement une photo du véhicule doit
  // montrer la plaque d'immatriculation pour une moto.
  static const Map<String, Map<String, String>> _docsByVehicle = {
    'moto': {
      'cni': "Pièce d'identité (CNI/passeport)",
      'photoMotoPlaque': 'Photo de la moto avec la plaque bien visible',
    },
    'voiture': {
      'cni': "Pièce d'identité (CNI/passeport)",
      'permis': 'Permis de conduire',
      'assurance': "Assurance du véhicule",
      'photoVehicule': 'Photo du véhicule avec la plaque bien visible',
    },
    'coursier': {
      'cni': "Pièce d'identité (CNI/passeport)",
      'photoMoyenTransport': 'Photo de votre moyen de transport (vélo, à pied...)',
    },
  };

  // Documents facultatifs pour le type sélectionné (ex: assurance moto,
  // pas toujours souscrite) — n'empêchent pas l'envoi s'ils sont absents.
  static const Map<String, Set<String>> _optionalDocsByVehicle = {
    'moto': {'assurance'},
  };

  Map<String, String> get _requiredDocs => _docsByVehicle[_vehicleType]!;
  Set<String> get _optionalDocs => _optionalDocsByVehicle[_vehicleType] ?? {};
  Map<String, String> get _mandatoryDocs =>
      Map.fromEntries(_requiredDocs.entries.where((e) => !_optionalDocs.contains(e.key)));

  Future<void> _pickDoc(String key) async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked == null) return;
    // Compression automatique — les photos caméra brutes (souvent 3-8 Mo)
    // rendaient l'envoi du formulaire très lent, voire impossible sur une
    // connexion faible. Cible plus généreuse que pour les produits (~300 Ko
    // au lieu de 40 Ko) car les documents d'identité doivent rester
    // lisibles pour la vérification.
    setState(() => _compressingKey = key);
    final compressed = await ImageCompressionService().compress(File(picked.path), targetSizeBytes: 300 * 1024);
    if (mounted) {
      setState(() {
        _docs[key] = compressed;
        _compressingKey = null;
      });
    }
  }

  Future<void> _submit() async {
    final missing = _mandatoryDocs.keys.where((k) => !_docs.containsKey(k));
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Tous les documents requis pour ce type de véhicule doivent être fournis.")),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final uploadService = UploadService();
      final documentsR2 = <String, String>{};
      for (final entry in _docs.entries) {
        documentsR2[entry.key] =
            await uploadService.uploadFile(entry.value, folder: 'drivers');
      }
      final position = await LocationService().getCurrentPosition();
      await ApiClient.instance.post(ApiConstants.drivers, data: {
        'vehicleType': _vehicleType,
        'lat': position.latitude,
        'lng': position.longitude,
        'documentsR2': documentsR2,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Candidature envoyée ! Vous serez notifié dès validation par notre équipe.'),
        ));
        context.go('/client/home');
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Livra',
            style:
                TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: ListView(
          children: [
            SizedBox(height: 8),
            Text(
              'Devenir livreur/chauffeur',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            SizedBox(height: 24),
            Text('Type de véhicule',
                style: TextStyle(color: AppColors.textSecondary)),
            SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: ['moto', 'voiture', 'coursier'].map((v) {
                final selected = _vehicleType == v;
                return ChoiceChip(
                  label: Text(v),
                  avatar: selected
                      ? Icon(Icons.check, size: 16, color: Colors.black)
                      : null,
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _vehicleType = v;
                    _docs.clear(); // les documents d'un autre type de véhicule ne sont plus valides
                  }),
                  selectedColor: AppColors.gold,
                  backgroundColor: AppColors.surface,
                  side: BorderSide(
                      color: selected ? AppColors.gold : AppColors.divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  labelStyle: TextStyle(
                    color: selected ? Colors.black : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 28),
            Text("Documents (vérification d'identité)",
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('Tous requis avant activation par notre équipe.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            SizedBox(height: 12),
            ..._requiredDocs.entries.map((e) {
              final done = _docs.containsKey(e.key);
              final optional = _optionalDocs.contains(e.key);
              final compressing = _compressingKey == e.key;
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: ListTile(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(e.value,
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: compressing
                      ? Text('Compression en cours…',
                          style: TextStyle(color: AppColors.gold, fontSize: 11))
                      : optional
                          ? Text('Facultatif',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 11))
                          : null,
                  trailing: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? AppColors.success.withOpacity(0.12)
                          : AppColors.goldSoft,
                    ),
                    child: compressing
                        ? Padding(
                            padding: const EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                          )
                        : Icon(
                            done ? Icons.check_circle : Icons.camera_alt_outlined,
                            color: done ? AppColors.success : AppColors.textSecondary,
                            size: 20,
                          ),
                  ),
                  onTap: compressing ? null : () => _pickDoc(e.key),
                ),
              );
            }),
            SizedBox(height: 24),
            PrimaryButton(
                label: 'Envoyer', onPressed: _submit, loading: _loading),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
