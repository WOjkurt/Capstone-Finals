import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/models/activity_log_models.dart';
import 'package:sis_registrar_app/repositories/activity_log_repository.dart';
import 'package:sis_registrar_app/repositories/enrollment_repository.dart';
import 'package:sis_registrar_app/repositories/grading_repository.dart';
import 'package:sis_registrar_app/repositories/report_repository.dart';
import 'package:sis_registrar_app/repositories/student_record_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/views/grades_view.dart';
import 'package:sis_registrar_app/views/main_layout_view.dart';

class FakeAuthService implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {'Authorization': 'Bearer t'};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _requests = <String>[];
final _bodies = <String, String>{};

Future<http.Response> _api(http.Request req) async {
  final path = req.url.path;
  _requests.add('${req.method} $path?${req.url.query}');
  if (req.body.isNotEmpty) _bodies[path] = req.body;

  if (path.endsWith('/api/AcademicTerms')) {
    return http.Response(
        jsonEncode([
          {'termID': 't1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true},
          {'termID': 't0', 'schoolYear': '2025-2026', 'semester': 2, 'isActive': false},
        ]),
        200);
  }
  if (path.contains('/grade-release')) {
    return http.Response(
        jsonEncode({
          'termID': 't1',
          'schoolYear': '2026-2027',
          'semester': 1,
          'isActive': true,
          'gradesReleasedAt': '2026-11-25T02:00:00Z',
          'unverifiedSheets': 1,
        }),
        200);
  }
  if (path.endsWith('/api/reports/grade-sheets')) {
    return http.Response(
        jsonEncode([
          {
            'classId': 'c1',
            'className': 'IT101-A',
            'subjectCode': 'IT 101',
            'subjectTitle': 'Intro to Computing',
            'units': 3.0,
            'termLabel': '2026-2027 (1st Sem)',
            'teacherName': 'Mr Dela Cruz',
            'verifiedAt': '2026-11-20T01:00:00Z',
            'verifiedByName': 'Ms Program Head',
            'students': [],
            'passed': 12,
            'failed': 1,
            'noFinalYet': 0,
          },
          {
            'classId': 'c2',
            'className': 'IT102-A',
            'subjectCode': 'IT 102',
            'subjectTitle': 'Programming 1',
            'units': 3.0,
            'termLabel': '2026-2027 (1st Sem)',
            'teacherName': null,
            'verifiedAt': null,
            'verifiedByName': null,
            'students': [],
            'passed': 8,
            'failed': 0,
            'noFinalYet': 2,
          },
        ]),
        200);
  }
  if (path.endsWith('/api/activity-log')) {
    return http.Response(
        jsonEncode({
          'items': [
            {
              'id': 'a1',
              'occurredAt': '2026-11-24T09:15:00Z',
              'actorName': 'Rita Reg',
              'actorRole': 2,
              'action': 'GRADE_MODIFIED',
              'studentUserId': 's1',
              'studentName': 'Ana Cruz',
              'termLabel': '2026-2027 (1st Sem)',
              'summary': 'IT 101 for Ana Cruz: final 2.50 → 1.75 — encoding error on the sheet',
            }
          ],
          'page': 1,
          'pageSize': 25,
          'totalCount': 1,
        }),
        200);
  }
  if (path.endsWith('/api/students/search')) {
    return http.Response(
        jsonEncode([
          {
            'userID': 's1',
            'firstname': 'Ana',
            'lastname': 'Cruz',
            'email': 'ana@dbtc-cebu.edu.ph',
            'studentID': '25060208',
            'programCode': 'BSIT',
            'yearLevel': 2,
            'role': 5,
          }
        ]),
        200);
  }
  if (path.contains('/grades')) return http.Response(jsonEncode([]), 200);
  return http.Response(jsonEncode([]), 200);
}

Future<void> _register() async {
  await getIt.reset();
  getIt.registerSingleton<AuthService>(FakeAuthService());
  getIt.registerLazySingleton<AcademicSetupRepository>(
      () => AcademicSetupRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<ReportRepository>(
      () => ReportRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<ActivityLogRepository>(
      () => ActivityLogRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<UserSearchRepository>(
      () => UserSearchRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<StudentGradeRepository>(
      () => StudentGradeRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<CreditedSubjectRepository>(
      () => CreditedSubjectRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<StudentRecordRepository>(
      () => StudentRecordRepository(getIt<AuthService>()));
}

void main() {
  setUp(() async {
    _requests.clear();
    _bodies.clear();
    await _register();
  });

  tearDown(() async => getIt.reset());

  testWidgets('Grades is its own menu page', (tester) async {
    final titles = MainLayoutView.buildNavItems(role: 2, roleName: 'Registrar')
        .map((i) => i['title'])
        .toList();
    expect(titles.contains('Grades'), isTrue);
    // After Pending loads and before Reports: the sheets are checked before anything is filed.
    expect(titles.indexOf('Grades'), titles.indexOf('Pending loads') + 1);
    expect(titles.indexOf('Grades'), lessThan(titles.indexOf('Reports')));
  });

  testWidgets('the Accounting Office never sees it', (tester) async {
    final titles = MainLayoutView.buildNavItems(role: 7, roleName: 'Accounting')
        .map((i) => i['title'])
        .toList();
    expect(titles, ['Student accounts']);
  });

  testWidgets('grade sheets name who verified them, and who did not', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: GradesView()));
      await tester.pumpAndSettle();

      expect(find.text('IT 101'), findsOneWidget);
      expect(find.text('IT 102'), findsOneWidget);
      // A class with no teacher is said plainly; 74 of 79 of them have none.
      expect(find.text('No teacher'), findsOneWidget);
      // One sheet checked, one not.
      expect(find.text('Not verified'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      // The verifying is somebody else's job, and the page says so rather than leaving a gap.
      expect(
        find.textContaining('Verified by a Program Head or the College Head'),
        findsOneWidget,
      );
      expect(find.textContaining('1 not verified'), findsOneWidget);

      expect(_requests.any((r) => r.contains('/api/reports/grade-sheets?termId=t1')), isTrue);
    }, () => MockClient(_api));
  });

  testWidgets('releasing a term says how many sheets went out unchecked', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: GradesView()));
      await tester.pumpAndSettle();

      expect(find.text('Release grades'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('grades_release_button')));
      await tester.pumpAndSettle();

      // The count is named before the button is pressed, not after.
      expect(find.textContaining('have not been verified yet'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm_grades_release')));
      await tester.pumpAndSettle();

      expect(_bodies['/api/AcademicTerms/t1/grade-release'], '{"released":true}');
      expect(find.textContaining('had not been verified'), findsOneWidget);
      // The button now offers the other direction.
      expect(find.text('Withhold grades'), findsOneWidget);
    }, () => MockClient(_api));
  });

  testWidgets('corrections already made are listed with their reason', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: GradesView()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('grades_corrections_tab')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('final 2.50 → 1.75 — encoding error on the sheet'),
        findsOneWidget,
      );
      expect(
        _requests.any((r) => r.contains('/api/activity-log?') && r.contains('GRADE_MODIFIED')),
        isTrue,
      );
    }, () => MockClient(_api));
  });

  testWidgets('a student can be found from the Grades page itself', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: GradesView()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('grades_corrections_tab')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('grades_student_search')), 'ana');
      await tester.tap(find.byKey(const ValueKey('grades_student_search_button')));
      await tester.pumpAndSettle();

      expect(find.text('Ana Cruz'), findsOneWidget);
      expect(find.text('25060208 · BSIT · Year 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('open_student_grades_s1')), findsOneWidget);
    }, () => MockClient(_api));
  });

  test('the log labels the codes the grade work writes', () {
    expect(kActivityActionLabels['GRADE_MODIFIED'], 'Grade corrected');
    expect(kActivityActionLabels['GRADE_SHEET_VERIFIED'], 'Grade sheet verified');
    expect(kActivityActionLabels['GRADES_RELEASED'], 'Grades released');
  });
}
