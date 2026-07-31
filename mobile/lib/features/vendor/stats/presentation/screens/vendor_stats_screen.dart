import 'package:flutter/material.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/skeleton_loader.dart';

class VendorStatsScreen extends StatefulWidget {
  VendorStatsScreen({super.key});
  @override
  State<VendorStatsScreen> createState() => _VendorStatsScreenState();
}

class _VendorStatsScreenState extends State<VendorStatsScreen> {
  List<dynamic>? _orders;

  @override
  void initState() {
    super.initState();
    ApiClient.instance.get(ApiConstants.orders, query: {'limit': 50}).then((res) {
      setState(() => _orders = res['items']);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_orders == null) return Scaffold(body: SkeletonCardList());
    final delivered = _orders!.where((o) => o['status'] == 'delivered').toList();
    final revenue = delivered.fold<num>(0, (sum, o) => sum + (o['priceBreakdown']?['subtotal'] ?? 0));

    return Scaffold(
      appBar: AppBar(title: Text('Statistiques')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _statCard('Commandes livrées', '${delivered.length}')),
                SizedBox(width: 12),
                Expanded(child: _statCard('Chiffre d\'affaires', '$revenue XOF')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.gold)),
        ],
      ),
    );
  }
}
