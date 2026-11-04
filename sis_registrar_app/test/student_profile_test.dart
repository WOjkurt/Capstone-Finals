import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_registrar_app/blocs/clearance_bloc.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/models/grading_models.dart';
import 'package:sis_registrar_app/repositories/activity_log_repository.dart';
import 'package:sis_registrar_app/repositories/class_repository.dart';
import 'package:sis_registrar_app/repositories/enrollment_repository.dart';
import 'package:sis_registrar_app/repositories/grading_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/views/clearance_view.dart';

class FakeAuthService implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {'Authorization': 'Bearer t'};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records events and never changes state, so the test controls what the page shows.
class RecordingClearanceBloc extends Bloc<ClearanceEvent, ClearanceState> implements ClearanceBloc {
  final List<ClearanceEvent> events = [];
  RecordingClearanceBloc(super.initialState) {
    on<ClearanceEvent>((event, emit) => events.add(event));
  }
}

const _student = UserSearchResultModel(
  userId: 'u1',
  firstname: 'Ana',
  lastname: 'Cruz',
  email: 'ana@dbtc-cebu.edu.ph',
  programId: 1,
  programCode: 'BSIT',
  yearLevel: 1,
  role: 5,
  lrn: '123456789012',
  hasLrn: true,
);

final _clearances = [
  GradeClearanceModel(clearanceId: 'c1', userId: 'u1', termId: 't1', termLabel: '2026-2027 (1st Semester)', isCleared: false),
  GradeClearanceModel(clearanceId: 'c0', userId: 'u1', termId: 't0', termLabel: '2025-2026 (2nd Semester)', isCleared: true),
];

void main() {
  late List<String> requests;

  setUp(() async {
    await getIt.reset();
    requests = [];
    // http.get calls without an injected client (AcademicSetupRepository) go through runWithClient below.
    final client = MockClient((req) async {
      requests.add('${req.url.path}?${req.url.query}');
      final path = req.url.path;
      Object body = <Object>[];
      if (path.endsWith('/api/AcademicTerms')) {
        body = [
          {'termID': 't0', 'schoolYear': '2025-2026', 'semester': 2, 'isActive': false},
          {'termID': 't1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true},
        ];
      } else if (path.endsWith('/api/activity-log')) {
        body = {'items': [], 'page': 1, 'pageSize': 25, 'totalCount': 0};
      } else if (path.endsWith('/api/studyloads/unit-limit')) {
        body = {'maxUnits': 21, 'currentUnits': 0};
      }
      return http.Response(jsonEncode(body), 200);
    });
    final auth = FakeAuthService();
    getIt.registerSingleton<AuthService>(auth);
    getIt.registerSingleton<AcademicSetupRepository>(AcademicSetupRepository(auth));
    getIt.registerSingleton<ClassRepository>(ClassRepository(auth, client));
    getIt.registerSingleton<StudentGradeRepository>(StudentGradeRepository(auth, client: client));
    getIt.registerSingleton<CreditedSubjectRepository>(CreditedSubjectRepository(auth, client: client));
    getIt.registerSingleton<ActivityLogRepository>(ActivityLogRepository(auth, client: client));
  });

  tearDown(() async => getIt.reset());

  Future<RecordingClearanceBloc> pump(WidgetTester tester, {UserSearchResultModel? selected = _student}) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bloc = RecordingClearanceBloc(ClearanceStateData(
      searchQuery: 'ana',
      searchResults: const [_student],
      selectedStudent: selected,
      clearances: _clearances,
    ));
    addTearDown(bloc.close);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        home: BlocProvider<ClearanceBloc>.value(value: bloc, child: const ClearanceView()),
      ));
      await tester.pumpAndSettle();
    }, () => MockClient((req) async {
          requests.add('${req.url.path}?${req.url.query}');
          return http.Response(
              jsonEncode(req.url.path.endsWith('/api/AcademicTerms')
                  ? [
                      {'termID': 't0', 'schoolYear': '2025-2026', 'semester': 2, 'isActive': false},
                      {'termID': 't1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true},
                    ]
                  : []),
              200);
        }));
    return bloc;
  }

  Finder tab(String name) => find.descendant(of: find.byKey(const ValueKey('student_tabs')), matching: find.text(name));

  testWidgets('no student selected shows how to start', (tester) async {
    await pump(tester, selected: null);
    expect(find.text('Choose a student'), findsOneWidget);
    expect(find.byKey(const ValueKey('student_tabs')), findsNothing);
  });

  testWidgets('profile shows the header chips and five tabs; Study load opens on the active term', (tester) async {
    await pump(tester);

    expect(find.text('LRN 123456789012'), findsOneWidget);
    expect(find.text('BSIT'), findsWidgets);
    expect(find.text('Year 1'), findsWidgets);
    for (final t in ['Study load', 'Grades', 'Credits', 'Grade release', 'History']) {
      expect(tab(t), findsOneWidget, reason: t);
    }
    expect(requests.any((r) => r.startsWith('/api/studyloads/student/u1') && r.contains('termId=t1')), isTrue);
    expect(find.byKey(const ValueKey('build_study_load_button')), findsOneWidget);
    // Grades, Credits and History are tabs here, so the old window buttons are gone.
    expect(find.byKey(const ValueKey('view_grades_button')), findsNothing);
    expect(find.byKey(const ValueKey('credited_subjects_button')), findsNothing);
  });

  testWidgets('Grade release lists terms; Study load jumps to that term; the switch sends a toggle', (tester) async {
    final bloc = await pump(tester);

    await tester.tap(tab('Grade release'));
    await tester.pumpAndSettle();
    expect(find.text('On hold'), findsOneWidget);
    expect(find.text('Released'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('release_switch_t1')));
    await tester.pump();
    final toggle = bloc.events.whereType<ToggleClearanceEvent>().single;
    expect((toggle.termId, toggle.isCleared), ('t1', true));

    requests.clear();
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('release_row_t0')), matching: find.text('Study load')));
    await tester.pumpAndSettle();
    expect(requests.any((r) => r.startsWith('/api/studyloads/student/u1') && r.contains('termId=t0')), isTrue);
  });

  testWidgets('History tab asks the log for this student only', (tester) async {
    await pump(tester);

    await tester.tap(tab('History'));
    await tester.pumpAndSettle();

    expect(requests.any((r) => r.startsWith('/api/activity-log') && r.contains('studentId=u1')), isTrue);
  });
}
