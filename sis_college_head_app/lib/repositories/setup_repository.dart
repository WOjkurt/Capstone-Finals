import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/setup_models.dart';
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

class AcademicSetupRepository {
  final AuthService _auth;
  final http.Client _client;

  AcademicSetupRepository(this._auth, [http.Client? client])
      : _client = client ?? http.Client();

  Future<List<AcademicTermModel>> getTerms() async {
    final headers = await _auth.getAuthHeaders();
    final res = await _client.get(Uri.parse('$baseUrl/api/AcademicTerms'),
        headers: headers);
    if (res.statusCode != 200) {
      throw ApiException(
          statusCode: res.statusCode, message: _extractMessage(res.body));
    }
    return (jsonDecode(res.body) as List)
        .map((e) => AcademicTermModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
