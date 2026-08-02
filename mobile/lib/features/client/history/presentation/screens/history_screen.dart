import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/skeleton_loader.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/app_bottom_nav.dart';
import '../../../../../core/widgets/notification_bell_action.dart';
import '../../../../../core/constants/status_labels.dart';

class HistoryScreen extends StatefulWidget {
  HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<dynamic>? _orders;
  List<dynamic>? _rides;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final ordersRes = await ApiClient.instance.get(ApiConstants.orders, query: {'limit': 20});
    final ridesRes = await ApiClient.instance.get(ApiConstants.rides, query: {'limit': 20});
    setState(() {
      _orders = ordersRes['items'];
      _rides = ridesRes['items'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historique'),
        actions: [notificationBellAction(context)],
        bottom: TabBar(controller: _tab, indicatorColor: AppColors.gold, tabs: const [Tab(text: 'Commandes'), Tab(text: 'Courses')]),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          RefreshIndicator(
            onRefresh: _load,
            color: AppColors.gold,
            child: _orders == null
              ? SkeletonCardList()
              : _orders!.isEmpty
                  ? ListView(children: [SizedBox(height: 100), EmptyState(icon: Icons.receipt_long_outlined, message: 'Aucune commande pour le moment.')])
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _orders!.length,
                      itemBuilder: (context, i) {
                        final o = _orders![i];
                        return Card(
                          margin: EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text('${o['type']} — ${o['priceBreakdown']?['total'] ?? '-'} XOF'),
                            subtitle: Text(statusLabelFr(o['status'])),
                            onTap: () => context.push('/client/tracking/order/${o['id']}'),
                          ),
                        );
                      },
                    ),
          ),
          RefreshIndicator(
            onRefresh: _load,
            color: AppColors.gold,
            child: _rides == null
              ? SkeletonCardList()
              : _rides!.isEmpty
                  ? ListView(children: [SizedBox(height: 100), EmptyState(icon: Icons.local_taxi_outlined, message: 'Aucune course pour le moment.')])
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _rides!.length,
                      itemBuilder: (context, i) {
                        final r = _rides![i];
                        return Card(
                          margin: EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text('${r['vehicleType']} — ${r['price']} XOF'),
                            subtitle: Text(statusLabelFr(r['status'])),
                            onTap: () => context.push('/client/tracking/ride/${r['id']}'),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}
