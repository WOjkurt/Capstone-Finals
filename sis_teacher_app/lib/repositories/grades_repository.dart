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

class GradesRepository {
  final AuthService _auth;

  GradesRepository(this._auth);

  Future<List<GradeModel>> getClassGrades(String classId) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/api/grades/class/$classId'),
      headers: headers,
    );

    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }

    return (jsonDecode(res.body) as List)
        .map((e) => GradeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GradeModel> submitGrade(
    String studyLoadId, {
    double? midtermGrade,
    double? finalGrade,
  }) async {
    final headers = await _auth.getAuthHeaders();
    final body = jsonEncode({
      'studyLoadId': studyLoadId,
      'midtermGrade': midtermGrade,
      'finalGrade': finalGrade,
    });

    final res = await http.post(
      Uri.parse('$baseUrl/api/grades/submit'),
      headers: headers,
      body: body,
    );

    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }

    return GradeModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<GradeBatchResultModel> submitGradeBatch(SubmitGradeBatchModel batch) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/api/grades/submit-batch'),
      headers: headers,
      body: jsonEncode(batch.toJson()),
    );

    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }

    return GradeBatchResultModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }
}
