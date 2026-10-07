import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment.dart';
import '../models/health_record.dart';

class ClinicalRepository {
  ClinicalRepository(this._db);
  final FirebaseFirestore _db;

  Stream<QuerySnapshot<Map<String, dynamic>>> timeline(String patientId) => _db
      .collection('patients').doc(patientId).collection('timeline')
      .orderBy('occurredAt', descending: true).snapshots();

  Future<void> addObservation(HealthObservation observation) => _db
      .collection('patients').doc(observation.patientId)
      .collection('observations').doc(observation.id).set(observation.toJson());

  Stream<QuerySnapshot<Map<String, dynamic>>> appointmentsForPatient(String patientId) =>
      _db.collection('appointments').where('patientId', isEqualTo: patientId).snapshots();

  Future<void> requestAppointment(Appointment appointment) =>
      _db.collection('appointments').doc(appointment.id).set(appointment.toJson());
}
