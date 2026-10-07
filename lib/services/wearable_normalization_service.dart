import '../core/health_domain.dart';
import '../models/health_record.dart';

class WearableSample {
  const WearableSample({
    required this.source,
    required this.metric,
    required this.value,
    required this.unit,
    required this.measuredAt,
    this.qualityScore,
  });

  final String source;
  final String metric;
  final num value;
  final String unit;
  final DateTime measuredAt;
  final double? qualityScore;
}

class WearableNormalizationService {
  const WearableNormalizationService();

  HealthObservation normalize({
    required String id,
    required String patientId,
    required WearableSample sample,
  }) {
    return HealthObservation(
      id: id,
      patientId: patientId,
      code: _canonicalCode(sample.metric),
      display: sample.metric,
      value: sample.value,
      unit: sample.unit,
      recordedAt: sample.measuredAt,
      provenance: DataProvenanceType.wearable,
      sourceId: sample.source,
      qualityScore: sample.qualityScore,
    );
  }

  String _canonicalCode(String metric) {
    switch (metric.trim().toLowerCase()) {
      case 'heart rate':
      case 'hr':
        return 'heart_rate';
      case 'resting heart rate':
        return 'resting_heart_rate';
      case 'steps':
        return 'steps';
      case 'sleep':
      case 'sleep duration':
        return 'sleep_duration';
      case 'spo2':
      case 'blood oxygen':
        return 'oxygen_saturation';
      case 'hrv':
        return 'heart_rate_variability';
      default:
        return metric.trim().toLowerCase().replaceAll(' ', '_');
    }
  }
}
