import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/offline_queue_service.dart';
import '../theme/app_colors.dart';

/// Enveloppe TOUTE l'application (branché via MaterialApp.builder) — affiche
/// un bandeau discret "Hors connexion" en permanence tant que le réseau est
/// coupé, et un message temporaire de confirmation dès que des actions
/// mises en attente ont bien été synchronisées.
class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _offline = false;
  String? _syncMessage;
  StreamSubscription? _connectivitySub;
  StreamSubscription? _syncedSub;
  Timer? _syncMessageTimer;

  @override
  void initState() {
    super.initState();
    OfflineQueueService.instance.init();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.contains(ConnectivityResult.none) && results.length <= 1;
      if (mounted) setState(() => _offline = offline);
    });
    Connectivity().checkConnectivity().then((results) {
      if (mounted) setState(() => _offline = results.contains(ConnectivityResult.none) && results.length <= 1);
    });
    _syncedSub = OfflineQueueService.instance.onSynced.listen((label) {
      if (!mounted) return;
      _syncMessageTimer?.cancel();
      setState(() => _syncMessage = 'Synchronisé : $label');
      _syncMessageTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _syncMessage = null);
      });
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _syncedSub?.cancel();
    _syncMessageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_offline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                color: AppColors.warning,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: const Text(
                  'Hors connexion — certaines actions seront synchronisées automatiquement',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.black, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        if (_syncMessage != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                color: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: Text(
                  _syncMessage!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
