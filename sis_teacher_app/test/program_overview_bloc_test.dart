import 'package:flutter_test/flutter_test.dart';
import 'package:sis_teacher_app/blocs/program_overview_bloc.dart';
import 'package:sis_teacher_app/models/class_models.dart';
import 'package:sis_teacher_app/repositories/class_repository.dart';

class FakeClassRepository implements ClassRepository {
  List<ClassModel> mockClasses = [];
  bool shouldThrow = false;
  bool shouldThrowOnAssign = false;
  String errorMessage = 'Failed to fetch classes';
  String assignError = 'Permission denied';

  @override
  Future<List<ClassModel>> getProgramClasses({
    String? termId,
    String? subjectId,
  }) async {
    if (shouldThrow) {
      throw Exception(errorMessage);
    }
    return mockClasses;
  }

  @override
  Future<List<ClassModel>> getMyClasses({
    required String teacherUserId,
    String? termId,
  }) async {
    return mockClasses;
  }

  @override
  Future<List<ClassRosterItemModel>> getClassRoster(String classId) async {
    return [];
  }

  @override
  Future<void> assignTeacher(String classId, String? teacherUserId) async {
    if (shouldThrowOnAssign) {
      throw Exception(assignError);
    }
    // Simulate updating the in-memory list so the follow-up load reflects it.
    mockClasses = mockClasses.map((c) {
      if (c.classId == classId) {
        return ClassModel(
          classId: c.classId,
          subjectId: c.subjectId,
          subjectCode: c.subjectCode,
          subjectTitle: c.subjectTitle,
          userId: teacherUserId,
          teacherName:
              teacherUserId != null ? 'New Teacher' : null,
          termId: c.termId,
          className: c.className,
          enrolledCount: c.enrolledCount,
        );
      }
      return c;
    }).toList();
  }
}


void main() {
  late FakeClassRepository fakeRepo;
  late ProgramOverviewBloc bloc;

  setUp(() {
    fakeRepo = FakeClassRepository();
    bloc = ProgramOverviewBloc(fakeRepo);
  });

  tearDown(() {
    bloc.close();
  });

  group('ProgramOverviewBloc tests', () {
    test('initial state is ProgramOverviewInitial', () {
      expect(bloc.state, isA<ProgramOverviewInitial>());
    });

    test('emits [Loading, Loaded] on successful LoadProgramClassesEvent', () async {
      fakeRepo.mockClasses = [
        const ClassModel(
          classId: 'c-1',
          subjectId: 's-1',
          subjectCode: 'IT 111',
          subjectTitle: 'Intro to IT',
          userId: 'teacher-1',
          teacherName: 'Prof. Cruz',
          termId: 't-1',
          className: 'BSIT-1A',
          enrolledCount: 30,
        ),
        const ClassModel(
          classId: 'c-2',
          subjectId: 's-2',
          subjectCode: 'IT 211',
          subjectTitle: 'Data Structures',
          userId: 'teacher-2',
          teacherName: 'Prof. Santos',
          termId: 't-1',
          className: 'BSIT-2A',
          enrolledCount: 25,
        ),
        const ClassModel(
          classId: 'c-3',
          subjectId: 's-3',
          subjectCode: 'IT 311',
          subjectTitle: 'Systems Integration',
          userId: null,
          teacherName: null,
          termId: 't-1',
          className: 'BSIT-3A',
          enrolledCount: 20,
        ),
      ];

      final expectedStates = [
        isA<ProgramOverviewLoading>(),
        isA<ProgramOverviewLoaded>(),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(LoadProgramClassesEvent());
    });

    test('calculates correct metrics in ProgramOverviewLoaded state', () {
      final classes = [
        const ClassModel(
          classId: 'c-1',
          subjectId: 's-1',
          userId: 'teacher-1',
          teacherName: 'Prof. Cruz',
          termId: 't-1',
          className: 'BSIT-1A',
          enrolledCount: 30,
        ),
        const ClassModel(
          classId: 'c-2',
          subjectId: 's-2',
          userId: 'teacher-1',
          teacherName: 'Prof. Cruz',
          termId: 't-1',
          className: 'BSIT-1B',
          enrolledCount: 28,
        ),
        const ClassModel(
          classId: 'c-3',
          subjectId: 's-3',
          userId: 'teacher-2',
          teacherName: 'Prof. Santos',
          termId: 't-1',
          className: 'BSIT-2A',
          enrolledCount: 25,
        ),
        const ClassModel(
          classId: 'c-4',
          subjectId: 's-4',
          userId: null,
          teacherName: null,
          termId: 't-1',
          className: 'BSIT-3A',
          enrolledCount: 0,
        ),
      ];

      final state = ProgramOverviewLoaded(classes);

      expect(state.totalClasses, 4);
      expect(state.activeFacultyCount, 2); // Cruz and Santos
      expect(state.unassignedCount, 1);
    });

    test('emits [Loading, Error] when repository throws', () async {
      fakeRepo.shouldThrow = true;
      fakeRepo.errorMessage = 'Network connection refused';

      final expectedStates = [
        isA<ProgramOverviewLoading>(),
        isA<ProgramOverviewError>(),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(LoadProgramClassesEvent());
    });

    test('emits [Assigning, Loaded] on successful AssignTeacherEvent', () async {
      fakeRepo.mockClasses = [
        const ClassModel(
          classId: 'c-1',
          subjectId: 's-1',
          subjectCode: 'IT 111',
          subjectTitle: 'Intro to IT',
          userId: null,
          teacherName: null,
          termId: 't-1',
          className: 'BSIT-1A',
          enrolledCount: 20,
        ),
      ];

      final expectedStates = [
        isA<ProgramOverviewAssigning>(),
        isA<ProgramOverviewLoaded>(),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(AssignTeacherEvent(classId: 'c-1', teacherUserId: 'teacher-99'));
    });

    test('emits [Assigning, AssignError] when assignTeacher throws', () async {
      fakeRepo.mockClasses = [
        const ClassModel(
          classId: 'c-1',
          subjectId: 's-1',
          subjectCode: 'IT 111',
          subjectTitle: 'Intro to IT',
          userId: null,
          teacherName: null,
          termId: 't-1',
          className: 'BSIT-1A',
          enrolledCount: 20,
        ),
      ];
      fakeRepo.shouldThrowOnAssign = true;

      final expectedStates = [
        isA<ProgramOverviewAssigning>(),
        isA<ProgramOverviewAssignError>(),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(AssignTeacherEvent(classId: 'c-1', teacherUserId: 'teacher-99'));
    });
  });
}
