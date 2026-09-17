import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sis_student_app/blocs/grades_bloc.dart';
import 'package:sis_student_app/models/class_models.dart';
import 'package:sis_student_app/models/grading_models.dart';
import 'package:sis_student_app/models/setup_models.dart';
import 'package:sis_student_app/models/student_models.dart';
import 'package:sis_student_app/repositories/student_repository.dart';
import 'package:sis_student_app/views/grades_view.dart';

class MockStudentRepository implements StudentRepository {
  List<AcademicTermModel> terms = [];
  AcademicTermModel? activeTerm;
  List<GradeClearanceModel> clearances = [];
  Map<String, List<GradeModel>> gradesByTerm = {};
  bool shouldThrow = false;
  String? lastRequestedTermId;

  @override
  Future<AcademicTermModel?> getActiveTerm() async {
    if (shouldThrow) throw Exception('Failed to load active term');
    return activeTerm;
  }

  @override
  Future<List<AcademicTermModel>> getAllTerms() async {
    if (shouldThrow) throw Exception('Failed to load terms');
    return terms;
  }

  @override
  Future<List<GradeClearanceModel>> getGradeClearances(String userId) async {
    if (shouldThrow) throw Exception('Failed to load clearances');
    return clearances;
  }

  @override
  Future<List<GradeModel>> getGrades(String userId, String termId) async {
    if (shouldThrow) throw Exception('Failed to load grades');
    lastRequestedTermId = termId;
    return gradesByTerm[termId] ?? [];
  }

  @override
  Future<List<StudentScheduleItemModel>> getMySchedule(
      String userId, String termId) async {
    return [];
  }

  @override
  Future<StudentProfileModel> getMyProfile() async =>
      throw UnimplementedError();
}

