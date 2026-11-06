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
import 'package:sis_registrar_app/repositories/class_repository.dart';
import 'package:sis_registrar_app/repositories/enrollment_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/views/widgets/study_load_builder_dialog.dart';

// ─────────────────────────────────────────────────────────────────
// Mock auth service (no Firebase dependency)
// ─────────────────────────────────────────────────────────────────
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
  Future<Map<String, dynamic>?> signInAndVerify(
          String email, String password) async =>
      null;

  @override
  Future<Map<String, dynamic>?> fetchCurrentUserInfo() async => null;

  @override
  Future<void> signOut() async {}
}

// ─────────────────────────────────────────────────────────────────
// Helper: student fixture
// ─────────────────────────────────────────────────────────────────
const _student = UserSearchResultModel(
  userId: 'usr-1',
  firstname: 'Ada',
  lastname: 'Lovelace',
  email: 'ada@example.com',
  programCode: 'BSIT',
  yearLevel: 2,
  role: 5,
);

// ─────────────────────────────────────────────────────────────────
// Helper: build a proposed-block item JSON
// ─────────────────────────────────────────────────────────────────
Map<String, dynamic> _regularItem({
  String subjectId = 'subj-1',
  String subjectCode = 'IT211',
  String subjectTitle = 'Data Structures',
  String? classId = 'cls-1',
  String? className = 'BSIT 2-A',
  String matchType = 'auto',
  double units = 3.0,
  int subjectYearLevel = 2,
  String prerequisiteStatus = 'met',
  List<String> prerequisiteMessages = const [],
  bool alreadyPassed = false,
  bool alreadyEnrolledThisTerm = false,
  String standingStatus = 'not_required',
  List<Map<String, dynamic>> corequisites = const [],
  List<Map<String, dynamic>> options = const [],
  String category = 'regular',
}) {
  return {
    'subjectId': subjectId,
    'subjectCode': subjectCode,
    'subjectTitle': subjectTitle,
    'classId': classId,
    'className': className,
    'matchType': matchType,
    'category': category,
    'subjectYearLevel': subjectYearLevel,
    'units': units,
    'prerequisiteStatus': prerequisiteStatus,
    'prerequisiteMessages': prerequisiteMessages,
    'alreadyPassed': alreadyPassed,
    'alreadyEnrolledThisTerm': alreadyEnrolledThisTerm,
    'standingStatus': standingStatus,
    'corequisites': corequisites,
    'options': options,
  };
}

Map<String, dynamic> _retakeItem({
  String subjectId = 'subj-ret',
  String subjectCode = 'IT111',
  String subjectTitle = 'Intro Programming',
  double units = 3.0,
  double lastGrade = 65.0,
  String lastGradeTerm = '2025-2026 - 1st Sem',
  int subjectYearLevel = 1,
}) {
  return {
    'subjectId': subjectId,
    'subjectCode': subjectCode,
    'subjectTitle': subjectTitle,
    'classId': 'cls-ret',
    'className': 'BSIT 1-A',
    'matchType': 'auto',
    'category': 'retake',
    'subjectYearLevel': subjectYearLevel,
    'units': units,
    'lastGrade': lastGrade,
    'lastGradeTerm': lastGradeTerm,
    'prerequisiteStatus': 'met',
    'prerequisiteMessages': <dynamic>[],
    'alreadyPassed': false,
    'alreadyEnrolledThisTerm': false,
    'standingStatus': 'not_required',
    'corequisites': <dynamic>[],
    'options': <dynamic>[],
  };
}

Map<String, dynamic> _backSubjectItem({
  String subjectId = 'subj-back',
  String subjectCode = 'MATH102',
  String subjectTitle = 'Calculus',
  double units = 3.0,
  int subjectYearLevel = 1,
}) {
  return {
    'subjectId': subjectId,
    'subjectCode': subjectCode,
    'subjectTitle': subjectTitle,
    'classId': 'cls-back',
    'className': 'BSIT 1-B',
    'matchType': 'auto',
    'category': 'back_subject',
    'subjectYearLevel': subjectYearLevel,
    'units': units,
    'prerequisiteStatus': 'met',
    'prerequisiteMessages': <dynamic>[],
    'alreadyPassed': false,
    'alreadyEnrolledThisTerm': false,
    'standingStatus': 'not_required',
    'corequisites': <dynamic>[],
    'options': <dynamic>[],
  };
}

// ─────────────────────────────────────────────────────────────────
// Setup helper: registers mock repos in getIt
// ─────────────────────────────────────────────────────────────────
void _setupGetIt(http.Client mockClient) {
  if (getIt.isRegistered<ClassRepository>()) {
    getIt.unregister<ClassRepository>();
  }
  getIt.registerSingleton<ClassRepository>(
    ClassRepository(MockAuthService(), mockClient),
  );

  if (getIt.isRegistered<AcademicSetupRepository>()) {
    getIt.unregister<AcademicSetupRepository>();
  }
  getIt.registerSingleton<AcademicSetupRepository>(
    AcademicSetupRepository(MockAuthService()),
  );
}

