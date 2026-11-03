import 'package:flutter_test/flutter_test.dart';
import 'package:sis_teacher_app/blocs/faculty_bloc.dart';
import 'package:sis_teacher_app/models/class_models.dart';
import 'package:sis_teacher_app/models/grading_models.dart';
import 'package:sis_teacher_app/models/setup_models.dart';
import 'package:sis_teacher_app/repositories/class_repository.dart';
import 'package:sis_teacher_app/repositories/grading_repository.dart';
import 'package:sis_teacher_app/services/auth_service.dart';

class FakeAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserSearchRepository extends UserSearchRepository {
  List<UserSearchResultModel> mockTeachers = [];
  bool shouldThrow = false;
  String errorMessage = 'Failed to search users';

  FakeUserSearchRepository() : super(FakeAuthService());

  @override
  Future<List<UserSearchResultModel>> search({String? query, int? role}) async {
    if (shouldThrow) {
      throw Exception(errorMessage);
    }
    return mockTeachers;
  }
}

class FakeClassRepository implements ClassRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  List<ClassModel> mockClasses = [];
  bool shouldThrow = false;
  bool shouldThrowOnAssign = false;
  String errorMessage = 'Failed to fetch classes';
  String assignErrorMessage = 'Failed to assign teacher';

  @override
  Future<List<ClassModel>> getProgramClasses(
      {String? termId, String? subjectId, int? yearLevel}) async {
    if (shouldThrow) {
      throw Exception(errorMessage);
    }
    return mockClasses;
  }

  @override
  Future<List<ClassModel>> getMyClasses(
      {required String teacherUserId, String? termId}) async {
    return mockClasses;
  }

  @override
  Future<List<ClassRosterItemModel>> getClassRoster(String classId) async {
    return [];
  }

  @override
  Future<List<AcademicTermModel>> getTerms() async {
    return [];
  }

  @override
  Future<AcademicTermModel?> getActiveTerm() async {
    return null;
  }

  @override
  Future<void> assignTeacher(String classId, String? teacherUserId) async {
    if (shouldThrowOnAssign) {
      throw Exception(assignErrorMessage);
    }
    mockClasses = mockClasses.map((c) {
      if (c.classId == classId) {
        return ClassModel(
          classId: c.classId,
          subjectId: c.subjectId,
          subjectCode: c.subjectCode,
          subjectTitle: c.subjectTitle,
          userId: teacherUserId,
          teacherName: teacherUserId != null ? 'Teacher Name' : null,
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
  late FakeUserSearchRepository userSearchRepo;
  late FakeClassRepository classRepo;
  late FacultyBloc bloc;

  final teacher1 = UserSearchResultModel(
    userId: 'teacher-1',
    firstname: 'John',
    lastname: 'Doe',
    email: 'john.doe@dbtc-cebu.edu.ph',
    role: 3,
    roleName: 'Teacher',
    programId: 1,
    programCode: 'BSIT',
  );

  final teacher2 = UserSearchResultModel(
    userId: 'teacher-2',
    firstname: 'Jane',
    lastname: 'Smith',
    email: 'jane.smith@dbtc-cebu.edu.ph',
    role: 3,
    roleName: 'Teacher',
    programId: 1,
    programCode: 'BSIT',
  );

  final class1 = ClassModel(
    classId: 'class-1',
    subjectId: 'sub-1',
    subjectCode: 'IT101',
    subjectTitle: 'Intro to IT',
    className: 'BSIT-1A',
    termId: 'term-1',
    userId: 'teacher-1',
    teacherName: 'John Doe',
    enrolledCount: 25,
  );

  final class2 = ClassModel(
    classId: 'class-2',
    subjectId: 'sub-2',
    subjectCode: 'IT102',
    subjectTitle: 'Data Structures',
    className: 'BSIT-1B',
    termId: 'term-1',
    userId: 'teacher-1',
    teacherName: 'John Doe',
    enrolledCount: 30,
  );

  final unassignedClass = ClassModel(
    classId: 'class-3',
    subjectId: 'sub-3',
    subjectCode: 'IT103',
    subjectTitle: 'Web Development',
    className: 'BSIT-2A',
    termId: 'term-1',
    userId: null,
    teacherName: null,
    enrolledCount: 20,
  );

  setUp(() {
    userSearchRepo = FakeUserSearchRepository();
    classRepo = FakeClassRepository();
    bloc = FacultyBloc(userSearchRepo, classRepo);
  });

  tearDown(() {
    bloc.close();
  });

  group('FacultyBloc tests', () {
    test('initial state is FacultyInitial', () {
      expect(bloc.state, isA<FacultyInitial>());
    });

    test('emits [FacultyLoading, FacultyLoaded] on successful LoadFacultyEvent',
        () async {
      userSearchRepo.mockTeachers = [teacher1, teacher2];
      classRepo.mockClasses = [class1, class2, unassignedClass];

      final expectedStates = [
        isA<FacultyLoading>(),
        isA<FacultyLoaded>()
            .having((s) => s.totalFaculty, 'totalFaculty', 2)
            .having((s) => s.teachersWithClassesCount, 'teachersWithClassesCount', 1)
            .having((s) => s.teachersWithZeroClassesCount, 'teachersWithZeroClassesCount', 1)
            .having((s) => s.unassignedClasses.length, 'unassignedClasses', 1),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));
      bloc.add(LoadFacultyEvent());
    });

    test('correctly computes class count and enrolled count per teacher',
        () async {
      userSearchRepo.mockTeachers = [teacher1, teacher2];
      classRepo.mockClasses = [class1, class2, unassignedClass];

      bloc.add(LoadFacultyEvent());

      final loadedState = await bloc.stream
          .firstWhere((s) => s is FacultyLoaded) as FacultyLoaded;

      // teacher1 (John Doe) has 2 classes, 55 total enrolled students
      final member1 =
          loadedState.faculty.firstWhere((f) => f.userId == 'teacher-1');
      expect(member1.classCount, 2);
      expect(member1.hasClasses, isTrue);
      expect(member1.totalEnrolledStudents, 55);
      expect(member1.assignedClasses.length, 2);

      // teacher2 (Jane Smith) has 0 classes, 0 total enrolled students
      final member2 =
          loadedState.faculty.firstWhere((f) => f.userId == 'teacher-2');
      expect(member2.classCount, 0);
      expect(member2.hasClasses, isFalse);
      expect(member2.totalEnrolledStudents, 0);
      expect(member2.assignedClasses, isEmpty);

      // Unassigned class is captured
      expect(loadedState.unassignedClasses.single.classId, 'class-3');
    });

    test('emits [FacultyLoading, FacultyError] when repository fails', () async {
      userSearchRepo.shouldThrow = true;

      final expectedStates = [
        isA<FacultyLoading>(),
        isA<FacultyError>(),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));
      bloc.add(LoadFacultyEvent());
    });

    test('emits [FacultyAssigning, FacultyLoaded] on successful assign',
        () async {
      userSearchRepo.mockTeachers = [teacher1, teacher2];
      classRepo.mockClasses = [class1, class2, unassignedClass];

      // First load the initial data
      bloc.add(LoadFacultyEvent());
      await bloc.stream.firstWhere((s) => s is FacultyLoaded);

      // Now assign unassignedClass (class-3) to teacher2
      final expectedStates = [
        isA<FacultyAssigning>()
            .having((s) => s.teacherUserId, 'teacherUserId', 'teacher-2')
            .having((s) => s.classId, 'classId', 'class-3'),
        isA<FacultyLoaded>()
            .having((s) => s.teachersWithClassesCount, 'teachersWithClassesCount', 2)
            .having((s) => s.teachersWithZeroClassesCount, 'teachersWithZeroClassesCount', 0)
            .having((s) => s.unassignedClasses, 'unassignedClasses', isEmpty),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));
      bloc.add(AssignFacultyToClassEvent(
        classId: 'class-3',
        teacherUserId: 'teacher-2',
      ));
    });

    test('emits [FacultyAssigning, FacultyAssignError] on assign failure',
        () async {
      userSearchRepo.mockTeachers = [teacher1, teacher2];
      classRepo.mockClasses = [class1, class2, unassignedClass];

      // First load initial data
      bloc.add(LoadFacultyEvent());
      await bloc.stream.firstWhere((s) => s is FacultyLoaded);

      // Make assign throw
      classRepo.shouldThrowOnAssign = true;

      final expectedStates = [
        isA<FacultyAssigning>(),
        isA<FacultyAssignError>()
            .having((s) => s.previousFaculty.length, 'previousFaculty', 2),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));
      bloc.add(AssignFacultyToClassEvent(
        classId: 'class-3',
        teacherUserId: 'teacher-2',
      ));
    });

    test('emits [FacultyAssigning, FacultyLoaded] on successful unassign (teacherUserId: null)',
        () async {
      userSearchRepo.mockTeachers = [teacher1, teacher2];
      classRepo.mockClasses = [class1, class2, unassignedClass];

      // First load initial data
      bloc.add(LoadFacultyEvent());
      await bloc.stream.firstWhere((s) => s is FacultyLoaded);

      // Now unassign class-1 (which was assigned to teacher-1)
      final expectedStates = [
        isA<FacultyAssigning>()
            .having((s) => s.teacherUserId, 'teacherUserId', isNull)
            .having((s) => s.classId, 'classId', 'class-1'),
        isA<FacultyLoaded>()
            .having((s) => s.teachersWithClassesCount, 'teachersWithClassesCount', 1)
            .having((s) => s.unassignedClasses.length, 'unassignedClasses count', 2),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));
      bloc.add(AssignFacultyToClassEvent(
        classId: 'class-1',
        teacherUserId: null,
      ));
    });
  });
}
