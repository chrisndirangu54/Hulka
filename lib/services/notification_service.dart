import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'dosage_schedule.dart';

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
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

  // ---------------------------------------------------------------------------
  // Dosage reminder scheduling
  //
  // Reminders are stored under `patients/{uid}/dosageReminders/{id}` so that the
  // Cloud Function can read them and dispatch FCM push notifications at each
  // scheduled dose time. The `scheduledAt` field records when the document was
  // written; `times` holds HH:mm strings consumed by [DosageSchedule].
  // ---------------------------------------------------------------------------

  /// Writes [reminders] to Firestore so the Cloud Function can send FCM push
  /// notifications at each dose time. Returns the list of Firestore document
  /// IDs that were created or updated (one per reminder).
  Future<List<String>> scheduleDosageReminders(
    List<DosageReminder> reminders,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Authentication required.');
    for (final reminder in reminders) {
      if (reminder.medicine.trim().isEmpty ||
          reminder.medicine.length >= 120 ||
          reminder.times.length >= 12 ||
          reminder.times.isEmpty ||
          reminder.times.any(
            (time) => !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(time),
          )) {
        throw ArgumentError(
          'A medicine and valid HH:mm dose times are required.',
        );
      }
    }

    final collection = _db
        .collection('patients')
        .doc(uid)
        .collection('dosageReminders');
    final ids = <String>[];

    for (final reminder in reminders) {
      final payload = <String, Object?>{
        'patientId': uid,
        'medicine': reminder.medicine,
        'strength': reminder.strength,
        'doseForm': reminder.doseForm,
        'instructions': reminder.instructions,
        'times': reminder.times.toSet().toList()..sort(),
        'utcOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
        'active': reminder.active,
        if (reminder.prescriptionId != null)
          'prescriptionId': reminder.prescriptionId,
        'scheduledAt': FieldValue.serverTimestamp(),
      };

      if (reminder.id.isEmpty) {
        final ref = await collection.add(payload);
        ids.add(ref.id);
      } else {
        await collection.doc(reminder.id).set(payload, SetOptions(merge: true));
        ids.add(reminder.id);
      }
    }

    return ids;
  }

  /// Sets `active: false` on a dosage reminder document so the Cloud Function
  /// stops sending FCM push notifications for it.
  Future<void> cancelDosageReminder(String reminderId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db
        .collection('patients')
        .doc(uid)
        .collection('dosageReminders')
        .doc(reminderId)
        .update({'active': false});
  }
}
