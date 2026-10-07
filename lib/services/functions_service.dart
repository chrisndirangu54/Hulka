import 'package:cloud_functions/cloud_functions.dart';

class HulkaFunctions {
  HulkaFunctions({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<String> createAppointment(Map<String, Object?> payload) async {
    final r = await _functions.httpsCallable('createAppointment').call(payload);
    return (r.data as Map)['appointmentId'] as String;
  }

  Future<String> issuePrescription(Map<String, Object?> payload) async {
    final r = await _functions.httpsCallable('issuePrescription').call(payload);
    return (r.data as Map)['prescriptionId'] as String;
  }

  Future<void> revokeConsent(String consentId) async {
    await _functions.httpsCallable('revokeConsent').call({'consentId': consentId});
  }

  Future<String> reportAdverseEvent(Map<String, Object?> payload) async {
    final r = await _functions.httpsCallable('recordAdverseEvent').call(payload);
    return (r.data as Map)['adverseEventId'] as String;
  }

  Future<Map<String, dynamic>> askClinicalAi(String prompt) async {
    final r = await _functions.httpsCallable('clinicalAiGateway').call({'prompt': prompt});
    return Map<String, dynamic>.from(r.data as Map);
  }
}
