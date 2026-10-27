import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/class_models.dart';
import '../models/setup_models.dart';
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

  ClassRepository(this._auth);

  Future<List<ClassModel>> getMyClasses({
    required String teacherUserId,
    String? termId,
  }) async {
    final headers = await _auth.getAuthHeaders();
    final queryParams = <String, String>{
      'teacherUserId': teacherUserId,
    };
    if (termId != null && termId.isNotEmpty) {
      queryParams['termId'] = termId;
    }

    final uri = Uri.parse('$baseUrl/api/classes').replace(queryParameters: queryParams);
    final res = await http.get(uri, headers: headers);

    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }

    return (jsonDecode(res.body) as List)
        .map((e) => ClassModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ClassModel>> getProgramClasses({
    String? termId,
    String? subjectId,
    int? yearLevel,
  }) async {
    final headers = await _auth.getAuthHeaders();
    final queryParams = <String, String>{};
    if (termId != null && termId.isNotEmpty) {
      queryParams['termId'] = termId;
    }
    if (subjectId != null && subjectId.isNotEmpty) {
      queryParams['subjectId'] = subjectId;
    }
    if (yearLevel != null) {
      queryParams['yearLevel'] = yearLevel.toString();
    }

    final uri = Uri.parse('$baseUrl/api/classes')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final res = await http.get(uri, headers: headers);

    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }

    return (jsonDecode(res.body) as List)
        .map((e) => ClassModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Assigns (or unassigns when [teacherUserId] is null) a teacher to a class.
  /// Calls PATCH /api/classes/{classId}/teacher — updates only UserID.
  Future<void> assignTeacher(String classId, String? teacherUserId) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/classes/$classId/teacher');
    final res = await http.patch(
      uri,
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'userID': teacherUserId}),
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }
  }

  Future<List<ClassRosterItemModel>> getClassRoster(String classId) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/studyloads/class/$classId');
    final res = await http.get(uri, headers: headers);

    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }

    final list = (jsonDecode(res.body) as List)
        .map((e) => ClassRosterItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    // Sort alphabetically by student display name
    list.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return list;
  }

  Future<List<AcademicTermModel>> getTerms() async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/academicterms');
    final res = await http.get(uri, headers: headers);

    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }

    return (jsonDecode(res.body) as List)
        .map((e) => AcademicTermModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AcademicTermModel?> getActiveTerm() async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/academicterms/active');
    final res = await http.get(uri, headers: headers);

    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }

    return AcademicTermModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
