import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sis_registrar_app/models/grading_models.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/repositories/enrollment_repository.dart';
import 'package:sis_registrar_app/views/widgets/initialize_clearance_dialog.dart';

// ── Minimal stub of AcademicSetupRepository ───────────────────────────────────
// We cannot call the real constructor (it requires AuthService / network),
// so we implement the interface and override only getTerms().
class _FakeAcademicSetupRepository implements AcademicSetupRepository {
  final List<AcademicTermModel> terms;

  _FakeAcademicSetupRepository(this.terms);

  @override
  Future<List<AcademicTermModel>> getTerms() async => terms;

  // All other interface members are unused by the dialog.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not stubbed');
}

// ── Helper: build the dialog inside a roomy test surface ─────────────────────
// Use a 800×1200 test size to avoid the RenderFlex overflow that occurs at the
// default 400×600 flutter-test surface when the dialog renders its button row.
Widget _dialogInApp({
  required UserSearchResultModel student,
  required List<String> existingTermIds,
  void Function(String termId, bool isCleared)? onConfirmed,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 800,
        height: 1200,
        child: InitializeClearanceDialog(
          student: student,
          existingTermIds: existingTermIds,
          onConfirmed: onConfirmed ?? (_, __) {},
        ),
      ),
    ),
  );
}

const _student = UserSearchResultModel(
  userId: 'user-1',
  firstname: 'Maria',
  lastname: 'Santos',
  email: 'maria.santos@dbtc-cebu.edu.ph',
  role: 5,
);

void main() {
  setUp(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<AcademicSetupRepository>()) {
      getIt.unregister<AcademicSetupRepository>();
    }
  });

  tearDown(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<AcademicSetupRepository>()) {
      getIt.unregister<AcademicSetupRepository>();
    }
  });

  void registerFakeRepo(List<AcademicTermModel> terms) {
    GetIt.instance.registerSingleton<AcademicSetupRepository>(
      _FakeAcademicSetupRepository(terms),
    );
  }

  // ── Test 1: header renders student full name ──────────────────────────────
  testWidgets(
      'InitializeClearanceDialog displays student full name in the header',
      (tester) async {
    registerFakeRepo([
      AcademicTermModel(termId: 'term-1', schoolYear: '2025-2026', semester: 1),
    ]);

    await tester.pumpWidget(_dialogInApp(
      student: _student,
      existingTermIds: [],
    ));

    await tester.pumpAndSettle();

    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('Initialize Clearance Record'), findsOneWidget);
  });

  // ── Test 2: "all terms covered" empty-state ───────────────────────────────
  // When every available term is already in existingTermIds, the dialog shows
  // an informational message and hides the dropdown + confirm button entirely.
  testWidgets(
      'InitializeClearanceDialog shows "all terms covered" message when '
      'existingTermIds already contains every available term', (tester) async {
    const coveredTermId = 'term-1';

    registerFakeRepo([
      AcademicTermModel(
          termId: coveredTermId, schoolYear: '2025-2026', semester: 1),
    ]);

    await tester.pumpWidget(_dialogInApp(
      student: _student,
      existingTermIds: [coveredTermId], // already covered → filtered list empty
    ));

    await tester.pumpAndSettle();

    // The "all covered" informational message must be visible
    expect(
      find.textContaining(
          'All available academic terms already have a clearance record'),
      findsOneWidget,
    );

    // The confirm button is rendered but disabled (onPressed is null)
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Initialize Clearance'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(button.enabled, isFalse);
  });

  // ── Test 3: confirm callback fires with correct args ──────────────────────
  testWidgets(
      'InitializeClearanceDialog calls onConfirmed with the selected termId '
      'and isCleared=false when "Initialize Clearance" is tapped', (tester) async {
    const targetTermId = 'term-2025-1';

    registerFakeRepo([
      AcademicTermModel(
          termId: targetTermId, schoolYear: '2025-2026', semester: 1),
    ]);

    String? confirmedTermId;
    bool? confirmedIsCleared;

    // Use a large test-surface size to prevent RenderFlex overflow
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_dialogInApp(
      student: _student,
      existingTermIds: [],
      onConfirmed: (termId, isCleared) {
        confirmedTermId = termId;
        confirmedIsCleared = isCleared;
      },
    ));

    await tester.pumpAndSettle();

    // The term label must appear in the dropdown
    expect(find.text('2025-2026 — 1st Sem'), findsOneWidget);

    // Tap the confirm button
    await tester.tap(find.text('Initialize Clearance'));
    await tester.pumpAndSettle();

    // Callback must have fired with the right values
    expect(confirmedTermId, equals(targetTermId));
    expect(confirmedIsCleared, isFalse);
  });
}
