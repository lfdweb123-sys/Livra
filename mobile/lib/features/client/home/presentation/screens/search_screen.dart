import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/services/api/api_client.dart';
import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/models/vendor_model.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/skeleton_loader.dart';
import '../../../../../core/widgets/empty_state.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<VendorModel>? _all;
  List<VendorModel> _results = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get(ApiConstants.vendors, query: {'status': 'active', 'limit': 50});
      final items = (res['items'] as List).map((e) => VendorModel.fromMap(e['id'], e)).toList();
      if (mounted) setState(() { _all = items; _results = items; });
    } catch (_) {
      if (mounted) setState(() { _all = []; _results = []; });
    }
  }

  void _filter(String query) {
    if (_all == null) return;
    final q = query.trim().toLowerCase();
    setState(() {
      _results = q.isEmpty
          ? _all!
          : _all!.where((v) => v.businessName.toLowerCase().contains(q) || v.category.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _filter,
          decoration: const InputDecoration(
            hintText: 'Restaurants, boutiques...',
            border: InputBorder.none,
          ),
        ),
      ),
      body: _all == null
          ? const SkeletonCardList()
          : _results.isEmpty
              ? const EmptyState(icon: Icons.search_off_rounded, message: 'Aucun résultat pour cette recherche.')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final v = _results[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surfaceElevated,
                          child: Text(v.businessName.isNotEmpty ? v.businessName[0] : '?'),
                        ),
                        title: Text(v.businessName),
                        subtitle: Text(v.category == 'resto' ? 'Restaurant' : 'Boutique'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.star, size: 14, color: AppColors.gold),
                          Text(v.rating.toStringAsFixed(1)),
                        ]),
                        onTap: () => context.push('/client/vendor/${v.id}'),
                      ),
                    );
                  },
                ),
    );
  }
}
