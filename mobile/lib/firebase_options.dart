// Généré à partir de la config Firebase réelle du projet livra-efb01.
// À terme, lance `flutterfire configure` pour générer une config Android/iOS
// dédiée (nécessaire pour Google Sign-In natif, Analytics par plateforme...),
// mais pour Email/Password Auth + Firestore + FCM, cette config web réutilisée
// suffit et fonctionne sur toutes les plateformes (le projectId/apiKey sont
// ce qui compte réellement pour l'authentification et Firestore).
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Plateforme non supportée par DefaultFirebaseOptions');
    }
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyDWiLnQSDFPE348-7PsHGcF-qPaAUXMWYg',
    appId: '1:40887549835:web:ecef433414e003cb2a798e',
    messagingSenderId: '40887549835',
    projectId: 'livra-efb01',
    authDomain: 'livra-efb01.firebaseapp.com',
    storageBucket: 'livra-efb01.firebasestorage.app',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyDWiLnQSDFPE348-7PsHGcF-qPaAUXMWYg',
    appId: '1:40887549835:web:ecef433414e003cb2a798e',
    messagingSenderId: '40887549835',
    projectId: 'livra-efb01',
    storageBucket: 'livra-efb01.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyDWiLnQSDFPE348-7PsHGcF-qPaAUXMWYg',
    appId: '1:40887549835:web:ecef433414e003cb2a798e',
    messagingSenderId: '40887549835',
    projectId: 'livra-efb01',
    storageBucket: 'livra-efb01.firebasestorage.app',
    iosBundleId: 'com.lfd.livra',
  );
}
