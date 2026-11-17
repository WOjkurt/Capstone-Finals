import 'package:flutter_test/flutter_test.dart';
import 'package:sis_teacher_app/blocs/grades_bloc.dart';
import 'package:sis_teacher_app/models/class_models.dart';
import 'package:sis_teacher_app/models/grading_models.dart';
import 'package:sis_teacher_app/repositories/class_repository.dart';
import 'package:sis_teacher_app/repositories/grades_repository.dart';
const _classItem = ClassModel(
  classId: 'cls-1',
  subjectId: 'subj-1',
  subjectCode: 'IT 311',
  subjectTitle: 'Systems Integration',
  termId: 'term-1',
  className: 'BSIT 3A',
);

ClassRosterItemModel _rosterItem(String id, String name) =>
    ClassRosterItemModel(
      studyLoadId: id,
      studentUserId: 'u-$id',
      studentName: name,
      subjectCode: 'IT 311',
      subjectTitle: 'Systems Integration',
      className: 'BSIT 3A',
      termLabel: '2026-2027 (1st Sem)',
      loadStatus: 'Enrolled',
    );

GradeModel _grade(String studyLoadId, {double? midterm, double? finalGrade}) =>
    GradeModel(
      gradeId: 'g-$studyLoadId',
      studyLoadId: studyLoadId,
      midtermGrade: midterm,
      finalGrade: finalGrade,
    );

class _FakeClassRepository implements ClassRepository {
  List<ClassRosterItemModel> roster = [];
  bool shouldThrow = false;

