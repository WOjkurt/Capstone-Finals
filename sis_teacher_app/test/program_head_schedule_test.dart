import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sis_teacher_app/blocs/program_overview_bloc.dart';
import 'package:sis_teacher_app/models/class_models.dart';
import 'package:sis_teacher_app/models/setup_models.dart';
import 'package:sis_teacher_app/repositories/class_repository.dart';
import 'package:sis_teacher_app/repositories/grading_repository.dart';
import 'package:sis_teacher_app/utils/error_handler.dart';
import 'package:sis_teacher_app/views/program_overview_view.dart';
import 'package:sis_teacher_app/views/widgets/class_schedule_dialog.dart';

class _FakeClassRepository implements ClassRepository {
  List<ClassModel> mockClasses = [];
  int programClassLoads = 0;
  final List<ClassScheduleModel> schedules = [];
  final List<Map<String, String>> created = [];

  @override
  Future<List<ClassModel>> getProgramClasses({String? termId, String? subjectId, int? yearLevel}) async {
    programClassLoads++;
    return mockClasses;
  }

  @override
  Future<List<ClassRosterItemModel>> getClassRoster(String classId) async => [];

  @override
  Future<List<AcademicTermModel>> getTerms() async => const [
        AcademicTermModel(termId: 'term-1', schoolYear: '2026-2027', semester: 1, isActive: true),
      ];

  @override
  Future<AcademicTermModel?> getActiveTerm() async =>
      const AcademicTermModel(termId: 'term-1', schoolYear: '2026-2027', semester: 1, isActive: true);

  @override
  Future<List<ClassScheduleModel>> getSchedules(String classId) async => List.of(schedules);

  @override
  Future<void> createSchedule({
    required String classId,
    required String daysOfWeek,
    required String startTime,
    required String endTime,
    required String room,
  }) async {
    created.add({'classId': classId, 'days': daysOfWeek, 'start': startTime, 'end': endTime, 'room': room});
    schedules.add(ClassScheduleModel(
        scheduleId: 'sch-${created.length}', classId: classId, daysOfWeek: daysOfWeek,
        startTime: '$startTime:00', endTime: '$endTime:00', room: room));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ClassModel _class(String id, String code, {bool isMinor = false, DateTime? verifiedAt}) => ClassModel(
      classId: id,
      subjectId: 'subj-$id',
      subjectCode: code,
      subjectTitle: '$code title',
      yearLevel: 1,
      userId: 't1',
      teacherName: 'Prof. Alan',
      termId: 'term-1',
      className: 'BSIT 1A',
      isMinor: isMinor,
      verifiedAt: verifiedAt,
    );

/// Records what the verify button asked the server to do.
class _FakeGradeSheetRepository implements GradeSheetRepository {
  final List<(String, bool)> calls = [];
  Object? throws;

  @override
  Future<void> setVerified(String classId, bool verified) async {
    if (throws != null) throw throws!;
    calls.add((classId, verified));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final getIt = GetIt.instance;
  late _FakeGradeSheetRepository sheets;
  late _FakeClassRepository repo;

  setUp(() async {
    await getIt.reset();
    repo = _FakeClassRepository();
    sheets = _FakeGradeSheetRepository();
    getIt.registerSingleton<ClassRepository>(repo);
    getIt.registerSingleton<GradeSheetRepository>(sheets);
  });

  tearDown(() async => getIt.reset());

  test('ClassModel parses isMinor (defaults to false)', () {
    final minor = ClassModel.fromJson({'classID': 'a', 'subjectID': 'b', 'termID': 'c', 'className': 'n', 'isMinor': true});
    final plain = ClassModel.fromJson({'classID': 'a', 'subjectID': 'b', 'termID': 'c', 'className': 'n'});
    expect(minor.isMinor, isTrue);
    expect(plain.isMinor, isFalse);
  });

  Future<void> openDetail(WidgetTester tester, String code) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final bloc = ProgramOverviewBloc(repo);
    addTearDown(bloc.close);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BlocProvider<ProgramOverviewBloc>.value(value: bloc, child: const ProgramOverviewView()),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(code).first);
    await tester.pumpAndSettle();
  }

  testWidgets('minor class: no Edit schedule button, says the College Head sets it', (tester) async {
    repo.mockClasses = [_class('c2', 'THEO 101A', isMinor: true)];

    await openDetail(tester, 'THEO 101A');

    expect(find.text('Schedule set by the College Head'), findsOneWidget);
    expect(find.byKey(const ValueKey('edit_schedule_button')), findsNothing);
  });

  testWidgets('major class: Program Head adds a meeting time and the overview reloads', (tester) async {
    repo.mockClasses = [_class('c1', 'IT 101A')];

    await openDetail(tester, 'IT 101A');
    final loadsBefore = repo.programClassLoads;

    await tester.tap(find.byKey(const ValueKey('edit_schedule_button')));
    await tester.pumpAndSettle();
    expect(find.byType(ClassScheduleDialog), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('day_M')));
    await tester.tap(find.byKey(const ValueKey('day_W')));
    await tester.tap(find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField<String> && w.key.toString().contains('start_time')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1:00 PM').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField<String> && w.key.toString().contains('end_time')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2:30 PM').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('room_field')), 'Lab 2');
    await tester.tap(find.byKey(const ValueKey('save_schedule_button')));
    await tester.pumpAndSettle();

