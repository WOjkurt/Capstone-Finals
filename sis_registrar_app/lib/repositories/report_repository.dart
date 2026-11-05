import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/report_models.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';

class ReportRepository {
  final AuthService _auth;
  final http.Client _client;
  ReportRepository(this._auth, {http.Client? client}) : _client = client ?? http.Client();

  Future<List<Map<String, dynamic>>> _get(String report, String? termId, {Map<String, String> extra = const {}}) async {
    final headers = await _auth.getAuthHeaders();
    final query = {if (termId != null) 'termId': termId, ...extra};
    final res = await _client.get(
      Uri.parse('$baseUrl/api/reports/$report').replace(queryParameters: query.isEmpty ? null : query),
      headers: headers,
    );
    if (res.statusCode != 200) {
      String message = 'Request failed (${res.statusCode}).';
      try {
        message = (jsonDecode(res.body) as Map<String, dynamic>)['message'] as String? ?? message;
      } catch (_) {}
      throw ApiException(statusCode: res.statusCode, message: message);
    }
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  Future<List<EnrollmentSummaryRow>> enrollmentSummary(String termId) async =>
      (await _get('enrollment-summary', termId)).map(EnrollmentSummaryRow.fromJson).toList();

  Future<List<ClassSizeRow>> classSizes(String termId) async =>
      (await _get('class-sizes', termId)).map(ClassSizeRow.fromJson).toList();

  Future<List<FailedStudentRow>> failedStudents(String termId) async =>
      (await _get('failed-students', termId)).map(FailedStudentRow.fromJson).toList();

  Future<List<TeacherLoadRow>> teacherLoads(String termId) async =>
      (await _get('teacher-loads', termId)).map(TeacherLoadRow.fromJson).toList();

  Future<List<EnrollmentStatisticsRow>> enrollmentStatistics(String termId) async =>
      (await _get('enrollment-statistics', termId)).map(EnrollmentStatisticsRow.fromJson).toList();

  /// Every class of the term, or just [classId].
  Future<List<ClassList>> classLists(String termId, {String? classId}) async =>
      (await _get('class-lists', termId, extra: {if (classId != null) 'classId': classId})).map(ClassList.fromJson).toList();

  Future<List<MissingSexRow>> studentsMissingSex(String termId) async =>
      (await _get('missing-sex', termId)).map(MissingSexRow.fromJson).toList();

  /// Not tied to a term.
  Future<List<TransfereeRow>> transferees() async =>
      (await _get('transferees', null)).map(TransfereeRow.fromJson).toList();
}
