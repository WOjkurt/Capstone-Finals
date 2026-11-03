import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/grading_models.dart';
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
}

class GradeCorrectionRepository {
  final AuthService _auth;
  GradeCorrectionRepository(this._auth);

  /// Teacher: submit a new correction request for an already-submitted grade.
  /// [gradeId] — the GradeID of the locked grade row.
  /// [correctionPeriod] — 1 = Midterms, 2 = Finals.
  /// [oldGrade] — must exactly match the current stored value or the backend returns 400.
  /// [newGrade] — the desired corrected grade (must be on the DBTC grading scale).
  /// [reason] — required justification text.
  Future<GradeCorrectionModel> requestCorrection({
    required String gradeId,
    required int correctionPeriod,
    required double oldGrade,
    required double newGrade,
    required String reason,
  }) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/api/gradecorrections'),
      headers: headers,
      body: jsonEncode({
        'gradeId': gradeId,
        'correctionPeriod': correctionPeriod,
        'oldGrade': oldGrade,
        'newGrade': newGrade,
        'reason': reason,
      }),
    );
    if (res.statusCode != 201) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
    return GradeCorrectionModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Teacher: fetch all correction requests filed by the authenticated user,
  /// ordered by DateRequested descending.
  Future<List<GradeCorrectionModel>> getMyCorrections() async {
    final headers = await _auth.getAuthHeaders();
    final res = await http
        .get(Uri.parse('$baseUrl/api/gradecorrections/mine'), headers: headers);
    if (res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
    return (jsonDecode(res.body) as List)
        .map((e) => GradeCorrectionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Registrar-side methods ──────────────────────────────────────────

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

  Future<List<UserSearchResultModel>> search(
      {String? query, int? role}) async {
    final headers = await _auth.getAuthHeaders();
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

  /// Teachers and Program Heads, who can both be assigned to classes.
  Future<List<UserSearchResultModel>> searchTeachingStaff(
      {String? query}) async {
    final results = await Future.wait([
      search(query: query, role: 3),
      search(query: query, role: 4),
    ]);
    final seen = <String>{};
    final merged = [
      for (final list in results)
        for (final u in list)
          if (seen.add(u.userId)) u,
    ];
    merged.sort((a, b) =>
        a.lastname.toLowerCase().compareTo(b.lastname.toLowerCase()));
    return merged;
  }
}
