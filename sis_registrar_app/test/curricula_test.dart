import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_registrar_app/blocs/setup_bloc.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/models/curriculum_models.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/repositories/curriculum_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/utils/file_pick.dart';
import 'package:sis_registrar_app/views/setup_view.dart';
import 'package:sis_registrar_app/views/widgets/curricula_tab.dart';
import 'package:sis_registrar_app/views/widgets/student_curriculum_chip.dart';

class _FakeAuth implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {'Authorization': 'Bearer t'};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingSetupBloc extends Bloc<SetupEvent, SetupState> implements SetupBloc {
  final List<SetupEvent> events = [];
  RecordingSetupBloc(super.initialState) {
    on<SetupEvent>((event, emit) => events.add(event));
  }
}

const _programs = [
  AcademicProgramModel(programId: 1, programCode: 'BTVTED-MT', programName: 'BTVTEd Mechanical'),
  AcademicProgramModel(programId: 2, programCode: 'BSIT', programName: 'BS IT'),
];

Map<String, dynamic> _curriculum(String id, int program, String code, String name, int year,
        {int subjects = 0, int students = 0, bool newest = false}) =>
    {
      'curriculumID': id,
      'programID': program,
      'programCode': code,
      'name': name,
      'effectiveFromYear': year,
      'effectiveSchoolYear': '$year-${year + 1}',
      'subjectCount': subjects,
      'studentCount': students,
      'isNewest': newest,
    };

/// A small in-memory /api/curricula that records each request.
class FakeCurriculaApi {
  final requests = <String>[];
  final bodies = <Map<String, dynamic>>[];
  final items = <Map<String, dynamic>>[
    _curriculum('old', 1, 'BTVTED-MT', '2021 curriculum', 2021, subjects: 65, students: 40),
    _curriculum('new', 1, 'BTVTED-MT', 'CHED 2026', 2026, newest: true),
    _curriculum('it', 2, 'BSIT', 'First curriculum', 2000, subjects: 68, students: 120, newest: true),
  ];
  Map<String, dynamic> student = {'programID': 1, 'curriculumID': 'old', 'name': '2021 curriculum', 'effectiveSchoolYear': '2021-2022'};

  /// What the import endpoint answers; `dryRun` comes from the query.
  Map<String, dynamic> Function(bool dryRun) importAnswer = (dryRun) => {
        'dryRun': dryRun,
        'program': 'BTVTED-MT',
        'subjects': {'create': 3, 'update': 1, 'unchanged': 2},
        'requisites': {'prerequisitesToAdd': 2, 'corequisitesToAdd': 0},
        'warnings': [],
        'errors': [],
      };

  late final client = MockClient((req) async {
    requests.add('${req.method} ${req.url.path}${req.url.query.isEmpty ? '' : '?${req.url.query}'}');
    final path = req.url.path;
    if (path.endsWith('/api/Curriculum/import')) {
      return http.Response(jsonEncode(importAnswer(req.url.queryParameters['dryRun'] == 'true')), 200);
    }
    if (path.endsWith('/api/curricula/student/s1')) {
      if (req.method == 'PUT') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        bodies.add(body);
        final picked = items.firstWhere((c) => c['curriculumID'] == body['curriculumID']);
        student = {...student, 'curriculumID': picked['curriculumID'], 'name': picked['name']};
        return http.Response(jsonEncode({'curriculumId': picked['curriculumID'], 'name': picked['name']}), 200);
      }
      return http.Response(jsonEncode(student), 200);
    }
    if (req.method == 'POST' && path.endsWith('/api/curricula')) {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      bodies.add(body);
      final year = body['effectiveFromYear'] as int;
      if (items.any((c) => c['programID'] == body['programID'] && c['effectiveFromYear'] == year)) {
        return http.Response(jsonEncode({'message': 'BTVTED-MT already has a curriculum for SY $year-${year + 1}: CHED 2026.'}), 409);
      }
      final c = _curriculum('c${items.length}', body['programID'] as int, 'BTVTED-MT', body['name'] as String, year);
      items.add(c);
      return http.Response(jsonEncode(c), 200);
    }
    if (req.method == 'DELETE') {
      items.removeWhere((c) => path.endsWith('/${c['curriculumID']}'));
      return http.Response('', 204);
    }
    final programId = req.url.queryParameters['programId'];
    return http.Response(
        jsonEncode(items.where((c) => programId == null || '${c['programID']}' == programId).toList()), 200);
  });

  late final repo = CurriculumRepository(_FakeAuth(), client: client);
}

