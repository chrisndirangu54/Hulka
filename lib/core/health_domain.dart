enum HulkaRole {
  patient,
  clinician,
  pharmacist,
  laboratory,
  hospitalAdmin,
  researcher,
  platformAdmin,
}

enum ClinicalRiskLevel { informational, routine, soon, urgent, emergency }

enum DataProvenanceType {
  patientReported,
  clinicianEntered,
  laboratory,
  pharmacy,
  wearable,
  medicalDevice,
  importedFhir,
  synthetic,
}

class ClinicalSafetyPolicy {
  const ClinicalSafetyPolicy();

  bool requiresHumanReview({
    required bool changesMedication,
    required bool assertsDiagnosis,
    required ClinicalRiskLevel risk,
  }) {
    return changesMedication ||
        assertsDiagnosis ||
        risk == ClinicalRiskLevel.urgent ||
        risk == ClinicalRiskLevel.emergency;
  }
}
