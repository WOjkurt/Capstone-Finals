import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/models/class_models.dart';
import 'package:sis_registrar_app/models/grading_models.dart';
import 'package:sis_registrar_app/repositories/class_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/utils/error_handler.dart';
import 'package:sis_registrar_app/views/widgets/status_badge.dart';
import 'package:sis_registrar_app/views/widgets/student_study_load_dialog.dart';

class MockAuthService implements AuthService {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pending Study Loads Models Unit Tests', () {
    test('ClassRosterItemModel parses isPending, isForced, and forcedReason', () {
      final json = {
        'studyLoadId': 'sl-pending-1',
        'studentUserId': 'usr-1',
        'studentName': 'Ada Lovelace',
        'subjectCode': 'CS102',
        'subjectTitle': 'Data Structures',
        'className': 'BSCS 1-B',
        'loadStatus': 'Pending',
        'termLabel': '2026-2027 (Sem 1)',
        'isForced': true,
        'forcedReason': 'Dean override for graduating student',
        'forcedByUserID': 'head-123',
      };

      final item = ClassRosterItemModel.fromJson(json);

      expect(item.studyLoadId, 'sl-pending-1');
      expect(item.isPending, isTrue);
      expect(item.loadStatusInt, 4);
      expect(item.isEnrolled, isFalse);
      expect(item.isForced, isTrue);
      expect(item.forcedReason, 'Dean override for graduating student');
      expect(item.forcedByUserId, 'head-123');
    });

    test('ClassRosterItemModel parses Rejected correctly', () {
      final json = {
        'studyLoadId': 'sl-rejected-1',
        'loadStatus': 'Rejected',
      };
      final item = ClassRosterItemModel.fromJson(json);
      expect(item.loadStatusInt, 5);
      expect(item.isRejected, isTrue);
      expect(item.isPending, isFalse);
      expect(item.isEnrolled, isFalse);
    });

    test('StatusBadge.forLoadStatus renders neutral Rejected badge', () {
      final badge = StatusBadge.forLoadStatus('Rejected') as StatusBadge;
      expect(badge.label, 'Rejected');
      expect(badge.backgroundColor, const Color(0xFFF3F4F6));
      expect(badge.textColor, const Color(0xFF4B5563));
    });

