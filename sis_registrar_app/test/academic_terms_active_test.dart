import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/blocs/setup_bloc.dart';
import 'package:sis_registrar_app/views/setup_view.dart';
import 'package:sis_registrar_app/repositories/enrollment_repository.dart';

class FakeAcademicSetupRepository implements AcademicSetupRepository {
  List<AcademicTermModel> terms = [];
  String? activatedId;

  @override
  Future<List<AcademicProgramModel>> getPrograms() async => [
        const AcademicProgramModel(
            programId: 1, programCode: 'BSIT', programName: 'Information Technology'),
      ];

  @override
  Future<AcademicProgramModel> createProgram({required String code, required String name}) async =>
      AcademicProgramModel(programId: 1, programCode: code, programName: name);

  @override
  Future<AcademicProgramModel> updateProgram(int id, {required String code, required String name}) async =>
      AcademicProgramModel(programId: id, programCode: code, programName: name);

  @override
  Future<void> deleteProgram(int id) async {}

  @override
  Future<List<AcademicTermModel>> getTerms() async => terms;

  @override
  Future<AcademicTermModel> createTerm({required String schoolYear, required int semester}) async =>
      AcademicTermModel(termId: 'new', schoolYear: schoolYear, semester: semester);

  @override
  Future<AcademicTermModel> updateTerm(String id, {required String schoolYear, required int semester}) async =>
      AcademicTermModel(termId: id, schoolYear: schoolYear, semester: semester);

  @override
  Future<void> deleteTerm(String id) async {}

  @override
  Future<AcademicTermModel> setEnrollmentPeriod(String id, {DateTime? opensOn, DateTime? closesOn}) async =>
      throw UnimplementedError();

  @override
  Future<AcademicTermModel> activateTerm(String id) async {
    activatedId = id;
    final target = terms.firstWhere((t) => t.termId == id);
    terms = terms
        .map((t) => AcademicTermModel(
              termId: t.termId,
              schoolYear: t.schoolYear,
              semester: t.semester,
              isActive: t.termId == id,
            ))
        .toList();
    return AcademicTermModel(
      termId: target.termId,
      schoolYear: target.schoolYear,
      semester: target.semester,
      isActive: true,
    );
  }

  @override
  Future<List<SubjectModel>> getSubjects({int? programId, int? yearLevel}) async => [];

  @override
  Future<SubjectModel> createSubject(Map<String, dynamic> dto) async =>
      SubjectModel.fromJson({...dto, 'subjectID': 'subj-new'});

  @override
  Future<SubjectModel> updateSubject(String id, Map<String, dynamic> dto) async =>
      SubjectModel.fromJson({...dto, 'subjectID': id});

  @override
  Future<void> deleteSubject(String id) async {}

  @override
  Future<List<PrerequisiteModel>> getPrerequisites(String subjectId) async => [];

  @override
  Future<void> addPrerequisite(String subjectId, String prerequisiteSubjectId,
      {int requisiteType = 0}) async {}

  @override
  Future<void> removePrerequisite(String prerequisiteId) async {}
}

class TestSetupBloc extends Bloc<SetupEvent, SetupState> implements SetupBloc {
  final List<SetupEvent> recordedEvents = [];
  TestSetupBloc(super.initialState) {
    on<SetupEvent>((event, emit) {
      recordedEvents.add(event);
    });
  }
}

void main() {
  group('AcademicTermModel.isActive', () {
    test('fromJson parses isActive true and false correctly', () {
      final activeJson = {
        'termID': 'term-1',
        'schoolYear': '2025-2026',
        'semester': 1,
        'isActive': true,
      };
      final inactiveJson = {
        'termID': 'term-2',
        'schoolYear': '2024-2025',
        'semester': 2,
        'isActive': false,
      };
      final omittedJson = {
        'termID': 'term-3',
        'schoolYear': '2023-2024',
        'semester': 1,
      };

      final term1 = AcademicTermModel.fromJson(activeJson);
      final term2 = AcademicTermModel.fromJson(inactiveJson);
      final term3 = AcademicTermModel.fromJson(omittedJson);

      expect(term1.isActive, isTrue);
      expect(term2.isActive, isFalse);
      expect(term3.isActive, isFalse);
    });
  });

  group('SetupBloc ActivateTermEvent', () {
    late FakeAcademicSetupRepository fakeRepo;
    late SetupBloc setupBloc;

    setUp(() {
      fakeRepo = FakeAcademicSetupRepository();
      fakeRepo.terms = [
        const AcademicTermModel(
          termId: 'term-1',
          schoolYear: '2024-2025',
          semester: 2,
          isActive: true,
        ),
        const AcademicTermModel(
          termId: 'term-2',
          schoolYear: '2025-2026',
          semester: 1,
          isActive: false,
        ),
      ];
      setupBloc = SetupBloc(fakeRepo);
    });

    tearDown(() {
      setupBloc.close();
    });

    test('ActivateTermEvent deactivates previous term and sets new term active', () async {
      setupBloc.add(ActivateTermEvent('term-2'));

      await expectLater(
        setupBloc.stream,
        emitsInOrder([
          predicate<SetupState>((s) => s.isSubmitting == true),
          predicate<SetupState>((s) {
            final activeTerm = s.terms.firstWhere((t) => t.isActive);
            return s.isSubmitting == false &&
                activeTerm.termId == 'term-2' &&
                s.successMessage!.contains('is now active');
          }),
        ]),
      );

      expect(fakeRepo.activatedId, 'term-2');
    });
  });

  group('SetupView Academic Terms Tab UI', () {
    late TestSetupBloc testBloc;

    setUp(() {
      testBloc = TestSetupBloc(
        SetupState(
          programs: const [
            AcademicProgramModel(
              programId: 1,
              programCode: 'BSIT',
              programName: 'Information Technology',
            ),
          ],
          terms: const [
            AcademicTermModel(
              termId: 'term-1',
              schoolYear: '2024-2025',
              semester: 2,
              isActive: true,
            ),
            AcademicTermModel(
              termId: 'term-2',
              schoolYear: '2025-2026',
              semester: 1,
              isActive: false,
            ),
          ],
          activeTab: 1,
          isLoading: false,
        ),
      );
    });

    tearDown(() {
      testBloc.close();
    });

    testWidgets('renders Active Term and Inactive badges, and Set Active action with two-sided dialog',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<SetupBloc>.value(
            value: testBloc,
            child: const SetupView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check for Status column header
      expect(find.text('Status'), findsOneWidget);

      // Check for Active Term and Inactive badges
      expect(find.text('Active Term'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);

      // Only the inactive term should have a "Set Active" button
      expect(find.text('Set Active'), findsOneWidget);

      // Tap "Set Active" on the inactive term (term-2)
      await tester.tap(find.text('Set Active'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear showing BOTH sides:
      // "This will deactivate 2024-2025 (2nd Sem) and activate 2025-2026 (1st Sem) as the current academic term."
      expect(find.text('Set Active Academic Term'), findsOneWidget);
      expect(
        find.textContaining('This will deactivate 2024-2025 (2nd Sem) and activate 2025-2026 (1st Sem)'),
        findsOneWidget,
      );

      // Tap "Set as Active" confirm button
      await tester.tap(find.text('Set as Active'));
      await tester.pumpAndSettle();

      // Verify that ActivateTermEvent was dispatched with 'term-2'
      expect(testBloc.recordedEvents.any((e) => e is ActivateTermEvent && e.id == 'term-2'), isTrue);
    });
  });
}
