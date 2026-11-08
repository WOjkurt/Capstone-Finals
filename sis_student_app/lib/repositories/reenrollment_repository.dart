import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/reenrollment_models.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';

/// Online enrollment for old students. The API always uses the signed-in student; nothing here names a student.
class ReenrollmentRepository {
  final AuthService _auth;
  ReenrollmentRepository(this._auth);

  Uri get _uri => Uri.parse('$baseUrl/api/me/reenrollment');

  Future<ReenrollmentStatus> status() async {
    final res = await http.get(_uri, headers: await _auth.getAuthHeaders());
    _check(res);
    return ReenrollmentStatus.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Returns the API's confirmation message.
  Future<String> submit({
    required String termId,
    required int yearLevel,
    required Map<String, dynamic> form,
    required List<Map<String, dynamic>> contacts,
  }) async {
    // "cityOfMunicipality" is an old second name for the city; sending it back would undo an edit.
    final cleanForm = Map<String, dynamic>.of(form)..remove('cityOfMunicipality');
    final headers = {...await _auth.getAuthHeaders(), 'Content-Type': 'application/json'};
    final res = await http.post(_uri,
        headers: headers,
        body: jsonEncode({
          'termId': termId,
          'yearLevel': yearLevel,
          'form': cleanForm,
          'contacts': contacts,
          'confirmed': true,
        }));
    _check(res);
    return (jsonDecode(res.body) as Map<String, dynamic>)['message'] as String? ?? 'Sent.';
  }

  static void _check(http.Response res) {
    if (res.statusCode == 200) return;
    String message = res.statusCode == 429
        ? 'Too many tries. Please wait a minute and try again.'
        : 'Something went wrong (${res.statusCode}). Please try again.';
    try {
      message = (jsonDecode(res.body) as Map<String, dynamic>)['message'] as String? ?? message;
    } catch (_) {}
    throw ApiException(statusCode: res.statusCode, message: message);
  }
}
