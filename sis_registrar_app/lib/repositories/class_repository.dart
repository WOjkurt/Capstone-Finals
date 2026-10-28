import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/class_models.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';

String _extractMessage(String body) {
  try {
    final j = jsonDecode(body) as Map<String, dynamic>;
    return (j['message'] ?? j['error'] ?? body).toString();
  } catch (_) {
    return body;
  }
}

class ClassRepository {
  final AuthService _auth;
  final http.Client _client;

  ClassRepository(this._auth, [http.Client? client])
      : _client = client ?? http.Client();

  Future<List<ClassModel>> getClasses({String? termId}) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/Classes').replace(
      queryParameters: termId != null && termId.isNotEmpty
          ? {'termId': termId}
          : null,
    );
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }
    final list = (jsonDecode(res.body) as List)
        .map((e) => ClassModel.fromJson(e as Map<String, dynamic>))
        .toList();

    list.sort((a, b) =>
        (a.subjectCode ?? '').compareTo(b.subjectCode ?? ''));
    return list;
  }

  Future<List<ClassRosterItemModel>> getClassRoster(String classId) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/studyloads/class/$classId');
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }
    final list = (jsonDecode(res.body) as List)
        .map((e) => ClassRosterItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    list.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return list;
  }

  Future<List<ClassRosterItemModel>> getStudentStudyLoads(
      String userId, String termId) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/studyloads/student/$userId')
        .replace(queryParameters: {'termId': termId});
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }
    final list = (jsonDecode(res.body) as List)
        .map((e) => ClassRosterItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    list.sort((a, b) =>
        a.subjectCode.toLowerCase().compareTo(b.subjectCode.toLowerCase()));
    return list;
  }

  Future<ClassRosterItemModel> updateStudyLoadStatus(
      String studyLoadId, int loadStatus) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/studyloads/$studyLoadId/status');
    final res = await _client.patch(
      uri,
      headers: headers,
      body: jsonEncode({'loadStatus': loadStatus}),
    );
    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }
    return ClassRosterItemModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<OpenTermResultModel> openTerm({
    required int programId,
    required String termId,
    int? yearLevel,
    int sections = 1,
    required bool dryRun,
  }) async {
    final headers = await _auth.getAuthHeaders();
    headers['Content-Type'] = 'application/json';
    final uri = Uri.parse('$baseUrl/api/Classes/open-term').replace(
      queryParameters: {'dryRun': dryRun.toString()},
    );
    final body = jsonEncode({
      'programId': programId,
      'termId': termId,
      'yearLevel': ?yearLevel,
      'sections': sections,
    });
    final res = await _client.post(uri, headers: headers, body: body);
    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }
    return OpenTermResultModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }
}
