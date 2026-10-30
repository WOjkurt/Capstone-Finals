import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sis_student_app/blocs/schedule_bloc.dart';
import 'package:sis_student_app/models/class_models.dart';
import 'package:sis_student_app/models/grading_models.dart';
import 'package:sis_student_app/models/setup_models.dart';
import 'package:sis_student_app/models/student_models.dart';
import 'package:sis_student_app/repositories/student_repository.dart';
import 'package:sis_student_app/services/auth_service.dart';
import 'package:sis_student_app/theme/app_theme.dart';
import 'package:sis_student_app/views/schedule_view.dart';

class FakeAuthService extends AuthService {}

class FakeStudentRepository implements StudentRepository {
  AcademicTermModel? activeTerm;
  List<StudentScheduleItemModel> scheduleItems = [];
  bool shouldThrow = false;
  String? lastUserIdPassed;
  String? lastTermIdPassed;

  @override
  Future<AcademicTermModel?> getActiveTerm() async {
    if (shouldThrow) {
      throw Exception('Network error fetching active term');
    }
    return activeTerm;
  }

  @override
  Future<List<StudentScheduleItemModel>> getMySchedule(
    String userId,
    String termId,
  ) async {
    if (shouldThrow) {
      throw Exception('Network error fetching schedule');
    }
    lastUserIdPassed = userId;
    lastTermIdPassed = termId;
    return scheduleItems;
  }

  @override
  Future<List<AcademicTermModel>> getAllTerms() async =>
      activeTerm != null ? [activeTerm!] : [];

  @override
  Future<List<GradeClearanceModel>> getGradeClearances(String userId) async => [];

  @override
  Future<List<GradeModel>> getGrades(String userId, String termId) async => [];

  @override
  Future<StudentProfileModel> getMyProfile() async =>
      throw UnimplementedError();
}

