import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sis_registrar_app/models/curriculum_models.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/repositories/enrollment_repository.dart';
import 'package:sis_registrar_app/views/widgets/curriculum_view_page.dart';

class _FakeSetupRepo implements AcademicSetupRepository {
  List<SubjectModel> subjects = [];
  Object? throws;

  @override
  Future<List<SubjectModel>> getSubjects({int? programId, int? yearLevel}) async {
    if (throws != null) throw throws!;
    return subjects;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _curriculum = CurriculumModel(
  curriculumId: 'cur-1',
  programId: 1,
  programCode: 'BSIT',
  name: 'BSIT 2023',
  effectiveFromYear: 2023,
  effectiveSchoolYear: '2023-2024',
  subjectCount: 3,
  studentCount: 40,
);

SubjectModel _subject(
  String code, {
  int year = 1,
  int sem = 1,
  double lecUnits = 3,
  double labUnits = 0,
  double lecHours = 3,
  double labHours = 0,
  String curriculumId = 'cur-1',
  List<PrerequisiteModel> requisites = const [],
}) =>
    SubjectModel(
      subjectId: '$code-$year-$sem',
      subjectCode: code,
      subjectTitle: '$code title',
      lecUnits: lecUnits,
      labUnits: labUnits,
      lecHours: lecHours,
      labHours: labHours,
      programId: 1,
      curriculumId: curriculumId,
      yearLevel: year,
      defaultSemester: sem,
      prerequisites: requisites,
    );

PrerequisiteModel _requisite(String code, {required int type}) => PrerequisiteModel(
      prerequisiteId: 'p-$code-$type',
      subjectId: 'x',
      prerequisiteSubjectId: 'y',
      prerequisiteSubjectCode: code,
      requisiteType: type,
    );

void main() {
  final getIt = GetIt.instance;
  late _FakeSetupRepo repo;

  setUp(() async {
    await getIt.reset();
    repo = _FakeSetupRepo();
    getIt.registerSingleton<AcademicSetupRepository>(repo);
  });

  tearDown(() async => getIt.reset());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(const MaterialApp(
      home: CurriculumViewPage(curriculum: _curriculum),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('groups the subjects by year and semester', (tester) async {
    repo.subjects = [
      _subject('IT 201', year: 2, sem: 1),
      _subject('IT 101', year: 1, sem: 1),
      _subject('IT 104', year: 1, sem: 2),
    ];

    await pump(tester);

    expect(find.byKey(const ValueKey('curriculum_year_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('curriculum_year_2')), findsOneWidget);
    expect(find.text('First Semester'), findsWidgets);
    expect(find.text('Second Semester'), findsOneWidget);
    expect(find.text('First Year'), findsOneWidget);
    expect(find.text('Second Year'), findsOneWidget);
  });

  testWidgets('only shows the subjects of this curriculum', (tester) async {
    repo.subjects = [
      _subject('IT 101'),
      _subject('OLD 101', curriculumId: 'cur-other'),
    ];

    await pump(tester);

    expect(find.text('IT 101'), findsOneWidget);
    // Subjects are fetched for every curriculum, so filtering is this page's job.
    expect(find.text('OLD 101'), findsNothing);
  });

  testWidgets('totals each semester separately, not the whole curriculum', (tester) async {
    repo.subjects = [
      _subject('IT 101', lecUnits: 3, lecHours: 3),
      _subject('IT 102', lecUnits: 2, labUnits: 1, lecHours: 2, labHours: 3),
      _subject('IT 201', year: 2, lecUnits: 3, lecHours: 3),
    ];

    await pump(tester);

    // First year, first semester: 5 lecture units and 1 lab unit, so 6 academic units.
    // One decimal, matching the "TOTAL ACADEMIC UNIT(S): 24.0" on the Registrar's own printout.
    expect(find.text('6.0 academic units'), findsOneWidget);
    // Second year's own semester totals 3, and must not be rolled into the first.
    expect(find.text('3.0 academic units'), findsOneWidget);
  });

  testWidgets('separates pre-requisites from co-requisites', (tester) async {
    repo.subjects = [
      _subject('IT 104', requisites: [
        _requisite('IT 102A', type: 0),
        _requisite('IT 102B', type: 0),
        _requisite('IT 104A', type: 1),
      ]),
    ];

    await pump(tester);

    // Several of a kind are comma separated the way the Registrar's printout lists them.
    expect(find.text('IT 102A, IT 102B'), findsOneWidget);
    expect(find.text('IT 104A'), findsOneWidget);
  });

  testWidgets('a curriculum with nothing in it says so rather than showing an empty table',
      (tester) async {
    repo.subjects = [_subject('OLD 101', curriculumId: 'cur-other')];

    await pump(tester);

    expect(find.byKey(const ValueKey('curriculum_view_empty')), findsOneWidget);
  });

  testWidgets('a failure to load offers another go', (tester) async {
    repo.throws = Exception('network');

    await pump(tester);

    expect(find.byKey(const ValueKey('curriculum_view_error')), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('names the course and curriculum, and offers printing and going back',
      (tester) async {
    repo.subjects = [_subject('IT 101')];

    await pump(tester);

    expect(find.textContaining('BSIT 2023'), findsWidgets);
    expect(find.textContaining('takes effect 2023-2024'), findsOneWidget);
    expect(find.byKey(const ValueKey('curriculum_print')), findsOneWidget);
    expect(find.byKey(const ValueKey('curriculum_view_back')), findsOneWidget);
    expect(find.byKey(const ValueKey('curriculum_show_groups')), findsOneWidget);
  });
}
