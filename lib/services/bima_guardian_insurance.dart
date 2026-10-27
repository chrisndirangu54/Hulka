import 'dart:convert';
import 'package:http/http.dart' as http;

/// Client for a secure first-party gateway (not the local-only Bima API).
/// Bima credentials must remain on the server. No automatic policy binding.
class BimaGuardianInsuranceClient {
  final Uri gateway;
  final Future<String> Function() userAccessToken;
  final http.Client httpClient;
  BimaGuardianInsuranceClient({
    required this.gateway,
    required this.userAccessToken,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  Future<Map<String, dynamic>> quote({
    required String applicantId,
    required String consentReference,
    required num sumInsured,
    String product = 'medical',
    String subtype = 'individual',
    Map<String, dynamic> details = const {},
  }) async {
    if (gateway.scheme != 'https') throw StateError('HTTPS gateway is required');
    if (applicantId.isEmpty || consentReference.isEmpty || sumInsured <= 0) {
      throw ArgumentError('Applicant, consent and valid sum insured required');
    }
    final token = await userAccessToken();
    if (token.isEmpty) throw StateError('Authenticated user required');
    final response = await httpClient.post(
      gateway.resolve('/v1/quotes'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'product': product,
        'subtype': subtype,
        'sumInsured': sumInsured,
        'applicantId': applicantId,
        'consentReference': consentReference,
        ...details
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Insurance quote request failed (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) throw const FormatException('Invalid quote response');
    return decoded;
  }

  void close() => httpClient.close();
}

// patient workflows should collect only underwriting-relevant fields.
// Hulka must never include diagnoses or medical history without separately
// documented explicit purpose-specific consent.