class _OneTermRepo implements AcademicSetupRepository {
  @override
  Future<List<AcademicTermModel>> getTerms() async =>
      [AcademicTermModel.fromJson({'termID': 'term-1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true})];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrapDialog({
  required Widget child,
}) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ──────────────────────────────────────────────────────────────
  // Unit tests: ProposedBlockItemModel parsing
  // ──────────────────────────────────────────────────────────────
  group('ProposedBlockItemModel unit tests', () {
    test('parses regular category correctly', () {
      final item =
          ProposedBlockItemModel.fromJson(_regularItem(category: 'regular'));
      expect(item.isRegular, isTrue);
      expect(item.isRetake, isFalse);
      expect(item.isBackSubject, isFalse);
      expect(item.units, 3.0);
      expect(item.subjectYearLevel, 2);
    });

    test('parses retake category with lastGrade and lastGradeTerm', () {
      final item = ProposedBlockItemModel.fromJson(_retakeItem(
        lastGrade: 5.0,
        lastGradeTerm: '2025-2026 - 1st Sem',
      ));
      expect(item.isRetake, isTrue);
      expect(item.lastGrade, 5.0);
      expect(item.lastGradeTerm, '2025-2026 - 1st Sem');
    });

    test('parses back_subject category', () {
      final item = ProposedBlockItemModel.fromJson(_backSubjectItem());
      expect(item.isBackSubject, isTrue);
      expect(item.isRegular, isFalse);
    });

    test('isBlocked is true when prerequisiteStatus is unmet', () {
      final item = ProposedBlockItemModel.fromJson(_regularItem(
        prerequisiteStatus: 'unmet',
        prerequisiteMessages: ['IT101 not yet passed'],
      ));
      expect(item.isBlocked, isTrue);
      expect(item.isPrereqUnmet, isTrue);
      expect(item.prerequisiteMessages, contains('IT101 not yet passed'));
    });

    test('isBlocked is true when standingStatus is unmet', () {
      final item = ProposedBlockItemModel.fromJson(
          _regularItem(standingStatus: 'unmet'));
      expect(item.isBlocked, isTrue);
      expect(item.isStandingUnmet, isTrue);
    });

    test('isNoClassOffered is true when matchType is no_class_offered', () {
      final json = _regularItem(matchType: 'no_class_offered', classId: '');
      final item = ProposedBlockItemModel.fromJson(json);
      expect(item.isNoClassOffered, isTrue);
    });

    test('corequisites parsed with subjectId, subjectCode, includedInProposal', () {
      final json = _regularItem(
        corequisites: [
          {
            'subjectId': 'subj-lab',
            'subjectCode': 'IT211L',
            'includedInProposal': true,
          }
        ],
      );
      final item = ProposedBlockItemModel.fromJson(json);
      expect(item.corequisites.length, 1);
      expect(item.corequisites.first.subjectCode, 'IT211L');
      expect(item.corequisites.first.includedInProposal, isTrue);
    });

    test('options parsed correctly for multiple_found matchType', () {
      final json = _regularItem(
        matchType: 'multiple_found',
        classId: null,
        options: [
          {'classId': 'cls-A', 'className': 'BSIT 2-A'},
          {'classId': 'cls-B', 'className': 'BSIT 2-B'},
        ],
      );
      final item = ProposedBlockItemModel.fromJson(json);
      expect(item.options.length, 2);
      expect(item.matchType, 'multiple_found');
    });

    test('EnrollBatchResponseModel parses correctly', () {
      final json = {
        'classId': 'cls-1',
        'enrolled': true,
        'studyLoadId': 'sl-99',
        'reasons': <dynamic>[],
      };
      final m = EnrollBatchResponseModel.fromJson(json);
      expect(m.enrolled, isTrue);
      expect(m.classId, 'cls-1');
      expect(m.studyLoadId, 'sl-99');
    });

    test('EnrollSingleResponseModel parses correctly', () {
      final json = {
        'success': true,
        'studyLoadId': 'sl-100',
        'warnings': ['Overload warning'],
      };
      final m = EnrollSingleResponseModel.fromJson(json);
      expect(m.success, isTrue);
      expect(m.warnings, ['Overload warning']);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // Unit tests: ClassRepository new methods
  // ──────────────────────────────────────────────────────────────
  group('ClassRepository new methods unit tests', () {
    test('getProposedBlock calls GET /api/studyloads/proposed-block with userId and termId', () async {
      final mockClient = MockClient((req) async {
        expect(req.method, 'GET');
        expect(req.url.path, '/api/studyloads/proposed-block');
        expect(req.url.queryParameters['userId'], 'usr-1');
        expect(req.url.queryParameters['termId'], 'term-1');
        return http.Response(jsonEncode([_regularItem()]), 200);
      });

      final repo = ClassRepository(MockAuthService(), mockClient);
      final items = await repo.getProposedBlock('usr-1', 'term-1');

      expect(items.length, 1);
      expect(items.first.subjectCode, 'IT211');
    });

    test('enrollBatch calls POST /api/studyloads/enroll-batch with correct body', () async {
      String? capturedBody;
      final mockClient = MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, '/api/studyloads/enroll-batch');
        capturedBody = req.body;
        return http.Response(
          jsonEncode([
            {'classId': 'cls-1', 'enrolled': true, 'studyLoadId': 'sl-1', 'reasons': []},
          ]),
          200,
        );
      });

      final repo = ClassRepository(MockAuthService(), mockClient);
      final results = await repo.enrollBatch(
        userId: 'usr-1',
        termId: 'term-1',
        classIds: ['cls-1'],
        asPending: false,
      );

      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body['userId'], 'usr-1');
      expect(body['termId'], 'term-1');
      expect(body['classIds'], ['cls-1']);
      expect(body['asPending'], false);
      expect(results.first.enrolled, isTrue);
    });

    test('enrollBatch with asPending=true sends asPending correctly', () async {
      bool? sentAsPending;
      final mockClient = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        sentAsPending = body['asPending'] as bool?;
        return http.Response(
          jsonEncode([
            {'classId': 'cls-1', 'enrolled': true, 'studyLoadId': 'sl-1', 'reasons': []},
          ]),
          200,
        );
      });

      final repo = ClassRepository(MockAuthService(), mockClient);
      await repo.enrollBatch(
        userId: 'usr-1',
        termId: 'term-1',
        classIds: ['cls-1'],
        asPending: true,
      );

      expect(sentAsPending, isTrue);
    });

    test('enrollSingle with force=true and forceReason sends correct fields', () async {
      Map<String, dynamic>? sentBody;
      final mockClient = MockClient((req) async {
        expect(req.url.path, '/api/studyloads/enroll-single');
        sentBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'success': true, 'studyLoadId': 'sl-forced', 'warnings': []}),
          200,
        );
      });