    test('PendingStudyLoadSummaryModel parses correctly from json', () {
      final json = {
        'userId': 'usr-42',
        'fullName': 'Grace Hopper',
        'lrn': '123456789012',
        'programCode': 'BSCS',
        'programName': 'Bachelor of Science in Computer Science',
        'yearLevel': 2,
        'pendingCount': 3,
        'pendingUnits': 9.0,
      };

      final summary = PendingStudyLoadSummaryModel.fromJson(json);

      expect(summary.userId, 'usr-42');
      expect(summary.fullName, 'Grace Hopper');
      expect(summary.lrn, '123456789012');
      expect(summary.programCode, 'BSCS');
      expect(summary.programName, 'Bachelor of Science in Computer Science');
      expect(summary.yearLevel, 2);
      expect(summary.pendingCount, 3);
      expect(summary.pendingUnits, 9.0);
    });
  });

  group('ClassRepository Pending Workflow Methods', () {
    test('finalizeStudyLoads posts to /api/studyloads/finalize and returns map', () async {
      final mockClient = MockClient((req) async {
        expect(req.url.path, '/api/studyloads/finalize');
        expect(req.method, 'POST');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['userId'], 'usr-1');
        expect(body['termId'], 'term-1');
        expect(body['studyLoadIds'], ['sl-1']);

        return http.Response(
          jsonEncode({
            'success': true,
            'finalizedLoads': [
              {
                'studyLoadID': 'sl-1',
                'loadStatus': 'Enrolled',
              }
            ],
            'findings': [],
            'message': 'Successfully finalized 1 load(s).'
          }),
          200,
        );
      });

      final repo = ClassRepository(MockAuthService(), mockClient);
      final res = await repo.finalizeStudyLoads(
        userId: 'usr-1',
        termId: 'term-1',
        studyLoadIds: ['sl-1'],
      );

      expect(res['success'], isTrue);
      expect((res['finalizedLoads'] as List).length, 1);
    });

    test('finalizeStudyLoads throws ApiException with findings message on 400', () async {
      final mockClient = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'message': 'Cannot finalize pending loads due to blocking enrollment validation findings.',
            'findings': [
              {
                'code': 'PREREQUISITE_NOT_MET',
                'message': 'Missing prerequisite: MATH101.',
                'subjectCode': 'MATH102',
              }
            ]
          }),
          400,
        );
      });

      final repo = ClassRepository(MockAuthService(), mockClient);
      expect(
        () => repo.finalizeStudyLoads(
          userId: 'usr-1',
          termId: 'term-1',
          studyLoadIds: ['sl-1'],
        ),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Missing prerequisite: MATH101'),
        )),
      );
    });

    test('getPendingSummary calls GET /api/studyloads/pending-summary', () async {
      final mockClient = MockClient((req) async {
        expect(req.url.path, '/api/studyloads/pending-summary');
        expect(req.url.queryParameters['termId'], 'term-1');
        return http.Response(
          jsonEncode([
            {
              'userId': 'usr-1',
              'fullName': 'Ada Lovelace',
              'programCode': 'BSCS',
              'pendingCount': 2,
              'pendingUnits': 6.0,
            }
          ]),
          200,
        );
      });

      final repo = ClassRepository(MockAuthService(), mockClient);
      final list = await repo.getPendingSummary(termId: 'term-1');

      expect(list.length, 1);
      expect(list.first.fullName, 'Ada Lovelace');
      expect(list.first.pendingCount, 2);
    });
  });

  group('StudentStudyLoadDialog Widget Tests', () {
    const student = UserSearchResultModel(
      userId: 'usr-1',
      firstname: 'Ada',
      lastname: 'Lovelace',
      email: 'ada@example.com',
      programCode: 'BSCS',
      yearLevel: 1,
      role: 5,
    );

    testWidgets('Renders pending loads in separate pending section with Finalize all and Forced badge', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool finalizedAll = false;

      final mockClient = MockClient((req) async {
        if (req.method == 'GET' && req.url.path.contains('/api/studyloads/student/usr-1')) {
          return http.Response(
            jsonEncode([
              {
                'studyLoadId': 'sl-pending-1',
                'studentUserId': 'usr-1',
                'studentName': 'Ada Lovelace',
                'subjectCode': 'CS102',
                'subjectTitle': 'Data Structures',
                'className': 'BSCS 1-B',
                'loadStatus': 'Pending',
                'termLabel': '2026-2027 (Sem 1)',
                'isForced': true,
                'forcedReason': 'College Head approved overload',
              },
              {
                'studyLoadId': 'sl-enrolled-1',
                'studentUserId': 'usr-1',
                'studentName': 'Ada Lovelace',
                'subjectCode': 'CS101',
                'subjectTitle': 'Intro to CS',
                'className': 'BSCS 1-A',
                'loadStatus': 'Enrolled',
                'termLabel': '2026-2027 (Sem 1)',
                'isForced': false,
              },
            ]),
            200,
          );
        } else if (req.method == 'POST' && req.url.path == '/api/studyloads/finalize') {
          finalizedAll = true;
          return http.Response(
            jsonEncode({
              'success': true,
              'finalizedLoads': [
                {'studyLoadID': 'sl-pending-1', 'loadStatus': 'Enrolled'}
              ],
              'findings': [],
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      if (getIt.isRegistered<ClassRepository>()) {
        getIt.unregister<ClassRepository>();
      }
      getIt.registerSingleton<ClassRepository>(
        ClassRepository(MockAuthService(), mockClient),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudentStudyLoadDialog(
              student: student,
              termId: 'term-1',
              termLabel: '2026-2027 (Sem 1)',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and section headings
      expect(find.text('Study Load & Enrollment'), findsOneWidget);
      expect(find.text('Pending Study Load'), findsOneWidget);
      expect(find.text('1 pending'), findsOneWidget);
      expect(find.text('Finalize all'), findsOneWidget);

      // Check row contents
      expect(find.text('CS102'), findsOneWidget);
      expect(find.text('Data Structures'), findsOneWidget);
      expect(find.text('Forced'), findsOneWidget);
      expect(find.text('Finalize'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);

      // Check enrolled section
      expect(find.text('Enrolled & Term Classes'), findsOneWidget);
      expect(find.text('CS101'), findsOneWidget);
      expect(find.text('Intro to CS'), findsOneWidget);

      // Tap "Finalize all"
      await tester.tap(find.text('Finalize all'));
      await tester.pumpAndSettle();

      expect(finalizedAll, isTrue);
    });

    testWidgets('StudentStudyLoadDialog Reject sets Rejected status (5) and shows badge in history', (tester) async {
      int? updatedStatus;
      const student = UserSearchResultModel(
        userId: 'usr-1',
        firstname: 'Ada',
        lastname: 'Lovelace',
        email: 'ada@example.com',
        role: 1,
      );

      final mockClient = MockClient((req) async {
        if (req.method == 'GET' && req.url.path.contains('/api/studyloads/student/usr-1')) {
          return http.Response(
            jsonEncode([
              {
                'studyLoadId': 'sl-pending-1',
                'studentUserId': 'usr-1',
                'studentName': 'Ada Lovelace',
                'subjectCode': 'CS102',
                'subjectTitle': 'Data Structures',
                'className': 'BSCS 1-B',
                'loadStatus': 'Pending',
                'termLabel': '2026-2027 (Sem 1)',
              },
            ]),
            200,
          );
        } else if (req.method == 'PATCH' && req.url.path == '/api/studyloads/sl-pending-1/status') {
          final body = jsonDecode(req.body);
          updatedStatus = body['loadStatus'];
          return http.Response(
            jsonEncode({
              'studyLoadId': 'sl-pending-1',
              'studentUserId': 'usr-1',
              'studentName': 'Ada Lovelace',
              'subjectCode': 'CS102',
              'subjectTitle': 'Data Structures',
              'className': 'BSCS 1-B',
              'loadStatus': 'Rejected',
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
      getIt.registerSingleton<ClassRepository>(
        ClassRepository(MockAuthService(), mockClient),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentStudyLoadDialog(
              student: student,
              termId: 'term-1',
              termLabel: '2026-2027 (Sem 1)',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending Study Load'), findsOneWidget);
      expect(find.text('CS102'), findsOneWidget);

      // Tap Reject button on the pending row
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Reject Pending Load?'), findsOneWidget);
      expect(find.text('Reject'), findsNWidgets(2));

      // Tap Confirm Reject in dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reject'));
      await tester.pumpAndSettle();

      expect(updatedStatus, 5);
      expect(find.text('Pending Study Load'), findsNothing);
      expect(find.text('Rejected'), findsOneWidget);
    });
  });
}
