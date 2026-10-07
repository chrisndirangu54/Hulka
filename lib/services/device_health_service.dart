import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:health/health.dart';
import 'package:uuid/uuid.dart';

class DeviceHealthService {
  DeviceHealthService({
    Health? health,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _health = health ?? Health(),
        _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final Health _health;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final _uuid = const Uuid();

  static const readableTypes = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BLOOD_GLUCOSE,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.WEIGHT,
    HealthDataType.SLEEP_ASLEEP,
  ];

  Future<bool> requestReadAccess() async {
    await _health.configure();
    return _health.requestAuthorization(readableTypes);
  }

  Future<int> syncLast24Hours() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Authentication required');

    await _health.configure();
    final allowed = await _health.requestAuthorization(readableTypes);
    if (!allowed) return 0;

    final now = DateTime.now();
    final points = await _health.getHealthDataFromTypes(
      now.subtract(const Duration(hours: 24)),
      now,
      readableTypes,
    );
    final unique = _health.removeDuplicates(points);

    final batch = _db.batch();
    var count = 0;
    for (final p in unique) {
      final value = p.value.toString();
      final ref = _db.collection('patients').doc(uid).collection('deviceRaw').doc(_uuid.v4());
      batch.set(ref, {
        'healthType': p.type.name,
        'value': value,
        'unit': p.unit.name,
        'dateFrom': p.dateFrom.toUtc().toIso8601String(),
        'dateTo': p.dateTo.toUtc().toIso8601String(),
        'sourceName': p.sourceName,
        'sourceId': p.sourceId,
        'recordingMethod': p.recordingMethod.name,
        'provenance': 'wearable',
        'synthetic': false,
        'ingestedAt': FieldValue.serverTimestamp(),
      });
      count++;
    }
    await batch.commit();
    return count;
  }
}
