import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/public_enrollment_models.dart';
import '../utils/error_handler.dart';

/// Applying to DBTC with no account yet.
///
/// The only repository in the app that sends no Authorization header, because the person using
/// it has nothing to sign in with. It therefore takes no AuthService: there is no token to
/// forget to attach, and no signed-in student's identity anywhere near these two calls.
class PublicEnrollmentRepository {
  Uri get _uri => Uri.parse('$baseUrl/api/public/enrollment');
  Uri get _statusUri => Uri.parse('$baseUrl/api/public/enrollment/status');

  /// Whether anyone may apply today, and the courses to choose from.
  Future<PublicEnrollmentStatus> status() async {
    final res = await http.get(_statusUri);
    _check(res);
    return PublicEnrollmentStatus.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<PublicEnrollmentReceipt> submit({
    required String email,
    required Map<String, dynamic> form,
    required List<Map<String, dynamic>> contacts,
  }) async {
    // "cityOfMunicipality" is an old second name for the city; sending both confuses the server.
    final cleanForm = Map<String, dynamic>.of(form)..remove('cityOfMunicipality');
    final res = await http.post(
      _uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'emailAddress': email, 'form': cleanForm, 'contacts': contacts}),
    );
    _check(res);
    return PublicEnrollmentReceipt.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
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
