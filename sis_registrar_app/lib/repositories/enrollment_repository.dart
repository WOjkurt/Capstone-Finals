import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/enrollment_models.dart';
import '../models/setup_models.dart';
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

class EnrollmentRepository {
  final AuthService _auth;
  EnrollmentRepository(this._auth);

  Future<List<EnrollmentResponseModel>> getUnprocessedResponses() async {
    final headers = await _auth.getAuthHeaders();
    final res =
        await http.get(Uri.parse('$baseUrl/api/EnrollmentResponses/unprocessed'), headers: headers);
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
    return (jsonDecode(res.body) as List)
        .map((e) => EnrollmentResponseModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EnrollmentApplicationModel>> getApplications(String? status) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/EnrollmentApplications')
        .replace(queryParameters: status != null ? {'status': status} : null);
    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
    return (jsonDecode(res.body) as List)
        .map((e) => EnrollmentApplicationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EnrollmentApplicationModel>> getApprovedApplications() async {
    final headers = await _auth.getAuthHeaders();
    final res = await http
        .get(Uri.parse('$baseUrl/api/EnrollmentApplications/approved'), headers: headers);
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
    return (jsonDecode(res.body) as List)
        .map((e) => EnrollmentApplicationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EnrollmentApplicationModel> getApplicationById(String id) async {
    final headers = await _auth.getAuthHeaders();
    final res =
        await http.get(Uri.parse('$baseUrl/api/EnrollmentApplications/$id'), headers: headers);
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
    return EnrollmentApplicationModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> createApplication({
    required String responseId,
    required int programId,
    required String termId,
    required EnrollmentFormModel form,
    required List<ContactModel> contacts,
  }) async {
    final headers = await _auth.getAuthHeaders();
    final body = jsonEncode({
      'responseID': responseId,
      'programID': programId,
      'termID': termId,
      'form': form.toJson(),
      'contacts': contacts.map((c) => c.toJson()).toList(),
    });
    final res = await http.post(
        Uri.parse('$baseUrl/api/EnrollmentApplications'),
        headers: headers,
        body: body);
    if (res.statusCode != 201) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
  }

  Future<void> approveApplication(String id, {int? yearLevel}) async {
    final headers = await _auth.getAuthHeaders();
    final body = yearLevel != null ? jsonEncode({'yearLevel': yearLevel}) : '{}';
    final res = await http.patch(
        Uri.parse('$baseUrl/api/EnrollmentApplications/$id/approve'),
        headers: headers,
        body: body);
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
  }

  Future<void> rejectApplication(String id, {String? reason}) async {
    final headers = await _auth.getAuthHeaders();
    final body = reason != null ? jsonEncode({'reason': reason}) : '{}';
    final res = await http.patch(
        Uri.parse('$baseUrl/api/EnrollmentApplications/$id/reject'),
        headers: headers,
        body: body);
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
  }

  Future<Map<String, dynamic>> linkAccount(String id, String email) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.patch(
        Uri.parse('$baseUrl/api/EnrollmentApplications/$id/link-account'),
        headers: headers,
        body: jsonEncode({'email': email}));
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> updateApplicationLrn(String id, String? lrn) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.patch(
      Uri.parse('$baseUrl/api/EnrollmentApplications/$id/lrn'),
      headers: headers,
      body: jsonEncode({'lrn': lrn}),
    );
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
  }

  Future<EnrollmentApplicationModel> updateApplicationSchoolEmail(String id, String? schoolEmail) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.patch(
      Uri.parse('$baseUrl/api/EnrollmentApplications/$id/school-email'),
      headers: headers,
      body: jsonEncode({'schoolEmail': schoolEmail}),
    );
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
    return EnrollmentApplicationModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}

class AcademicSetupRepository {
  final AuthService _auth;
  AcademicSetupRepository(this._auth);

  // Programs
  Future<List<AcademicProgramModel>> getPrograms() async {
    final headers = await _auth.getAuthHeaders();
    final res =
        await http.get(Uri.parse('$baseUrl/api/AcademicPrograms'), headers: headers);
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
    return (jsonDecode(res.body) as List)
        .map((e) => AcademicProgramModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AcademicProgramModel> createProgram(
      {required String code, required String name}) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.post(Uri.parse('$baseUrl/api/AcademicPrograms'),
        headers: headers,
        body: jsonEncode({'programCode': code, 'programName': name}));
    if (res.statusCode != 201) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
    return AcademicProgramModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AcademicProgramModel> updateProgram(
      int id, {required String code, required String name}) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.put(Uri.parse('$baseUrl/api/AcademicPrograms/$id'),
        headers: headers,
        body: jsonEncode({'programCode': code, 'programName': name}));
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
    return AcademicProgramModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteProgram(int id) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.delete(
        Uri.parse('$baseUrl/api/AcademicPrograms/$id'),
        headers: headers);
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
  }

  // Terms
  Future<List<AcademicTermModel>> getTerms() async {
    final headers = await _auth.getAuthHeaders();
    final res =
        await http.get(Uri.parse('$baseUrl/api/AcademicTerms'), headers: headers);
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
    return (jsonDecode(res.body) as List)
        .map((e) => AcademicTermModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AcademicTermModel> createTerm(
      {required String schoolYear, required int semester}) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.post(Uri.parse('$baseUrl/api/AcademicTerms'),
        headers: headers,
        body: jsonEncode({'schoolYear': schoolYear, 'semester': semester}));
    if (res.statusCode != 201) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
    return AcademicTermModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AcademicTermModel> updateTerm(String id,
      {required String schoolYear, required int semester}) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.put(Uri.parse('$baseUrl/api/AcademicTerms/$id'),
        headers: headers,
        body: jsonEncode({'schoolYear': schoolYear, 'semester': semester}));
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
    return AcademicTermModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteTerm(String id) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.delete(
        Uri.parse('$baseUrl/api/AcademicTerms/$id'),
        headers: headers);
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
  }

  Future<AcademicTermModel> activateTerm(String id) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.patch(
        Uri.parse('$baseUrl/api/AcademicTerms/$id/activate'),
        headers: headers);
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
    return AcademicTermModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  // Subjects
  Future<List<SubjectModel>> getSubjects({int? programId, int? yearLevel}) async {
    final headers = await _auth.getAuthHeaders();
    final params = <String, String>{};
    if (programId != null) params['programId'] = programId.toString();
    if (yearLevel != null) params['yearLevel'] = yearLevel.toString();
    final uri =
        Uri.parse('$baseUrl/api/Subjects').replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
    return (jsonDecode(res.body) as List)
        .map((e) => SubjectModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SubjectModel> createSubject(Map<String, dynamic> dto) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.post(Uri.parse('$baseUrl/api/Subjects'),
        headers: headers, body: jsonEncode(dto));
    if (res.statusCode != 201) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
    return SubjectModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<SubjectModel> updateSubject(String id, Map<String, dynamic> dto) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.put(Uri.parse('$baseUrl/api/Subjects/$id'),
        headers: headers, body: jsonEncode(dto));
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
    return SubjectModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteSubject(String id) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.delete(Uri.parse('$baseUrl/api/Subjects/$id'),
        headers: headers);
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
  }

  Future<List<PrerequisiteModel>> getPrerequisites(String subjectId) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.get(
        Uri.parse('$baseUrl/api/Subjects/$subjectId/prerequisites'),
        headers: headers);
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
    return (jsonDecode(res.body) as List)
        .map((e) => PrerequisiteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addPrerequisite(
      String subjectId, String prerequisiteSubjectId,
      {int requisiteType = 0}) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.post(
        Uri.parse('$baseUrl/api/Subjects/$subjectId/prerequisites'),
        headers: headers,
        body: jsonEncode({
          'prerequisiteSubjectID': prerequisiteSubjectId,
          'requisiteType': requisiteType,
        }));
    if (res.statusCode != 201) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
  }

  Future<void> removePrerequisite(String prerequisiteId) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.delete(
        Uri.parse('$baseUrl/api/Subjects/prerequisites/$prerequisiteId'),
        headers: headers);
    if (res.statusCode != 200) throw ApiException(statusCode: res.statusCode, message: _extractMessage(res.body));
  }
}
