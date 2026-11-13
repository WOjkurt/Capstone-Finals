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

/// Setup → Dean's list rules. Units are always the student's regular study load.
class DeansListRules {
  final double maxGwa;
  final double worstGrade;
  final String? updatedBy;
  final DateTime? updatedAt;

  const DeansListRules({required this.maxGwa, required this.worstGrade, this.updatedBy, this.updatedAt});

  factory DeansListRules.fromJson(Map<String, dynamic> j) => DeansListRules(
        maxGwa: (j['maxGwa'] as num?)?.toDouble() ?? 1.7,
        worstGrade: (j['worstGrade'] as num?)?.toDouble() ?? 2.3,
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

  Future<DeansListRules> getDeansListRules() async => DeansListRules.fromJson(await _raw('deans-list', null));

  Future<DeansListRules> saveDeansListRules({required double maxGwa, required double worstGrade}) async =>
      DeansListRules.fromJson(await _raw('deans-list', {'maxGwa': maxGwa, 'worstGrade': worstGrade}));

  Future<UnitLimitSettings> _send(Object? body) async => UnitLimitSettings.fromJson(await _raw('unit-limits', body));

  Future<Map<String, dynamic>> _raw(String path, Object? body) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/school-settings/$path');
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
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
