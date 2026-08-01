import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:twilio_voice/twilio_voice.dart';
import 'api/api_client.dart';

/// Appels vocaux intégrés (VoIP), via Twilio — le client et le livreur/
/// vendeur s'appellent sans jamais sortir de l'app, chacun sur sa propre
/// connexion internet (aucun coût réseau téléphonique classique).
///
/// L'identité Twilio de chaque utilisateur = son uid Firebase, donc appeler
/// "quelqu'un" revient à appeler son uid (voir /api/twilio/voice côté
/// backend qui route l'appel vers ce client).
class TwilioCallService {
  TwilioCallService._();
  static final TwilioCallService instance = TwilioCallService._();

  bool _registered = false;
  StreamSubscription? _eventsSub;

  /// À appeler une fois au démarrage de l'app (après connexion), pour que
  /// l'utilisateur puisse recevoir des appels même app fermée.
  Future<void> registerForIncomingCalls() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _registered) return;

    try {
      final res = await ApiClient.instance.get('/api/twilio/token');
      final accessToken = res['token'] as String;
      final fcmToken = await FirebaseMessaging.instance.getToken() ?? '';

      await TwilioVoice.instance.setTokens(accessToken: accessToken, deviceToken: fcmToken);
      _registered = true;
    } catch (_) {
      // best-effort — un échec ici ne doit jamais bloquer le démarrage de
      // l'app ; l'appel simple redemandera un token au moment de l'usage.
    }
  }

  /// Place un appel vers l'uid Firebase du destinataire.
  Future<void> call({required String toUid, String? displayName}) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) throw Exception('not_authenticated');
    if (!_registered) await registerForIncomingCalls();
    if (displayName != null) {
      TwilioVoice.instance.registerClient(toUid, displayName);
    }
    await TwilioVoice.instance.call.place(from: myUid, to: toUid);
  }

  void hangUp() => TwilioVoice.instance.call.hangUp();
  void toggleMute(bool muted) => TwilioVoice.instance.call.toggleMute(isMuted: muted);
  void toggleSpeaker(bool speakerOn) => TwilioVoice.instance.call.toggleSpeaker(speakerIsOn: speakerOn);

  Stream<CallEvent> get events => TwilioVoice.instance.callEventsListener;
}
