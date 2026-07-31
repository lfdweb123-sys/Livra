import 'dart:async';
import 'package:flutter/foundation.dart';

/// Minuteur d'inactivité global — remis à zéro à chaque interaction utilisateur
/// (tap n'importe où dans l'app). Si le verrouillage biométrique est actif et
/// qu'aucune interaction n'a lieu pendant [timeout], `shouldLock` notifie
/// AppLockGate pour reverrouiller l'app, même si elle reste au premier plan.
class InactivityService {
  InactivityService._();
  static final InactivityService instance = InactivityService._();

  static const Duration timeout = Duration(minutes: 2);

  Timer? _timer;
  final ValueNotifier<bool> shouldLock = ValueNotifier(false);

  void start() {
    _timer?.cancel();
    _timer = Timer(timeout, () => shouldLock.value = true);
  }

  void registerActivity() {
    if (_timer == null) return; // pas armé (app verrouillée ou biométrie désactivée)
    _timer!.cancel();
    _timer = Timer(timeout, () => shouldLock.value = true);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
