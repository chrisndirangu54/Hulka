class MedicationExposure {
  const MedicationExposure({
    required this.patientId,
    required this.medicationCode,
    required this.startedAt,
    required this.dose,
    this.stoppedAt,
  });

  final String patientId;
  final String medicationCode;
  final DateTime startedAt;
  final String dose;
  final DateTime? stoppedAt;
}

class OutcomeSignal {
  const OutcomeSignal({
    required this.patientId,
    required this.metric,
    required this.observedAt,
    required this.value,
    required this.unit,
    this.patientReported = false,
  });

  final String patientId;
  final String metric;
  final DateTime observedAt;
  final num value;
  final String unit;
  final bool patientReported;
}

class MedicationTemporalSignal {
  const MedicationTemporalSignal({
    required this.medicationCode,
    required this.metric,
    required this.daysFromStart,
    required this.summary,
    required this.requiresClinicalReview,
  });

  final String medicationCode;
  final String metric;
  final int daysFromStart;
  final String summary;
  final bool requiresClinicalReview;
}

class MedicationOutcomeAnalyzer {
  const MedicationOutcomeAnalyzer();

  List<MedicationTemporalSignal> detectTemporalSignals({
    required MedicationExposure exposure,
    required Iterable<OutcomeSignal> outcomes,
  }) {
    return outcomes
        .where((o) =>
            o.patientId == exposure.patientId &&
            !o.observedAt.isBefore(exposure.startedAt))
        .map((o) {
      final delta = o.observedAt.difference(exposure.startedAt).inDays;
      return MedicationTemporalSignal(
        medicationCode: exposure.medicationCode,
        metric: o.metric,
        daysFromStart: delta,
        summary:
            '${o.metric} changed/was reported $delta day(s) after medication initiation. This is temporal association, not proof of causation.',
        requiresClinicalReview: true,
      );
    }).toList();
  }
}
