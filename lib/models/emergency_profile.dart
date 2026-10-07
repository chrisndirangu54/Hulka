class EmergencyProfile {
  const EmergencyProfile({
    required this.patientId,
    this.bloodGroup,
    this.criticalAllergies = const [],
    this.majorConditions = const [],
    this.currentMedications = const [],
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.implants = const [],
  });

  final String patientId;
  final String? bloodGroup;
  final List<String> criticalAllergies;
  final List<String> majorConditions;
  final List<String> currentMedications;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final List<String> implants;

  Map<String, Object?> toJson() => {
    'patientId': patientId,
    'bloodGroup': bloodGroup,
    'criticalAllergies': criticalAllergies,
    'majorConditions': majorConditions,
    'currentMedications': currentMedications,
    'emergencyContactName': emergencyContactName,
    'emergencyContactPhone': emergencyContactPhone,
    'implants': implants,
  };
}
