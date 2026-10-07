import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Future<void> initializeForCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;

    await _db.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'notificationsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _messaging.onTokenRefresh.listen((nextToken) {
      _db.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([nextToken]),
        'notificationsUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
