import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/user_model.dart';
import '../routing/app_router.dart';
import '../theme/app_colors.dart';

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  const _NavItem(this.icon, this.activeIcon, this.label, this.route);
}

const _clientItems = [
  _NavItem(Icons.home_outlined, Icons.home_rounded, 'Accueil', '/client/home'),
  _NavItem(Icons.history_outlined, Icons.history_rounded, 'Historique', '/client/history'),
  _NavItem(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Portefeuille', '/wallet'),
  _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profil', '/client/profile'),
];

const _driverItems = [
  _NavItem(Icons.home_outlined, Icons.home_rounded, 'Accueil', '/driver/home'),
  _NavItem(Icons.payments_outlined, Icons.payments_rounded, 'Gains', '/driver/earnings'),
  _NavItem(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Portefeuille', '/wallet'),
  _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profil', '/client/profile'),
];

const _vendorItems = [
  _NavItem(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Accueil', '/vendor/dashboard'),
  _NavItem(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Commandes', '/vendor/orders'),
  _NavItem(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Portefeuille', '/wallet'),
  _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profil', '/client/profile'),
];

/// Barre de navigation basse — 5 onglets, adaptés au rôle courant
/// (client/livreur/vendeur). Les 3 derniers onglets (Portefeuille,
/// Notifications, Profil) pointent vers les mêmes écrans partagés quel
/// que soit le rôle.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  const AppBottomNav({super.key, required this.currentIndex});

  List<_NavItem> get _items {
    switch (AppRouter.currentRole) {
      case UserRole.driver:
        return _driverItems;
      case UserRole.vendor:
        return _vendorItems;
      default:
        return _clientItems;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 62,
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.gold,
          unselectedItemColor: AppColors.textSecondary,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
          onTap: (i) {
            if (i == currentIndex) return;
            context.go(items[i].route);
          },
          items: [
            for (int i = 0; i < items.length; i++)
              BottomNavigationBarItem(
                icon: Icon(i == currentIndex ? items[i].activeIcon : items[i].icon),
                label: items[i].label,
              ),
          ],
        ),
      ),
    );
  }
}
