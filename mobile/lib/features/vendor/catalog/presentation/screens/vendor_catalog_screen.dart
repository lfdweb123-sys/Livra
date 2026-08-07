import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/services/friendly_error.dart';
import '../../../../../core/services/storage/upload_service.dart';
import '../../../../../core/services/storage/image_compression_service.dart';
import '../../../../../core/models/product_model.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../../core/widgets/notification_bell_action.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/debounced_button.dart';
import '../../../../../core/widgets/share_button.dart';

const int _maxProductsPerVendor = 50;

class VendorCatalogScreen extends StatefulWidget {
  const VendorCatalogScreen({super.key});
  @override
  State<VendorCatalogScreen> createState() => _VendorCatalogScreenState();
}

class _VendorCatalogScreenState extends State<VendorCatalogScreen> {
  String? _vendorId;
  List<ProductModel> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final snap = await FirebaseFirestore.instance.collection('vendors').where('ownerId', isEqualTo: uid).limit(1).get();
      if (snap.docs.isEmpty) {
        if (mounted) setState(() { _loading = false; _error = "Aucune boutique associée à ce compte."; });
        return;
      }
      setState(() => _vendorId = snap.docs.first.id);
      FirebaseFirestore.instance.collection('vendors/${snap.docs.first.id}/products').snapshots().listen((s) {
        final items = s.docs.map((d) => ProductModel.fromMap(d.id, d.data())).toList();
        items.sort((a, b) => b.pinned == a.pinned ? 0 : (b.pinned ? 1 : -1));
        if (mounted) setState(() { _products = items; _loading = false; });
      }, onError: (e) {
        if (mounted) setState(() { _loading = false; _error = 'Erreur de chargement : $e'; });
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Erreur de chargement : $e'; });
    }
  }

  Future<void> _addOrEditProduct({ProductModel? existing}) async {
    if (existing == null && _products.length >= _maxProductsPerVendor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limite de 50 produits atteinte. Retirez-en un pour en ajouter un nouveau.')),
      );
      return;
    }

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing?.price != null ? existing!.price.toString() : '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    File? image;
    String? existingImageUrl = existing?.imageUrl;
    bool compressing = false;

    await showAppBottomSheet(
      context,
      title: existing == null ? 'Nouveau produit' : 'Modifier le produit',
      child: StatefulBuilder(builder: (context, setSheetState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () async {
                final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
                if (picked != null) {
                  setSheetState(() => compressing = true);
                  final compressed = await ImageCompressionService().compress(File(picked.path));
                  setSheetState(() {
                    image = compressed;
                    existingImageUrl = null;
                    compressing = false;
                  });
                }
              },
              child: Container(
                height: 100,
                decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(14)),
                child: Center(
                  child: compressing
                      ? CircularProgressIndicator(color: AppColors.gold)
                      : (image != null || existingImageUrl != null)
                          ? existingImageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(existingImageUrl!, height: 100, width: double.infinity, fit: BoxFit.cover),
                                )
                              : Icon(Icons.check_circle, color: AppColors.gold)
                          : Icon(Icons.add_a_photo_outlined, color: AppColors.gold),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text('Image compressée automatiquement (~40 Ko)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Titre du produit')),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(hintText: 'Petite description')),
            const SizedBox(height: 12),
            TextField(controller: priceCtrl, decoration: const InputDecoration(hintText: 'Prix (XOF)'), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            DebouncedButton(
              label: existing == null ? 'Ajouter' : 'Enregistrer',
              onPressed: () async {
                if (compressing) return;
                String? imageUrl = existingImageUrl;
                if (image != null) imageUrl = await UploadService().uploadFile(image!, folder: 'products');
                try {
                  final data = {
                    'name': nameCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'price': num.tryParse(priceCtrl.text) ?? 0,
                    'imageUrl': imageUrl,
                  };
                  if (existing == null) {
                    await ApiClient.instance.post('/api/vendors/$_vendorId/products', data: data);
                  } else {
                    await ApiClient.instance.patch('/api/vendors/$_vendorId/products/${existing.id}', data: data);
                  }
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                }
              },
            ),
          ],
        );
      }),
    );
  }

  Future<void> _deleteProduct(ProductModel p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        content: Text('« ${p.name} » sera définitivement retiré de votre catalogue. Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Supprimer', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.instance.delete('/api/vendors/$_vendorId/products/${p.id}');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produit supprimé.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _toggleAvailability(ProductModel p) async {
    await ApiClient.instance.patch('/api/vendors/$_vendorId/products/${p.id}', data: {'isAvailable': !p.isAvailable});
  }

  Future<void> _togglePinned(ProductModel p) async {
    if (!p.pinned) {
      final pinnedCount = _products.where((x) => x.pinned).length;
      if (pinnedCount >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 5 produits épinglés à la fois.')));
        return;
      }
    }
    await ApiClient.instance.patch('/api/vendors/$_vendorId/products/${p.id}', data: {'pinned': !p.pinned});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mon catalogue (${_products.length}/$_maxProductsPerVendor)'),
        actions: [notificationBellAction(context)],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.gold,
        onPressed: () => _addOrEditProduct(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: RefreshIndicator(
        onRefresh: _init,
        color: AppColors.gold,
        child: _loading
            ? Center(child: CircularProgressIndicator(color: AppColors.gold))
            : _error != null
                ? ListView(children: [SizedBox(height: 120), EmptyState(icon: Icons.error_outline_rounded, message: _error!)])
                : _products.isEmpty
                    ? ListView(children: const [SizedBox(height: 120), EmptyState(icon: Icons.restaurant_menu_outlined, message: 'Ajoutez votre premier produit avec le bouton +.')])
                    : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _products.length,
              itemBuilder: (context, i) {
                final p = _products[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () => _addOrEditProduct(existing: p),
                    leading: p.imageUrl != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(p.imageUrl!, width: 44, height: 44, fit: BoxFit.cover))
                        : null,
                    title: Row(
                      children: [
                        if (p.pinned) Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.push_pin_rounded, size: 14, color: AppColors.gold)),
                        Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    subtitle: Text('${p.price} XOF', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(p.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, color: p.pinned ? AppColors.gold : AppColors.textSecondary, size: 20),
                          onPressed: () => _togglePinned(p),
                        ),
                        Switch(value: p.isAvailable, activeColor: AppColors.gold, onChanged: (_) => _toggleAvailability(p)),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
                          onSelected: (v) {
                            if (v == 'edit') _addOrEditProduct(existing: p);
                            if (v == 'delete') _deleteProduct(p);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                            PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: AppColors.danger))),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }
}
