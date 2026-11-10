import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/views/widgets/student_details_tab.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_registrar_app/blocs/clearance_bloc.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/models/grading_models.dart';
import 'package:sis_registrar_app/repositories/activity_log_repository.dart';
import 'package:sis_registrar_app/repositories/class_repository.dart';
import 'package:sis_registrar_app/repositories/enrollment_repository.dart';
import 'package:sis_registrar_app/repositories/grading_repository.dart';
import 'package:sis_registrar_app/repositories/hold_repository.dart';
import 'package:sis_registrar_app/repositories/student_record_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/utils/study_load_pdf.dart';
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
  Map<String, dynamic>? savedDetails;
  bool? standingSet;

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
      } else if (path.endsWith('/api/student-records/u1/grades')) {
        body = [
          {'gradeId': 'g1', 'subjectCode': 'IT 101', 'subjectTitle': 'Intro', 'units': 3, 'finalGrade': 1.5, 'remarks': 1, 'loadStatus': 1, 'schoolYear': '2025-2026', 'semester': 2, 'termLabel': '2025-2026 (2nd Sem)'},
          {'gradeId': 'g2', 'subjectCode': 'IT 102', 'subjectTitle': 'Prog', 'units': 1, 'finalGrade': 3.5, 'remarks': 2, 'loadStatus': 1, 'schoolYear': '2025-2026', 'semester': 2, 'termLabel': '2025-2026 (2nd Sem)'},
          {'gradeId': 'g3', 'subjectCode': 'IT 103', 'subjectTitle': 'Dropped', 'units': 3, 'finalGrade': 5.0, 'remarks': 2, 'loadStatus': 2, 'schoolYear': '2025-2026', 'semester': 2, 'termLabel': '2025-2026 (2nd Sem)'},
        ];
      } else if (path.endsWith('/api/student-records/u1/standing')) {
        if (req.method == 'PUT') {
          standingSet = (jsonDecode(req.body) as Map<String, dynamic>)['isRegular'] as bool;
          body = {'isRegular': true, 'backMajorUnitsPassed': 0, 'unitsToRegular': 6};
        } else {
          body = {
            'isRegular': false, 'irregularSince': '2026-06-01T00:00:00Z', 'backMajorUnitsPassed': 6, 'unitsToRegular': 6,
            'countedSubjects': ['IT 101', 'IT 104'], 'unresolvedSubjects': [], 'suggestion': 'MarkRegular',
          };
        }
      } else if (path.endsWith('/api/studyloads/changes')) {
        body = [
          {'changeId': 'ch1', 'kind': 'Dropped', 'subjectCode': 'IT 102', 'subjectTitle': 'Prog', 'className': 'BSIT 1A', 'units': 3, 'reason': 'Schedule conflict', 'changedBy': 'Rita Reg', 'changedAt': '2026-08-20T02:00:00Z'},
          {'changeId': 'ch2', 'kind': 'Added', 'subjectCode': 'IT 103', 'subjectTitle': 'Data', 'className': 'BSIT 1B', 'units': 3, 'reason': 'Replacement', 'changedBy': 'Rita Reg', 'changedAt': '2026-08-21T02:00:00Z'},
        ];
      } else if (path.endsWith('/api/student-records/u1/personal-details')) {
        if (req.method == 'PUT') {
          savedDetails = jsonDecode(req.body) as Map<String, dynamic>;
          body = {'firstname': 'Ana', 'lastname': 'Cruz', 'hasEnrollmentForm': false, ...savedDetails!, 'fromForm': [], 'updatedBy': 'Rita Reg', 'updatedAt': '2026-11-05T01:00:00Z'};
        } else {
          body = {'firstname': 'Ana', 'lastname': 'Cruz', 'hasEnrollmentForm': false, 'firstTermEnrolled': '2nd Semester, 2025-2026', 'fromForm': []};
        }
      } else if (path.endsWith('/api/student-records/u1/transcript')) {
        body = {
          'fullName': 'CRUZ, Ana Reyes', 'lrn': '123456789012', 'programCode': 'BSIT', 'programName': 'BS Information Technology',
          'address': 'Cebu City', 'dateOfBirth': '2007-05-01', 'dateAdmitted': '2nd Semester, 2025-2026', 'entranceData': 'Abellana NHS',
          'terms': [
            {'heading': '2nd Semester, 2025-2026', 'rows': [{'subjectCode': 'IT 101', 'subjectTitle': 'Intro', 'final': '1.50', 'units': 3}]},
          ],
          'credits': [
            {'sourceSchool': 'USC', 'rows': [{'subjectCode': 'GE 1', 'subjectTitle': 'Math', 'final': '1.5', 'units': 3}]},
          ],
        };
      } else if (path.endsWith('/api/student-records/u1/evaluation')) {
        body = {
          'programCode': 'BSIT', 'programName': 'BS Information Technology', 'yearLevel': 1,
          'totalUnits': 9, 'earnedUnits': 6, 'inProgressUnits': 0, 'remainingUnits': 3,
          'subjects': [
            {'subjectId': 's1', 'subjectCode': 'IT 101', 'subjectTitle': 'Intro', 'units': 3, 'yearLevel': 1, 'semester': 1, 'isMinor': false, 'status': 'Passed', 'finalGrade': 1.5, 'termLabel': '2025-2026 (2nd Sem)'},
            {'subjectId': 's2', 'subjectCode': 'GE 1', 'subjectTitle': 'Math', 'units': 3, 'yearLevel': 1, 'semester': 1, 'isMinor': true, 'status': 'Credited', 'creditedFrom': 'USC', 'creditedGrade': '1.5'},
            {'subjectId': 's3', 'subjectCode': 'IT 201', 'subjectTitle': 'Data', 'units': 3, 'yearLevel': 2, 'semester': 1, 'isMinor': false, 'status': 'NotTaken'},
          ],
        };
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
    getIt.registerSingleton<StudentRecordRepository>(StudentRecordRepository(auth, client: client));
    getIt.registerSingleton<HoldRepository>(HoldRepository(auth, client: client));
    savedDetails = null;
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

  testWidgets('profile shows the header chips and seven tabs; Study load opens on the active term', (tester) async {
    await pump(tester);

    expect(find.text('LRN 123456789012'), findsOneWidget);
    expect(find.text('BSIT'), findsWidgets);
    expect(find.text('Year 1'), findsWidgets);
    for (final t in ['Study load', 'Grades', 'Evaluation', 'Credits', 'Details', 'Grade release', 'History']) {
      expect(tab(t), findsOneWidget, reason: t);
    }
    expect(requests.any((r) => r.startsWith('/api/studyloads/student/u1') && r.contains('termId=t1')), isTrue);
    expect(find.byKey(const ValueKey('build_study_load_button')), findsOneWidget);
    // Grades, Credits and History are tabs here, so the old window buttons are gone.
    expect(find.byKey(const ValueKey('view_grades_button')), findsNothing);
    expect(find.byKey(const ValueKey('credited_subjects_button')), findsNothing);
  });

  testWidgets('Grades shows GWA per term and overall (dropped loads not counted)', (tester) async {
    await pump(tester);
    await tester.tap(tab('Grades'));
    await tester.pumpAndSettle();

    // (3 × 1.5 + 1 × 3.5) / 4 = 2.00
    expect(find.descendant(of: find.byKey(const ValueKey('overall_gwa')), matching: find.text('2.00')), findsOneWidget);
    expect(find.byKey(const ValueKey('term_gwa_2025-2026 (2nd Sem)')), findsOneWidget);
    expect(find.text('GWA 2.00'), findsOneWidget);
  });

  testWidgets('Evaluation shows units earned and the checklist; "Left to take only" hides finished subjects', (tester) async {
    await pump(tester);
    await tester.tap(tab('Evaluation'));
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byKey(const ValueKey('evaluation_earned')), matching: find.text('6')), findsOneWidget);
    expect(find.text('units earned of 9'), findsOneWidget);
    expect(find.text('67% of the curriculum done'), findsOneWidget);
    expect(find.text('FIRST YEAR FIRST SEMESTER'), findsOneWidget);
    expect(find.text('Credited - USC'), findsOneWidget);
    for (final c in ['IT 101', 'GE 1']) {
      expect(find.byKey(ValueKey('evaluation_row_$c')), findsOneWidget, reason: c);
    }

    await tester.tap(find.byKey(const ValueKey('evaluation_left_only')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('evaluation_row_IT 101')), findsNothing);
    expect(find.byKey(const ValueKey('evaluation_row_GE 1')), findsNothing);
    expect(find.byKey(const ValueKey('evaluation_row_IT 201')), findsOneWidget);
    expect(find.text('SECOND YEAR FIRST SEMESTER'), findsOneWidget);
    expect(find.text('Not yet taken'), findsNWidgets(2));   // the row and the color key
  });

  testWidgets('Grades and Evaluation each print a PDF', (tester) async {
    final printed = <String>[];
    final original = printPdf;
    printPdf = (bytes, name) async {
      expect(bytes.length, greaterThan(500));
      printed.add(name);
    };
    addTearDown(() => printPdf = original);
    await pump(tester);

    await tester.tap(tab('Grades'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('print_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('print_residency_button')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pumpAndSettle();

    await tester.tap(tab('Evaluation'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('print_evaluation_button')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pumpAndSettle();

    expect(printed, ['Residency_Ana_Cruz.pdf', 'Evaluation_Ana_Cruz.pdf']);
  });

  testWidgets('Print menu: a grade sheet for one semester or one subject, and the TOR with signatories', (tester) async {
    final printed = <String>[];
    final original = printPdf;
    printPdf = (bytes, name) async => printed.add(name);
    addTearDown(() => printPdf = original);
    await pump(tester);
    await tester.tap(tab('Grades'));
    await tester.pumpAndSettle();

    Future<void> openMenu(String item) async {
      await tester.tap(find.byKey(const ValueKey('print_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(item)));
      await tester.pumpAndSettle();
    }

    Future<void> tapAndWait(String key) async {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      await tester.pumpAndSettle();
    }

    await openMenu('print_grade_sheet_button');
    expect(find.text('Print grade sheet'), findsOneWidget);
    expect(find.byKey(const ValueKey('grade_sheet_term')), findsOneWidget);
    await tapAndWait('grade_sheet_print');
    expect(find.text('Print grade sheet'), findsNothing);

    await openMenu('print_grade_sheet_button');
    await tester.tap(find.text('One subject'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('grade_sheet_subject')), findsOneWidget);
    await tapAndWait('grade_sheet_print');

    await openMenu('print_tor_button');
    await tester.enterText(find.byKey(const ValueKey('tor_remarks')), 'For transfer purposes');
    await tester.enterText(find.byKey(const ValueKey('tor_registrar')), 'Rita Reg');
    await tapAndWait('tor_print');
    expect(requests.any((r) => r.startsWith('/api/student-records/u1/transcript')), isTrue);

    expect(printed, ['Grade_Sheet_Ana_Cruz.pdf', 'Grade_Sheet_Ana_Cruz.pdf', 'TOR_Ana_Cruz.pdf']);
  });

  testWidgets('Details: a student without a form shows what the TOR is missing; Edit and Save sends the values', (tester) async {
    await pump(tester);
    // Taller screen: the Holds card sits above the details.
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    await tester.pumpAndSettle();
    await tester.tap(tab('Details'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no online enrollment form'), findsOneWidget);
    expect(find.textContaining('Missing for the transcript: Address, Date of birth'), findsOneWidget);
    expect(find.text('2nd Semester, 2025-2026 (first term enrolled)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('edit_details_button')));
    await tester.pumpAndSettle();
    // The name can be corrected too.
    expect(tester.widget<TextField>(find.byKey(const ValueKey('details_firstname'))).controller!.text, isNotEmpty);
    await tester.enterText(find.byKey(const ValueKey('details_lastname')), ' Dela Cruz ');
    await tester.enterText(find.byKey(const ValueKey('details_address')), 'Talisay City');
    await tester.enterText(find.byKey(const ValueKey('details_entranceData')), 'Abellana NHS');
    await tester.tap(find.byKey(const ValueKey('save_details_button')));
    await tester.pumpAndSettle();

    expect(savedDetails!['lastname'], 'Dela Cruz');
    expect(savedDetails!['firstname'], isNotEmpty);
    expect(savedDetails!['address'], 'Talisay City');
    expect(savedDetails!['entranceData'], 'Abellana NHS');
    expect(savedDetails!['middleName'], '');
    expect(savedDetails!.containsKey('dateOfBirth'), isTrue);
    expect(find.text('Personal details saved.'), findsOneWidget);
    expect(find.text('Talisay City'), findsOneWidget);
    expect(find.textContaining('by Rita Reg'), findsOneWidget);
  });

  test('age counts whole years from the date of birth', () {
    expect(ageOn(DateTime(2004, 6, 15), DateTime(2026, 6, 14)), 21);
    expect(ageOn(DateTime(2004, 6, 15), DateTime(2026, 6, 15)), 22);
    expect(ageOn(DateTime(2004, 12, 31), DateTime(2026, 1, 1)), 21);
  });

  testWidgets('Study load lists adds and drops with reasons and prints the Adding/Dropping form', (tester) async {
    final printed = <String>[];
    final original = printPdf;
    printPdf = (bytes, name) async {
      expect(bytes.length, greaterThan(500));
      printed.add(name);
    };
    addTearDown(() => printPdf = original);
    await pump(tester);

    expect(find.text('Adds & drops this term (2)'), findsOneWidget);
    expect(find.text('IT 102 — Prog · Schedule conflict'), findsOneWidget);
    expect(requests.any((r) => r.startsWith('/api/studyloads/changes') && r.contains('userId=u1') && r.contains('termId=t1')), isTrue);

    await tester.tap(find.byKey(const ValueKey('print_add_drop_button')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pumpAndSettle();
    expect(printed, ['Adding_Dropping_Ana_Cruz.pdf']);
  });

  testWidgets('Evaluation shows irregular progress and marks the student regular after 6 back major units', (tester) async {
    standingSet = null;
    await pump(tester);
    await tester.tap(tab('Evaluation'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('standing_card')), findsOneWidget);
    expect(find.textContaining('Irregular since'), findsOneWidget);
    expect(find.textContaining('6 of 6 back major units passed (IT 101, IT 104) — ready to be regular again.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mark_regular_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_standing_button')));
    await tester.pumpAndSettle();
    expect(standingSet, isTrue);
    expect(find.text('Regular student'), findsOneWidget);
  });

  testWidgets('the Program chip opens the shift window', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('profile_program')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Shift Ana Cruz'), findsOneWidget);
    expect(find.text('Current program: BSIT'), findsOneWidget);
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
