import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> registerClient({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await _db.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'role': 'client',
      'name': name,
      'phone': phone,
      'email': email,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return cred;
  }

  Future<UserCredential> login({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> logout() => _auth.signOut();

  Future<Map<String, dynamic>?> fetchUserDoc(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserDoc(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }
}
