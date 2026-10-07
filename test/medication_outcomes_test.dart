import 'package:flutter_test/flutter_test.dart';
import 'package:hulka/services/medication_outcomes.dart';

void main() {
  test('outcome analyzer labels temporal signals for review', () {
    final start = DateTime(2026, 1, 1);
    final signals = const MedicationOutcomeAnalyzer().detectTemporalSignals(
      exposure: MedicationExposure(
        patientId: 'patient',
        medicationCode: 'drug',
        startedAt: start,
        dose: '1 tablet',
      ),
      outcomes: [
        OutcomeSignal(
          patientId: 'patient',
          metric: 'dizziness',
          observedAt: DateTime(2026, 1, 3),
          value: 1,
          unit: 'reported',
          patientReported: true,
        ),
      ],
    );

    expect(signals.single.daysFromStart, 2);
    expect(signals.single.requiresClinicalReview, isTrue);
  });
}
