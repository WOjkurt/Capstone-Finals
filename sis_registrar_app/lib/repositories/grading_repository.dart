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
}
