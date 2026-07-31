import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/services/storage/upload_service.dart';
import '../../../../../core/models/product_model.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/widgets/empty_state.dart';

class VendorCatalogScreen extends StatefulWidget {
  VendorCatalogScreen({super.key});
  @override
  State<VendorCatalogScreen> createState() => _VendorCatalogScreenState();
}

class _VendorCatalogScreenState extends State<VendorCatalogScreen> {
  String? _vendorId;
  List<ProductModel> _products = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final snap = await FirebaseFirestore.instance.collection('vendors').where('ownerId', isEqualTo: uid).limit(1).get();
    if (snap.docs.isEmpty) return;
    setState(() => _vendorId = snap.docs.first.id);
    FirebaseFirestore.instance.collection('vendors/${snap.docs.first.id}/products').snapshots().listen((s) {
      setState(() => _products = s.docs.map((d) => ProductModel.fromMap(d.id, d.data())).toList());
    });
  }

  Future<void> _addProduct() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    File? image;

    await showAppBottomSheet(
      context,
      title: 'Nouveau produit',
      child: StatefulBuilder(builder: (context, setSheetState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () async {
                final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (picked != null) setSheetState(() => image = File(picked.path));
              },
              child: Container(
                height: 100,
                decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(14)),
                child: Center(child: Icon(image == null ? Icons.add_a_photo_outlined : Icons.check_circle, color: AppColors.gold)),
              ),
            ),
            SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: InputDecoration(hintText: 'Nom du produit')),
            SizedBox(height: 12),
            TextField(controller: priceCtrl, decoration: InputDecoration(hintText: 'Prix (XOF)'), keyboardType: TextInputType.number),
            SizedBox(height: 16),
            PrimaryButton(
              label: 'Ajouter',
              onPressed: () async {
                String? imageUrl;
                if (image != null) imageUrl = await UploadService().uploadFile(image!, folder: 'products');
                await ApiClient.instance.post('/api/vendors/$_vendorId/products', data: {
                  'name': nameCtrl.text.trim(),
                  'price': num.tryParse(priceCtrl.text) ?? 0,
                  'imageUrl': imageUrl,
                });
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        );
      }),
    );
  }

  Future<void> _toggleAvailability(ProductModel p) async {
    await ApiClient.instance.patch('/api/vendors/$_vendorId/products/${p.id}', data: {'isAvailable': !p.isAvailable});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mon catalogue')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.gold,
        onPressed: _addProduct,
        child: Icon(Icons.add, color: Colors.black),
      ),
      body: _products.isEmpty
          ? EmptyState(icon: Icons.restaurant_menu_outlined, message: 'Ajoutez votre premier produit avec le bouton +.')
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _products.length,
              itemBuilder: (context, i) {
                final p = _products[i];
                return Card(
                  margin: EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(p.name),
                    subtitle: Text('${p.price} XOF'),
                    trailing: Switch(value: p.isAvailable, activeColor: AppColors.gold, onChanged: (_) => _toggleAvailability(p)),
                  ),
                );
              },
            ),
    );
  }
}
