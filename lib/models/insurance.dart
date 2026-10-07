class InsuranceCoverage {
  const InsuranceCoverage({
    required this.id,
    required this.patientId,
    required this.insurerId,
    required this.planName,
    required this.memberReference,
    this.active = true,
  });

  final String id;
  final String patientId;
  final String insurerId;
  final String planName;
  final String memberReference;
  final bool active;
}

class CoverageCheck {
  const CoverageCheck({
    required this.covered,
    required this.message,
    this.copay,
    this.currency,
    this.authorizationRequired = false,
  });

  final bool covered;
  final String message;
  final num? copay;
  final String? currency;
  final bool authorizationRequired;
}
