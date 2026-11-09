import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/grading_models.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';

String _extractMessage(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      if (decoded['message'] != null) return decoded['message'].toString();
      if (decoded['error'] != null) return decoded['error'].toString();
      if (decoded['detail'] != null) return decoded['detail'].toString();
      if (decoded['title'] != null) return decoded['title'].toString();
      if (decoded['errors'] != null && decoded['errors'] is Map) {
        final errMap = decoded['errors'] as Map;
        final firstList = errMap.values.firstWhere((v) => v is List && v.isNotEmpty, orElse: () => null);
        if (firstList != null && (firstList as List).isNotEmpty) {
          return firstList.first.toString();
        }
      }
    }
    return body;
  } catch (_) {
    return body;
  }
}

class GradeClearanceRepository {
  final AuthService _auth;
  GradeClearanceRepository(this._auth);

  Future<List<GradeClearanceModel>> getClearancesForUser(String userId) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http
        .get(Uri.parse('$baseUrl/api/gradeclearances/$userId'), headers: headers);
    if (res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
    return (jsonDecode(res.body) as List)
        .map((e) =>
            GradeClearanceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GradeClearanceModel> toggleClearance(
      String userId, String termId, bool isCleared) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.patch(
        Uri.parse('$baseUrl/api/gradeclearances/$userId/$termId'),
        headers: headers,
        body: jsonEncode({'isCleared': isCleared}));
    if (res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
    return GradeClearanceModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<GradeClearanceModel> createClearance({
    required String userId,
    required String termId,
    bool isCleared = false,
  }) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/api/gradeclearances'),
      headers: headers,
      body: jsonEncode({
        'userId': userId,
        'termId': termId,
        'isCleared': isCleared,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
    return GradeClearanceModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }
}

class GradeCorrectionRepository {
  final AuthService _auth;
  GradeCorrectionRepository(this._auth);

  Future<List<GradeCorrectionModel>> getPendingCorrections() async {
    final headers = await _auth.getAuthHeaders();
    final res = await http
        .get(Uri.parse('$baseUrl/api/gradecorrections/pending'), headers: headers);
    if (res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
    return (jsonDecode(res.body) as List)
        .map((e) =>
            GradeCorrectionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GradeCorrectionModel> approveCorrection(String id) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.patch(
        Uri.parse('$baseUrl/api/gradecorrections/$id/approve'),
        headers: headers,
        body: '{}');
    if (res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
    return GradeCorrectionModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<GradeCorrectionModel> rejectCorrection(String id,
      {String? reason}) async {
    final headers = await _auth.getAuthHeaders();
    final body = reason != null ? jsonEncode({'reason': reason}) : '{}';
    final res = await http.patch(
        Uri.parse('$baseUrl/api/gradecorrections/$id/reject'),
        headers: headers,
        body: body);
    if (res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
    return GradeCorrectionModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }
}

class UserSearchRepository {
  final AuthService _auth;
  UserSearchRepository(this._auth);

  Future<List<UserSearchResultModel>> search({
    String? query,
    int? role,
    bool? missingLrn,
    int? programId,
  }) async {
    final headers = await _auth.getAuthHeaders();
    if (role == null || role == 5 || missingLrn == true) {
      final params = <String, String>{};
      if (query != null && query.trim().isNotEmpty) params['q'] = query.trim();
      if (missingLrn != null) params['missingLrn'] = missingLrn.toString();
      if (programId != null) params['programId'] = programId.toString();
      final uri = Uri.parse('$baseUrl/api/students/search')
          .replace(queryParameters: params.isNotEmpty ? params : null);
      final res = await http.get(uri, headers: headers);
      if (res.statusCode != 200) {
        throw ApiException(
            statusCode: res.statusCode, message: _extractMessage(res.body));
      }
      return (jsonDecode(res.body) as List)
          .map((e) =>
              UserSearchResultModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final params = <String, String>{};
    if (query != null && query.isNotEmpty) params['search'] = query;
    if (role != null) params['role'] = role.toString();
    final uri = Uri.parse('$baseUrl/api/UserDetails')
        .replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
    return (jsonDecode(res.body) as List)
        .map((e) =>
            UserSearchResultModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateStudentLrn(String userId, String? lrn) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.patch(
      Uri.parse('$baseUrl/api/UserDetails/$userId/lrn'),
      headers: headers,
      body: jsonEncode({'lrn': lrn}),
    );
    if (res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
  }

  /// Saves the student ID (null or empty clears it) and returns what the server stored.
  Future<String?> updateStudentId(String userId, String? studentId) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.patch(
      Uri.parse('$baseUrl/api/UserDetails/$userId/student-id'),
      headers: headers,
      body: jsonEncode({'studentID': studentId}),
    );
    if (res.statusCode != 200) {
      throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['studentID'] as String? ?? body['studentId'] as String?;
  }

  Future<void> updateStudentYearLevel(String userId, int yearLevel) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.patch(
      Uri.parse('$baseUrl/api/UserDetails/$userId/year-level'),
      headers: headers,
      body: jsonEncode({'yearLevel': yearLevel}),
    );
    if (res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
  }

  Future<YearLevelSuggestionModel> getYearLevelSuggestion(String userId) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/api/studyloads/year-level-suggestion?userId=$userId'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
    return YearLevelSuggestionModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }
}

class StudentGradeRepository {
  final AuthService _auth;
  final http.Client _client;
  StudentGradeRepository(this._auth, {http.Client? client})
      : _client = client ?? http.Client();

  /// Every subject one student took, every term, with or without a grade.
  Future<List<StudentGradeModel>> getStudentGrades(String userId) async {
    final headers = await _auth.getAuthHeaders();
    final res = await _client.get(
      Uri.parse('$baseUrl/api/student-records/$userId/grades'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
    return (jsonDecode(res.body) as List)
        .map((e) => StudentGradeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class CreditedSubjectRepository {
  final AuthService _auth;
  final http.Client _client;
  CreditedSubjectRepository(this._auth, {http.Client? client})
      : _client = client ?? http.Client();

  Future<List<CreditedSubjectModel>> getForStudent(String userId) async {
    final headers = await _auth.getAuthHeaders();
    final res = await _client.get(
      Uri.parse('$baseUrl/api/credited-subjects/student/$userId'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
    return (jsonDecode(res.body) as List)
        .map((e) => CreditedSubjectModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CreditedSubjectModel> create({
    required String userId,
    required String subjectId,
    required String sourceSchool,
    String? sourceSubjectCode,
    String? grade,
    String? schoolYear,
    required double creditedUnits,
    bool crossEnrollment = false,
    String? termId,
  }) async {
    final headers = await _auth.getAuthHeaders();
    headers['Content-Type'] = 'application/json';
    final res = await _client.post(
      Uri.parse('$baseUrl/api/credited-subjects'),
      headers: headers,
      body: jsonEncode({
        'userId': userId,
        'subjectId': subjectId,
        'sourceSchool': sourceSchool,
        'sourceSubjectCode': sourceSubjectCode,
        'grade': grade,
        'schoolYear': schoolYear,
        'creditedUnits': creditedUnits,
        'kind': crossEnrollment ? 2 : 1,
        if (termId != null) 'termId': termId,
      }),
    );
    if (res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
    return CreditedSubjectModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> delete(String creditedSubjectId) async {
    final headers = await _auth.getAuthHeaders();
    final res = await _client.delete(
      Uri.parse('$baseUrl/api/credited-subjects/$creditedSubjectId'),
      headers: headers,
    );
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
  }
}

/// End-of-year promotion: suggestions for a whole program, and saving many year levels at once.
class PromotionRepository {
  final AuthService _auth;
  final http.Client _client;
  PromotionRepository(this._auth, {http.Client? client})
      : _client = client ?? http.Client();

  Future<List<StudentPromotionModel>> getSuggestions(
      {required int programId, int? yearLevel}) async {
    final headers = await _auth.getAuthHeaders();
    final res = await _client.get(
      Uri.parse('$baseUrl/api/studyloads/year-level-suggestions').replace(
        queryParameters: {
          'programId': '$programId',
          if (yearLevel != null) 'yearLevel': '$yearLevel',
        },
      ),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
    return (jsonDecode(res.body) as List)
        .map((e) => StudentPromotionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// [changes] maps userId to the new year level. Returns how many were updated.
  Future<int> applyYearLevels(Map<String, int> changes) async {
    final headers = await _auth.getAuthHeaders();
    headers['Content-Type'] = 'application/json';
    final res = await _client.post(
      Uri.parse('$baseUrl/api/studyloads/apply-year-levels'),
      headers: headers,
      body: jsonEncode({
        'changes': [
          for (final e in changes.entries) {'userId': e.key, 'yearLevel': e.value}
        ],
      }),
    );
    if (res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
    return (jsonDecode(res.body) as Map<String, dynamic>)['updated'] as int? ?? 0;
  }
}
