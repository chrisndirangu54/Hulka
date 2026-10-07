import '../core/health_domain.dart';

class HealthObservation {
  const HealthObservation({
    required this.id,
    required this.patientId,
    required this.code,
    required this.display,
    required this.value,
    required this.unit,
    required this.recordedAt,
    required this.provenance,
    this.sourceId,
    this.qualityScore,
    this.synthetic = false,
  });

  final String id;
  final String patientId;
  final String code;
  final String display;
  final num value;
  final String unit;
  final DateTime recordedAt;
  final DataProvenanceType provenance;
  final String? sourceId;
  final double? qualityScore;
  final bool synthetic;

  Map<String, Object?> toJson() => {
        'id': id,
        'patientId': patientId,
        'code': code,
        'display': display,
        'value': value,
        'unit': unit,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'provenance': provenance.name,
        'sourceId': sourceId,
        'qualityScore': qualityScore,
        'synthetic': synthetic,
      };
}

class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.patientId,
    required this.type,
    required this.title,
    required this.occurredAt,
    this.summary,
    this.sourceOrganizationId,
    this.evidenceRefs = const [],
    this.synthetic = false,
  });

  final String id;
  final String patientId;
  final String type;
  final String title;
  final String? summary;
  final DateTime occurredAt;
  final String? sourceOrganizationId;
  final List<String> evidenceRefs;
  final bool synthetic;
}