void main() {
  group('StudentScheduleItemModel tests', () {
    test('deserializes enriched StudyLoadResponseDto correctly', () {
      final json = {
        'studyLoadId': 'sl-100',
        'classId': 'class-200',
        'studentUserId': 'student-1',
        'studentName': 'Kurt Woj',
        'subjectCode': 'CS 301',
        'subjectTitle': 'Software Engineering',
        'units': 3.0,
        'className': 'BSCS 3A',
        'teacherName': 'Engr. Garcia',
        'loadStatus': 'Enrolled',
        'termLabel': '2026-2027 (Sem 1)',
        'schedules': [
          {
            'scheduleId': 'sched-1',
            'classId': 'class-200',
            'daysOfWeek': 'MWF',
            'startTime': '08:00:00',
            'endTime': '09:30:00',
            'room': 'Room 301',
          },
          {
            'scheduleId': 'sched-2',
            'classId': 'class-200',
            'daysOfWeek': 'Sat',
            'startTime': '10:00:00',
            'endTime': '12:00:00',
            'room': 'Lab 2',
          },
        ],
      };

      final item = StudentScheduleItemModel.fromJson(json);

      expect(item.studyLoadId, 'sl-100');
      expect(item.classId, 'class-200');
      expect(item.studentUserId, 'student-1');
      expect(item.studentName, 'Kurt Woj');
      expect(item.subjectCode, 'CS 301');
      expect(item.subjectTitle, 'Software Engineering');
      expect(item.units, 3.0);
      expect(item.unitsLabel, '3 Units');
      expect(item.className, 'BSCS 3A');
      expect(item.teacherName, 'Engr. Garcia');
      expect(item.teacherDisplayName, 'Engr. Garcia');
      expect(item.loadStatus, 'Enrolled');
      expect(item.termLabel, '2026-2027 (Sem 1)');
      expect(item.schedules.length, 2);
      expect(
        item.scheduleSummary,
        'MWF 8:00 AM – 9:30 AM · Room 301 | Sat 10:00 AM – 12:00 PM · Lab 2',
      );
    });

    test('handles null/empty optional fields gracefully', () {
      final json = {
        'studyLoadId': 'sl-101',
        'classId': 'class-201',
        'subjectCode': 'MATH 101',
        'subjectTitle': 'Calculus I',
        'units': 1.0,
        'className': 'BSIT 1A',
        'loadStatus': 'Enrolled',
        'termLabel': '2026-2027',
        'schedules': <dynamic>[],
      };

      final item = StudentScheduleItemModel.fromJson(json);

      expect(item.teacherName, isNull);
      expect(item.teacherDisplayName, 'Instructor TBA');
      expect(item.unitsLabel, '1 Unit');
      expect(item.scheduleSummary, 'No schedule assigned');
    });

    test('AcademicTermModel isActive property serialization and label', () {
      final activeJson = {
        'termId': 'term-active',
        'schoolYear': '2026-2027',
        'semester': 1,
        'isActive': true,
      };

      final term = AcademicTermModel.fromJson(activeJson);
      expect(term.termId, 'term-active');
      expect(term.schoolYear, '2026-2027');
      expect(term.semester, 1);
      expect(term.isActive, isTrue);
      expect(term.label, '2026-2027 — 1st Sem');

      final inactiveJson = {
        'termId': 'term-inactive',
        'schoolYear': '2025-2026',
        'semester': 2,
      };
      final inactiveTerm = AcademicTermModel.fromJson(inactiveJson);
      expect(inactiveTerm.isActive, isFalse);
      expect(inactiveTerm.label, '2025-2026 — 2nd Sem');
    });
  });

  group('ScheduleBloc tests', () {
    late FakeStudentRepository repository;
    late ScheduleBloc bloc;

    setUp(() {
      repository = FakeStudentRepository();
      bloc = ScheduleBloc(repository);
    });

    tearDown(() {
      bloc.close();
    });

    test('initial state is ScheduleInitial', () {
      expect(bloc.state, isA<ScheduleInitial>());
    });

    test('emits [ScheduleLoading, ScheduleLoaded] on successful fetch', () async {
      final term = const AcademicTermModel(
        termId: 'term-1',
        schoolYear: '2026-2027',
        semester: 1,
        isActive: true,
      );
      final item = const StudentScheduleItemModel(
        studyLoadId: 'sl-1',
        classId: 'c-1',
        subjectCode: 'IT 201',
        subjectTitle: 'Database Systems',
        units: 3.0,
        className: 'BSIT 2A',
        teacherName: 'Dr. Santos',
        loadStatus: 'Enrolled',
        termLabel: '2026-2027 (Sem 1)',
        schedules: [
          ClassScheduleModel(
            scheduleId: 's-1',
            classId: 'c-1',
            daysOfWeek: 'TTh',
            startTime: '10:30:00',
            endTime: '12:00:00',
            room: 'Lab 3',
          ),
        ],
      );

      repository.activeTerm = term;
      repository.scheduleItems = [item];

      expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ScheduleLoading>(),
          predicate<ScheduleLoaded>((state) {
            return state.activeTerm == term &&
                state.items.length == 1 &&
                state.totalUnits == 3.0 &&
                state.items.first.subjectCode == 'IT 201';
          }),
        ]),
      );

      bloc.add(LoadScheduleEvent(userId: 'student-user-123'));
    });

    test('emits ScheduleLoaded with activeTerm == null when no active term exists', () async {
      repository.activeTerm = null;

      expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ScheduleLoading>(),
          predicate<ScheduleLoaded>((state) {
            return state.activeTerm == null && state.items.isEmpty;
          }),
        ]),
      );

      bloc.add(LoadScheduleEvent(userId: 'student-user-123'));
    });

    test('emits ScheduleError when repository throws exception', () async {
      repository.shouldThrow = true;

      expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ScheduleLoading>(),
          isA<ScheduleError>(),
        ]),
      );

      bloc.add(LoadScheduleEvent(userId: 'student-user-123'));
    });
  });

  group('ScheduleView widget tests', () {
    late FakeStudentRepository repository;

    setUp(() {
      repository = FakeStudentRepository();
    });

    Widget createTestWidget({required ScheduleBloc bloc}) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: BlocProvider<ScheduleBloc>.value(
          value: bloc,
          child: const ScheduleView(userId: 'student-test-id'),
        ),
      );
    }

    testWidgets('renders loaded classes with active term and schedule details',
        (tester) async {
      final term = const AcademicTermModel(
        termId: 'term-active-1',
        schoolYear: '2026-2027',
        semester: 1,
        isActive: true,
      );

      final classes = [
        const StudentScheduleItemModel(
          studyLoadId: 'sl-1',
          classId: 'c-1',
          subjectCode: 'CS 101',
          subjectTitle: 'Introduction to Computing',
          units: 3.0,
          className: 'BSCS 1A',
          teacherName: 'Prof. Cruz',
          loadStatus: 'Enrolled',
          termLabel: '2026-2027 — 1st Sem',
          schedules: [
            ClassScheduleModel(
              scheduleId: 's-1',
              classId: 'c-1',
              daysOfWeek: 'MWF',
              startTime: '08:00:00',
              endTime: '09:30:00',
              room: 'Room 301',
            ),
          ],
        ),
        const StudentScheduleItemModel(
          studyLoadId: 'sl-2',
          classId: 'c-2',
          subjectCode: 'ENG 101',
          subjectTitle: 'Purposive Communication',
          units: 3.0,
          className: 'BSCS 1A',
          teacherName: 'Ms. Reyes',
          loadStatus: 'Enrolled',
          termLabel: '2026-2027 — 1st Sem',
          schedules: [
            ClassScheduleModel(
              scheduleId: 's-2',
              classId: 'c-2',
              daysOfWeek: 'TTh',
              startTime: '13:00:00',
              endTime: '14:30:00',
              room: 'Room 205',
            ),
          ],
        ),
      ];

      repository.activeTerm = term;
      repository.scheduleItems = classes;

      final bloc = ScheduleBloc(repository);

      await tester.pumpWidget(createTestWidget(bloc: bloc));
      await tester.pumpAndSettle();

      // Check header details
      expect(find.text('My Schedule'), findsOneWidget);
      expect(find.text('2026-2027 — 1st Sem'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('2 Classes · 6 Units'), findsOneWidget);

      // Check class 1
      expect(find.text('CS 101'), findsOneWidget);
      expect(find.text('Introduction to Computing'), findsOneWidget);
      expect(find.text('Prof. Cruz'), findsOneWidget);
      expect(find.text('MWF 8:00 AM – 9:30 AM · Room 301'), findsOneWidget);

      // Check class 2
      expect(find.text('ENG 101'), findsOneWidget);
      expect(find.text('Purposive Communication'), findsOneWidget);
      expect(find.text('Ms. Reyes'), findsOneWidget);
      expect(find.text('TTh 1:00 PM – 2:30 PM · Room 205'), findsOneWidget);

      bloc.close();
    });

    testWidgets('renders empty state when student has no enrolled classes',
        (tester) async {
      final term = const AcademicTermModel(
        termId: 'term-empty',
        schoolYear: '2026-2027',
        semester: 1,
        isActive: true,
      );

      repository.activeTerm = term;
      repository.scheduleItems = [];

      final bloc = ScheduleBloc(repository);

      await tester.pumpWidget(createTestWidget(bloc: bloc));
      await tester.pumpAndSettle();

      expect(find.text('2026-2027 — 1st Sem'), findsOneWidget);
      expect(find.text('You have no classes for this term'), findsOneWidget);
      expect(find.text('Refresh Schedule'), findsOneWidget);

      bloc.close();
    });

    testWidgets('renders gracefully on narrow mobile layout (375x667)',
        (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final term = const AcademicTermModel(
        termId: 'term-mobile',
        schoolYear: '2026-2027',
        semester: 2,
        isActive: true,
      );

      final classes = [
        const StudentScheduleItemModel(
          studyLoadId: 'sl-mob-1',
          classId: 'c-mob-1',
          subjectCode: 'IT 311',
          subjectTitle: 'Systems Integration and Architecture',
          units: 3.0,
          className: 'BSIT 3A - Day',
          teacherName: 'Prof. Long Instructor Name Here',
          loadStatus: 'Enrolled',
          termLabel: '2026-2027 — 2nd Sem',
          schedules: [
            ClassScheduleModel(
              scheduleId: 's-m-1',
              classId: 'c-mob-1',
              daysOfWeek: 'MWF',
              startTime: '08:00:00',
              endTime: '09:30:00',
              room: 'Computer Lab 304',
            ),
          ],
        ),
      ];

      repository.activeTerm = term;
      repository.scheduleItems = classes;

      final bloc = ScheduleBloc(repository);

      await tester.pumpWidget(createTestWidget(bloc: bloc));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('IT 311'), findsOneWidget);
      expect(find.text('Systems Integration and Architecture'), findsOneWidget);

      bloc.close();
    });

    testWidgets('renders separate Waiting for Registrar approval section and header excludes pending units',
        (tester) async {
      final term = const AcademicTermModel(
        termId: 'term-pending',
        schoolYear: '2026-2027',
        semester: 1,
        isActive: true,
      );

      final enrolledItem = const StudentScheduleItemModel(
        studyLoadId: 'sl-enrolled-1',
        classId: 'c-1',
        subjectCode: 'CS 101',
        subjectTitle: 'Intro to CS',
        units: 3.0,
        className: 'BSCS 1A',
        teacherName: 'Prof. Turing',
        loadStatus: 'Enrolled',
        termLabel: '2026-2027 — 1st Sem',
      );

      final pendingItem = const StudentScheduleItemModel(
        studyLoadId: 'sl-pending-1',
        classId: 'c-2',
        subjectCode: 'MATH 102',
        subjectTitle: 'Calculus I',
        units: 4.0,
        className: 'BSCS 1B',
        teacherName: 'Prof. Gauss',
        loadStatus: 'Pending',
        termLabel: '2026-2027 — 1st Sem',
      );

      repository.activeTerm = term;
      repository.scheduleItems = [enrolledItem, pendingItem];

      final bloc = ScheduleBloc(repository);

      await tester.pumpWidget(createTestWidget(bloc: bloc));
      await tester.pumpAndSettle();

      // Enrolled header pill reflects only enrolled items (1 Class · 3 Units), excluding pending 4 units
      expect(find.text('1 Class · 3 Units'), findsOneWidget);

      // Pending section is rendered with "Waiting for Registrar approval"
      expect(find.text('Waiting for Registrar approval'), findsOneWidget);
      expect(find.text('1 pending'), findsOneWidget);
      expect(find.text('MATH 102'), findsOneWidget);
      expect(find.text('Calculus I'), findsOneWidget);

      // Enrolled item rendered in main list
      expect(find.text('CS 101'), findsOneWidget);
      expect(find.text('Intro to CS'), findsOneWidget);

      bloc.close();
    });

    testWidgets('Rejected study loads do not appear in schedule or pending card', (tester) async {
      final repository = FakeStudentRepository();
      const term = AcademicTermModel(
        termId: 'term-1',
        schoolYear: '2026-2027',
        semester: 1,
        isActive: true,
      );

      final enrolledItem = const StudentScheduleItemModel(
        studyLoadId: 'sl-enrolled-1',
        classId: 'c-1',
        subjectCode: 'CS 101',
        subjectTitle: 'Intro to CS',
        units: 3.0,
        className: 'BSCS 1A',
        teacherName: 'Prof. Turing',
        loadStatus: 'Enrolled',
        termLabel: '2026-2027 — 1st Sem',
      );

      final rejectedItem = const StudentScheduleItemModel(
        studyLoadId: 'sl-rejected-1',
        classId: 'c-3',
        subjectCode: 'PHYS 101',
        subjectTitle: 'University Physics',
        units: 4.0,
        className: 'BSCS 1C',
        teacherName: 'Prof. Newton',
        loadStatus: 'Rejected',
        termLabel: '2026-2027 — 1st Sem',
      );

      expect(rejectedItem.isRejected, isTrue);
      expect(rejectedItem.isEnrolled, isFalse);
      expect(rejectedItem.isPending, isFalse);

      repository.activeTerm = term;
      repository.scheduleItems = [enrolledItem, rejectedItem];

      final bloc = ScheduleBloc(repository);

      await tester.pumpWidget(createTestWidget(bloc: bloc));
      await tester.pumpAndSettle();

      // Enrolled item is shown
      expect(find.text('CS 101'), findsOneWidget);
      expect(find.text('Intro to CS'), findsOneWidget);

      // Rejected item is NOT shown in schedule or pending
      expect(find.text('PHYS 101'), findsNothing);
      expect(find.text('University Physics'), findsNothing);
      expect(find.text('Waiting for Registrar approval'), findsNothing);

      bloc.close();
    });
  });
}
