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
