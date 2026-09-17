import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/class_models.dart';
import '../models/grading_models.dart';
import '../models/setup_models.dart';
import '../models/student_models.dart';
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

class StudentRepository {
  final AuthService _auth;

  StudentRepository(this._auth);

  Future<AcademicTermModel?> getActiveTerm() async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/academicterms/active');
    final res = await http.get(uri, headers: headers);

    if (res.statusCode == 404) {
      return null;
    }

    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return AcademicTermModel.fromJson(data);
  }

  Future<List<StudentScheduleItemModel>> getMySchedule(
    String userId,
    String termId,
  ) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/studyloads/student/$userId')
        .replace(queryParameters: {'termId': termId});
    final res = await http.get(uri, headers: headers);

    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }

    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => StudentScheduleItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AcademicTermModel>> getAllTerms() async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/academicterms');
    final res = await http.get(uri, headers: headers);

    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }

    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => AcademicTermModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<GradeClearanceModel>> getGradeClearances(String userId) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/gradeclearances/$userId');
    final res = await http.get(uri, headers: headers);

    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }

    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => GradeClearanceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<GradeModel>> getGrades(String userId, String termId) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/grades/student/$userId')
        .replace(queryParameters: {'termId': termId});
    final res = await http.get(uri, headers: headers);

    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }

    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => GradeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StudentProfileModel> getMyProfile() async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/userdetails/me');
    final res = await http.get(uri, headers: headers);

    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return StudentProfileModel.fromJson(data);
  }
}
