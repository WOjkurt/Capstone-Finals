import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_registrar_app/models/records_import_models.dart';
import 'package:sis_registrar_app/repositories/records_import_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/utils/error_handler.dart';
import 'package:sis_registrar_app/utils/file_pick.dart';
import 'package:sis_registrar_app/views/widgets/edit_student_email_dialog.dart';
import 'package:sis_registrar_app/views/widgets/records_import_dialog.dart';

class _FakeAuth implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {'Authorization': 'Bearer t', 'Content-Type': 'application/json'};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers POST /api/import/records like the API, recording each request's form fields.
class FakeImportApi {
  final calls = <Map<String, String>>[];
  final fileNames = <List<String>>[];

  late final repo = RecordsImportRepository(_FakeAuth(), client: MockClient.streaming((request, body) async {
    final raw = utf8.decode(await body.toBytes(), allowMalformed: true);
    final fields = <String, String>{};
    for (final m in RegExp(r'name="(\w+)"\r\n\r\n([^\r]*)').allMatches(raw)) {
      fields[m.group(1)!] = m.group(2)!;
    }
    calls.add(fields);
    fileNames.add([for (final m in RegExp(r'filename="([^"]+)"').allMatches(raw)) m.group(1)!]);
    final years = (fields['schoolYears'] ?? '').split(',').where((y) => y.isNotEmpty).toList();
    final dry = fields['dryRun'] == 'true';
    final result = {
      'dryRun': dry,
      'schoolYearsFound': ['2025-2026', '2024-2025'],
      'schoolYearsImported': years,
      'newStudents': years.isEmpty ? 0 : 258,
      'existingStudents': 0,
      'studentsPerProgram': years.isEmpty ? {} : {'BSIT': 137, 'BSME': 56},
      'studentsPerCurriculum': years.isEmpty ? {} : {'BSIT BSIT 2023': 137},
      'gradesPassed': years.isEmpty ? 0 : 2697,
      'gradesFailed': years.isEmpty ? 0 : 215,
      'dropped': years.isEmpty ? 0 : 42,
      'noGradeYet': years.isEmpty ? 0 : 4,
      'alreadyImported': 0,
      'termsCreated': years.isEmpty ? [] : ['2025-2026 (1st Sem)'],
      'gradesReleased': fields['releaseGrades'] == 'true',
      'problems': years.isEmpty
          ? []
          : [
              {'file': 'Grades', 'sheet': '2ND SEM_2025-2026', 'row': 877, 'message': 'Final grade "1..6" of IT 212A is not a valid grade; row skipped.'}
            ],
      'totalProblems': years.isEmpty ? 0 : 1,
      'notes': years.isEmpty ? [] : ['New students can\'t sign in until their school email is added on their profile.'],
    };
    return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(result))), 200);
  }));
}

