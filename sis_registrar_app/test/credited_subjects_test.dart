import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/models/grading_models.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/repositories/enrollment_repository.dart';
import 'package:sis_registrar_app/repositories/grading_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/views/widgets/credited_subjects_dialog.dart';
import 'package:sis_registrar_app/views/widgets/student_grades_dialog.dart';
import 'package:sis_registrar_app/models/school_models.dart';
import 'package:sis_registrar_app/repositories/accredited_school_repository.dart';

class FakeAuthService implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {'Authorization': 'Bearer t'};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCreditRepo implements CreditedSubjectRepository {
  final List<CreditedSubjectModel> credits = [];
  Map<String, String?>? lastCreate;
  Map<String, String?>? lastUpdate;
  String? deletedId;
  String? failWith;

  @override
  Future<List<CreditedSubjectModel>> getForStudent(String userId) async => List.of(credits);

  @override
  Future<CreditedSubjectModel> create({
    required String userId,
    required String subjectId,
    required String sourceSchool,
    String? sourceSubjectCode,
    String? grade,
    String? schoolYear,
    required double creditedUnits,
    bool crossEnrollment = false,
    String? termId,
  }) async {
    if (failWith != null) throw Exception(failWith);
    lastCreate = {
      'subjectId': subjectId, 'school': sourceSchool, 'code': sourceSubjectCode, 'grade': grade, 'sy': schoolYear,
      'units': '$creditedUnits', 'cross': '$crossEnrollment', 'termId': termId,
    };
    final c = CreditedSubjectModel(
        creditedSubjectId: 'c-$subjectId', subjectId: subjectId, subjectCode: 'IT 101', subjectTitle: 'Intro', sourceSchool: sourceSchool, grade: grade);
    credits.add(c);
    return c;
  }

  @override
  Future<CreditedSubjectModel> update({
    required String creditedSubjectId,
    required String subjectId,
    required String sourceSchool,
    String? sourceSubjectCode,
    String? grade,
    String? schoolYear,
    required double creditedUnits,
    bool crossEnrollment = false,
    String? termId,
  }) async {
    if (failWith != null) throw Exception(failWith);
    lastUpdate = {
      'id': creditedSubjectId, 'subjectId': subjectId, 'school': sourceSchool, 'code': sourceSubjectCode,
      'grade': grade, 'sy': schoolYear, 'units': '$creditedUnits', 'cross': '$crossEnrollment', 'termId': termId,
    };
    final i = credits.indexWhere((c) => c.creditedSubjectId == creditedSubjectId);
    final old = credits[i];
    final updated = CreditedSubjectModel(
      creditedSubjectId: old.creditedSubjectId,
      subjectId: subjectId,
      subjectCode: subjectId == 's1' ? 'IT 101' : 'GEC 101',
      subjectTitle: subjectId == 's1' ? 'Intro' : 'Self',
      units: 3,
      sourceSchool: sourceSchool,
      sourceSubjectCode: sourceSubjectCode,
      grade: grade,
      schoolYear: schoolYear,
      creditedUnits: creditedUnits,
      kind: crossEnrollment ? 2 : 1,
      termId: termId,
      termLabel: termId == null ? null : '2026-2027 (1st Sem)',
    );
    credits[i] = updated;
    return updated;
  }

