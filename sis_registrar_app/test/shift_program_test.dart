import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/models/grading_models.dart';
import 'package:sis_registrar_app/models/record_models.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/repositories/enrollment_repository.dart';
import 'package:sis_registrar_app/repositories/grading_repository.dart';
import 'package:sis_registrar_app/repositories/student_record_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/views/widgets/credited_subjects_dialog.dart';
import 'package:sis_registrar_app/views/widgets/shift_program_dialog.dart';

class FakeAuthService implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {'Authorization': 'Bearer t'};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSetupRepo implements AcademicSetupRepository {
  @override
  Future<List<AcademicProgramModel>> getPrograms() async => const [
        AcademicProgramModel(programId: 1, programCode: 'BSIT', programName: 'BS IT'),
        AcademicProgramModel(programId: 2, programCode: 'BSME', programName: 'BS ME'),
      ];
  @override
  Future<List<SubjectModel>> getSubjects({int? programId, int? yearLevel}) async => [
        SubjectModel.fromJson({'subjectID': 'm1', 'subjectCode': 'GEC 101', 'subjectTitle': 'Self', 'programID': 2, 'yearLevel': 1, 'lecUnits': 3}),
      ];
  @override
  Future<List<AcademicTermModel>> getTerms() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCreditRepo implements CreditedSubjectRepository {
  @override
  Future<List<CreditedSubjectModel>> getForStudent(String userId) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Map<String, dynamic>? shiftBody;

  setUp(() async {
    await getIt.reset();
    shiftBody = null;
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/shift')) {
        shiftBody = jsonDecode(req.body) as Map<String, dynamic>;
        expect(req.method, 'POST');
        return http.Response(jsonEncode({'programId': 2, 'programCode': 'BSME', 'inProgressSubjects': 2, 'pendingSubjects': 1}), 200);
      }
      return http.Response(
          jsonEncode([
            {'subjectCode': 'GEC 101', 'subjectTitle': 'Self', 'programCode': 'BSIT', 'units': 3, 'status': 'Passed', 'finalGrade': 1.75,
             'schoolYear': '2025-2026', 'termLabel': '2025-2026 (1st Sem)', 'suggestedSubjectId': 'm1', 'suggestedSubjectCode': 'GEC 101', 'suggestedUnits': 3},
            {'subjectCode': 'IT 101', 'subjectTitle': 'Intro', 'programCode': 'BSIT', 'units': 3, 'status': 'InProgress',
             'schoolYear': '2026-2027', 'termLabel': '2026-2027 (1st Sem)'},
            {'subjectCode': 'GEC 102', 'subjectTitle': 'History', 'programCode': 'BSIT', 'units': 3, 'status': 'Passed', 'finalGrade': 2,
             'schoolYear': '2025-2026', 'termLabel': '2025-2026 (1st Sem)', 'suggestedSubjectId': 'm2', 'suggestedSubjectCode': 'GEC 102', 'alreadyCredited': true},
          ]),
          200);
    });
    getIt.registerSingleton<AcademicSetupRepository>(FakeSetupRepo());
    getIt.registerSingleton<CreditedSubjectRepository>(FakeCreditRepo());
    getIt.registerSingleton<StudentRecordRepository>(StudentRecordRepository(FakeAuthService(), client: client));
  });

  tearDown(() async => getIt.reset());

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pumpAndSettle();
  }

  testWidgets('shift needs a new program and a reason, and leaves out the current program', (tester) async {
    ShiftResult? result;
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await ShiftProgramDialog.show(context,
              userId: 'u1', studentName: 'Ana Cruz', currentProgramId: 1, currentProgramCode: 'BSIT'),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('confirm_shift_button')));
    await tester.pumpAndSettle();
    expect(find.text('Choose the new program.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('shift_program_dropdown')));
    await tester.pumpAndSettle();
    expect(find.textContaining('BSIT —'), findsNothing);
    await tester.tap(find.textContaining('BSME —').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_shift_button')));
    await tester.pumpAndSettle();
    expect(find.text('Give a reason for the shift.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('shift_reason_field')), 'Student request');
    await tester.tap(find.byKey(const ValueKey('confirm_shift_button')));
    await tester.pumpAndSettle();

    expect(shiftBody, {'programId': 2, 'reason': 'Student request'});
    expect((result!.programCode, result!.inProgressSubjects, result!.pendingSubjects), ('BSME', 2, 1));
  });

  testWidgets('Credits lists old-program subjects; Use fills the form, and units stay editable', (tester) async {
    const student = UserSearchResultModel(
        userId: 'u1', firstname: 'Ana', lastname: 'Cruz', email: 'a@x.com', role: 5, programId: 2, programCode: 'BSME');
    await pump(tester, const CreditedSubjectsDialog(student: student, embedded: true));

    expect(find.byKey(const ValueKey('previous_program_subjects')), findsOneWidget);
    expect(find.textContaining('matches GEC 101'), findsOneWidget);
    expect(find.textContaining('in progress'), findsOneWidget);
    expect(find.byKey(const ValueKey('use_previous_GEC 102')), findsNothing);   // already credited

    await tester.tap(find.byKey(const ValueKey('use_previous_GEC 101')));
    await tester.pumpAndSettle();

    String field(String key) => tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;
    expect(field('credit_school_field'), 'Don Bosco Technical College - Cebu (BSIT)');
    expect(field('credit_their_code_field'), 'GEC 101');
    expect(field('credit_grade_field'), '1.75');
    expect(field('credit_school_year_field'), '2025-2026');
    expect(field('credit_units_field'), '3');
    expect(find.textContaining('Not on the accredited list'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('credit_units_field')), '2');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('partial_credit_note')), findsOneWidget);
  });
}