void main() {
  test('RecordsImportProblem label says where the row is', () {
    const p = RecordsImportProblem(file: 'Grades', sheet: '1ST SEM_2025-2026', row: 12, message: 'Bad grade.');
    expect(p.label, 'Grades › 1ST SEM_2025-2026, row 12: Bad grade.');
    expect(const RecordsImportProblem(message: 'Program BSIE is not in Setup.').label, 'Program BSIE is not in Setup.');
  });

  testWidgets('choose the grades file → newest school year ticked → preview → import', (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final api = FakeImportApi();
    final picks = [PickedFile('GRADES.xlsx', Uint8List.fromList([1, 2])), PickedFile('STUDENTS.xlsx', Uint8List.fromList([3]))];
    pickFile = ({String accept = ''}) async => picks.removeAt(0);
    addTearDown(() => pickFile = ({String accept = ''}) async => null);

    bool? closed;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => closed = await showDialog<bool>(
                context: context, builder: (_) => RecordsImportDialog(repository: api.repo)),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('run_records_import'))).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('choose_grades_file')));
    await tester.pumpAndSettle();

    // First call only lists the years; then the newest is checked (dry run).
    expect(api.calls[0]['schoolYears'] ?? '', '');
    expect(api.calls[1], containsPair('schoolYears', '2025-2026'));
    expect(api.calls[1], containsPair('dryRun', 'true'));
    expect(tester.widget<FilterChip>(find.byKey(const ValueKey('year_2025-2026'))).selected, isTrue);
    expect(tester.widget<FilterChip>(find.byKey(const ValueKey('year_2024-2025'))).selected, isFalse);
    expect(find.text('258 new student(s)'), findsOneWidget);
    expect(find.text('2697 passed, 215 failed, 42 dropped, 4 without a final grade'), findsOneWidget);
    expect(find.textContaining('Grades › 2ND SEM_2025-2026, row 877'), findsOneWidget);

    // Adding the students file checks again with both files.
    await tester.tap(find.byKey(const ValueKey('choose_students_file')));
    await tester.pumpAndSettle();
    expect(api.fileNames.last, ['GRADES.xlsx', 'STUDENTS.xlsx']);

    await tester.tap(find.byKey(const ValueKey('release_grades_checkbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('run_records_import')));
    await tester.pumpAndSettle();

    expect(api.calls.last, containsPair('dryRun', 'false'));
    expect(api.calls.last, containsPair('releaseGrades', 'false'));
    expect(closed, isTrue);
    expect(find.textContaining('Imported SY 2025-2026: 258 new student(s)'), findsOneWidget);
  });

  testWidgets('unticking every school year clears the preview and disables Import', (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final api = FakeImportApi();
    pickFile = ({String accept = ''}) async => PickedFile('GRADES.xlsx', Uint8List(1));
    addTearDown(() => pickFile = ({String accept = ''}) async => null);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RecordsImportDialog(repository: api.repo))));
    await tester.tap(find.byKey(const ValueKey('choose_grades_file')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('year_2025-2026')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('records_import_summary')), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('run_records_import'))).onPressed, isNull);
  });

  testWidgets('ticking only an older school year turns on "only students already in the system"', (tester) async {
    tester.view.physicalSize = const Size(1400, 1300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final api = FakeImportApi();
    pickFile = ({String accept = ''}) async => PickedFile('GRADES.xlsx', Uint8List(1));
    addTearDown(() => pickFile = ({String accept = ''}) async => null);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RecordsImportDialog(repository: api.repo))));
    await tester.tap(find.byKey(const ValueKey('choose_grades_file')));
    await tester.pumpAndSettle();

    // Newest year ticked: the option is off.
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('only_existing_checkbox'))).value, isFalse);
    expect(api.calls.last['onlyExistingStudents'], 'false');

    // Switch to the older year only: the option turns on and the check runs with it.
    await tester.tap(find.byKey(const ValueKey('year_2024-2025')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('year_2025-2026')));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('only_existing_checkbox'))).value, isTrue);
    expect(api.calls.last, containsPair('schoolYears', '2024-2025'));
    expect(api.calls.last, containsPair('onlyExistingStudents', 'true'));

    // It can still be turned off by hand.
    await tester.tap(find.byKey(const ValueKey('only_existing_checkbox')));
    await tester.pumpAndSettle();
    expect(api.calls.last, containsPair('onlyExistingStudents', 'false'));
  });

  test('RecordsImportResult reads the left-out count', () {
    final r = RecordsImportResult.fromJson({'onlyExistingStudents': true, 'studentsNotInSystem': 41});
    expect(r.onlyExistingStudents, isTrue);
    expect(r.studentsNotInSystem, 41);
  });

  group('school email of an imported student', () {
    Future<List<String?>> open(WidgetTester tester, Future<String> Function(String, String) save) async {
      final results = <String?>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(await showDialog<String>(
                  context: context,
                  builder: (_) => EditStudentEmailDialog(userId: 'u1', studentName: 'Ana Dela Cruz', save: save))),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('only a school email is accepted; it is saved in lower case', (tester) async {
      final sent = <String>[];
      final results = await open(tester, (id, email) async {
        sent.add(email);
        return email;
      });
      await tester.enterText(find.byKey(const ValueKey('student_email_field')), 'ana@gmail.com');
      await tester.tap(find.byKey(const ValueKey('save_student_email')));
      await tester.pumpAndSettle();
      expect(find.textContaining('ends with @dbtc-cebu.edu.ph'), findsOneWidget);
      expect(sent, isEmpty);

      await tester.enterText(find.byKey(const ValueKey('student_email_field')), ' Ana.DelaCruz@dbtc-cebu.edu.ph ');
      await tester.tap(find.byKey(const ValueKey('save_student_email')));
      await tester.pumpAndSettle();
      expect(sent, ['ana.delacruz@dbtc-cebu.edu.ph']);
      expect(results, ['ana.delacruz@dbtc-cebu.edu.ph']);
    });

    testWidgets('an email already used shows the server message', (tester) async {
      await open(tester, (id, email) async =>
          throw ApiException(statusCode: 409, message: 'ana@dbtc-cebu.edu.ph already belongs to Ana Cruz.'));
      await tester.enterText(find.byKey(const ValueKey('student_email_field')), 'ana@dbtc-cebu.edu.ph');
      await tester.tap(find.byKey(const ValueKey('save_student_email')));
      await tester.pumpAndSettle();
      expect(find.text('ana@dbtc-cebu.edu.ph already belongs to Ana Cruz.'), findsOneWidget);
    });
  });
}
