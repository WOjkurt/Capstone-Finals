import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';

/// The summer unit limits the Registrar can change.
class UnitLimitSettings {
  final double summerMaxUnits;
  final double graduatingSummerMaxUnits;
  final String? updatedBy;
  final DateTime? updatedAt;

  const UnitLimitSettings({
    required this.summerMaxUnits,
    required this.graduatingSummerMaxUnits,
    this.updatedBy,
    this.updatedAt,
  });

  factory UnitLimitSettings.fromJson(Map<String, dynamic> j) => UnitLimitSettings(
        summerMaxUnits: (j['summerMaxUnits'] as num?)?.toDouble() ?? 0,
        graduatingSummerMaxUnits: (j['graduatingSummerMaxUnits'] as num?)?.toDouble() ?? 0,
        updatedBy: j['updatedBy'] as String?,
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '')?.toLocal(),
      );
}

class SchoolSettingsRepository {
  final AuthService _auth;
  final http.Client _client;
  SchoolSettingsRepository(this._auth, {http.Client? client}) : _client = client ?? http.Client();

  Future<UnitLimitSettings> getUnitLimits() => _send(null);

  Future<UnitLimitSettings> saveUnitLimits({required double summer, required double graduating}) =>
      _send({'summerMaxUnits': summer, 'graduatingSummerMaxUnits': graduating});

  Future<UnitLimitSettings> _send(Object? body) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/school-settings/unit-limits');
    final res = body == null
        ? await _client.get(uri, headers: headers)
        : await _client.put(uri, headers: {...headers, 'Content-Type': 'application/json'}, body: jsonEncode(body));
    if (res.statusCode != 200) {
      String message = 'Request failed (${res.statusCode}).';
      try {
        message = (jsonDecode(res.body) as Map<String, dynamic>)['message'] as String? ?? message;
      } catch (_) {}
      throw ApiException(statusCode: res.statusCode, message: message);
    }
    return UnitLimitSettings.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
