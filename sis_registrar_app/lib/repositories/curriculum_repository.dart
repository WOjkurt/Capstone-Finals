import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/curriculum_models.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';

/// Curriculum versions of each program, the curriculum CSV import, and a student's curriculum.
class CurriculumRepository {
  final AuthService _auth;
  final http.Client _client;
  CurriculumRepository(this._auth, {http.Client? client}) : _client = client ?? http.Client();

  Future<List<CurriculumModel>> list({int? programId}) async => [
        for (final j in await _send('GET', '', query: {if (programId != null) 'programId': '$programId'}) as List)
          CurriculumModel.fromJson(j as Map<String, dynamic>)
      ];

  Future<CurriculumModel> create({required int programId, required String name, required int effectiveFromYear}) async =>
      CurriculumModel.fromJson(await _send('POST', '',
          body: {'programID': programId, 'name': name, 'effectiveFromYear': effectiveFromYear}) as Map<String, dynamic>);

  Future<CurriculumModel> update(String id, {required String name, required int effectiveFromYear}) async =>
      CurriculumModel.fromJson(
          await _send('PUT', id, body: {'name': name, 'effectiveFromYear': effectiveFromYear}) as Map<String, dynamic>);

  Future<void> delete(String id) async => _send('DELETE', id);

  Future<StudentCurriculumModel> forStudent(String userId) async =>
      StudentCurriculumModel.fromJson(await _send('GET', 'student/$userId') as Map<String, dynamic>);

  Future<void> setForStudent(String userId, String curriculumId) async =>
      _send('PUT', 'student/$userId', body: {'curriculumID': curriculumId});

  /// Checks ([dryRun]) or imports a curriculum CSV into one curriculum. Errors come back in the result, not as an exception.
  Future<CurriculumImportResult> importCsv({
    required String curriculumId,
    required String fileName,
    required Uint8List bytes,
    required bool dryRun,
    bool updateExisting = false,
  }) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/Curriculum/import').replace(queryParameters: {
      'dryRun': '$dryRun',
      'updateExisting': '$updateExisting',
      'curriculumId': curriculumId,
    });
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    final res = await http.Response.fromStream(await _client.send(request));
    final Object? decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      throw ApiException(statusCode: res.statusCode, message: 'Import failed (${res.statusCode}).');
    }
    if (decoded is Map<String, dynamic> && decoded.containsKey('subjects')) {
      return CurriculumImportResult.fromJson(decoded);
    }
    throw ApiException(
        statusCode: res.statusCode,
        message: decoded is Map ? '${decoded['message'] ?? 'Import failed (${res.statusCode}).'}' : 'Import failed.');
  }

  Future<Object?> _send(String method, String path, {Map<String, String>? query, Object? body}) async {
    final headers = await _auth.getAuthHeaders();
    var uri = Uri.parse('$baseUrl/api/curricula${path.isEmpty ? '' : '/$path'}');
    if (query != null && query.isNotEmpty) uri = uri.replace(queryParameters: query);
    final json = {...headers, 'Content-Type': 'application/json'};
    final res = switch (method) {
      'POST' => await _client.post(uri, headers: json, body: jsonEncode(body)),
      'PUT' => await _client.put(uri, headers: json, body: jsonEncode(body)),
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
