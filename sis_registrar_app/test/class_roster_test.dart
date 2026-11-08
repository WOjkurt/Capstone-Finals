import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/models/class_models.dart';
import 'package:sis_registrar_app/models/grading_models.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/blocs/setup_bloc.dart';
import 'package:sis_registrar_app/repositories/class_repository.dart';
import 'package:sis_registrar_app/repositories/enrollment_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/views/widgets/class_roster_dialog.dart';
import 'package:sis_registrar_app/views/widgets/student_study_load_dialog.dart';

class MockAuthService implements AuthService {
  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  User? get currentUser => null;

  @override
  Stream<User?> get userStream => const Stream.empty();

  @override
  Future<String?> getToken() async => 'test-token';

  @override
  Future<Map<String, String>> getAuthHeaders() async => {
        'Authorization': 'Bearer test-token',
        'Content-Type': 'application/json',
      };

  @override
  Future<Map<String, dynamic>?> signInAndVerify(String email, String password) async => null;

  @override
  Future<Map<String, dynamic>?> fetchCurrentUserInfo() async => null;

  @override
  Future<void> signOut() async {}
}

class FakeAcademicSetupRepository implements AcademicSetupRepository {
  List<AcademicTermModel> terms = [
    const AcademicTermModel(
      termId: 'term-1',
      schoolYear: '2026-2027',
      semester: 1,
      isActive: true,
    ),
  ];

  @override
  Future<List<AcademicProgramModel>> getPrograms() async => [];
  @override
  Future<AcademicProgramModel> createProgram({required String code, required String name}) async => throw UnimplementedError();
  @override
  Future<AcademicProgramModel> updateProgram(int id, {required String code, required String name}) async => throw UnimplementedError();
  @override
  Future<void> deleteProgram(int id) async {}
  @override
  Future<List<AcademicTermModel>> getTerms() async => terms;
  @override
  Future<AcademicTermModel> createTerm({required String schoolYear, required int semester}) async => throw UnimplementedError();
  @override
  Future<AcademicTermModel> updateTerm(String id, {required String schoolYear, required int semester}) async => throw UnimplementedError();
  @override
  Future<void> deleteTerm(String id) async {}
  @override
  Future<AcademicTermModel> setEnrollmentPeriod(String id, {DateTime? opensOn, DateTime? closesOn}) async =>
      throw UnimplementedError();

