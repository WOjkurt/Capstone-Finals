import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/class_models.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';

String _extractMessage(String body) {
  try {
    final j = jsonDecode(body) as Map<String, dynamic>;
    if (j['findings'] is List && (j['findings'] as List).isNotEmpty) {
      final list = (j['findings'] as List);
      final details = list.map((f) {
        if (f is Map) {
          final msg = f['message']?.toString();
          final code = f['code']?.toString();
          final sc = f['subjectCode']?.toString();
          if (sc != null && sc.isNotEmpty) {
            return '$sc: ${msg ?? code}';
          }
          return msg ?? code ?? '';
        }
        return f.toString();
      }).where((s) => s.isNotEmpty).join('; ');
      final mainMsg = j['message'] ?? j['error'];
      return mainMsg != null ? '$mainMsg: $details' : details;
    }
    return (j['message'] ?? j['error'] ?? body).toString();
  } catch (_) {
    return body;
  }
}

class ClassRepository {
  final AuthService _auth;
  final http.Client _client;

  ClassRepository(this._auth, [http.Client? client])
      : _client = client ?? http.Client();

  Future<List<ClassModel>> getClasses({String? termId}) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/Classes').replace(
      queryParameters: termId != null && termId.isNotEmpty
          ? {'termId': termId}
          : null,
    );
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }
    final list = (jsonDecode(res.body) as List)
        .map((e) => ClassModel.fromJson(e as Map<String, dynamic>))
        .toList();

    list.sort((a, b) =>
        (a.subjectCode ?? '').compareTo(b.subjectCode ?? ''));
    return list;
  }

  Future<List<ClassRosterItemModel>> getClassRoster(String classId) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/studyloads/class/$classId');
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }
    final list = (jsonDecode(res.body) as List)
        .map((e) => ClassRosterItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    list.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return list;
  }

  Future<List<ClassRosterItemModel>> getStudentStudyLoads(
      String userId, String termId) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/studyloads/student/$userId')
        .replace(queryParameters: {'termId': termId});
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }
    final list = (jsonDecode(res.body) as List)
        .map((e) => ClassRosterItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    list.sort((a, b) =>
        a.subjectCode.toLowerCase().compareTo(b.subjectCode.toLowerCase()));
    return list;
  }

  Future<List<ProposedBlockItemModel>> getProposedBlock(
      String userId, String termId) async {
    final headers = await _auth.getAuthHeaders();
    final uri = Uri.parse('$baseUrl/api/studyloads/proposed-block').replace(
      queryParameters: {
        'userId': userId,
        'termId': termId,
      },
    );
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }
    final list = (jsonDecode(res.body) as List)
        .map((e) => ProposedBlockItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<List<EnrollBatchResponseModel>> enrollBatch({
    required String userId,
    required String termId,
    required List<String> classIds,
    bool asPending = false,
  }) async {
    final headers = await _auth.getAuthHeaders();
    headers['Content-Type'] = 'application/json';
    final uri = Uri.parse('$baseUrl/api/studyloads/enroll-batch');
    final body = jsonEncode({
      'userId': userId,
      'termId': termId,
      'classIds': classIds,
      'asPending': asPending,
    });
    final res = await _client.post(uri, headers: headers, body: body);
    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }
    final list = (jsonDecode(res.body) as List)
        .map((e) => EnrollBatchResponseModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<EnrollSingleResponseModel> enrollSingle({
    required String userId,
    required String classId,
    bool force = false,
    String? forceReason,
    bool asPending = false,
  }) async {
    final headers = await _auth.getAuthHeaders();
    headers['Content-Type'] = 'application/json';
    final uri = Uri.parse('$baseUrl/api/studyloads/enroll-single');
    final body = jsonEncode({
      'userId': userId,
      'classId': classId,
      'force': force,
      'forceReason': forceReason,
      'asPending': asPending,
    });
    final res = await _client.post(uri, headers: headers, body: body);
    if (res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: _extractMessage(res.body),
      );
    }
    return EnrollSingleResponseModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }
}

