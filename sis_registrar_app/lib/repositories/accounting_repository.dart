import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/grading_models.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';

/// The Accounting Office's whole reach into this system: find a student, and see their holds.
///
/// It searches through `api/UserDetails`, not `api/students/search`, because the Accounting
/// role is not allowed near the student records endpoints -- those carry transcripts,
/// evaluations and personal details. This returns a name, program and year level, which is
/// enough to be sure you have the right person and nothing more.
///
/// Raising and lifting holds goes through [HoldRepository], shared with the Registrar.
class AccountingRepository {
  final AuthService _auth;
  final http.Client _client;

  AccountingRepository(this._auth, {http.Client? client})
      : _client = client ?? http.Client();

  Future<List<UserSearchResultModel>> searchStudents(String query) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/UserDetails').replace(queryParameters: {
      if (query.trim().isNotEmpty) 'search': query.trim(),
      // Students only. The API refuses an Accounting caller asking for any other role.
      'role': '5',
    });

    final res = await _client.get(uri, headers: headers);
    if (res.statusCode != 200) {
      String message = 'Search failed (${res.statusCode}).';
      try {
        message = (jsonDecode(res.body) as Map<String, dynamic>)['message'] as String? ?? message;
      } catch (_) {}
      throw ApiException(statusCode: res.statusCode, message: message);
    }

    return (jsonDecode(res.body) as List)
        .map((e) => UserSearchResultModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