  @override
  Future<void> delete(String creditedSubjectId) async {
    deletedId = creditedSubjectId;
    credits.removeWhere((c) => c.creditedSubjectId == creditedSubjectId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSetupRepo implements AcademicSetupRepository {
  @override
  Future<List<SubjectModel>> getSubjects({int? programId, int? yearLevel}) async => [
        SubjectModel.fromJson({'subjectID': 's1', 'subjectCode': 'IT 101', 'subjectTitle': 'Intro', 'programID': 1, 'yearLevel': 1, 'lecUnits': 3}),
        SubjectModel.fromJson({'subjectID': 's2', 'subjectCode': 'GEC 101', 'subjectTitle': 'Self', 'programID': 1, 'yearLevel': 1, 'lecUnits': 3}),
      ];

  @override
  Future<List<AcademicTermModel>> getTerms() async =>
      [AcademicTermModel.fromJson({'termID': 't1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true})];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSchoolRepo implements AccreditedSchoolRepository {
  @override
  Future<List<AccreditedSchool>> getAll() async => const [
        AccreditedSchool(schoolId: 'a', name: 'Cebu Technological University'),
        AccreditedSchool(schoolId: 'b', name: 'University of San Carlos'),
      ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGradeRepo implements StudentGradeRepository {
  List<StudentGradeModel> grades = [];
  @override
  Future<List<StudentGradeModel>> getStudentGrades(String userId) async => grades;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _student = UserSearchResultModel(
    userId: 'u1', firstname: 'Tina', lastname: 'Transfer', email: 't@x.com', role: 5, programId: 1, programCode: 'BSIT');

void main() {
  test('repository: list, create and delete call the right endpoints', () async {
    final calls = <String>[];
    final client = MockClient((req) async {
      calls.add('${req.method} ${req.url.path}');
      if (req.method == 'GET') {
        return http.Response(jsonEncode([
          {'creditedSubjectId': 'c1', 'subjectId': 's1', 'subjectCode': 'IT 101', 'subjectTitle': 'Intro', 'units': 3, 'sourceSchool': 'Cebu Tech', 'grade': '1.75'}
        ]), 200);
      }
      if (req.method == 'POST') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['sourceSchool'], 'Cebu Tech');
        return http.Response(jsonEncode({'creditedSubjectId': 'c2', 'subjectId': body['subjectId'], 'subjectCode': 'GEC 101', 'subjectTitle': 'Self', 'sourceSchool': 'Cebu Tech'}), 200);
      }
      if (req.method == 'PUT') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body, {
          'subjectId': 's2',
          'sourceSchool': 'Cebu Technological University',
          'sourceSubjectCode': 'CS 101',
          'grade': '2.0',
          'schoolYear': null,
          'creditedUnits': 1.5,
          'kind': 2,
          'termId': 't1',
        });
        return http.Response(jsonEncode({'creditedSubjectId': 'c1', 'subjectId': 's2', 'subjectCode': 'GEC 101', 'subjectTitle': 'Self', 'units': 3, 'creditedUnits': 1.5, 'sourceSchool': body['sourceSchool'], 'kind': 2, 'termId': 't1'}), 200);
      }
      return http.Response('', 204);
    });
    final repo = CreditedSubjectRepository(FakeAuthService(), client: client);

    final list = await repo.getForStudent('u1');
    expect(list.single.grade, '1.75');
    expect((await repo.create(userId: 'u1', subjectId: 's2', sourceSchool: 'Cebu Tech', creditedUnits: 3)).subjectCode, 'GEC 101');
    final fixedUp = await repo.update(
        creditedSubjectId: 'c1',
        subjectId: 's2',
        sourceSchool: 'Cebu Technological University',
        sourceSubjectCode: 'CS 101',
        grade: '2.0',
        creditedUnits: 1.5,
        crossEnrollment: true,
        termId: 't1');
    expect((fixedUp.subjectCode, fixedUp.creditedUnits, fixedUp.isPartial, fixedUp.termId), ('GEC 101', 1.5, true, 't1'));
    await repo.delete('c1');

    expect(calls, [
      'GET /api/credited-subjects/student/u1',
      'POST /api/credited-subjects',
      'PUT /api/credited-subjects/c1',
      'DELETE /api/credited-subjects/c1',
    ]);
  });

  test('a credit resolves an earlier failure', () {
    const failed = StudentGradeModel(gradeId: 'g', subjectCode: 'IT 101', remarks: 2, loadStatus: 1);
    expect(unresolvedFailedSubjects([failed]), ['IT 101']);
    expect(unresolvedFailedSubjects([failed], creditedCodes: ['IT 101']), isEmpty);
  });

  group('dialogs', () {
    late FakeCreditRepo credits;
    late FakeGradeRepo grades;

    setUp(() async {
      await getIt.reset();
      credits = FakeCreditRepo();
      grades = FakeGradeRepo();
      getIt.registerSingleton<CreditedSubjectRepository>(credits);
      getIt.registerSingleton<AcademicSetupRepository>(FakeSetupRepo());
      getIt.registerSingleton<StudentGradeRepository>(grades);
    });

    tearDown(() async => getIt.reset());

    Future<void> pump(WidgetTester tester, Widget child) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
      await tester.pumpAndSettle();
    }

    testWidgets('add a credit: subject and school are required, then it is saved and listed', (tester) async {
      await pump(tester, const CreditedSubjectsDialog(student: _student));
      expect(find.text('No credited subjects yet.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('add_credit_button')));
      await tester.pump();
      expect(find.text('Choose the DBTC subject.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('credit_subject_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('IT 101 — Intro').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add_credit_button')));
      await tester.pump();
      expect(find.text('Enter the school where it was taken.'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('credit_school_field')), 'Cebu Tech');
      await tester.enterText(find.byKey(const ValueKey('credit_grade_field')), '1.75');
      await tester.tap(find.byKey(const ValueKey('add_credit_button')));
      await tester.pumpAndSettle();

      expect(credits.lastCreate!['subjectId'], 's1');
      expect(credits.lastCreate!['grade'], '1.75');
      expect(credits.lastCreate!['units'], '3.0');   // starts at the subject's full units
      expect(find.textContaining('From Cebu Tech'), findsOneWidget);
      // School stays filled for the next subject.
      expect(tester.widget<TextField>(find.byKey(const ValueKey('credit_school_field'))).controller!.text, 'Cebu Tech');
    });

    testWidgets('the school field suggests accredited schools and warns about unlisted names', (tester) async {
      getIt.registerSingleton<AccreditedSchoolRepository>(FakeSchoolRepo());
      await pump(tester, const CreditedSubjectsDialog(student: _student));

      await tester.enterText(find.byKey(const ValueKey('credit_school_field')), 'san');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('school_option_University of San Carlos')), findsOneWidget);
      expect(find.byKey(const ValueKey('school_option_Cebu Technological University')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('school_option_University of San Carlos')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const ValueKey('credit_school_field'))).controller!.text, 'University of San Carlos');
      expect(find.textContaining('Not on the accredited list'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('credit_school_field')), 'Some Other College');
      await tester.pumpAndSettle();
      expect(find.textContaining('Not on the accredited list'), findsOneWidget);
    });

    testWidgets('partial units show a note; cross-enrollment needs the DBTC term', (tester) async {
      await pump(tester, const CreditedSubjectsDialog(student: _student));

      await tester.tap(find.text('Cross-enrolled while at DBTC'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('credit_school_year_field')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('credit_subject_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('IT 101 — Intro').last);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const ValueKey('credit_units_field'))).controller!.text, '3');

      await tester.enterText(find.byKey(const ValueKey('credit_units_field')), '2');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('credit_partial_note')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('credit_units_field')), '4');
      await tester.enterText(find.byKey(const ValueKey('credit_school_field')), 'USC');
      await tester.tap(find.byKey(const ValueKey('add_credit_button')));
      await tester.pump();
      expect(find.text('This subject has only 3 units.'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('credit_units_field')), '2');
      await tester.tap(find.byKey(const ValueKey('add_credit_button')));
      await tester.pump();
      expect(find.text('Choose the DBTC term it was cross-enrolled in.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('credit_term_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026-2027 (1st Sem)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add_credit_button')));
      await tester.pumpAndSettle();
      expect(credits.lastCreate!['units'], '2.0');
      expect(credits.lastCreate!['cross'], 'true');
      expect(credits.lastCreate!['termId'], 't1');
      expect(credits.lastCreate!['sy'], isNull);
    });

    testWidgets('server errors are shown', (tester) async {
      credits.failWith = 'The student already passed IT 101 at DBTC.';
      await pump(tester, const CreditedSubjectsDialog(student: _student));

      await tester.tap(find.byKey(const ValueKey('credit_subject_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('IT 101 — Intro').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('credit_school_field')), 'Cebu Tech');
      await tester.tap(find.byKey(const ValueKey('add_credit_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('already passed IT 101'), findsOneWidget);
    });

    testWidgets('every detail of a recorded credit can be corrected', (tester) async {
      getIt.registerSingleton<AccreditedSchoolRepository>(FakeSchoolRepo());
      credits.credits.add(const CreditedSubjectModel(
          creditedSubjectId: 'c1', subjectId: 's1', subjectCode: 'IT 101', subjectTitle: 'Intro',
          units: 3, sourceSchool: 'Cebu Tecnological Univerity', sourceSubjectCode: 'CS 1O1',
          grade: '1.75', schoolYear: '2025-2026'));
      await pump(tester, const CreditedSubjectsDialog(student: _student));
      expect(find.textContaining('From Cebu Tecnological Univerity'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('edit_credit_IT 101')));
      await tester.pumpAndSettle();
      // Opens on what was recorded.
      String fieldText(String key) =>
          tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;
      expect(fieldText('edit_credit_school_field'), 'Cebu Tecnological Univerity');
      expect(fieldText('edit_credit_their_code_field'), 'CS 1O1');
      expect(fieldText('edit_credit_grade_field'), '1.75');
      expect(fieldText('edit_credit_school_year_field'), '2025-2026');
      expect(fieldText('edit_credit_units_field'), '3');
      expect(find.text('Y1 · IT 101 — Intro'), findsOneWidget);

      // The accredited list suggests the right spelling here too.
      await tester.enterText(find.byKey(const ValueKey('edit_credit_school_field')), 'Cebu Tech');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('school_option_Cebu Technological University')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('edit_credit_their_code_field')), 'CS 101');
      await tester.enterText(find.byKey(const ValueKey('edit_credit_grade_field')), '2.00');
      await tester.enterText(find.byKey(const ValueKey('edit_credit_units_field')), '1.5');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('edit_credit_partial_note')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save_credit_edit_button')));
      await tester.pumpAndSettle();

      expect(credits.lastUpdate, {
        'id': 'c1', 'subjectId': 's1', 'school': 'Cebu Technological University', 'code': 'CS 101',
        'grade': '2.00', 'sy': '2025-2026', 'units': '1.5', 'cross': 'false', 'termId': null,
      });
      expect(find.textContaining('From Cebu Technological University · as CS 101 · grade 2.00'), findsOneWidget);
      expect(find.textContaining('1.5 of 3 units (partial, still to take)'), findsOneWidget);
    });

    testWidgets('a credit can be moved to another subject and turned into a cross-enrollment', (tester) async {
      credits.credits.add(const CreditedSubjectModel(
          creditedSubjectId: 'c1', subjectId: 's1', subjectCode: 'IT 101', subjectTitle: 'Intro',
          units: 3, sourceSchool: 'USC', schoolYear: '2025-2026'));
      await pump(tester, const CreditedSubjectsDialog(student: _student));

      await tester.tap(find.byKey(const ValueKey('edit_credit_IT 101')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit_credit_subject_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('GEC 101 — Self').last);
      await tester.pumpAndSettle();
      // The new subject brings its own units.
      expect(tester.widget<TextField>(find.byKey(const ValueKey('edit_credit_units_field'))).controller!.text, '3');

      await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('edit_credit_kind')), matching: find.text('Cross-enrolled while at DBTC')));
      await tester.pumpAndSettle();
      // A cross-enrollment takes its school year from the term, so that field goes away.
      expect(find.byKey(const ValueKey('edit_credit_school_year_field')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('save_credit_edit_button')));
      await tester.pump();
      expect(find.text('Choose the DBTC term it was cross-enrolled in.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('edit_credit_term_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026-2027 (1st Sem)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save_credit_edit_button')));
      await tester.pumpAndSettle();

      expect(credits.lastUpdate!['subjectId'], 's2');
      expect(credits.lastUpdate!['cross'], 'true');
      expect(credits.lastUpdate!['termId'], 't1');
      expect(credits.lastUpdate!['sy'], isNull);
      expect(find.textContaining('Cross-enrolled at USC in 2026-2027 (1st Sem)'), findsOneWidget);
    });

    testWidgets('the correction dialog checks the fields before saving', (tester) async {
      credits.credits.add(const CreditedSubjectModel(
          creditedSubjectId: 'c1', subjectId: 's1', subjectCode: 'IT 101', subjectTitle: 'Intro',
          units: 3, sourceSchool: 'Cebu Tech'));
      await pump(tester, const CreditedSubjectsDialog(student: _student));

      await tester.tap(find.byKey(const ValueKey('edit_credit_IT 101')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('edit_credit_school_field')), '   ');
      await tester.tap(find.byKey(const ValueKey('save_credit_edit_button')));
      await tester.pump();
      expect(find.text('Enter the school where it was taken.'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('edit_credit_school_field')), 'Cebu Tech');
      await tester.enterText(find.byKey(const ValueKey('edit_credit_units_field')), '4');
      await tester.tap(find.byKey(const ValueKey('save_credit_edit_button')));
      await tester.pump();
      expect(find.text('This subject has only 3 units.'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('edit_credit_units_field')), '0');
      await tester.tap(find.byKey(const ValueKey('save_credit_edit_button')));
      await tester.pump();
      expect(find.text('Enter the units to credit.'), findsOneWidget);
      expect(credits.lastUpdate, isNull);
    });

    testWidgets('a correction the server refuses is reported and the credit is left as it was', (tester) async {
      credits.credits.add(const CreditedSubjectModel(
          creditedSubjectId: 'c1', subjectId: 's1', subjectCode: 'IT 101', subjectTitle: 'Intro',
          units: 3, sourceSchool: 'Cebu Tech'));
      await pump(tester, const CreditedSubjectsDialog(student: _student));
      credits.failWith = 'The student already passed GEC 101 at DBTC.';

      await tester.tap(find.byKey(const ValueKey('edit_credit_IT 101')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('edit_credit_school_field')), 'USC');
      await tester.tap(find.byKey(const ValueKey('save_credit_edit_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('already passed GEC 101'), findsOneWidget);
      expect(find.textContaining('From Cebu Tech'), findsOneWidget);
    });

    testWidgets('remove asks first, then deletes', (tester) async {
      credits.credits.add(const CreditedSubjectModel(
          creditedSubjectId: 'c1', subjectId: 's1', subjectCode: 'IT 101', subjectTitle: 'Intro', sourceSchool: 'Cebu Tech'));
      await pump(tester, const CreditedSubjectsDialog(student: _student));

      await tester.tap(find.byKey(const ValueKey('remove_credit_IT 101')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm_remove_credit')));
      await tester.pumpAndSettle();

      expect(credits.deletedId, 'c1');
      expect(find.text('No credited subjects yet.'), findsOneWidget);
    });

    testWidgets('Grades window lists credits and drops them from the retake note', (tester) async {
      grades.grades = [const StudentGradeModel(gradeId: 'g', subjectCode: 'IT 101', subjectTitle: 'Intro', remarks: 2, loadStatus: 1, termLabel: 'T')];
      credits.credits.add(const CreditedSubjectModel(
          creditedSubjectId: 'c1', subjectId: 's1', subjectCode: 'IT 101', subjectTitle: 'Intro', sourceSchool: 'Cebu Tech', grade: '1.75'));
      await pump(tester, const StudentGradesDialog(userId: 'u1', studentName: 'Tina Transfer'));

      expect(find.text('Credited from other schools and cross-enrollment'), findsOneWidget);
      expect(find.text('Credited from Cebu Tech · 1.75'), findsOneWidget);
      expect(find.byKey(const ValueKey('retake_summary')), findsNothing);
    });
  });
}
