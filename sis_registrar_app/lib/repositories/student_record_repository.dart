import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/enrollment_models.dart';
import '../models/record_models.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';

class StudentRecordRepository {
  final AuthService _auth;
  final http.Client _client;
  StudentRecordRepository(this._auth, {http.Client? client}) : _client = client ?? http.Client();

  Future<StudentEvaluation> evaluation(String userId) async =>
      StudentEvaluation.fromJson(await _get('$userId/evaluation'));

  Future<Transcript> transcript(String userId) async => Transcript.fromJson(await _get('$userId/transcript'));

  Future<PersonalDetails> personalDetails(String userId) async =>
      PersonalDetails.fromJson(await _get('$userId/personal-details'));

  /// The student's latest enrollment form with parents/guardian, or null when there is none (read-only).
  Future<EnrollmentApplicationModel?> enrollmentForm(String userId) async {
    final app = (await _get('$userId/enrollment-form'))['application'];
    return app is Map<String, dynamic> ? EnrollmentApplicationModel.fromJson(app) : null;
  }

  /// Saves the Registrar's values. Send null or empty for "use the enrollment form".
  Future<PersonalDetails> savePersonalDetails(String userId, Map<String, String?> values) async =>
      PersonalDetails.fromJson(await _send('$userId/personal-details', values));

  /// Saves only the student's sex ("Male" or "Female"); their other details stay as they are.
  Future<void> setSex(String userId, String sex) => _send('$userId/sex', {'sex': sex});

  Future<Standing> standing(String userId) async => Standing.fromJson(await _get('$userId/standing'));

  /// Marking irregular starts the count of back major units; marking regular clears it.
  Future<Standing> setStanding(String userId, {required bool isRegular}) async =>
      Standing.fromJson(await _send('$userId/standing', {'isRegular': isRegular}));

  Future<List<IrregularStudent>> irregularStudents() async =>
      [for (final j in await _sendRaw('irregular', null) as List) IrregularStudent.fromJson(j as Map<String, dynamic>)];

  /// Moves the student to another program; their subjects and grades stay on record.
  Future<ShiftResult> shiftProgram(String userId, int programId, String reason) async =>
      ShiftResult.fromJson(await _send('$userId/shift', {'programId': programId, 'reason': reason}, post: true));

  Future<List<PreviousProgramSubject>> previousProgramSubjects(String userId) async => [
        for (final j in await _sendRaw('$userId/previous-program-subjects', null) as List)
          PreviousProgramSubject.fromJson(j as Map<String, dynamic>)
      ];

  Future<Map<String, dynamic>> _get(String path) => _send(path, null);

  Future<Map<String, dynamic>> _send(String path, Object? body, {bool post = false}) async =>
      await _sendRaw(path, body, post: post) as Map<String, dynamic>;

  /// GET without a [body]; with one, PUT (or POST when [post] is true).
  Future<Object?> _sendRaw(String path, Object? body, {bool post = false}) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/student-records/$path');
    final json = {...headers, 'Content-Type': 'application/json'};
    final res = body == null
        ? await _client.get(uri, headers: headers)
        : post
            ? await _client.post(uri, headers: json, body: jsonEncode(body))
            : await _client.put(uri, headers: json, body: jsonEncode(body));
    if (res.statusCode != 200) {
      String message = 'Request failed (${res.statusCode}).';
      try {
        message = (jsonDecode(res.body) as Map<String, dynamic>)['message'] as String? ?? message;
      } catch (_) {}
      throw ApiException(statusCode: res.statusCode, message: message);
    }
    return jsonDecode(res.body);
  }
}
