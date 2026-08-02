import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Sans ce fichier, un message FCM reçu app OUVERTE (premier plan) n'affiche
/// RIEN sur Android — pas de son, pas de bannière — c'est le comportement
/// standard de FCM, qui ne montre automatiquement une notification système
/// que pour l'app en arrière-plan ou fermée. On affiche donc nous-mêmes une
/// vraie notification système à chaque message reçu en premier plan.
class FcmService {
  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channel = AndroidNotificationChannel(
    'livra_default',
    'Notifications Livra',
    description: 'Commandes, courses, paiements, candidatures — toutes les actions importantes de l\'app.',
    importance: Importance.high,
  );

  Future<void> initAndSaveToken() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    if (!_initialized) {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _localNotifications.initialize(const InitializationSettings(android: androidInit));
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
      _initialized = true;
    }

    // App ouverte : FCM ne montre rien tout seul, on affiche nous-mêmes.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    });

    final token = await _messaging.getToken();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (token != null && uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'fcmToken': token});
    }
    _messaging.onTokenRefresh.listen((newToken) async {
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({'fcmToken': newToken});
      }
    });
  }

  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;
}
