import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/records_import_models.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';

/// Imports old students and their grades from the registrar's Excel files, and sets imported students' school emails.
class RecordsImportRepository {
  final AuthService _auth;
  final http.Client _client;
  RecordsImportRepository(this._auth, {http.Client? client}) : _client = client ?? http.Client();

  Future<RecordsImportResult> importRecords({
    required String gradesName,
    required Uint8List gradesBytes,
    String? studentsName,
    Uint8List? studentsBytes,
    List<String> schoolYears = const [],
    required bool dryRun,
    bool releaseGrades = true,
  }) async {
    final headers = await _auth.getAuthHeaders()
      ..remove('Content-Type');
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/import/records'))
      ..headers.addAll(headers)
      ..fields['schoolYears'] = schoolYears.join(',')
      ..fields['dryRun'] = '$dryRun'
      ..fields['releaseGrades'] = '$releaseGrades'
      ..files.add(http.MultipartFile.fromBytes('gradesFile', gradesBytes, filename: gradesName));
    if (studentsBytes != null) {
      request.files.add(http.MultipartFile.fromBytes('studentsFile', studentsBytes, filename: studentsName ?? 'students.xlsx'));
    }
    final res = await http.Response.fromStream(await _client.send(request));
    final body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode,
          message: body is Map ? '${body['message'] ?? 'Import failed (${res.statusCode}).'}' : 'Import failed (${res.statusCode}).');
    }
    return RecordsImportResult.fromJson(body as Map<String, dynamic>);
  }

  /// For an imported student who hasn't signed in yet. Empty clears it. Returns the saved email.
  Future<String> setSchoolEmail(String userId, String email) async {
    final headers = await _auth.getAuthHeaders();
    final res = await _client.patch(
      Uri.parse('$baseUrl/api/Students/$userId/school-email'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'schoolEmail': email}),
    );
    final body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode, message: body is Map ? '${body['message'] ?? 'Could not save.'}' : 'Could not save.');
    }
    return (body as Map<String, dynamic>)['schoolEmail'] as String? ?? '';
  }
}
