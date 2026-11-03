import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sis_teacher_app/blocs/program_overview_bloc.dart';
import 'package:sis_teacher_app/models/class_models.dart';
import 'package:sis_teacher_app/models/setup_models.dart';
import 'package:sis_teacher_app/repositories/class_repository.dart';
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

ClassModel _class(String id, String code, {bool isMinor = false}) => ClassModel(
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
    );

void main() {
  final getIt = GetIt.instance;
  late _FakeClassRepository repo;

  setUp(() async {
    await getIt.reset();
    repo = _FakeClassRepository();
    getIt.registerSingleton<ClassRepository>(repo);
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
}