void main() {
  Future<FakeCurriculaApi> pumpTab(WidgetTester tester, {VoidCallback? onSubjectsChanged}) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final api = FakeCurriculaApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CurriculaTab(programs: _programs, repository: api.repo, onSubjectsChanged: onSubjectsChanged)),
    ));
    await tester.pumpAndSettle();
    return api;
  }

  test('CurriculumModel and SubjectModel read the curriculum fields', () {
    final c = CurriculumModel.fromJson(_curriculum('x', 1, 'BTVTED-MT', 'CHED 2026', 2026, newest: true));
    expect(c.label, 'CHED 2026 (from SY 2026-2027)');
    expect(c.isNewest, isTrue);
    final s = SubjectModel.fromJson({'subjectID': 's', 'subjectCode': 'MT 101', 'subjectTitle': 'T', 'programID': 1,
      'curriculumID': 'x', 'curriculumName': 'CHED 2026'});
    expect(s.curriculumId, 'x');
    expect(s.curriculumName, 'CHED 2026');
  });

  testWidgets('lists curricula, marks the one new students get, and only empty ones can be deleted', (tester) async {
    await pumpTab(tester);

    expect(find.text('2021 curriculum'), findsOneWidget);
    expect(find.text('CHED 2026'), findsOneWidget);
    expect(find.text('New students'), findsNWidgets(2)); // CHED 2026 and BSIT's only curriculum
    expect(find.text('SY 2021-2022'), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const ValueKey('delete_old'))).onPressed, isNull);
    expect(tester.widget<IconButton>(find.byKey(const ValueKey('delete_new'))).onPressed, isNotNull);
  });

  testWidgets('program filter shows only that program', (tester) async {
    await pumpTab(tester);
    await tester.tap(find.byKey(const ValueKey('curricula_program_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BSIT').last);
    await tester.pumpAndSettle();

    expect(find.text('First curriculum'), findsOneWidget);
    expect(find.text('2021 curriculum'), findsNothing);
  });

  testWidgets('add a curriculum: name and school year are sent; a taken year shows the error', (tester) async {
    final api = await pumpTab(tester);

    await tester.tap(find.byKey(const ValueKey('add_curriculum_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('curriculum_name_field')), 'Again');
    await tester.tap(find.byKey(const ValueKey('curriculum_year_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-2027').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save_curriculum_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('already has a curriculum for SY 2026-2027'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('curriculum_year_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2027-2028').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('curriculum_name_field')), 'CMO 2027');
    await tester.tap(find.byKey(const ValueKey('save_curriculum_button')));
    await tester.pumpAndSettle();

    expect(api.bodies.last, {'programID': 1, 'name': 'CMO 2027', 'effectiveFromYear': 2027});
    expect(find.text('CMO 2027'), findsOneWidget);
    expect(find.text('Curriculum added.'), findsOneWidget);
  });

  testWidgets('delete an empty curriculum after confirming', (tester) async {
    final api = await pumpTab(tester);
    await tester.tap(find.byKey(const ValueKey('delete_new')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_delete_curriculum')));
    await tester.pumpAndSettle();

    expect(api.requests, contains('DELETE /api/curricula/new'));
    expect(find.text('CHED 2026'), findsNothing);
  });

  testWidgets('import: preview first, then import into the chosen curriculum', (tester) async {
    var reloaded = 0;
    final api = await pumpTab(tester, onSubjectsChanged: () => reloaded++);
    pickFile = ({String accept = ''}) async => PickedFile('mt_2026.csv', Uint8List.fromList(utf8.encode('program,code\n')));
    addTearDown(() => pickFile = ({String accept = ''}) async => null);

    await tester.tap(find.byKey(const ValueKey('import_new')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('run_import_button'))).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('choose_csv_button')));
    await tester.pumpAndSettle();
    expect(find.text('3 new subject(s)'), findsOneWidget);
    expect(find.text('1 subject(s) differ from the file and will be left as they are'), findsOneWidget);
    expect(api.requests.last, contains('dryRun=true'));
    expect(api.requests.last, contains('curriculumId=new'));

    await tester.tap(find.byKey(const ValueKey('run_import_button')));
    await tester.pumpAndSettle();
    expect(api.requests.where((r) => r.contains('dryRun=false')), hasLength(1));
    expect(find.textContaining('Imported into CHED 2026: 3 new'), findsOneWidget);
    expect(reloaded, 1);
  });

  testWidgets('import with errors lists them and cannot be imported', (tester) async {
    final api = await pumpTab(tester);
    api.importAnswer = (dryRun) => {
          'dryRun': dryRun,
          'program': 'BTVTED-MT',
          'subjects': {'create': 0, 'update': 0, 'unchanged': 0},
          'requisites': {},
          'warnings': [],
          'errors': [
            {'row': 4, 'code': 'MT 9', 'message': 'semester must be between 1 and 3 (found \'5\').'}
          ],
        };
    pickFile = ({String accept = ''}) async => PickedFile('bad.csv', Uint8List(0));
    addTearDown(() => pickFile = ({String accept = ''}) async => null);

    await tester.tap(find.byKey(const ValueKey('import_new')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('choose_csv_button')));
    await tester.pumpAndSettle();

    expect(find.text('Fix these first, then choose the file again:'), findsOneWidget);
    expect(find.textContaining('Row 4: semester must be between 1 and 3'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('run_import_button'))).onPressed, isNull);
  });

  testWidgets('student curriculum chip shows the curriculum and changes it', (tester) async {
    final api = FakeCurriculaApi();
    var changed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StudentCurriculumChip(userId: 's1', studentName: 'Kurt Rizal', repository: api.repo, onChanged: () => changed++),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Curriculum: 2021 curriculum'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile_curriculum')));
    await tester.pumpAndSettle();
    // Only the student's program is offered, and the current one can't be "saved" again.
    expect(find.text('First curriculum'), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('save_student_curriculum'))).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('pick_new')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save_student_curriculum')));
    await tester.pumpAndSettle();

    expect(api.bodies.last, {'curriculumID': 'new'});
    expect(find.text('Curriculum: CHED 2026'), findsOneWidget);
    expect(changed, 1);
  });

  group('Subjects tab', () {
    SubjectModel subject(String id, String code, String curriculumId, String curriculumName, {int program = 1}) => SubjectModel(
          subjectId: id,
          subjectCode: code,
          subjectTitle: '$code title',
          lecUnits: 3,
          labUnits: 0,
          lecHours: 3,
          labHours: 0,
          programId: program,
          programCode: program == 1 ? 'BTVTED-MT' : 'BSIT',
          curriculumId: curriculumId,
          curriculumName: curriculumName,
          yearLevel: 1,
          defaultSemester: 1,
        );

    Future<RecordingSetupBloc> pumpSubjects(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final api = FakeCurriculaApi();
      getIt.registerSingleton<CurriculumRepository>(api.repo);
      addTearDown(() => getIt.unregister<CurriculumRepository>());
      final bloc = RecordingSetupBloc(SetupState(activeTab: 2, programs: _programs, subjects: [
        subject('a', 'MT 101', 'old', '2021 curriculum'),
        subject('b', 'MT 101A', 'new', 'CHED 2026'),
        subject('c', 'IT 101', 'it', 'First curriculum', program: 2),
      ]));
      addTearDown(bloc.close);
      await tester.pumpWidget(MaterialApp(home: BlocProvider<SetupBloc>.value(value: bloc, child: const SetupView())));
      await tester.pumpAndSettle();
      return bloc;
    }

    testWidgets('filters by program and curriculum, and shows the curriculum when a program has several', (tester) async {
      await pumpSubjects(tester);
      expect(find.text('Subjects (3)'), findsOneWidget);
      expect(find.text('2021 curriculum'), findsOneWidget); // BTVTED-MT has two curricula
      expect(find.text('First curriculum'), findsNothing); // BSIT has one: no need to repeat it

      await tester.tap(find.byKey(const ValueKey('subjects_program_filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BTVTED-MT').last);
      await tester.pumpAndSettle();
      expect(find.text('Subjects (2)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('subjects_curriculum_filter_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CHED 2026 (from SY 2026-2027)').last);
      await tester.pumpAndSettle();
      expect(find.text('Subjects (1)'), findsOneWidget);
      expect(find.text('MT 101A'), findsOneWidget);
      expect(find.text('MT 101'), findsNothing);
    });

    testWidgets('a new subject goes to the newest curriculum unless another is picked', (tester) async {
      final bloc = await pumpSubjects(tester);
      await tester.tap(find.text('Add Subject'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Subject Code *'), 'MT 105A');
      await tester.enterText(find.widgetWithText(TextFormField, 'Subject Title *'), 'Machining');
      expect(find.text('CHED 2026 (from SY 2026-2027)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('subject_curriculum_field_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2021 curriculum (from SY 2021-2022)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Subject'));
      await tester.pumpAndSettle();

      final create = bloc.events.whereType<CreateSubjectEvent>().single;
      expect(create.dto['curriculumID'], 'old');
      expect(create.dto['programID'], 1);
    });
  });
}
