abstract interface class FhirConnector {
  Future<Map<String, dynamic>> readPatient(String externalPatientId);
  Future<void> pushEncounter(Map<String, dynamic> encounter);
}

abstract interface class DicomConnector {
  Future<List<Map<String, dynamic>>> studiesForPatient(String patientId);
}

abstract interface class VideoConsultationProvider {
  Future<Map<String, dynamic>> createSession({
    required String appointmentId,
    required String patientId,
    required String clinicianId,
  });
}

abstract interface class InsuranceConnector {
  Future<Map<String, dynamic>> checkEligibility({
    required String memberReference,
    required String serviceCode,
  });
}

abstract interface class PaymentConnector {
  Future<Map<String, dynamic>> createPayment({
    required num amount,
    required String currency,
    required String reference,
  });
}

class IntegrationNotConfigured implements Exception {
  const IntegrationNotConfigured(this.integration);
  final String integration;

  @override
  String toString() => '$integration is not configured for this deployment.';
}

class FailClosedFhirConnector implements FhirConnector {
  const FailClosedFhirConnector();
  @override
  Future<Map<String, dynamic>> readPatient(String externalPatientId) =>
      Future.error(const IntegrationNotConfigured('FHIR connector'));

  @override
  Future<void> pushEncounter(Map<String, dynamic> encounter) =>
      Future.error(const IntegrationNotConfigured('FHIR connector'));
}
