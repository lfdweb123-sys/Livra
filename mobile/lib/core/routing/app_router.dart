import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/apply_driver_screen.dart';
import '../../features/auth/presentation/screens/apply_vendor_screen.dart';

import '../../features/client/home/presentation/screens/client_home_screen.dart';
import '../../features/client/home/presentation/screens/search_screen.dart';
import '../../features/client/order/presentation/screens/vendor_detail_screen.dart';
import '../../features/client/order/presentation/screens/order_checkout_screen.dart';
import '../../features/client/ride/presentation/screens/request_ride_screen.dart';
import '../../features/client/tracking/presentation/screens/tracking_screen.dart';
import '../widgets/contact_screen.dart';
import '../../features/client/history/presentation/screens/history_screen.dart';
import '../../features/client/profile/presentation/screens/profile_screen.dart';

import '../../features/driver/home/presentation/screens/driver_home_screen.dart';
import '../../features/driver/navigation/presentation/screens/driver_navigation_screen.dart';
import '../../features/driver/earnings/presentation/screens/driver_earnings_screen.dart';

import '../../features/vendor/dashboard/presentation/screens/vendor_dashboard_screen.dart';
import '../../features/vendor/catalog/presentation/screens/vendor_catalog_screen.dart';
import '../../features/vendor/orders/presentation/screens/vendor_orders_screen.dart';
import '../../features/vendor/stats/presentation/screens/vendor_stats_screen.dart';

import '../../features/wallet/presentation/screens/wallet_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';

/// Convertit un Stream en Listenable pour piloter `refreshListenable` du router :
/// à chaque changement d'auth (login/logout) OU appel manuel de `ping()`
/// (voir AppRouter.refresh, utilisé par RoleGate quand le rôle change),
/// go_router réévalue `redirect`.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;
  void ping() => notifyListeners();
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Un seul projet Flutter, 3 "espaces" par rôle : la redirection se fait ici
/// selon le rôle stocké sur users/{uid}. Voir RoleGate pour le chargement du rôle.
class AppRouter {
  static UserRole? currentRole; // mis à jour par RoleGate à chaque changement d'auth

  static final _refreshListenable = GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges());

  static final router = GoRouter(
    initialLocation: '/onboarding',
    refreshListenable: _refreshListenable,
    redirect: (context, state) {
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      final onboarding = state.matchedLocation == '/onboarding';

      if (!loggedIn && !loggingIn && !onboarding) return '/login';
      if (loggedIn && loggingIn) return _homeForRole(currentRole);
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (c, s) => OnboardingScreen()),
      GoRoute(path: '/login', builder: (c, s) => LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => RegisterScreen()),
      GoRoute(path: '/apply-driver', builder: (c, s) => ApplyDriverScreen()),
      GoRoute(path: '/apply-vendor', builder: (c, s) => ApplyVendorScreen()),

      // Espace Client
      GoRoute(path: '/client/home', builder: (c, s) => ClientHomeScreen()),
      GoRoute(path: '/client/search', builder: (c, s) => const SearchScreen()),
      GoRoute(
        path: '/contact',
        builder: (c, s) {
          final extra = s.extra as Map<String, dynamic>? ?? {};
          return ContactScreen(
            name: extra['name'] ?? 'Contact',
            phoneNumber: extra['phoneNumber'] ?? '',
            role: extra['role'] ?? '',
          );
        },
      ),
      GoRoute(path: '/client/vendor/:id', builder: (c, s) => VendorDetailScreen(vendorId: s.pathParameters['id']!)),
      GoRoute(
        path: '/client/checkout',
        builder: (c, s) => OrderCheckoutScreen(initialData: s.extra as Map<String, dynamic>?),
      ),
      GoRoute(
        path: '/client/ride',
        builder: (c, s) => RequestRideScreen(initialVehicleType: (s.extra as Map<String, dynamic>?)?['vehicleType'] as String?),
      ),
      GoRoute(path: '/client/tracking/:type/:id', builder: (c, s) => TrackingScreen(
            type: s.pathParameters['type']!,
            id: s.pathParameters['id']!,
          )),
      GoRoute(path: '/client/history', builder: (c, s) => HistoryScreen()),
      GoRoute(path: '/client/profile', builder: (c, s) => ProfileScreen()),

      // Espace Livreur/Chauffeur
      GoRoute(path: '/driver/home', builder: (c, s) => DriverHomeScreen()),
      GoRoute(path: '/driver/navigation/:type/:id', builder: (c, s) => DriverNavigationScreen(
            type: s.pathParameters['type']!,
            id: s.pathParameters['id']!,
          )),
      GoRoute(path: '/driver/earnings', builder: (c, s) => DriverEarningsScreen()),

      // Espace Vendeur
      GoRoute(path: '/vendor/dashboard', builder: (c, s) => VendorDashboardScreen()),
      GoRoute(path: '/vendor/catalog', builder: (c, s) => VendorCatalogScreen()),
      GoRoute(path: '/vendor/orders', builder: (c, s) => VendorOrdersScreen()),
      GoRoute(path: '/vendor/stats', builder: (c, s) => VendorStatsScreen()),

      // Commun
      GoRoute(path: '/wallet', builder: (c, s) => WalletScreen()),
      GoRoute(path: '/notifications', builder: (c, s) => NotificationsScreen()),
    ],
  );

  static String _homeForRole(UserRole? role) {
    switch (role) {
      case UserRole.driver:
        return '/driver/home';
      case UserRole.vendor:
        return '/vendor/dashboard';
      case UserRole.admin:
      case UserRole.client:
      default:
        return '/client/home';
    }
  }

  /// Appelé par RoleGate après (re)chargement du rôle depuis Firestore,
  /// pour forcer une réévaluation immédiate de `redirect`.
  static void refresh() => _refreshListenable.ping();
}
