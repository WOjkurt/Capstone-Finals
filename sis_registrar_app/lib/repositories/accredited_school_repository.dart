import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/school_models.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';

class AccreditedSchoolRepository {
  final AuthService _auth;
  final http.Client _client;
  AccreditedSchoolRepository(this._auth, {http.Client? client}) : _client = client ?? http.Client();

  Future<List<AccreditedSchool>> getAll() async =>
      [for (final j in await _send('GET', '') as List) AccreditedSchool.fromJson(j as Map<String, dynamic>)];

  Future<List<UnlistedSchool>> getUnlisted() async =>
      [for (final j in await _send('GET', '/unlisted') as List) UnlistedSchool.fromJson(j as Map<String, dynamic>)];

  Future<AccreditedSchool> create(String name, {String? address}) async =>
      AccreditedSchool.fromJson(await _send('POST', '', {'name': name, 'address': address}) as Map<String, dynamic>);

  /// Renaming also renames the school on credits that used the old name.
  Future<AccreditedSchool> update(String id, String name, {String? address}) async =>
      AccreditedSchool.fromJson(await _send('PUT', '/$id', {'name': name, 'address': address}) as Map<String, dynamic>);

  Future<void> delete(String id) => _send('DELETE', '/$id');

  Future<Object?> _send(String method, String path, [Object? body]) async {
    final headers = {...await _auth.getAuthHeaders(), if (body != null) 'Content-Type': 'application/json'};
    final uri = Uri.parse('$baseUrl/api/accredited-schools$path');
    final res = switch (method) {
      'POST' => await _client.post(uri, headers: headers, body: jsonEncode(body)),
      'PUT' => await _client.put(uri, headers: headers, body: jsonEncode(body)),
      'DELETE' => await _client.delete(uri, headers: headers),
      _ => await _client.get(uri, headers: headers),
    };
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String message = 'Request failed (${res.statusCode}).';
      try {
        message = (jsonDecode(res.body) as Map<String, dynamic>)['message'] as String? ?? message;
      } catch (_) {}
      throw ApiException(statusCode: res.statusCode, message: message);
    }
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }
}
