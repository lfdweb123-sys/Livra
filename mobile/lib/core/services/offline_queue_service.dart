import 'dart:async';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api/api_client.dart';

/// Une action en attente (appel API qui a échoué par manque de réseau,
/// à rejouer automatiquement dès que la connexion revient).
class _PendingAction {
  final String method; // 'post' | 'patch'
  final String path;
  final Map<String, dynamic> data;
  final String label; // description lisible, pour la notification de synchro

  _PendingAction({required this.method, required this.path, required this.data, required this.label});

  Map<String, dynamic> toJson() => {'method': method, 'path': path, 'data': data, 'label': label};
  factory _PendingAction.fromJson(Map json) => _PendingAction(
        method: json['method'],
        path: json['path'],
        data: Map<String, dynamic>.from(json['data']),
        label: json['label'],
      );
}

/// Certaines actions (marquer une commande "en livraison"/"livrée", par
/// exemple) doivent pouvoir être déclenchées même sans réseau — courant
/// pour un livreur dans une zone mal couverte — puis se synchroniser
/// automatiquement dès que la connexion revient, avec notification claire
/// pour que l'utilisateur sache que c'est bien parti.
class OfflineQueueService {
  static final OfflineQueueService instance = OfflineQueueService._();
  OfflineQueueService._();

  static const _boxName = 'livra_offline_queue';
  Box? _box;
  StreamSubscription? _connectivitySub;
  final _syncedController = StreamController<String>.broadcast();

  /// Émet un message lisible à chaque action synchronisée avec succès —
  /// à écouter pour afficher une notification/snackbar "Synchronisé".
  Stream<String> get onSynced => _syncedController.stream;

  Future<void> init() async {
    _box ??= await Hive.openBox(_boxName);
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = !results.contains(ConnectivityResult.none);
      if (online) _flush();
    });
    // Tentative immédiate au démarrage, au cas où des actions attendaient déjà.
    _flush();
  }

  int get pendingCount => _box?.length ?? 0;

  /// Tente l'appel immédiatement ; si ça échoue pour une raison réseau
  /// (pas une erreur métier), l'action est mise en file et sera rejouée
  /// automatiquement. Retourne true si exécutée tout de suite, false si
  /// mise en attente.
  Future<bool> postOrQueue({
    required String method, // 'post' | 'patch'
    required String path,
    required Map<String, dynamic> data,
    required String label,
  }) async {
    try {
      if (method == 'patch') {
        await ApiClient.instance.patch(path, data: data);
      } else {
        await ApiClient.instance.post(path, data: data);
      }
      return true;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final isNetworkIssue = msg.contains('network') || msg.contains('connexion') || msg.contains('délai') || msg.contains('timeout');
      if (!isNetworkIssue) rethrow; // vraie erreur métier — ne pas mettre en file, la remonter normalement
      await _enqueue(_PendingAction(method: method, path: path, data: data, label: label));
      return false;
    }
  }

  Future<void> _enqueue(_PendingAction action) async {
    _box ??= await Hive.openBox(_boxName);
    await _box!.add(jsonEncode(action.toJson()));
  }

  Future<void> _flush() async {
    _box ??= await Hive.openBox(_boxName);
    if (_box!.isEmpty) return;
    final keys = _box!.keys.toList();
    for (final key in keys) {
      final raw = _box!.get(key);
      if (raw == null) continue;
      final action = _PendingAction.fromJson(jsonDecode(raw));
      try {
        if (action.method == 'patch') {
          await ApiClient.instance.patch(action.path, data: action.data);
        } else {
          await ApiClient.instance.post(action.path, data: action.data);
        }
        await _box!.delete(key);
        _syncedController.add(action.label);
      } catch (_) {
        // Toujours pas de réseau (ou erreur persistante) — on retentera
        // au prochain changement de connectivité, on laisse l'action en file.
        break;
      }
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _syncedController.close();
  }
}
