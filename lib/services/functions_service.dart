import 'package:cloud_functions/cloud_functions.dart';

class HulkaFunctions {
  HulkaFunctions({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> _call(String name, Map<String, Object?> payload) async {
    final r = await _functions.httpsCallable(name).call(payload);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<String> createAppointment(Map<String, Object?> payload) async =>
      (await _call('createAppointment', payload))['appointmentId'] as String;

  Future<String> issuePrescription(Map<String, Object?> payload) async =>
      (await _call('issuePrescription', payload))['prescriptionId'] as String;

  Future<void> grantConsent(Map<String, Object?> payload) async {
    await _call('grantConsent', payload);
  }

  Future<void> revokeConsent(String consentId) async {
    await _call('revokeConsent', {'consentId': consentId});
  }

  Future<String> reportAdverseEvent(Map<String, Object?> payload) async =>
      (await _call('recordAdverseEvent', payload))['adverseEventId'] as String;

  Future<Map<String, dynamic>> askClinicalAi(String prompt) =>
      _call('clinicalAiGateway', {'prompt': prompt});

  Future<void> saveEmergencyProfile(Map<String, Object?> payload) async {
    await _call('saveEmergencyProfile', payload);
  }

  Future<void> linkCaregiver(Map<String, Object?> payload) async {
    await _call('linkCaregiver', payload);
  }

  Future<String> enrollCareProgram(Map<String, Object?> payload) async =>
      (await _call('enrollCareProgram', payload))['careProgramId'] as String;

  Future<String> saveInsuranceCoverage(Map<String, Object?> payload) async =>
      (await _call('saveInsuranceCoverage', payload))['coverageId'] as String;

  Future<Map<String, dynamic>> insuranceEligibility() =>
      _call('insuranceEligibility', const {});

  Future<Map<String, dynamic>> medicationReactionAggregate(String medicationCode) =>
      _call('rebuildMedicationReactionAggregate', {'medicationCode': medicationCode});

  Future<Map<String, dynamic>> getPopulationMetric(String metric) =>
      _call('getPopulationMetric', {'metric': metric});

  Future<Map<String, dynamic>> evaluatePreventiveCare() =>
      _call('evaluatePreventiveCare', const {});
}
