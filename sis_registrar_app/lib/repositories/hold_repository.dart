import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/hold_models.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';

class HoldRepository {
  final AuthService _auth;
  final http.Client _client;
  HoldRepository(this._auth, {http.Client? client}) : _client = client ?? http.Client();

  Future<List<EnrollmentHold>> forStudent(String userId) async => [
        for (final j in await _send('GET', 'student/$userId') as List) EnrollmentHold.fromJson(j as Map<String, dynamic>)
      ];

  Future<EnrollmentHold> add(String userId, {required String reason, String? note}) async =>
      EnrollmentHold.fromJson(await _send('POST', 'student/$userId', {'reason': reason, 'note': note}) as Map<String, dynamic>);

  Future<EnrollmentHold> remove(String holdId, {String? note}) async =>
      EnrollmentHold.fromJson(await _send('PATCH', '$holdId/remove', {'note': note}) as Map<String, dynamic>);

  Future<Object?> _send(String method, String path, [Object? body]) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/enrollment-holds/$path');
    final json = {...headers, 'Content-Type': 'application/json'};
    final res = switch (method) {
      'POST' => await _client.post(uri, headers: json, body: jsonEncode(body)),
      'PATCH' => await _client.patch(uri, headers: json, body: jsonEncode(body)),
      _ => await _client.get(uri, headers: headers),
    };
    if (res.statusCode != 200) {
      String message = 'Request failed (${res.statusCode}).';
      try {
        message = (jsonDecode(res.body) as Map<String, dynamic>)['message'] as String? ?? message;
      } catch (_) {}
      throw ApiException(statusCode: res.statusCode, message: message);
    }
    return jsonDecode(res.body);
  }
}
