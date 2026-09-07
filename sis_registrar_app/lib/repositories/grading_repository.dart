import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/grading_models.dart';
import '../services/auth_service.dart';

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
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body));
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
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body));
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
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body));
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
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body));
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
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body));
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
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body));
    return (jsonDecode(res.body) as List)
        .map((e) =>
            UserSearchResultModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