void main() {
  final term1 = const AcademicTermModel(
    termId: 'term-1',
    schoolYear: '2025-2026',
    semester: 1,
    isActive: false,
  );

  final term2 = const AcademicTermModel(
    termId: 'term-2',
    schoolYear: '2025-2026',
    semester: 2,
    isActive: true,
  );

  group('GradesBloc tests', () {
    late MockStudentRepository repo;
    late GradesBloc bloc;

    setUp(() {
      repo = MockStudentRepository();
      repo.terms = [term1, term2];
      repo.activeTerm = term2;
      repo.clearances = [
        const GradeClearanceModel(
          clearanceId: 'c-1',
          userId: 'user-1',
          termId: 'term-1',
          isCleared: false,
        ),
        const GradeClearanceModel(
          clearanceId: 'c-2',
          userId: 'user-1',
          termId: 'term-2',
          isCleared: true,
        ),
      ];
      repo.gradesByTerm['term-2'] = [
        const GradeModel(
          gradeId: 'g-1',
          studyLoadId: 'sl-1',
          midtermGrade: 1.75,
          finalGrade: 2.00,
          remarks: 1,
          remarksLabel: 'Passed',
          subjectCode: 'IT 311',
          subjectTitle: 'Systems Integration',
          className: 'BSIT-3A',
        ),
        const GradeModel(
          gradeId: 'g-2',
          studyLoadId: 'sl-2',
          midtermGrade: 2.25,
          finalGrade: null,
          remarks: null,
          remarksLabel: null,
          subjectCode: 'IT 312',
          subjectTitle: 'Mobile Dev',
          className: 'BSIT-3A',
        ),
      ];

      bloc = GradesBloc(repo);
    });

    tearDown(() {
      bloc.close();
    });

    test('initial state is GradesInitial', () {
      expect(bloc.state, isA<GradesInitial>());
    });

    test('LoadGradesEvent loads active term by default and fetches grades', () async {
      bloc.add(LoadGradesEvent(userId: 'user-1'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<GradesLoading>(),
          predicate<GradesLoaded>((state) {
            return state.terms.length == 2 &&
                state.selectedTerm?.termId == 'term-2' &&
                state.activeTerm?.termId == 'term-2' &&
                !state.isClearanceWithheld &&
                state.grades.length == 2 &&
                state.totalSubjects == 2 &&
                state.passedCount == 1 &&
                state.pendingFinalCount == 1;
          }),
        ]),
      );
    });

    test('SelectTermEvent switches term and updates grades without full reload', () async {
      bloc.add(LoadGradesEvent(userId: 'user-1'));
      await bloc.stream.firstWhere((s) => s is GradesLoaded);

      repo.gradesByTerm['term-1'] = [];
      bloc.add(SelectTermEvent(term: term1, userId: 'user-1'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<GradesLoaded>((state) =>
              state.selectedTerm?.termId == 'term-1' &&
              state.isTermGradesLoading == true),
          predicate<GradesLoaded>((state) =>
              state.selectedTerm?.termId == 'term-1' &&
              state.isTermGradesLoading == false &&
              state.isClearanceWithheld == true &&
              state.grades.isEmpty),
        ]),
      );
    });

    test('isClearanceWithheld evaluates correctly for absent, false, and true clearances', () {
      final loadedWithheldFalse = GradesLoaded(
        terms: [term1],
        selectedTerm: term1,
        activeTerm: null,
        clearances: [
          const GradeClearanceModel(
            clearanceId: 'c-1',
            userId: 'u-1',
            termId: 'term-1',
            isCleared: false,
          ),
        ],
        grades: [],
      );
      expect(loadedWithheldFalse.isClearanceWithheld, isTrue);

      final loadedNoRecord = GradesLoaded(
        terms: [term1],
        selectedTerm: term1,
        activeTerm: null,
        clearances: [],
        grades: [],
      );
      expect(loadedNoRecord.isClearanceWithheld, isTrue);

      final loadedCleared = GradesLoaded(
        terms: [term2],
        selectedTerm: term2,
        activeTerm: null,
        clearances: [
          const GradeClearanceModel(
            clearanceId: 'c-2',
            userId: 'u-1',
            termId: 'term-2',
            isCleared: true,
          ),
        ],
        grades: [],
      );
      expect(loadedCleared.isClearanceWithheld, isFalse);
    });

    test('emits GradesError on exception', () async {
      repo.shouldThrow = true;
      bloc.add(LoadGradesEvent(userId: 'user-1'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<GradesLoading>(),
          isA<GradesError>(),
        ]),
      );
    });
  });

  group('GradesView Widget tests', () {
    late MockStudentRepository repo;

    setUp(() {
      repo = MockStudentRepository();
      repo.terms = [term1, term2];
      repo.activeTerm = term2;
    });

    Widget createWidgetUnderTest(GradesBloc bloc) {
      return MaterialApp(
        home: BlocProvider<GradesBloc>.value(
          value: bloc,
          child: const GradesView(userId: 'user-1'),
        ),
      );
    }

    testWidgets('shows clearance withheld banner when term is not cleared', (tester) async {
      repo.clearances = [
        const GradeClearanceModel(
          clearanceId: 'c-1',
          userId: 'user-1',
          termId: 'term-2',
          isCleared: false,
        ),
      ];
      repo.gradesByTerm['term-2'] = [];

      final bloc = GradesBloc(repo);
      await tester.pumpWidget(createWidgetUnderTest(bloc));
      await tester.pump(); // Start loading
      await tester.pumpAndSettle(); // Loaded

      expect(find.text('My Grades'), findsOneWidget);
      expect(find.text('Clearance Withheld'), findsOneWidget);
      expect(find.text('Grades Withheld Pending Clearance'), findsOneWidget);
      expect(find.textContaining('Requirements for Clearance'), findsOneWidget);

      bloc.close();
    });

    testWidgets('shows empty state when cleared but no grades submitted yet', (tester) async {
      repo.clearances = [
        const GradeClearanceModel(
          clearanceId: 'c-1',
          userId: 'user-1',
          termId: 'term-2',
          isCleared: true,
        ),
      ];
      repo.gradesByTerm['term-2'] = [];

      final bloc = GradesBloc(repo);
      await tester.pumpWidget(createWidgetUnderTest(bloc));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Clearance Cleared'), findsOneWidget);
      expect(find.text('No Grades Submitted Yet'), findsOneWidget);
      expect(find.textContaining('No grades have been submitted yet'), findsOneWidget);

      bloc.close();
    });

    testWidgets('shows grade cards and summary count bar when grades are present', (tester) async {
      repo.clearances = [
        const GradeClearanceModel(
          clearanceId: 'c-1',
          userId: 'user-1',
          termId: 'term-2',
          isCleared: true,
        ),
      ];
      repo.gradesByTerm['term-2'] = [
        const GradeModel(
          gradeId: 'g-1',
          studyLoadId: 'sl-1',
          midtermGrade: 1.75,
          finalGrade: 2.00,
          remarks: 1,
          remarksLabel: 'Passed',
          subjectCode: 'IT 311',
          subjectTitle: 'Systems Integration and Architecture',
          className: 'BSIT-3A',
          teacherName: 'Prof. Rizal',
        ),
        const GradeModel(
          gradeId: 'g-2',
          studyLoadId: 'sl-2',
          midtermGrade: 2.25,
          finalGrade: null, // Midterm only!
          remarks: null,
          remarksLabel: null,
          subjectCode: 'IT 312',
          subjectTitle: 'Mobile App Development',
          className: 'BSIT-3A',
          teacherName: 'Prof. Luna',
        ),
      ];

      final bloc = GradesBloc(repo);
      await tester.pumpWidget(createWidgetUnderTest(bloc));
      await tester.pump();
      await tester.pumpAndSettle();

      // Summary Bar counts
      expect(find.text('Total Subjects'), findsOneWidget);
      expect(find.text('2'), findsWidgets); // count chip
      expect(find.text('Passed'), findsWidgets);
      expect(find.text('Pending Final'), findsOneWidget);

      // Grade Cards
      expect(find.text('IT 311'), findsOneWidget);
      expect(find.text('Systems Integration and Architecture'), findsOneWidget);
      expect(find.text('1.75'), findsOneWidget);
      expect(find.text('2.00'), findsOneWidget);
      expect(find.text('Instructor: Prof. Rizal'), findsOneWidget);

      // Midterm-only card
      expect(find.text('IT 312'), findsOneWidget);
      expect(find.text('Mobile App Development'), findsOneWidget);
      expect(find.text('2.25'), findsOneWidget);
      expect(find.text('—'), findsWidgets); // Final grade displays "—" and Remarks displays "—"
      expect(find.text('Instructor: Prof. Luna'), findsOneWidget);

      bloc.close();
    });
  });
}