      final repo = ClassRepository(MockAuthService(), mockClient);
      final result = await repo.enrollSingle(
        userId: 'usr-1',
        classId: 'cls-1',
        force: true,
        forceReason: 'Dean approval on file',
        asPending: false,
      );

      expect(sentBody!['force'], isTrue);
      expect(sentBody!['forceReason'], 'Dean approval on file');
      expect(sentBody!['asPending'], false);
      expect(result.success, isTrue);
    });

    test('enrollSingle throws ApiException on non-200', () async {
      final mockClient = MockClient((req) async {
        return http.Response(
          jsonEncode({'message': 'Class not found'}),
          404,
        );
      });

      final repo = ClassRepository(MockAuthService(), mockClient);
      expect(
        () => repo.enrollSingle(userId: 'usr-1', classId: 'bad-cls'),
        throwsA(isA<Object>()),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────
  // Widget tests: StudyLoadBuilderDialog
  // ──────────────────────────────────────────────────────────────
  group('StudyLoadBuilderDialog widget tests', () {
    setUp(() {
      // Reset per test
    });

    testWidgets('renders three sections when all categories present', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((req) async {
        if (req.url.path == '/api/studyloads/proposed-block') {
          return http.Response(
            jsonEncode([
              _regularItem(subjectCode: 'IT211', subjectTitle: 'Data Structures'),
              _retakeItem(subjectCode: 'IT111', subjectTitle: 'Intro Programming'),
              _backSubjectItem(subjectCode: 'MATH102', subjectTitle: 'Calculus'),
            ]),
            200,
          );
        }
        if (req.url.path == '/api/AcademicTerms') {
          return http.Response(
            jsonEncode([
              {'termID': 'term-1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      });

      _setupGetIt(mockClient);

      await tester.pumpWidget(_wrapDialog(
        child: StudyLoadBuilderDialog(
          student: _student,
          initialTermId: 'term-1',
          initialTermLabel: '2026-2027 — 1st Sem',
          isCollegeHead: false,
        ),
      ));
      await tester.pumpAndSettle();

      // Three section headers
      expect(find.text('Regular'), findsOneWidget);
      expect(find.text('Retake candidates'), findsOneWidget);
      expect(find.text('Back subjects'), findsOneWidget);

      // Subject rows
      expect(find.text('IT211'), findsOneWidget);
      expect(find.text('IT111'), findsOneWidget);
      expect(find.text('MATH102'), findsOneWidget);
    });

    testWidgets('regular item with met prereq is pre-checked by default; retake and back_subject are unchecked', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((req) async {
        if (req.url.path == '/api/studyloads/proposed-block') {
          return http.Response(
            jsonEncode([
              _regularItem(subjectCode: 'IT211', prerequisiteStatus: 'met'),
              _retakeItem(subjectCode: 'IT111'),
              _backSubjectItem(subjectCode: 'MATH102'),
            ]),
            200,
          );
        }
        if (req.url.path == '/api/AcademicTerms') {
          return http.Response(jsonEncode([
            {'termID': 'term-1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}
          ]), 200);
        }
        return http.Response('[]', 200);
      });

      _setupGetIt(mockClient);

      await tester.pumpWidget(_wrapDialog(
        child: StudyLoadBuilderDialog(
          student: _student,
          initialTermId: 'term-1',
          initialTermLabel: '2026-2027 — 1st Sem',
          isCollegeHead: false,
        ),
      ));
      await tester.pumpAndSettle();

      // IT211 (regular+met+auto) should be checked
      final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      // First checkbox corresponds to IT211 (regular)
      final regularRow = tester.widget<Checkbox>(
          find.byKey(const ValueKey('checkbox_IT211')));
      expect(regularRow.value, isTrue);

      // IT111 (retake) unchecked by default
      final retakeRow = tester.widget<Checkbox>(
          find.byKey(const ValueKey('checkbox_IT111')));
      expect(retakeRow.value, isFalse);

      // MATH102 (back_subject) unchecked by default
      final backRow = tester.widget<Checkbox>(
          find.byKey(const ValueKey('checkbox_MATH102')));
      expect(backRow.value, isFalse);
    });

    testWidgets('no_class_offered row is disabled and shows badge', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((req) async {
        if (req.url.path == '/api/studyloads/proposed-block') {
          return http.Response(
            jsonEncode([
              _regularItem(
                subjectCode: 'IT222',
                matchType: 'no_class_offered',
                classId: '',
              ),
            ]),
            200,
          );
        }
        if (req.url.path == '/api/AcademicTerms') {
          return http.Response(jsonEncode([
            {'termID': 'term-1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}
          ]), 200);
        }
        return http.Response('[]', 200);
      });

      _setupGetIt(mockClient);

      await tester.pumpWidget(_wrapDialog(
        child: StudyLoadBuilderDialog(
          student: _student,
          initialTermId: 'term-1',
          initialTermLabel: '2026-2027 — 1st Sem',
          isCollegeHead: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Not offered this term'), findsOneWidget);

      // Checkbox for no_class_offered row is disabled (null onChanged)
      final checkbox = tester.widget<Checkbox>(
          find.byKey(const ValueKey('checkbox_IT222')));
      expect(checkbox.onChanged, isNull);
      expect(checkbox.value, isFalse);
    });

    testWidgets('retake row shows last grade badge', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((req) async {
        if (req.url.path == '/api/studyloads/proposed-block') {
          return http.Response(
            jsonEncode([
              _retakeItem(
                subjectCode: 'IT111',
                lastGrade: 5.0,
                lastGradeTerm: '2025-2026 - 1st Sem',
              ),
            ]),
            200,
          );
        }
        if (req.url.path == '/api/AcademicTerms') {
          return http.Response(jsonEncode([
            {'termID': 'term-1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}
          ]), 200);
        }
        return http.Response('[]', 200);
      });

      _setupGetIt(mockClient);

      await tester.pumpWidget(_wrapDialog(
        child: StudyLoadBuilderDialog(
          student: _student,
          initialTermId: 'term-1',
          initialTermLabel: '2026-2027 — 1st Sem',
          isCollegeHead: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Last grade: 5.0'), findsOneWidget);
      expect(find.textContaining('2025-2026 - 1st Sem'), findsOneWidget);
    });

    testWidgets('blocked item shows Force button', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((req) async {
        if (req.url.path == '/api/studyloads/proposed-block') {
          return http.Response(
            jsonEncode([
              _regularItem(
                subjectCode: 'IT411',
                prerequisiteStatus: 'unmet',
                prerequisiteMessages: ['IT301 not yet passed'],
              ),
            ]),
            200,
          );
        }
        if (req.url.path == '/api/AcademicTerms') {
          return http.Response(jsonEncode([
            {'termID': 'term-1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}
          ]), 200);
        }
        return http.Response('[]', 200);
      });

      _setupGetIt(mockClient);

      await tester.pumpWidget(_wrapDialog(
        child: StudyLoadBuilderDialog(
          student: _student,
          initialTermId: 'term-1',
          initialTermLabel: '2026-2027 — 1st Sem',
          isCollegeHead: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('force_button_IT411')), findsOneWidget);
      expect(find.text('Force'), findsOneWidget);
      expect(find.text('IT301 not yet passed'), findsOneWidget);
    });

    testWidgets('units total updates when subject is checked', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((req) async {
        if (req.url.path == '/api/studyloads/proposed-block') {
          return http.Response(
            jsonEncode([
              _regularItem(
                subjectCode: 'IT211',
                units: 3.0,
                subjectId: 'subj-1',
              ),
              _retakeItem(
                subjectCode: 'IT111',
                units: 3.0,
                subjectId: 'subj-ret',
              ),
            ]),
            200,
          );
        }
        if (req.url.path == '/api/AcademicTerms') {
          return http.Response(jsonEncode([
            {'termID': 'term-1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}
          ]), 200);
        }
        return http.Response('[]', 200);
      });

      _setupGetIt(mockClient);

      await tester.pumpWidget(_wrapDialog(
        child: StudyLoadBuilderDialog(
          student: _student,
          initialTermId: 'term-1',
          initialTermLabel: '2026-2027 — 1st Sem',
          isCollegeHead: false,
        ),
      ));
      await tester.pumpAndSettle();

      // Initial: only IT211 is pre-checked → 3.0 units
      expect(find.text('1 subjects selected'), findsOneWidget);
      expect(find.text('Total: 3.0 units'), findsOneWidget);

      // Check IT111 (retake)
      await tester.tap(find.byKey(const ValueKey('checkbox_IT111')));
      await tester.pumpAndSettle();

      expect(find.text('2 subjects selected'), findsOneWidget);
      expect(find.text('Total: 6.0 units'), findsOneWidget);
    });

    testWidgets('Enroll now sends asPending=false', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool? capturedAsPending;
      List<String>? capturedClassIds;

      final mockClient = MockClient((req) async {
        if (req.url.path == '/api/studyloads/proposed-block') {
          return http.Response(jsonEncode([
            _regularItem(subjectCode: 'IT211', classId: 'cls-1'),
          ]), 200);
        }
        if (req.url.path == '/api/AcademicTerms') {
          return http.Response(jsonEncode([
            {'termID': 'term-1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}
          ]), 200);
        }
        if (req.url.path == '/api/studyloads/enroll-batch') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          capturedAsPending = body['asPending'] as bool?;
          capturedClassIds = (body['classIds'] as List).cast<String>();
          return http.Response(jsonEncode([
            {'classId': 'cls-1', 'enrolled': true, 'studyLoadId': 'sl-1', 'reasons': []}
          ]), 200);
        }
        return http.Response('[]', 200);
      });

      _setupGetIt(mockClient);

      await tester.pumpWidget(_wrapDialog(
        child: StudyLoadBuilderDialog(
          student: _student,
          initialTermId: 'term-1',
          initialTermLabel: '2026-2027 — 1st Sem',
          isCollegeHead: false,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enroll_now_button')));
      await tester.pumpAndSettle();

      expect(capturedAsPending, isFalse);
      expect(capturedClassIds, contains('cls-1'));
    });

    testWidgets('Enroll now for a student already enrolled this term asks why the subject is added', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      Map<String, dynamic>? sent;
      final mockClient = MockClient((req) async {
        if (req.url.path == '/api/studyloads/proposed-block') {
          return http.Response(jsonEncode([_regularItem(subjectCode: 'IT211', classId: 'cls-1')]), 200);
        }
        if (req.url.path == '/api/AcademicTerms') {
          return http.Response(jsonEncode([
            {'termID': 'term-1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}
          ]), 200);
        }
        if (req.url.path.startsWith('/api/studyloads/student/')) {
          return http.Response(jsonEncode([
            {'studyLoadId': 'sl-0', 'classId': 'cls-0', 'subjectCode': 'IT101', 'subjectTitle': 'Intro', 'className': 'A', 'loadStatus': 'Enrolled'}
          ]), 200);
        }
        if (req.url.path == '/api/studyloads/enroll-batch') {
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(jsonEncode([
            {'classId': 'cls-1', 'enrolled': true, 'studyLoadId': 'sl-1', 'reasons': []}
          ]), 200);
        }
        return http.Response('[]', 200);
      });

      _setupGetIt(mockClient);
      await tester.pumpWidget(_wrapDialog(
        child: StudyLoadBuilderDialog(
          student: _student,
          initialTermId: 'term-1',
          initialTermLabel: '2026-2027 — 1st Sem',
          isCollegeHead: false,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enroll_now_button')));
      await tester.pumpAndSettle();
      expect(find.text('Add subjects after enrollment'), findsOneWidget);
      expect(sent, isNull);

      await tester.enterText(find.byKey(const ValueKey('change_reason_field')), 'Late add approved');
      await tester.tap(find.byKey(const ValueKey('confirm_change_button')));
      await tester.pumpAndSettle();
      expect(sent!['changeReason'], 'Late add approved');
    });

    testWidgets('a deleted term falls back to a real one instead of showing an error', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final asked = <String>[];
      final mockClient = MockClient((req) async {
        if (req.url.path == '/api/studyloads/proposed-block') {
          final term = req.url.queryParameters['termId']!;
          asked.add(term);
          if (term == 'deleted') {
            return http.Response(jsonEncode({'message': "AcademicTerm with ID 'deleted' was not found."}), 404);
          }
          return http.Response(jsonEncode([_regularItem(subjectCode: 'IT211', classId: 'cls-1')]), 200);
        }
        return http.Response('[]', 200);
      });
      _setupGetIt(mockClient);
      getIt.unregister<AcademicSetupRepository>();
      getIt.registerSingleton<AcademicSetupRepository>(_OneTermRepo());

      await tester.pumpWidget(_wrapDialog(
        child: StudyLoadBuilderDialog(
          student: _student,
          initialTermId: 'deleted',
          initialTermLabel: '2026-2027 (2nd Sem)',
          isCollegeHead: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(asked, ['deleted', 'term-1']);
      expect(find.textContaining('was not found'), findsNothing);
      expect(find.textContaining('IT211'), findsWidgets);
    });

    testWidgets('Save as pending sends asPending=true', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool? capturedAsPending;

      final mockClient = MockClient((req) async {
        if (req.url.path == '/api/studyloads/proposed-block') {
          return http.Response(jsonEncode([
            _regularItem(subjectCode: 'IT211', classId: 'cls-1'),
          ]), 200);
        }
        if (req.url.path == '/api/AcademicTerms') {
          return http.Response(jsonEncode([
            {'termID': 'term-1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}
          ]), 200);
        }
        if (req.url.path == '/api/studyloads/enroll-batch') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          capturedAsPending = body['asPending'] as bool?;
          return http.Response(jsonEncode([
            {'classId': 'cls-1', 'enrolled': true, 'studyLoadId': 'sl-1', 'reasons': []}
          ]), 200);
        }
        return http.Response('[]', 200);
      });

      _setupGetIt(mockClient);

      await tester.pumpWidget(_wrapDialog(
        child: StudyLoadBuilderDialog(
          student: _student,
          initialTermId: 'term-1',
          initialTermLabel: '2026-2027 — 1st Sem',
          isCollegeHead: false,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('save_as_pending_button')));
      await tester.pumpAndSettle();

      expect(capturedAsPending, isTrue);
    });

    testWidgets('College Head sees Save as pending but NOT Enroll now button', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((req) async {
        if (req.url.path == '/api/studyloads/proposed-block') {
          return http.Response(jsonEncode([
            _regularItem(subjectCode: 'IT211'),
          ]), 200);
        }
        if (req.url.path == '/api/AcademicTerms') {
          return http.Response(jsonEncode([
            {'termID': 'term-1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}
          ]), 200);
        }
        return http.Response('[]', 200);
      });

      _setupGetIt(mockClient);

      await tester.pumpWidget(_wrapDialog(
        child: StudyLoadBuilderDialog(
          student: _student,
          initialTermId: 'term-1',
          initialTermLabel: '2026-2027 — 1st Sem',
          isCollegeHead: true, // College Head
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('save_as_pending_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('enroll_now_button')), findsNothing);
    });

    testWidgets('blocked selected row shows blocking banner and disables submit buttons', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((req) async {
        if (req.url.path == '/api/studyloads/proposed-block') {
          return http.Response(
            jsonEncode([
              _regularItem(
                subjectCode: 'IT411',
                prerequisiteStatus: 'unmet',
                prerequisiteMessages: ['IT301 not yet passed'],
                subjectId: 'subj-blocked',
              ),
            ]),
            200,
          );
        }
        if (req.url.path == '/api/AcademicTerms') {
          return http.Response(jsonEncode([
            {'termID': 'term-1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}
          ]), 200);
        }
        return http.Response('[]', 200);
      });

      _setupGetIt(mockClient);

      await tester.pumpWidget(_wrapDialog(
        child: StudyLoadBuilderDialog(
          student: _student,
          initialTermId: 'term-1',
          initialTermLabel: '2026-2027 — 1st Sem',
          isCollegeHead: false,
        ),
      ));
      await tester.pumpAndSettle();

      // IT411 is regular but blocked (unmet prereq) — not pre-checked by default
      // Check it manually
      await tester.tap(find.byKey(const ValueKey('checkbox_IT411')));
      await tester.pumpAndSettle();

      // Banner appears
      expect(
        find.textContaining('have blocking findings'),
        findsOneWidget,
      );

      // Enroll now and Save as pending buttons should be disabled
      final enrollNowBtn = tester.widget<FilledButton>(
          find.byKey(const ValueKey('enroll_now_button')));
      expect(enrollNowBtn.onPressed, isNull);

      final saveAsPendingBtn = tester.widget<FilledButton>(
          find.byKey(const ValueKey('save_as_pending_button')));
      expect(saveAsPendingBtn.onPressed, isNull);
    });

    testWidgets('section dropdown shows when multiple_found with several options', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((req) async {
        if (req.url.path == '/api/studyloads/proposed-block') {
          return http.Response(
            jsonEncode([
              _regularItem(
                subjectCode: 'IT211',
                matchType: 'multiple_found',
                classId: null,
                options: [
                  {'classId': 'cls-A', 'className': 'BSIT 2-A'},
                  {'classId': 'cls-B', 'className': 'BSIT 2-B'},
                ],
              ),
            ]),
            200,
          );
        }
        if (req.url.path == '/api/AcademicTerms') {
          return http.Response(jsonEncode([
            {'termID': 'term-1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}
          ]), 200);
        }
        return http.Response('[]', 200);
      });

      _setupGetIt(mockClient);

      await tester.pumpWidget(_wrapDialog(
        child: StudyLoadBuilderDialog(
          student: _student,
          initialTermId: 'term-1',
          initialTermLabel: '2026-2027 — 1st Sem',
          isCollegeHead: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('section_dropdown_IT211')), findsOneWidget);
    });

    testWidgets('corequisite badge rendered on paired item', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((req) async {
        if (req.url.path == '/api/studyloads/proposed-block') {
          return http.Response(
            jsonEncode([
              _regularItem(
                subjectCode: 'IT211',
                subjectId: 'subj-lec',
                corequisites: [
                  {
                    'subjectId': 'subj-lab',
                    'subjectCode': 'IT211L',
                    'includedInProposal': true,
                  }
                ],
              ),
              _regularItem(
                subjectCode: 'IT211L',
                subjectTitle: 'DS Laboratory',
                subjectId: 'subj-lab',
                corequisites: [
                  {
                    'subjectId': 'subj-lec',
                    'subjectCode': 'IT211',
                    'includedInProposal': true,
                  }
                ],
              ),
            ]),
            200,
          );
        }
        if (req.url.path == '/api/AcademicTerms') {
          return http.Response(jsonEncode([
            {'termID': 'term-1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}
          ]), 200);
        }
        return http.Response('[]', 200);
      });

      _setupGetIt(mockClient);

      await tester.pumpWidget(_wrapDialog(
        child: StudyLoadBuilderDialog(
          student: _student,
          initialTermId: 'term-1',
          initialTermLabel: '2026-2027 — 1st Sem',
          isCollegeHead: false,
        ),
      ));
      await tester.pumpAndSettle();

      // Both should show coreq badge
      expect(find.text('Coreq: IT211L'), findsOneWidget);
      expect(find.text('Coreq: IT211'), findsOneWidget);
    });

    testWidgets('per-row Force dialog respects pending vs immediate choice and College Head defaults to pending', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      Map<String, dynamic>? lastEnrollSingleBody;

      final mockClient = MockClient((req) async {
        if (req.url.path == '/api/studyloads/proposed-block') {
          return http.Response(
            jsonEncode([
              _regularItem(
                subjectCode: 'IT411',
                subjectTitle: 'Advanced Systems',
                classId: 'cls-411',
                prerequisiteStatus: 'unmet',
                prerequisiteMessages: ['IT301 not yet passed'],
              ),
            ]),
            200,
          );
        }
        if (req.url.path == '/api/studyloads/enroll-single') {
          lastEnrollSingleBody = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'studyLoadId': 'sl-forced-1',
              'warnings': [],
            }),
            200,
          );
        }
        if (req.url.path == '/api/AcademicTerms') {
          return http.Response(jsonEncode([
            {'termID': 'term-1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}
          ]), 200);
        }
        return http.Response('[]', 200);
      });

      _setupGetIt(mockClient);

      // 1. As Registrar (isCollegeHead: false)
      await tester.pumpWidget(_wrapDialog(
        child: StudyLoadBuilderDialog(
          student: _student,
          initialTermId: 'term-1',
          initialTermLabel: '2026-2027 — 1st Sem',
          isCollegeHead: false,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap Force button
      await tester.tap(find.byKey(const ValueKey('force_button_IT411')));
      await tester.pumpAndSettle();

      // Force dialog open
      expect(find.text('Force Enroll: IT411'), findsOneWidget);
      expect(find.byKey(const ValueKey('force_as_pending_checkbox')), findsOneWidget);

      // Fill reason
      await tester.enterText(find.byKey(const ValueKey('force_reason_field')), 'Dean override for graduating senior');
      await tester.pumpAndSettle();

      // Submit with asPending = false (default)
      await tester.tap(find.byKey(const ValueKey('confirm_force_button')));
      await tester.pumpAndSettle();

      expect(lastEnrollSingleBody, isNotNull);
      expect(lastEnrollSingleBody!['force'], isTrue);
      expect(lastEnrollSingleBody!['asPending'], isFalse);
      expect(lastEnrollSingleBody!['forceReason'], 'Dean override for graduating senior');

      // 2. As College Head (isCollegeHead: true)
      lastEnrollSingleBody = null;
      await tester.pumpWidget(_wrapDialog(
        child: StudyLoadBuilderDialog(
          student: _student,
          initialTermId: 'term-1',
          initialTermLabel: '2026-2027 — 1st Sem',
          isCollegeHead: true,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('force_button_IT411')));
      await tester.pumpAndSettle();

      expect(find.text('Force Enroll: IT411'), findsOneWidget);
      expect(find.byKey(const ValueKey('force_as_pending_checkbox')), findsNothing);
      expect(find.text('College Head forces are submitted as Pending loads for Registrar finalization.'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('force_reason_field')), 'Department chair endorsement');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('confirm_force_button')));
      await tester.pumpAndSettle();

      expect(lastEnrollSingleBody, isNotNull);
      expect(lastEnrollSingleBody!['force'], isTrue);
      expect(lastEnrollSingleBody!['asPending'], isTrue);
      expect(lastEnrollSingleBody!['forceReason'], 'Department chair endorsement');
    });

    testWidgets('batch results dialog shows partial success with breakdown and reasons, keeping refused items checked', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((req) async {
        if (req.url.path == '/api/studyloads/proposed-block') {
          return http.Response(
            jsonEncode([
              _regularItem(
                subjectId: 'subj-1',
                subjectCode: 'IT211',
                subjectTitle: 'Data Structures',
                classId: 'cls-1',
                units: 3.0,
              ),
              _regularItem(
                subjectId: 'subj-2',
                subjectCode: 'IT212',
                subjectTitle: 'Web Development',
                classId: 'cls-2',
                units: 3.0,
              ),
            ]),
            200,
          );
        }
        if (req.url.path == '/api/studyloads/enroll-batch') {
          return http.Response(
            jsonEncode([
              {
                'classId': 'cls-1',
                'enrolled': true,
                'studyLoadId': 'sl-1',
                'reasons': [],
              },
              {
                'classId': 'cls-2',
                'enrolled': false,
                'studyLoadId': null,
                'reasons': ['Class section is at maximum capacity (40/40)'],
              },
            ]),
            200,
          );
        }
        if (req.url.path == '/api/AcademicTerms') {
          return http.Response(jsonEncode([
            {'termID': 'term-1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}
          ]), 200);
        }
        return http.Response('[]', 200);
      });

      _setupGetIt(mockClient);

      await tester.pumpWidget(_wrapDialog(
        child: StudyLoadBuilderDialog(
          student: _student,
          initialTermId: 'term-1',
          initialTermLabel: '2026-2027 — 1st Sem',
          isCollegeHead: false,
        ),
      ));
      await tester.pumpAndSettle();

      // Both subjects are checked initially
      expect(tester.widget<Checkbox>(find.byKey(const ValueKey('checkbox_IT211'))).value, isTrue);
      expect(tester.widget<Checkbox>(find.byKey(const ValueKey('checkbox_IT212'))).value, isTrue);

      // Tap "Enroll now"
      await tester.tap(find.byKey(const ValueKey('enroll_now_button')));
      await tester.pumpAndSettle();

      // Batch Results dialog should appear
      expect(find.text('Batch Results'), findsOneWidget);
      expect(find.text('1 enrolled'), findsOneWidget);
      expect(find.text('1 refused'), findsOneWidget);
      expect(find.textContaining('Class section is at maximum capacity'), findsOneWidget);
      expect(find.byKey(const ValueKey('dismiss_batch_results_button')), findsOneWidget);

      // Tap 'Review and retry' to dismiss batch results dialog
      await tester.tap(find.byKey(const ValueKey('dismiss_batch_results_button')));
      await tester.pumpAndSettle();

      // Batch results dialog is dismissed
      expect(find.text('Batch Results'), findsNothing);

      // In the builder dialog, enrolled item (IT211) is now unchecked,
      // while refused item (IT212) remains checked so the user can fix and retry
      expect(tester.widget<Checkbox>(find.byKey(const ValueKey('checkbox_IT211'))).value, isFalse);
      expect(tester.widget<Checkbox>(find.byKey(const ValueKey('checkbox_IT212'))).value, isTrue);
    });
  });

  group('Unit limit warning', () {
    MockClient clientWith({required Map<String, dynamic> limit, void Function(Map<String, dynamic>)? onEnroll}) {
      return MockClient((req) async {
        if (req.url.path == '/api/studyloads/proposed-block') {
          return http.Response(jsonEncode([
            _regularItem(subjectId: 's1', subjectCode: 'IT211', classId: 'cls-1', units: 3.0),
            _regularItem(subjectId: 's2', subjectCode: 'IT212', classId: 'cls-2', units: 3.0),
          ]), 200);
        }
        if (req.url.path == '/api/studyloads/unit-limit') {
          return http.Response(jsonEncode(limit), 200);
        }
        if (req.url.path == '/api/AcademicTerms') {
          return http.Response(jsonEncode([
            {'termID': 'term-1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}
          ]), 200);
        }
        if (req.url.path == '/api/studyloads/enroll-batch') {
          onEnroll?.call(jsonDecode(req.body) as Map<String, dynamic>);
          return http.Response(jsonEncode([
            {'classId': 'cls-1', 'enrolled': true, 'studyLoadId': 'sl-1', 'reasons': []},
            {'classId': 'cls-2', 'enrolled': true, 'studyLoadId': 'sl-2', 'reasons': []},
          ]), 200);
        }
        return http.Response('[]', 200);
      });
    }

    Future<void> pumpBuilder(WidgetTester tester, MockClient client) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      _setupGetIt(client);
      await tester.pumpWidget(_wrapDialog(
        child: StudyLoadBuilderDialog(
          student: _student,
          initialTermId: 'term-1',
          initialTermLabel: '2026-2027 — 1st Sem',
          isCollegeHead: false,
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('within the limit: shows the limit, no warning, saves directly', (tester) async {
      var enrolled = false;
      await pumpBuilder(tester, clientWith(
        limit: {'maxUnits': 21, 'currentUnits': 0, 'rule': 'Regular limit.'},
        onEnroll: (_) => enrolled = true,
      ));

      expect(find.text('Limit 21.0'), findsOneWidget);
      expect(find.byKey(const ValueKey('unit_limit_warning')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('save_as_pending_button')));
      await tester.pumpAndSettle();
      expect(enrolled, isTrue);
    });

    testWidgets('over the limit: warns, asks for a reason, and Go back does not save', (tester) async {
      var enrolled = false;
      await pumpBuilder(tester, clientWith(
        limit: {'maxUnits': 6, 'currentUnits': 3, 'rule': 'Summer limit: 9 units.'},
        onEnroll: (_) => enrolled = true,
      ));

      expect(find.text('3.0 already in term · Limit 6.0'), findsOneWidget);
      expect(find.byKey(const ValueKey('unit_limit_warning')), findsOneWidget);
      expect(find.textContaining('Over the unit limit: 9.0 of 6.0 units'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('save_as_pending_button')));
      await tester.pumpAndSettle();
      expect(find.text('Approve overload'), findsOneWidget);

      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();
      expect(enrolled, isFalse);
    });

    testWidgets('over the limit: a reason is required, then it is sent with the save', (tester) async {
      Map<String, dynamic>? body;
      await pumpBuilder(tester, clientWith(
        limit: {'maxUnits': 3, 'currentUnits': 0, 'rule': 'r'},
        onEnroll: (b) => body = b,
      ));

      await tester.tap(find.byKey(const ValueKey('save_as_pending_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('confirm_over_limit_button')));
      await tester.pumpAndSettle();
      expect(find.text('A reason is required.'), findsOneWidget);
      expect(body, isNull);

      await tester.enterText(find.byKey(const ValueKey('overload_reason_field')), 'Irregular student');
      await tester.tap(find.byKey(const ValueKey('confirm_over_limit_button')));
      await tester.pumpAndSettle();

      expect(body!['overloadReason'], 'Irregular student');
    });

    testWidgets('within the limit: no overloadReason is sent', (tester) async {
      Map<String, dynamic>? body;
      await pumpBuilder(tester, clientWith(
        limit: {'maxUnits': 21, 'currentUnits': 0, 'rule': 'r'},
        onEnroll: (b) => body = b,
      ));

      await tester.tap(find.byKey(const ValueKey('save_as_pending_button')));
      await tester.pumpAndSettle();

      expect(body!.containsKey('overloadReason'), isFalse);
    });
  });
}
