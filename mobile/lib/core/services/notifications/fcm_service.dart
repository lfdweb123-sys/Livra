import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FcmService {
  final _messaging = FirebaseMessaging.instance;

  Future<void> initAndSaveToken() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
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
