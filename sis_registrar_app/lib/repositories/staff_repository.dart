import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/staff_model.dart';
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

class StaffRepository {
  final AuthService _auth;

  StaffRepository(this._auth);

  Future<List<StaffModel>> getAllStaff() async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/api/admin/staff'),
      headers: headers,
    );

    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }

    final data = jsonDecode(res.body) as List;
    return data
        .map((e) => StaffModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StaffModel> createStaff(CreateStaffRequest request) async {
    final headers = await _auth.getAuthHeaders();
    headers['Content-Type'] = 'application/json';

    final res = await http.post(
      Uri.parse('$baseUrl/api/admin/staff'),
      headers: headers,
      body: jsonEncode(request.toJson()),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }

    return StaffModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<StaffModel> disableStaff(String id) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.patch(
      Uri.parse('$baseUrl/api/admin/staff/$id/disable'),
      headers: headers,
      body: '{}',
    );

    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }

    return StaffModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<StaffModel> reactivateStaff(String id) async {
    final headers = await _auth.getAuthHeaders();
    final res = await http.patch(
      Uri.parse('$baseUrl/api/admin/staff/$id/reactivate'),
      headers: headers,
      body: '{}',
    );

    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }

    return StaffModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<StaffModel> updateStaff(String id, UpdateStaffRequest request) async {
    final headers = await _auth.getAuthHeaders();
    headers['Content-Type'] = 'application/json';

    final res = await http.patch(
      Uri.parse('$baseUrl/api/admin/staff/$id'),
      headers: headers,
      body: jsonEncode(request.toJson()),
    );

    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }

    return StaffModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