    expect(repo.created.single, {'classId': 'c1', 'days': 'M/W', 'start': '13:00', 'end': '14:30', 'room': 'Lab 2'});

    await tester.tap(find.text('Close').last);
    await tester.pumpAndSettle();

    expect(find.byType(ClassScheduleDialog), findsNothing);
    expect(find.byKey(const ValueKey('edit_schedule_button')), findsNothing, reason: 'detail closes after a change');
    expect(repo.programClassLoads, greaterThan(loadsBefore));
  });

  testWidgets('an unchecked sheet offers Verify; verifying tells the server', (tester) async {
    repo.mockClasses = [_class('c1', 'IT 101A')];

    await openDetail(tester, 'IT 101A');

    expect(find.text('Verify grade sheet'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('verify_sheet_button')));
    await tester.pumpAndSettle();

    expect(sheets.calls, [('c1', true)]);
    expect(find.text('Sheet verified'), findsOneWidget);
    // Checked is not published: the Registrar still has to release the term.
    expect(find.textContaining('released by the Registrar'), findsOneWidget);
  });

  testWidgets('a sheet already checked offers to take it off again', (tester) async {
    repo.mockClasses = [_class('c1', 'IT 101A', verifiedAt: DateTime.utc(2026, 11, 20))];

    await openDetail(tester, 'IT 101A');

    expect(find.text('Sheet verified'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('verify_sheet_button')));
    await tester.pumpAndSettle();

    expect(sheets.calls, [('c1', false)]);
    expect(find.text('Verify grade sheet'), findsOneWidget);
  });

  testWidgets('a refusal from the server is reported and the button does not lie', (tester) async {
    repo.mockClasses = [_class('c1', 'IT 101A')];
    sheets.throws = ApiException(
        statusCode: 403,
        message: 'A Program Head can only verify grade sheets for their own programme.');

    await openDetail(tester, 'IT 101A');
    await tester.tap(find.byKey(const ValueKey('verify_sheet_button')));
    await tester.pumpAndSettle();

    // The shared handler deliberately makes every 403 generic, so the server's own wording
    // does not reach the screen. Reaching this at all means the UI let somebody try a class
    // they cannot see in Program Overview anyway.
    expect(find.textContaining('Access denied'), findsOneWidget);
    // Still unverified: the screen must not claim something the server refused.
    expect(find.text('Verify grade sheet'), findsOneWidget);
  });
}
