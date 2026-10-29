import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:hulka/services/sokonis_client.dart';

class _DownClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(const Stream.empty(), 404, reasonPhrase: 'Not Found');
  }
}

void main() {
  test('MCP downtime falls back to Kenyan meal ideas', () async {
    final client = SokonisClient(httpClient: _DownClient());
    final meals = await client.recommendMeals(['sukuma']);
    expect(meals.map((m) => m.name), contains('Bean stew + rice'));
    expect(await client.pingMcp(), isFalse);
  });

  test('disclaimer is not a diagnosis', () {
    expect(sokonisDisclaimer.toLowerCase(), contains('not a medical diagnosis'));
  });
}
