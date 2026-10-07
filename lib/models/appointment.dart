enum AppointmentStatus { requested, confirmed, inProgress, completed, cancelled }

class Appointment {
  const Appointment({required this.id, required this.patientId, required this.clinicianId, required this.organizationId, required this.startsAt, required this.status, this.reason, this.telemedicineSessionId});
  final String id;
  final String patientId;
  final String clinicianId;
  final String organizationId;
  final DateTime startsAt;
  final AppointmentStatus status;
  final String? reason;
  final String? telemedicineSessionId;

  Map<String, Object?> toJson() => {
    'patientId': patientId,
    'clinicianId': clinicianId,
    'organizationId': organizationId,
    'startsAt': startsAt.toUtc().toIso8601String(),
    'status': status.name,
    'reason': reason,
    'telemedicineSessionId': telemedicineSessionId,
  };
}