  @override
  Future<AcademicTermModel> activateTerm(String id) async => throw UnimplementedError();
  @override
  Future<List<SubjectModel>> getSubjects({int? programId, int? yearLevel}) async => [];
  @override
  Future<SubjectModel> createSubject(Map<String, dynamic> dto) async => throw UnimplementedError();
  @override
  Future<SubjectModel> updateSubject(String id, Map<String, dynamic> dto) async => throw UnimplementedError();
  @override
  Future<void> deleteSubject(String id) async {}
  @override
  Future<List<PrerequisiteModel>> getPrerequisites(String subjectId) async => [];
  @override
  Future<void> addPrerequisite(String subjectId, String prerequisiteSubjectId,
      {int requisiteType = 0}) async {}
  @override
  Future<void> removePrerequisite(String prerequisiteId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Class Models Unit Tests', () {
    test('ClassRosterItemModel parsing and helper getters', () {
      final json = {
        'studyLoadId': 'sl-100',
        'studentUserId': 'usr-1',
        'studentName': 'Ada Lovelace',
        'subjectCode': 'CS101',
        'subjectTitle': 'Intro to CS',
        'className': 'BSCS 1-A',
        'teacherName': 'Prof. Turing',
        'loadStatus': 'Enrolled',
        'termLabel': '2026-2027 (Sem 1)',
      };

      final item = ClassRosterItemModel.fromJson(json);

      expect(item.studyLoadId, 'sl-100');
      expect(item.studentUserId, 'usr-1');
      expect(item.displayName, 'Ada Lovelace');
      expect(item.loadStatus, 'Enrolled');
      expect(item.loadStatusInt, 1);
      expect(item.isEnrolled, isTrue);
      expect(item.isDropped, isFalse);
      expect(item.isWithdrawn, isFalse);
    });

    test('ClassRosterItemModel status mappings for Dropped and Withdrawn', () {
      final droppedItem = ClassRosterItemModel.fromJson({
        'studyLoadId': 'sl-2',
        'studentName': 'Bob',
        'subjectCode': 'CS101',
        'subjectTitle': 'Intro to CS',
        'className': 'BSCS 1-A',
        'loadStatus': 'Dropped',
        'termLabel': '2026-2027',
      });
      expect(droppedItem.loadStatusInt, 2);
      expect(droppedItem.isDropped, isTrue);

      final withdrawnItem = ClassRosterItemModel.fromJson({
        'studyLoadId': 'sl-3',
        'studentName': 'Charlie',
        'subjectCode': 'CS101',
        'subjectTitle': 'Intro to CS',
        'className': 'BSCS 1-A',
        'loadStatus': 'Withdrawn',
        'termLabel': '2026-2027',
      });
      expect(withdrawnItem.loadStatusInt, 3);
      expect(withdrawnItem.isWithdrawn, isTrue);
    });

    test('ClassRosterItemModel displayName fallback when name is null or blank', () {
      final itemNull = ClassRosterItemModel.fromJson({
        'studyLoadId': 'sl-4',
        'studentName': null,
        'subjectCode': 'CS101',
        'subjectTitle': 'Intro to CS',
        'className': 'BSCS 1-A',
        'loadStatus': 'Enrolled',
        'termLabel': '2026-2027',
      });
      expect(itemNull.displayName, 'Unknown Student');

      final itemBlank = ClassRosterItemModel.fromJson({
        'studyLoadId': 'sl-5',
        'studentName': '   ',
        'subjectCode': 'CS101',
        'subjectTitle': 'Intro to CS',
        'className': 'BSCS 1-A',
        'loadStatus': 'Enrolled',
        'termLabel': '2026-2027',
      });
      expect(itemBlank.displayName, 'Unknown Student');
    });

    test('ClassModel schedule summary and termLabel', () {
      final classModel = ClassModel(
        classId: 'c-1',
        subjectId: 's-1',
        subjectCode: 'MATH101',
        subjectTitle: 'Calculus I',
        termId: 't-1',
        termSchoolYear: '2026-2027',
        termSemester: 1,
        className: 'Section A',
        schedules: [
          const ClassScheduleModel(
            scheduleId: 'sch-1',
            classId: 'c-1',
            daysOfWeek: 'M/W/F',
            startTime: '08:00',
            endTime: '09:30',
            room: 'Room 301',
          ),
        ],
      );

      expect(classModel.termLabel, '2026-2027 (1st Sem)');
      expect(classModel.scheduleSummary, 'M/W/F 8:00 AM – 9:30 AM · Room 301');
    });
  });

  group('ClassRepository HTTP Tests', () {
    test('getClasses queries /api/Classes with termId filter', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/Classes');
        expect(request.url.queryParameters['termId'], 'term-123');
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(
          jsonEncode([
            {
              'classId': 'c-1',
              'subjectId': 's-1',
              'subjectCode': 'CS101',
              'subjectTitle': 'Intro to CS',
              'termId': 'term-123',
              'className': 'BSCS 1-A',
              'enrolledCount': 5,
            }
          ]),
          200,
        );
      });

      final repo = ClassRepository(MockAuthService(), mockClient);
      final classes = await repo.getClasses(termId: 'term-123');

      expect(classes.length, 1);
      expect(classes[0].subjectCode, 'CS101');
      expect(classes[0].enrolledCount, 5);
    });

    test('getClassRoster queries /api/studyloads/class/{id}', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/studyloads/class/c-99');
        return http.Response(
          jsonEncode([
            {
              'studyLoadId': 'sl-1',
              'studentName': 'Grace Hopper',
              'subjectCode': 'CS101',
              'subjectTitle': 'Intro to CS',
              'className': 'BSCS 1-A',
              'loadStatus': 'Enrolled',
              'termLabel': '2026-2027',
            }
          ]),
          200,
        );
      });

      final repo = ClassRepository(MockAuthService(), mockClient);
      final roster = await repo.getClassRoster('c-99');

      expect(roster.length, 1);
      expect(roster[0].displayName, 'Grace Hopper');
      expect(roster[0].loadStatus, 'Enrolled');
    });

    test('updateStudyLoadStatus sends PATCH /api/studyloads/{id}/status with loadStatus', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/studyloads/sl-42/status');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['loadStatus'], 2); // Dropped
        return http.Response(
          jsonEncode({
            'studyLoadId': 'sl-42',
            'studentName': 'Alan Turing',
            'subjectCode': 'CS101',
            'subjectTitle': 'Intro to CS',
            'className': 'BSCS 1-A',
            'loadStatus': 'Dropped',
            'termLabel': '2026-2027',
          }),
          200,
        );
      });

      final repo = ClassRepository(MockAuthService(), mockClient);
      final updated = await repo.updateStudyLoadStatus('sl-42', 2);

      expect(updated.studyLoadId, 'sl-42');
      expect(updated.loadStatus, 'Dropped');
      expect(updated.isDropped, isTrue);
    });
  });

  group('ClassRosterDialog Widget Tests', () {
    late ClassModel testClass;
    late ClassRosterItemModel enrolledStudent;
    late ClassRosterItemModel droppedStudent;

    setUp(() {
      testClass = const ClassModel(
        classId: 'c-test-1',
        subjectId: 's-test-1',
        subjectCode: 'CS101',
        subjectTitle: 'Intro to CS',
        className: 'BSCS 1-A',
        termId: 't-test-1',
        termSchoolYear: '2026-2027',
        termSemester: 1,
        enrolledCount: 2,
      );

      enrolledStudent = const ClassRosterItemModel(
        studyLoadId: 'sl-enrolled-1',
        studentUserId: 'usr-1',
        studentName: 'Alice Developer',
        subjectCode: 'CS101',
        subjectTitle: 'Intro to CS',
        className: 'BSCS 1-A',
        loadStatus: 'Enrolled',
        termLabel: '2026-2027',
      );

      droppedStudent = const ClassRosterItemModel(
        studyLoadId: 'sl-dropped-2',
        studentUserId: 'usr-2',
        studentName: 'Bob Student',
        subjectCode: 'CS101',
        subjectTitle: 'Intro to CS',
        className: 'BSCS 1-A',
        loadStatus: 'Dropped',
        termLabel: '2026-2027',
      );
    });

    testWidgets('Displays roster list, shows confirmation dialog on Drop, and cancels cleanly', (tester) async {
      int patchCallCount = 0;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'studyLoadId': enrolledStudent.studyLoadId,
                'studentUserId': enrolledStudent.studentUserId,
                'studentName': enrolledStudent.studentName,
                'subjectCode': enrolledStudent.subjectCode,
                'subjectTitle': enrolledStudent.subjectTitle,
                'className': enrolledStudent.className,
                'loadStatus': 'Enrolled',
                'termLabel': enrolledStudent.termLabel,
              }
            ]),
            200,
          );
        } else if (request.method == 'PATCH') {
          patchCallCount++;
          return http.Response(
            jsonEncode({
              'studyLoadId': enrolledStudent.studyLoadId,
              'studentName': enrolledStudent.studentName,
              'subjectCode': enrolledStudent.subjectCode,
              'subjectTitle': enrolledStudent.subjectTitle,
              'className': enrolledStudent.className,
              'loadStatus': 'Dropped',
              'termLabel': enrolledStudent.termLabel,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      // Register mock repository
      if (getIt.isRegistered<ClassRepository>()) {
        getIt.unregister<ClassRepository>();
      }
      getIt.registerSingleton<ClassRepository>(ClassRepository(MockAuthService(), mockClient));

      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClassRosterDialog(classItem: testClass),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify student and load status badge rendered
      expect(find.text('Alice Developer'), findsOneWidget);
      expect(find.text('Enrolled'), findsOneWidget);

      // Open status menu
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      // Verify menu items
      expect(find.text('Drop Student'), findsOneWidget);
      expect(find.text('Withdraw Student'), findsOneWidget);

      // Tap Drop Student
      await tester.tap(find.text('Drop Student'));
      await tester.pumpAndSettle();

      // Verify Confirmation Dialog appears
      expect(find.text('Drop Student?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Cancel the dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Ensure no PATCH request was made and status remains Enrolled
      expect(patchCallCount, 0);
      expect(find.text('Enrolled'), findsOneWidget);
    });

    testWidgets('Confirming Drop Student dispatches PATCH and updates badge immediately', (tester) async {
      int patchCallCount = 0;
      String? requestedReason;
      int? requestedStatus;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'studyLoadId': enrolledStudent.studyLoadId,
                'studentUserId': enrolledStudent.studentUserId,
                'studentName': enrolledStudent.studentName,
                'subjectCode': enrolledStudent.subjectCode,
                'subjectTitle': enrolledStudent.subjectTitle,
                'className': enrolledStudent.className,
                'loadStatus': 'Enrolled',
                'termLabel': enrolledStudent.termLabel,
              }
            ]),
            200,
          );
        } else if (request.method == 'PATCH') {
          patchCallCount++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requestedStatus = body['loadStatus'] as int;
          requestedReason = body['reason'] as String?;
          return http.Response(
            jsonEncode({
              'studyLoadId': enrolledStudent.studyLoadId,
              'studentName': enrolledStudent.studentName,
              'subjectCode': enrolledStudent.subjectCode,
              'subjectTitle': enrolledStudent.subjectTitle,
              'className': enrolledStudent.className,
              'loadStatus': 'Dropped',
              'termLabel': enrolledStudent.termLabel,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      if (getIt.isRegistered<ClassRepository>()) {
        getIt.unregister<ClassRepository>();
      }
      getIt.registerSingleton<ClassRepository>(ClassRepository(MockAuthService(), mockClient));

      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClassRosterDialog(classItem: testClass),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open status menu
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      // Tap Drop Student
      await tester.tap(find.text('Drop Student'));
      await tester.pumpAndSettle();

      // Tap Confirm 'Drop Student' in dialog
      // A reason is required to drop.
      final dropConfirmButton = find.byKey(const ValueKey('confirm_change_button'));
      expect(dropConfirmButton, findsOneWidget);
      await tester.tap(dropConfirmButton);
      await tester.pumpAndSettle();
      expect(find.text('A reason is required.'), findsOneWidget);
      expect(patchCallCount, 0);
      await tester.enterText(find.byKey(const ValueKey('change_reason_field')), 'Schedule conflict');
      await tester.tap(dropConfirmButton);
      await tester.pumpAndSettle();
      expect(requestedReason, 'Schedule conflict');

      // Verify PATCH was called with status 2 (Dropped)
      expect(patchCallCount, 1);
      expect(requestedStatus, 2);

      // Verify UI immediately updated to show 'Dropped' badge
      expect(find.text('Dropped'), findsOneWidget);
      expect(find.text('Alice Developer updated to Dropped successfully.'), findsOneWidget);
    });

    testWidgets('Re-enroll Student undo action for Dropped student', (tester) async {
      int patchCallCount = 0;
      int? requestedStatus;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'studyLoadId': droppedStudent.studyLoadId,
                'studentUserId': droppedStudent.studentUserId,
                'studentName': droppedStudent.studentName,
                'subjectCode': droppedStudent.subjectCode,
                'subjectTitle': droppedStudent.subjectTitle,
                'className': droppedStudent.className,
                'loadStatus': 'Dropped',
                'termLabel': droppedStudent.termLabel,
              }
            ]),
            200,
          );
        } else if (request.method == 'PATCH') {
          patchCallCount++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requestedStatus = body['loadStatus'] as int;
          return http.Response(
            jsonEncode({
              'studyLoadId': droppedStudent.studyLoadId,
              'studentName': droppedStudent.studentName,
              'subjectCode': droppedStudent.subjectCode,
              'subjectTitle': droppedStudent.subjectTitle,
              'className': droppedStudent.className,
              'loadStatus': 'Enrolled',
              'termLabel': droppedStudent.termLabel,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      if (getIt.isRegistered<ClassRepository>()) {
        getIt.unregister<ClassRepository>();
      }
      getIt.registerSingleton<ClassRepository>(ClassRepository(MockAuthService(), mockClient));

      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClassRosterDialog(classItem: testClass),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify initial Dropped status
      expect(find.text('Dropped'), findsOneWidget);

      // Open status menu
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      // Verify 'Re-enroll Student' option is available
      expect(find.text('Re-enroll Student'), findsOneWidget);

      await tester.tap(find.text('Re-enroll Student'));
      await tester.pumpAndSettle();

      // Confirmation dialog for Re-enroll
      expect(find.text('Re-enroll Student?'), findsOneWidget);
      // Re-enrolling: the reason is optional.
      final reEnrollConfirm = find.byKey(const ValueKey('confirm_change_button'));
      await tester.tap(reEnrollConfirm);
      await tester.pumpAndSettle();

      // Verify PATCH called with status 1 (Enrolled)
      expect(patchCallCount, 1);
      expect(requestedStatus, 1);

      // Verify badge updated to Enrolled
      expect(find.text('Enrolled'), findsOneWidget);
    });

    testWidgets('Class rosters hide Rejected loads by default', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'studyLoadId': enrolledStudent.studyLoadId,
                'studentUserId': enrolledStudent.studentUserId,
                'studentName': enrolledStudent.studentName,
                'subjectCode': enrolledStudent.subjectCode,
                'subjectTitle': enrolledStudent.subjectTitle,
                'className': enrolledStudent.className,
                'loadStatus': 'Enrolled',
                'termLabel': enrolledStudent.termLabel,
              },
              {
                'studyLoadId': 'sl-rejected-3',
                'studentUserId': 'usr-3',
                'studentName': 'Charlie Rejected',
                'subjectCode': 'CS101',
                'subjectTitle': 'Intro to CS',
                'className': 'BSCS 1-A',
                'loadStatus': 'Rejected',
                'termLabel': '2026-2027',
              },
            ]),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      if (getIt.isRegistered<ClassRepository>()) {
        getIt.unregister<ClassRepository>();
      }
      getIt.registerSingleton<ClassRepository>(ClassRepository(MockAuthService(), mockClient));

      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClassRosterDialog(classItem: testClass),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Alice Developer should be displayed
      expect(find.text('Alice Developer'), findsOneWidget);
      expect(find.text('Enrolled'), findsOneWidget);

      // Charlie Rejected should be hidden by default
      expect(find.text('Charlie Rejected'), findsNothing);

      // Header badge shows count 1 (excluding rejected)
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsNothing);
    });
  });

  group('StudentStudyLoadDialog Widget Tests', () {
    testWidgets('Renders student study load and allows withdrawing class', (tester) async {
      int patchCallCount = 0;
      int? requestedStatus;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'studyLoadId': 'sl-std-1',
                'studentUserId': 'usr-std-1',
                'studentName': 'Ada Student',
                'subjectCode': 'PHYS101',
                'subjectTitle': 'Physics Mechanics',
                'className': 'BSCS 1-B',
                'teacherName': 'Prof. Feynman',
                'loadStatus': 'Enrolled',
                'termLabel': '2026-2027 (Sem 1)',
              }
            ]),
            200,
          );
        } else if (request.method == 'PATCH') {
          patchCallCount++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requestedStatus = body['loadStatus'] as int;
          return http.Response(
            jsonEncode({
              'studyLoadId': 'sl-std-1',
              'studentName': 'Ada Student',
              'subjectCode': 'PHYS101',
              'subjectTitle': 'Physics Mechanics',
              'className': 'BSCS 1-B',
              'loadStatus': 'Withdrawn',
              'termLabel': '2026-2027 (Sem 1)',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      if (getIt.isRegistered<ClassRepository>()) {
        getIt.unregister<ClassRepository>();
      }
      getIt.registerSingleton<ClassRepository>(ClassRepository(MockAuthService(), mockClient));

      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final testUser = UserSearchResultModel(
        userId: 'usr-std-1',
        email: 'ada@example.com',
        role: 5,
        firstname: 'Ada',
        lastname: 'Student',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentStudyLoadDialog(
              student: testUser,
              termId: 't-1',
              termLabel: '2026-2027 (Sem 1)',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('PHYS101'), findsOneWidget);
      expect(find.text('Physics Mechanics'), findsOneWidget);
      expect(find.text('Enrolled'), findsOneWidget);

      // Open status menu
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      // Tap Withdraw Student
      await tester.tap(find.text('Withdraw Student'));
      await tester.pumpAndSettle();

      expect(find.text('Withdraw in PHYS101?'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('change_reason_field')), 'Medical');
      final withdrawBtn = find.byKey(const ValueKey('confirm_change_button'));
      await tester.tap(withdrawBtn);
      await tester.pumpAndSettle();

      expect(patchCallCount, 1);
      expect(requestedStatus, 3); // Withdrawn
      expect(find.text('Withdrawn'), findsOneWidget);
    });
  });

  group('SetupBloc SelectTermForClassesEvent Tests', () {
    test('SelectTermForClassesEvent updates activeTab to 3 and sets selectedTermIdForClasses', () {
      final fakeSetupRepo = FakeAcademicSetupRepository();
      final bloc = SetupBloc(fakeSetupRepo);

      expect(bloc.state.activeTab, 0);
      expect(bloc.state.selectedTermIdForClasses, isNull);

      bloc.add(SelectTermForClassesEvent('term-special-99'));

      expect(
        bloc.stream,
        emits(predicate<SetupState>((s) =>
            s.activeTab == 3 && s.selectedTermIdForClasses == 'term-special-99')),
      );
    });
  });
}
