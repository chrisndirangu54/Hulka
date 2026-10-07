enum CareProgramType {
  diabetes,
  hypertension,
  asthma,
  cardiovascular,
  maternal,
  childHealth,
  rehabilitation,
}

class CareProgramEnrollment {
  const CareProgramEnrollment({
    required this.id,
    required this.patientId,
    required this.type,
    required this.startedAt,
    this.clinicianId,
    this.organizationId,
    this.active = true,
    this.goals = const [],
  });

  final String id;
  final String patientId;
  final CareProgramType type;
  final DateTime startedAt;
  final String? clinicianId;
  final String? organizationId;
  final bool active;
  final List<String> goals;
}

class CaregiverGrant {
  const CaregiverGrant({
    required this.patientId,
    required this.caregiverId,
    required this.scopes,
    required this.createdAt,
    this.expiresAt,
    this.revokedAt,
  });

  final String patientId;
  final String caregiverId;
  final Set<String> scopes;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
}