  @override
  Future<List<ClassRosterItemModel>> getClassRoster(String classId) async {
    if (shouldThrow) throw Exception('Failed to load roster');
    return roster;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGradesRepository implements GradesRepository {
  List<GradeModel> classGrades = [];
  bool shouldThrowOnLoad = false;
  bool shouldThrowOnSubmit = false;
  bool shouldThrowOnBatch = false;
  GradeBatchResultModel batchResult = const GradeBatchResultModel();

  /// What submitGrade was last called with.
  final List<Map<String, Object?>> submitted = [];

  @override
  Future<List<GradeModel>> getClassGrades(String classId) async {
    if (shouldThrowOnLoad) throw Exception('Failed to load grades');
    return classGrades;
  }

  @override
  Future<GradeModel> submitGrade(
    String studyLoadId, {
    double? midtermGrade,
    double? finalGrade,
  }) async {
    submitted.add({
      'studyLoadId': studyLoadId,
      'midterm': midtermGrade,
      'final': finalGrade,
    });
    if (shouldThrowOnSubmit) throw Exception('The grade was refused');
    return _grade(studyLoadId, midterm: midtermGrade, finalGrade: finalGrade);
  }

  @override
  Future<GradeBatchResultModel> submitGradeBatch(
      SubmitGradeBatchModel batch) async {
    if (shouldThrowOnBatch) throw Exception('The batch was refused');
    return batchResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeClassRepository classRepo;
  late _FakeGradesRepository gradesRepo;
  late GradesBloc bloc;

  setUp(() {
    classRepo = _FakeClassRepository();
    gradesRepo = _FakeGradesRepository();
    bloc = GradesBloc(classRepo, gradesRepo);
  });

  tearDown(() => bloc.close());

  Future<GradesSheetLoaded> loadSheet() async {
    bloc.add(LoadClassGradesSheetEvent(_classItem));
    await expectLater(
      bloc.stream,
      emitsInOrder([isA<GradesSheetLoading>(), isA<GradesSheetLoaded>()]),
    );
    return bloc.state as GradesSheetLoaded;
  }

  group('loading the grade sheet', () {
    test('pairs the roster with the grades already submitted', () async {
      classRepo.roster = [
        _rosterItem('sl-1', 'Dela Cruz, Ana'),
        _rosterItem('sl-2', 'Reyes, Mark'),
      ];
      gradesRepo.classGrades = [_grade('sl-1', midterm: 1.75)];

      final state = await loadSheet();

      expect(state.roster, hasLength(2));
      expect(state.grades.keys, ['sl-1']);
      expect(state.grades['sl-1']!.midtermGrade, 1.75);
    });

    test('a roster failure surfaces as an error, not an empty sheet', () async {
      classRepo.shouldThrow = true;

      bloc.add(LoadClassGradesSheetEvent(_classItem));
      await expectLater(
        bloc.stream,
        emitsInOrder([isA<GradesSheetLoading>(), isA<GradesSheetError>()]),
      );
    });

    test('a grades failure surfaces as an error too', () async {
      classRepo.roster = [_rosterItem('sl-1', 'Dela Cruz, Ana')];
      gradesRepo.shouldThrowOnLoad = true;

      bloc.add(LoadClassGradesSheetEvent(_classItem));
      await expectLater(
        bloc.stream,
        emitsInOrder([isA<GradesSheetLoading>(), isA<GradesSheetError>()]),
      );
    });
  });

  group('saving one row', () {
    test('marks the row saving, then keeps the saved grade', () async {
      classRepo.roster = [_rosterItem('sl-1', 'Dela Cruz, Ana')];
      await loadSheet();

      bloc.add(SubmitSingleGradeRowEvent(
        studyLoadId: 'sl-1',
        midtermGrade: 1.75,
        studentName: 'Dela Cruz, Ana',
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<GradesState>(
            (s) => s is GradesSheetLoaded && s.savingRowStudyLoadId == 'sl-1',
            'row marked as saving',
          ),
          predicate<GradesState>(
            (s) =>
                s is GradesSheetLoaded &&
                s.savingRowStudyLoadId == null &&
                s.grades['sl-1']?.midtermGrade == 1.75,
            'saved and no longer saving',
          ),
        ]),
      );

      expect((bloc.state as GradesSheetLoaded).actionSuccessMessage,
          contains('Dela Cruz, Ana'));
      expect(gradesRepo.submitted.single['midterm'], 1.75);
    });

    test('a refused grade reports the error and leaves the sheet intact',
        () async {
      classRepo.roster = [_rosterItem('sl-1', 'Dela Cruz, Ana')];
      gradesRepo.classGrades = [_grade('sl-1', midterm: 2.0)];
      await loadSheet();
      gradesRepo.shouldThrowOnSubmit = true;

      bloc.add(SubmitSingleGradeRowEvent(
        studyLoadId: 'sl-1',
        finalGrade: 9.9,
        studentName: 'Dela Cruz, Ana',
      ));
      await Future.delayed(const Duration(milliseconds: 20));

      final state = bloc.state as GradesSheetLoaded;
      expect(state.actionErrorMessage, isNotNull);
      expect(state.savingRowStudyLoadId, isNull);
      // The previously stored grade is untouched.
      expect(state.grades['sl-1']!.midtermGrade, 2.0);
    });

    test('saving is ignored before the sheet has loaded', () async {
      bloc.add(SubmitSingleGradeRowEvent(
        studyLoadId: 'sl-1',
        midtermGrade: 1.0,
        studentName: 'Nobody',
      ));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(bloc.state, isA<GradesInitial>());
      expect(gradesRepo.submitted, isEmpty);
    });
  });

  group('submitting a batch', () {
    test('keeps the grades that succeeded and reports the failures', () async {
      classRepo.roster = [
        _rosterItem('sl-1', 'Dela Cruz, Ana'),
        _rosterItem('sl-2', 'Reyes, Mark'),
      ];
      await loadSheet();

      gradesRepo.batchResult = GradeBatchResultModel(
        succeeded: [_grade('sl-1', midterm: 1.5, finalGrade: 1.75)],
        failed: [
          const GradeBatchFailedItemModel(
            studyLoadId: 'sl-2',
            reason: 'Final grade already submitted',
          ),
        ],
      );

      bloc.add(SubmitBatchGradesEvent(const SubmitGradeBatchModel(
        classId: 'cls-1',
        grades: [],
      )));
      await Future.delayed(const Duration(milliseconds: 20));

      final state = bloc.state as GradesSheetLoaded;
      expect(state.isSubmittingBatch, isFalse);
      expect(state.grades['sl-1']!.finalGrade, 1.75);
      expect(state.grades.containsKey('sl-2'), isFalse,
          reason: 'a refused row must not look saved');
      expect(state.lastBatchResult!.failed.single.reason,
          'Final grade already submitted');
    });

    test('a failed batch reports the error and stops the spinner', () async {
      classRepo.roster = [_rosterItem('sl-1', 'Dela Cruz, Ana')];
      await loadSheet();
      gradesRepo.shouldThrowOnBatch = true;

      bloc.add(SubmitBatchGradesEvent(const SubmitGradeBatchModel(
        classId: 'cls-1',
        grades: [],
      )));
      await Future.delayed(const Duration(milliseconds: 20));

      final state = bloc.state as GradesSheetLoaded;
      expect(state.isSubmittingBatch, isFalse);
      expect(state.actionErrorMessage, isNotNull);
    });
  });

  group('clearing feedback', () {
    test('drops the message and the last batch result', () async {
      classRepo.roster = [_rosterItem('sl-1', 'Dela Cruz, Ana')];
      await loadSheet();

      bloc.add(SubmitSingleGradeRowEvent(
        studyLoadId: 'sl-1',
        midtermGrade: 1.75,
        studentName: 'Dela Cruz, Ana',
      ));
      await Future.delayed(const Duration(milliseconds: 20));
      expect((bloc.state as GradesSheetLoaded).actionSuccessMessage, isNotNull);

      bloc.add(ClearGradeSheetFeedbackEvent());
      await Future.delayed(const Duration(milliseconds: 20));

      final state = bloc.state as GradesSheetLoaded;
      expect(state.actionSuccessMessage, isNull);
      expect(state.lastBatchResult, isNull);
      // The grades themselves survive.
      expect(state.grades['sl-1'], isNotNull);
    });
  });
}
