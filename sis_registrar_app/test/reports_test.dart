import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/models/report_models.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/repositories/enrollment_repository.dart';
import 'package:sis_registrar_app/repositories/report_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/utils/csv.dart';
import 'package:sis_registrar_app/utils/file_download.dart';
import 'package:sis_registrar_app/utils/study_load_pdf.dart';
import 'package:sis_registrar_app/views/main_layout_view.dart';
import 'package:sis_registrar_app/views/reports_view.dart';

class FakeAuthService implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {'Authorization': 'Bearer t'};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSetupRepo implements AcademicSetupRepository {
  @override
  Future<List<AcademicTermModel>> getTerms() async => [
        AcademicTermModel.fromJson({'termID': 't-old', 'schoolYear': '2025-2026', 'semester': 2, 'isActive': false}),
        AcademicTermModel.fromJson({'termID': 't-now', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}),
      ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _decode(Uint8List bytes) => utf8.decode(bytes.sublist(3));

void main() {
  group('CSV', () {
    test('quotes cells with commas, quotes and line breaks', () {
      expect(csvCell('plain'), 'plain');
      expect(csvCell('Cruz, Ana'), '"Cruz, Ana"');
      expect(csvCell('say "hi"'), '"say ""hi"""');
      expect(csvCell(null), '');
      expect(csvCell(3), '3');
    });

    test('starts with a UTF-8 BOM and keeps accents', () {
      final bytes = buildCsv(['Name', 'Units'], [
        ['Peña, Ana', 3]
      ]);
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(_decode(bytes), 'Name,Units\r\n"Peña, Ana",3\r\n');
    });
  });

  test('repository calls each report with the term', () async {
    final paths = <String>[];
    final client = MockClient((req) async {
      paths.add('${req.url.path}?${req.url.query}');
      return http.Response(
          jsonEncode([
            {'teacherUserId': null, 'teacherName': 'Unassigned', 'classes': 2, 'units': 6.0, 'students': 0, 'subjectCodes': ['IT 101']}
          ]),
          200);
    });
    final repo = ReportRepository(FakeAuthService(), client: client);

    final loads = await repo.teacherLoads('t1');
    await repo.enrollmentSummary('t1');
    await repo.classSizes('t1');
    await repo.failedStudents('t1');

    expect(loads.single.isUnassigned, isTrue);
    expect(paths, [
      '/api/reports/teacher-loads?termId=t1',
      '/api/reports/enrollment-summary?termId=t1',
      '/api/reports/class-sizes?termId=t1',
      '/api/reports/failed-students?termId=t1',
    ]);
  });

  test('Reports is in the Registrar menu', () {
    expect(MainLayoutView.buildNavItems(role: 2, roleName: 'Registrar').map((i) => i['title']), contains('Reports'));
  });

  group('ReportsView', () {
    late List<String> requested;
    late List<(String, Uint8List)> downloads;

    setUp(() async {
      await getIt.reset();
      requested = [];
      downloads = [];
      downloadFile = (bytes, name, type) => downloads.add((name, bytes));
      getIt.registerSingleton<AcademicSetupRepository>(FakeSetupRepo());
      getIt.registerSingleton<ReportRepository>(ReportRepository(
        FakeAuthService(),
        client: MockClient((req) async {
          requested.add('${req.url.pathSegments.last}:${req.url.queryParameters['termId']}');
          final body = switch (req.url.pathSegments.last) {
            'enrollment-summary' => [
                {'programCode': 'BSIT', 'yearLevel': 1, 'enrolledStudents': 40, 'pendingOnlyStudents': 2},
                {'programCode': 'BSME', 'yearLevel': 1, 'enrolledStudents': 30, 'pendingOnlyStudents': 0},
              ],
            'enrollment-statistics' => [
                {'programCode': 'BSIT', 'male': [10, 8, 6, 4], 'female': [5, 4, 3, 2], 'sexNotRecorded': 2},
                {'programCode': 'BSME', 'male': [7, 0, 0, 0], 'female': [1, 0, 0, 0]},
              ],
            'failed-students' => [
                {'studentName': 'Ana Cruz', 'lrn': '1234', 'programCode': 'BSIT', 'yearLevel': 1, 'subjectCode': 'IT 101', 'subjectTitle': 'Intro', 'className': 'BSIT 1A', 'finalGrade': 5.0, 'teacherName': 'Ben'},
              ],
            _ => <Map<String, dynamic>>[],
          };
          return http.Response(jsonEncode(body), 200);
        }),
      ));
    });

    tearDown(() async => getIt.reset());

    Future<void> pump(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1500, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: ReportsView()));
      await tester.pumpAndSettle();
    }

    testWidgets('opens on the active term with the enrollment summary and a total row', (tester) async {
      await pump(tester);

      expect(requested, ['enrollment-summary:t-now']);
      expect(find.text('BSIT'), findsOneWidget);
      expect(find.text('TOTAL'), findsOneWidget);
      expect(find.text('70'), findsOneWidget);
    });

    testWidgets('Statistics: 1st to 4th year by M and F with totals, a note for missing sex, and its own printout', (tester) async {
      final printed = <String>[];
      final original = printPdf;
      printPdf = (bytes, name) async => printed.add(name);
      addTearDown(() => printPdf = original);
      await pump(tester);

      await tester.tap(find.text('Statistics'));
      await tester.pumpAndSettle();
      expect(requested.last, 'enrollment-statistics:t-now');
      for (final h in ['1st Year M', '4th Year F', 'Total M', 'Total F', 'Total']) {
        expect(find.text(h), findsOneWidget, reason: h);
      }
      // BSIT: 28 male + 14 female = 42; all programs: 35 male, 15 female, 50.
      expect(find.text('42'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.byKey(const ValueKey('report_note')), findsOneWidget);
      expect(find.textContaining('2 enrolled student(s) have no sex on record'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('print_report_button')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      await tester.pumpAndSettle();
      expect(printed, ['Enrollment_Statistics_2026_2027_1st_Sem_.pdf']);
    });

    testWidgets('switching report loads it; empty reports say so and cannot be downloaded', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Failed students'));
      await tester.pumpAndSettle();
      expect(find.text('Ana Cruz'), findsOneWidget);
      expect(find.text('5.00'), findsOneWidget);

      await tester.tap(find.text('Class sizes'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing to show for class sizes in this term.'), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(find.byKey(const ValueKey('download_csv_button'))).onPressed, isNull);
    });

    testWidgets('Download CSV saves the shown report with a clear file name', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('download_csv_button')));
      await tester.pump();

      final (name, bytes) = downloads.single;
      expect(name, startsWith('Enrollment_Summary_2026'));
      expect(name, endsWith('.csv'));
      final text = _decode(bytes);
      expect(text, startsWith('Program,Year level,Enrolled students,Pending only\r\n'));
      expect(text, contains('BSIT,Year 1,40,2'));
      expect(text, contains('TOTAL,,70,2'));
    });
  });

  test('report rows parse safely when fields are missing', () {
    expect(ClassSizeRow.fromJson({}).enrolled, 0);
    expect(FailedStudentRow.fromJson({'finalGrade': 5}).finalGrade, 5.0);
  });
}
