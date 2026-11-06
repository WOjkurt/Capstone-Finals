import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/models/grading_models.dart';
import 'package:sis_registrar_app/repositories/grading_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/views/widgets/student_grades_dialog.dart';

class FakeAuthService implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {'Authorization': 'Bearer t'};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStudentGradeRepository implements StudentGradeRepository {
  List<StudentGradeModel> grades = [];

  @override
  Future<List<StudentGradeModel>> getStudentGrades(String userId) async => grades;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StudentGradeModel _g(String code, int? remarks,
        {String year = '2025-2026', int sem = 1, double? fin, int loadStatus = 1}) =>
    StudentGradeModel(
      gradeId: '$code-$year-$sem',
      subjectCode: code,
      subjectTitle: '$code title',
      units: 3,
      finalGrade: fin ?? (remarks == 2 ? 5.0 : remarks == 1 ? 2.0 : null),
      remarks: remarks,
      schoolYear: year,
      semester: sem,
      termLabel: '$year (Sem $sem)',
      loadStatus: loadStatus,
    );

void main() {
  group('unresolvedFailedSubjects', () {
    test('lists failed subjects not passed later', () {
      expect(
        unresolvedFailedSubjects([
          _g('IT 101', 2),
          _g('IT 101', 1, sem: 2), // passed on retake
          _g('THEO 101', 2),
          _g('GEC 101', 1),
        ]),
        ['THEO 101'],
      );
    });

    test('ignores grades on dropped or pending loads', () {
      expect(unresolvedFailedSubjects([_g('IT 102', 2, loadStatus: 2)]), isEmpty);
      expect(
        unresolvedFailedSubjects([_g('IT 102', 2), _g('IT 102', 1, sem: 2, loadStatus: 4)]),
        ['IT 102'],
      );
    });
  });

  test('repository calls GET /api/student-records/{id}/grades and parses term fields', () async {
    late Uri called;
    final client = MockClient((req) async {
      called = req.url;
      return http.Response(
          jsonEncode([
            {
              'gradeId': 'g1',
              'subjectCode': 'IT 101',
              'finalGrade': 5.0,
              'remarks': 2,
              'units': 3,
              'termLabel': '2025-2026 (1st Sem)',
              'schoolYear': '2025-2026',
              'semester': 1,
              'loadStatus': 1,
            }
          ]),
          200);
    });
    final repo = StudentGradeRepository(FakeAuthService(), client: client);

    final grades = await repo.getStudentGrades('u1');

    expect(called.path, '/api/student-records/u1/grades');
    expect(grades.single.isFailed, isTrue);
    expect(grades.single.units, 3);
    expect(grades.single.termLabel, '2025-2026 (1st Sem)');
  });

  group('StudentGradesDialog', () {
    late FakeStudentGradeRepository repo;

    setUp(() async {
      await getIt.reset();
      repo = FakeStudentGradeRepository();
      getIt.registerSingleton<StudentGradeRepository>(repo);
    });

    tearDown(() async => getIt.reset());

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: StudentGradesDialog(userId: 'u1', studentName: 'Ana Cruz')),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('groups by term newest first and shows retake summary', (tester) async {
      repo.grades = [
        _g('IT 101', 2, year: '2025-2026', sem: 1),
        _g('GEC 101', 1, year: '2025-2026', sem: 1),
        _g('IT 102', 1, year: '2025-2026', sem: 2),
      ];
      await pump(tester);

      final sem2 = tester.getTopLeft(find.text('2025-2026 (Sem 2)')).dy;
      final sem1 = tester.getTopLeft(find.text('2025-2026 (Sem 1)')).dy;
      expect(sem2, lessThan(sem1));
      expect(find.byKey(const ValueKey('retake_summary')), findsOneWidget);
      expect(find.textContaining('Not yet passed (retake needed): IT 101'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Passed'), findsNWidgets(2));
    });

    testWidgets('Failed only hides passed subjects', (tester) async {
      repo.grades = [_g('IT 101', 2), _g('GEC 101', 1)];
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('failed_only_chip')));
      await tester.pumpAndSettle();

      expect(find.text('IT 101'), findsOneWidget);
      expect(find.textContaining('GEC 101 —'), findsNothing);
    });

    testWidgets('no retake summary when every failure was passed later', (tester) async {
      repo.grades = [_g('IT 101', 2), _g('IT 101', 1, sem: 2)];
      await pump(tester);

      expect(find.byKey(const ValueKey('retake_summary')), findsNothing);
    });

    testWidgets('empty history message', (tester) async {
      await pump(tester);
      expect(find.text('No subjects on record for this student yet.'), findsOneWidget);
    });
  });
}
