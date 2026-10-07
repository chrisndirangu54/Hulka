import 'package:flutter_test/flutter_test.dart';
import 'package:hulka/core/health_domain.dart';

void main() {
  test('medication changes always require human review', () {
    const policy = ClinicalSafetyPolicy();
    expect(
      policy.requiresHumanReview(
        changesMedication: true,
        assertsDiagnosis: false,
        risk: ClinicalRiskLevel.routine,
      ),
      isTrue,
    );
  });

  test('emergency risk requires human review', () {
    const policy = ClinicalSafetyPolicy();
    expect(
      policy.requiresHumanReview(
        changesMedication: false,
        assertsDiagnosis: false,
        risk: ClinicalRiskLevel.emergency,
      ),
      isTrue,
    );
  });
}
