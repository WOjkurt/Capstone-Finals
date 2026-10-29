import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/models/class_models.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/repositories/class_repository.dart';
import 'package:sis_registrar_app/views/widgets/open_term_dialog.dart';

class _FakeClassRepository implements ClassRepository {
  OpenTermResultModel? nextResult;
  bool lastDryRun = false;

  @override
  Future<OpenTermResultModel> openTerm({
    required int programId,
    required String termId,
    int? yearLevel,
    int sections = 1,
    required bool dryRun,
  }) async {
    lastDryRun = dryRun;
    return nextResult ??
        OpenTermResultModel(
          dryRun: dryRun,
          termId: termId,
          programId: programId,
          plannedCount: 0,
          createdCount: 0,
          skippedExisting: 0,
          skippedNoDefaultSemester: 0,
          perYear: const {},
          termIsActive: true,
          sampleClassNames: const [],
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not stubbed');
}

void main() {
  late _FakeClassRepository fakeClassRepo;

  setUp(() {
    fakeClassRepo = _FakeClassRepository();
    if (getIt.isRegistered<ClassRepository>()) {
      getIt.unregister<ClassRepository>();
    }
    getIt.registerSingleton<ClassRepository>(fakeClassRepo);
  });

  tearDown(() {
    if (getIt.isRegistered<ClassRepository>()) {
      getIt.unregister<ClassRepository>();
    }
  });

  final testTerms = [
    const AcademicTermModel(
      termId: 'term-1',
      schoolYear: '2026-2027',
      semester: 1,
      isActive: true,
    ),
    const AcademicTermModel(
      termId: 'term-2',
      schoolYear: '2026-2027',
      semester: 2,
      isActive: false,
    ),
  ];

  final testPrograms = [
    const AcademicProgramModel(
      programId: 1,
      programCode: 'BSIT',
      programName: 'Bachelor of Science in Information Technology',
    ),
    const AcademicProgramModel(
      programId: 2,
      programCode: 'BSCS',
      programName: 'Bachelor of Science in Computer Science',
    ),
  ];

  Widget buildTestDialog({ValueChanged<OpenTermResultModel>? onComplete}) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1000,
          height: 1200,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => OpenTermDialog.show(
                context,
                terms: testTerms,
                programs: testPrograms,
                onComplete: onComplete,
              ),
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('OpenTermDialog renders all form fields with sensible defaults (no capacity)', (tester) async {
    await tester.pumpWidget(buildTestDialog());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Title and description
    expect(find.text('Open Classes for Term'), findsOneWidget);
    expect(find.text('Automatically generate scheduled class sections for curriculum subjects.'), findsOneWidget);

    // Form inputs
    expect(find.byKey(const Key('open_term_dropdown_term')), findsOneWidget);
    expect(find.byKey(const Key('open_term_dropdown_program')), findsOneWidget);
    expect(find.byKey(const Key('open_term_dropdown_year_level')), findsOneWidget);
    expect(find.byKey(const Key('open_term_input_sections')), findsOneWidget);
    // Capacity must NOT exist
    expect(find.byKey(const Key('open_term_input_capacity')), findsNothing);

    // Initial default values
    final sectionsField = tester.widget<TextFormField>(find.byKey(const Key('open_term_input_sections')));
    expect(sectionsField.controller?.text, '1');

    // Confirm button is initially disabled
    final confirmBtn = tester.widget<ElevatedButton>(find.byKey(const Key('open_term_btn_confirm')));
    expect(confirmBtn.onPressed, isNull, reason: 'Confirm button must be disabled before Preview is run');
  });

  testWidgets('Preview calls repo with dryRun: true and displays summary card, perYear, and counters', (tester) async {
    fakeClassRepo.nextResult = OpenTermResultModel(
      dryRun: true,
      termId: 'term-1',
      programId: 1,
      plannedCount: 3,
      createdCount: 0,
      skippedExisting: 1,
      skippedNoDefaultSemester: 2,
      perYear: const {1: 2, 2: 1},
      termIsActive: true,
      sampleClassNames: const ['BSIT 1A', 'BSIT 1B', 'BSIT 2A'],
    );

    await tester.pumpWidget(buildTestDialog());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Click Preview
    await tester.tap(find.byKey(const Key('open_term_btn_preview')));
    await tester.pumpAndSettle();

    expect(fakeClassRepo.lastDryRun, isTrue);

    // Check summary card counters
    expect(find.text('3 classes will be created, 1 will be skipped (already exist).'), findsOneWidget);
    expect(find.text('2 curriculum subjects skipped (no default semester assigned).'), findsOneWidget);
    expect(find.text('Year 1: 2 classes'), findsOneWidget);
    expect(find.text('Year 2: 1 classes'), findsOneWidget);
    expect(find.text('BSIT 1A'), findsWidgets);

    // Confirm button is now enabled
    final confirmBtn = tester.widget<ElevatedButton>(find.byKey(const Key('open_term_btn_confirm')));
    expect(confirmBtn.onPressed, isNotNull, reason: 'Confirm button must be enabled after Preview succeeds');
  });

  testWidgets('Preview shows warning when term is not active', (tester) async {
    fakeClassRepo.nextResult = OpenTermResultModel(
      dryRun: true,
      termId: 'term-2',
      programId: 1,
      plannedCount: 2,
      createdCount: 0,
      skippedExisting: 0,
      skippedNoDefaultSemester: 0,
      perYear: const {1: 2},
      termIsActive: false,
      sampleClassNames: const ['BSIT 1A', 'BSIT 1B'],
    );

    await tester.pumpWidget(buildTestDialog());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Click Preview
    await tester.tap(find.byKey(const Key('open_term_btn_preview')));
    await tester.pumpAndSettle();

    expect(find.text('Warning: The selected academic term is not active.'), findsOneWidget);
  });

  testWidgets('Confirm button calls repo with dryRun: false and triggers completion', (tester) async {
    fakeClassRepo.nextResult = OpenTermResultModel(
      dryRun: true,
      termId: 'term-1',
      programId: 1,
      plannedCount: 2,
      createdCount: 0,
      skippedExisting: 0,
      skippedNoDefaultSemester: 0,
      perYear: const {1: 2},
      termIsActive: true,
      sampleClassNames: const ['BSIT 1A', 'BSIT 1B'],
    );

    OpenTermResultModel? completedResult;
    await tester.pumpWidget(buildTestDialog(onComplete: (res) => completedResult = res));
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // 1. Run preview
    await tester.tap(find.byKey(const Key('open_term_btn_preview')));
    await tester.pumpAndSettle();

    // Set result for confirm
    fakeClassRepo.nextResult = OpenTermResultModel(
      dryRun: false,
      termId: 'term-1',
      programId: 1,
      plannedCount: 2,
      createdCount: 2,
      skippedExisting: 0,
      skippedNoDefaultSemester: 0,
      perYear: const {1: 2},
      termIsActive: true,
      sampleClassNames: const ['BSIT 1A', 'BSIT 1B'],
    );

    // 2. Run confirm
    await tester.tap(find.byKey(const Key('open_term_btn_confirm')));
    await tester.pumpAndSettle();

    expect(fakeClassRepo.lastDryRun, isFalse);

    // Dialog is dismissed and callback is invoked
    expect(find.text('Open Classes for Term'), findsNothing);
    expect(completedResult, isNotNull);
    expect(completedResult!.createdCount, 2);
    // Success snackbar is shown
    expect(find.text('Opened 2 classes'), findsOneWidget);
    expect(find.text('No new classes were created. They already exist.'), findsNothing);
  });

  testWidgets('Preview with plannedCount 0 and skippedExisting 34 shows all classes already open message and Confirm is disabled', (tester) async {
    fakeClassRepo.nextResult = OpenTermResultModel(
      dryRun: true,
      termId: 'term-1',
      programId: 1,
      plannedCount: 0,
      createdCount: 0,
      skippedExisting: 34,
      skippedNoDefaultSemester: 0,
      perYear: const {},
      termIsActive: true,
      sampleClassNames: const [],
    );

    await tester.pumpWidget(buildTestDialog());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_term_btn_preview')));
    await tester.pumpAndSettle();

    expect(
      find.text('All classes for this term are already open (34 existing). Nothing to create.'),
      findsOneWidget,
    );
    final confirmBtn = tester.widget<ElevatedButton>(find.byKey(const Key('open_term_btn_confirm')));
    expect(confirmBtn.onPressed, isNull, reason: 'Confirm button must be disabled when plannedCount is 0');
  });

  testWidgets('Preview with plannedCount 0 and skippedExisting 0 shows no subjects match message and Confirm is disabled', (tester) async {
    fakeClassRepo.nextResult = OpenTermResultModel(
      dryRun: true,
      termId: 'term-1',
      programId: 1,
      plannedCount: 0,
      createdCount: 0,
      skippedExisting: 0,
      skippedNoDefaultSemester: 3,
      perYear: const {},
      termIsActive: true,
      sampleClassNames: const [],
    );

    await tester.pumpWidget(buildTestDialog());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_term_btn_preview')));
    await tester.pumpAndSettle();

    expect(
      find.text('No subjects match this program, term and year level.'),
      findsOneWidget,
    );
    expect(
      find.text('3 subjects have no default semester set.'),
      findsOneWidget,
    );
    final confirmBtn = tester.widget<ElevatedButton>(find.byKey(const Key('open_term_btn_confirm')));
    expect(confirmBtn.onPressed, isNull, reason: 'Confirm button must be disabled when plannedCount is 0');
  });

  testWidgets('Confirm with createdCount 0 shows the neutral message, not the success one', (tester) async {
    fakeClassRepo.nextResult = OpenTermResultModel(
      dryRun: true,
      termId: 'term-1',
      programId: 1,
      plannedCount: 2,
      createdCount: 0,
      skippedExisting: 0,
      skippedNoDefaultSemester: 0,
      perYear: const {1: 2},
      termIsActive: true,
      sampleClassNames: const ['BSIT 1A', 'BSIT 1B'],
    );

    await tester.pumpWidget(buildTestDialog());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // 1. Run preview
    await tester.tap(find.byKey(const Key('open_term_btn_preview')));
    await tester.pumpAndSettle();

    // Set result for confirm with createdCount 0
    fakeClassRepo.nextResult = OpenTermResultModel(
      dryRun: false,
      termId: 'term-1',
      programId: 1,
      plannedCount: 2,
      createdCount: 0,
      skippedExisting: 2,
      skippedNoDefaultSemester: 0,
      perYear: const {1: 2},
      termIsActive: true,
      sampleClassNames: const [],
    );

    // 2. Run confirm
    await tester.tap(find.byKey(const Key('open_term_btn_confirm')));
    await tester.pumpAndSettle();

    // Dialog is dismissed
    expect(find.text('Open Classes for Term'), findsNothing);
    // Neutral message is shown, NOT success message
    expect(find.text('No new classes were created. They already exist.'), findsOneWidget);
    expect(find.textContaining('Opened'), findsNothing);
  });
}
