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
      return (decoded['message'] ?? decoded['error'] ?? body).toString();
    }
    return body;
  } catch (_) {
    return body;
  }
}

class StudentRepository {
  final AuthService _auth;
  final http.Client _client;

  StudentRepository(this._auth, [http.Client? client])
      : _client = client ?? http.Client();

  /// Searches students by LRN or name across all programs.
  Future<List<UserSearchResultModel>> searchStudents(String query) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/students/search')
        .replace(queryParameters: {'q': query.trim()});
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
    return (jsonDecode(res.body) as List)
        .map((e) => UserSearchResultModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
