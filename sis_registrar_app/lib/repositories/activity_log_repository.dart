import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/activity_log_models.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';

class ActivityLogRepository {
  final AuthService _auth;
  final http.Client _client;
  ActivityLogRepository(this._auth, {http.Client? client}) : _client = client ?? http.Client();

  /// [from] and [to] are local dates; [to] is inclusive (the whole day).
  Future<ActivityLogPage> search({
    DateTime? from,
    DateTime? to,
    String? action,
    String? studentId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final headers = await _auth.getAuthHeaders();
    final params = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
      if (from != null) 'from': DateTime(from.year, from.month, from.day).toUtc().toIso8601String(),
      if (to != null) 'to': DateTime(to.year, to.month, to.day + 1).toUtc().toIso8601String(),
      if (action != null) 'action': action,
      if (studentId != null) 'studentId': studentId,
    };
    final res = await _client.get(
      Uri.parse('$baseUrl/api/activity-log').replace(queryParameters: params),
      headers: headers,
    );
    if (res.statusCode != 200) {
      String message = 'Request failed (${res.statusCode}).';
      try {
        message = (jsonDecode(res.body) as Map<String, dynamic>)['message'] as String? ?? message;
      } catch (_) {}
      throw ApiException(statusCode: res.statusCode, message: message);
    }
    return ActivityLogPage.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
