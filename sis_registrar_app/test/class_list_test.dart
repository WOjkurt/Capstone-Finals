import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_registrar_app/models/report_models.dart';
import 'package:sis_registrar_app/repositories/report_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/utils/report_pdf.dart';

class FakeAuthService implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {'Authorization': 'Bearer t'};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('class lists: one class or the whole term, parsed with students', () async {
    final asked = <String>[];
    final repo = ReportRepository(FakeAuthService(), client: MockClient((req) async {
      asked.add('${req.url.path}?${req.url.query}');
      return http.Response(
          jsonEncode([
            {
              'classId': 'c1', 'className': 'BSIT 1A', 'subjectCode': 'IT 101', 'subjectTitle': 'Intro', 'units': 3,
              'termLabel': '2026-2027 (1st Sem)', 'teacherName': 'Ben Teach', 'schedules': ['M/W/F 8:00 AM - 9:30 AM · R101'],
              'students': [
                {'name': 'CRUZ, Ana', 'lrn': '1234', 'programCode': 'BSIT', 'yearLevel': 1, 'sex': 'F'},
                {'name': 'LIM, Ben', 'programCode': 'BSIT', 'yearLevel': 1},
              ],
            }
          ]),
          200);
    }));

    final one = await repo.classLists('t1', classId: 'c1');
    await repo.classLists('t1');

    expect(asked, ['/api/reports/class-lists?termId=t1&classId=c1', '/api/reports/class-lists?termId=t1']);
    expect(one.single.students.map((s) => s.sex), ['F', null]);
    expect(one.single.schedules.single, contains('R101'));

    final bytes = await buildClassListsPdf([
      ...one,
      const ClassList(classId: 'c2', className: 'BSIT 1B', subjectCode: 'IT 102', subjectTitle: 'Prog'),
    ]);
    expect(utf8.decode(bytes.sublist(0, 5), allowMalformed: true), '%PDF-');
    expect((await buildClassListsPdf(const [])).length, greaterThan(100));
  });
}
