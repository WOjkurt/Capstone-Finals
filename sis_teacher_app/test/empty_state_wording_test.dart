import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sis_teacher_app/blocs/faculty_bloc.dart';
import 'package:sis_teacher_app/blocs/program_overview_bloc.dart';
import 'package:sis_teacher_app/models/class_models.dart';
import 'package:sis_teacher_app/models/grading_models.dart';
import 'package:sis_teacher_app/models/setup_models.dart';
import 'package:sis_teacher_app/repositories/class_repository.dart';
import 'package:sis_teacher_app/repositories/grading_repository.dart';
import 'package:sis_teacher_app/views/faculty_view.dart';
import 'package:sis_teacher_app/views/program_overview_view.dart';

class _FakeClassRepository implements ClassRepository {
  List<ClassModel> mockClasses = [];
  List<AcademicTermModel> mockTerms = [
    const AcademicTermModel(
      termId: 'term-1',
      schoolYear: '2026-2027',
      semester: 1,
      isActive: true,
    ),
  ];

  @override
  Future<List<ClassModel>> getProgramClasses({
    String? termId,
    String? subjectId,
    int? yearLevel,
  }) async =>
      mockClasses;

  @override
  Future<List<ClassModel>> getMyClasses({
    required String teacherUserId,
    String? termId,
  }) async =>
      mockClasses;

  @override
  Future<List<ClassRosterItemModel>> getClassRoster(String classId) async => [];

  @override
  Future<List<AcademicTermModel>> getTerms() async => mockTerms;

  @override
  Future<AcademicTermModel?> getActiveTerm() async => mockTerms.first;

  @override
  Future<void> assignTeacher(String classId, String? teacherUserId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserSearchRepository implements UserSearchRepository {
  List<UserSearchResultModel> mockFaculty = [];

  @override
  Future<List<UserSearchResultModel>> search({String? query, int? role}) async =>
      mockFaculty;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final getIt = GetIt.instance;
  late _FakeClassRepository fakeClassRepo;
  late _FakeUserSearchRepository fakeUserSearchRepo;

  setUp(() async {
    await getIt.reset();
    fakeClassRepo = _FakeClassRepository();
    fakeUserSearchRepo = _FakeUserSearchRepository();

    getIt.registerSingleton<ClassRepository>(fakeClassRepo);
    getIt.registerSingleton<UserSearchRepository>(fakeUserSearchRepo);
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('Program Overview Empty State Wording', () {
    testWidgets('shows "No classes have been opened for this term yet." when term has zero classes',
        (tester) async {
      fakeClassRepo.mockClasses = [];

      final bloc = ProgramOverviewBloc(fakeClassRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider<ProgramOverviewBloc>.value(
              value: bloc,
              child: const ProgramOverviewView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No classes have been opened for this term yet.'), findsOneWidget);
      expect(find.text('No matching classes found'), findsNothing);
      expect(find.byKey(const Key('program_overview_clear_filters_button')), findsNothing);
    });

    testWidgets(
        'shows "No matching classes found" and Clear Filters button when filters hide classes, and clearing restores list',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      fakeClassRepo.mockClasses = [
        ClassModel(
          classId: 'c1',
          subjectId: 's1',
          subjectCode: 'IT 101',
          subjectTitle: 'Intro to Computing',
          yearLevel: 1,
          userId: 't1',
          teacherName: 'Prof. Alan',
          termId: 'term-1',
          className: 'BSIT 1A',
          enrolledCount: 25,
          schedules: const [],
        ),
      ];

      final bloc = ProgramOverviewBloc(fakeClassRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider<ProgramOverviewBloc>.value(
              value: bloc,
              child: const ProgramOverviewView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially class is visible
      expect(find.text('BSIT 1A'), findsWidgets);
      expect(find.text('No matching classes found'), findsNothing);

      // Enter search text that filters it out
      await tester.enterText(find.byType(TextField), 'NonExistentSubject');
      await tester.pumpAndSettle();

      // Now "No matching classes found" is shown with Clear Filters button
      expect(find.text('No matching classes found'), findsOneWidget);
      expect(find.text('No classes have been opened for this term yet.'), findsNothing);
      expect(find.byKey(const Key('program_overview_clear_filters_button')), findsOneWidget);

      // Tap Clear Filters button
      await tester.tap(find.byKey(const Key('program_overview_clear_filters_button')));
      await tester.pumpAndSettle();

      // Search field is cleared and class is visible again
      expect(find.text('No matching classes found'), findsNothing);
      expect(find.text('BSIT 1A'), findsWidgets);
    });
  });

  group('Faculty Tab Empty State Wording', () {
    testWidgets(
        'shows "No classes opened for this term yet" when term has zero classes at all',
        (tester) async {
      final teacher1 = UserSearchResultModel(
        userId: 'teacher-1',
        firstname: 'Alan',
        lastname: 'Turing',
        email: 'alan@dbtc-cebu.edu.ph',
        role: 3,
        roleName: 'Teacher',
        programId: 1,
        programCode: 'BSIT',
      );
      fakeUserSearchRepo.mockFaculty = [teacher1];
      fakeClassRepo.mockClasses = []; // No classes in term

      final bloc = FacultyBloc(fakeUserSearchRepo, fakeClassRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider<FacultyBloc>.value(
              value: bloc,
              child: const FacultyView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Expand Alan Turing card
      await tester.tap(find.text('Alan Turing'));
      await tester.pumpAndSettle();

      expect(find.text('No classes opened for this term yet'), findsOneWidget);
      expect(find.text('All classes staffed'), findsNothing);
    });

    testWidgets(
        'shows "All classes staffed" when classes exist in term and every one has a teacher',
        (tester) async {
      final teacher1 = UserSearchResultModel(
        userId: 'teacher-1',
        firstname: 'Alan',
        lastname: 'Turing',
        email: 'alan@dbtc-cebu.edu.ph',
        role: 3,
        roleName: 'Teacher',
        programId: 1,
        programCode: 'BSIT',
      );
      final teacher2 = UserSearchResultModel(
        userId: 'teacher-2',
        firstname: 'Ada',
        lastname: 'Lovelace',
        email: 'ada@dbtc-cebu.edu.ph',
        role: 3,
        roleName: 'Teacher',
        programId: 1,
        programCode: 'BSIT',
      );
      fakeUserSearchRepo.mockFaculty = [teacher1, teacher2];

      // Alan has a class assigned; Ada has 0 classes; all classes in term are assigned
      fakeClassRepo.mockClasses = [
        ClassModel(
          classId: 'c1',
          subjectId: 's1',
          subjectCode: 'IT 101',
          subjectTitle: 'Intro',
          yearLevel: 1,
          userId: 'teacher-1',
          teacherName: 'Alan Turing',
          termId: 'term-1',
          className: 'BSIT 1A',
          enrolledCount: 20,
          schedules: const [],
        ),
      ];

      final bloc = FacultyBloc(fakeUserSearchRepo, fakeClassRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider<FacultyBloc>.value(
              value: bloc,
              child: const FacultyView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Expand Ada Lovelace card (who has 0 classes)
      await tester.tap(find.text('Ada Lovelace'));
      await tester.pumpAndSettle();

      expect(find.text('All classes staffed'), findsOneWidget);
      expect(find.text('No classes opened for this term yet'), findsNothing);
    });
  });
}
