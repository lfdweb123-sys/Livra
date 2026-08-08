import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

const int kPageSize = 15;

/// Recherche texte + pagination côté client, réutilisable sur toutes les
/// listes de l'application (catalogue vendeur, historique...). items est
/// déjà chargé — le filtrage/la pagination se font ensuite localement.
class SearchAndPage<T> {
  final List<T> allItems;
  final String query;
  final int page;
  final List<String> Function(T item) searchableFields;

  SearchAndPage({required this.allItems, required this.query, required this.page, required this.searchableFields});

  List<T> get filtered {
    if (query.trim().isEmpty) return allItems;
    final q = query.trim().toLowerCase();
    return allItems.where((item) => searchableFields(item).any((f) => f.toLowerCase().contains(q))).toList();
  }

  int get pageCount => (filtered.length / kPageSize).ceil().clamp(1, 999999);
  int get safePage => page.clamp(0, pageCount - 1);
  List<T> get paginated => filtered.skip(safePage * kPageSize).take(kPageSize).toList();
}

class AppSearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String hintText;
  const AppSearchBar({super.key, required this.onChanged, this.hintText = 'Rechercher…'});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class AppPaginationBar extends StatelessWidget {
  final int page;
  final int pageCount;
  final ValueChanged<int> onPageChanged;
  const AppPaginationBar({super.key, required this.page, required this.pageCount, required this.onPageChanged});

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 18),
            label: const Text('Précédent'),
          ),
          Text('Page ${page + 1} / $pageCount', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          TextButton.icon(
            onPressed: page < pageCount - 1 ? () => onPageChanged(page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: const Text('Suivant'),
          ),
        ],
      ),
    );
  }
}
