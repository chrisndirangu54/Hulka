import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/health_domain.dart';
import '../models/app_user.dart';

class AuthService {
  AuthService(this._auth, this._db);
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  Stream<User?> authState() => _auth.authStateChanges();
  Future<AppUser?> currentProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final snap = await _db.collection('users').doc(user.uid).get();
    if (!snap.exists) return null;
    return AppUser.fromJson(user.uid, snap.data()!);
  }
  Future<UserCredential> signIn(String email, String password) => _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  Future<UserCredential> registerPatient({required String email, required String password, required String displayName}) async {
    final c = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    await c.user!.updateDisplayName(displayName);
    await _db.collection('users').doc(c.user!.uid).set({'email': email.trim(), 'displayName': displayName, 'role': HulkaRole.patient.name, 'verified': true, 'createdAt': FieldValue.serverTimestamp()});
    await _db.collection('patients').doc(c.user!.uid).set({'displayName': displayName, 'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    return c;
  }
  Future<void> signOut() => _auth.signOut();
}
