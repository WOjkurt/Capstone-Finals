import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sis_student_app/blocs/clearance_bloc.dart';
import 'package:sis_student_app/models/class_models.dart';
import 'package:sis_student_app/models/grading_models.dart';
import 'package:sis_student_app/models/setup_models.dart';
import 'package:sis_student_app/models/student_models.dart';
import 'package:sis_student_app/repositories/student_repository.dart';
import 'package:sis_student_app/views/clearance_status_view.dart';
import 'package:sis_student_app/views/widgets/status_badge.dart';

class MockStudentRepository implements StudentRepository {
  List<GradeClearanceModel> clearances = [];
  bool shouldThrow = false;

  @override
  Future<List<GradeClearanceModel>> getGradeClearances(String userId) async {
    if (shouldThrow) throw Exception('Failed to load clearances');
    return clearances;
  }

  @override
  Future<AcademicTermModel?> getActiveTerm() async => null;

  @override
  Future<List<AcademicTermModel>> getAllTerms() async => [];

  @override
  Future<List<GradeModel>> getGrades(String userId, String termId) async => [];

  @override
  Future<List<StudentScheduleItemModel>> getMySchedule(
      String userId, String termId) async => [];

  @override
  Future<StudentProfileModel> getMyProfile() async =>
      throw UnimplementedError();
}

void main() {
  final term1Clearance = GradeClearanceModel(
    clearanceId: 'c-1',
    userId: 'user-1',
    termId: 'term-1',
    termLabel: '2025-2026 (Sem 1)',
    isCleared: false,
    clearedByUserName: null,
    clearedAt: null,
  );

  final term2Clearance = GradeClearanceModel(
    clearanceId: 'c-2',
    userId: 'user-1',
    termId: 'term-2',
    termLabel: '2025-2026 (Sem 2)',
    isCleared: true,
    clearedByUserName: 'Registrar Officer',
    clearedAt: DateTime(2026, 9, 15, 10, 30),
  );

  group('ClearanceBloc tests', () {
    late MockStudentRepository repo;
    late ClearanceBloc bloc;

    setUp(() {
      repo = MockStudentRepository();
      bloc = ClearanceBloc(repo);
    });

    tearDown(() {
      bloc.close();
    });

    test('initial state is ClearanceInitial', () {
      expect(bloc.state, isA<ClearanceInitial>());
    });

    test('LoadClearancesEvent loads clearances and orders most recent first', () async {
      // Backend supplies ascending (older first: term 1 then term 2)
      repo.clearances = [term1Clearance, term2Clearance];

      bloc.add(LoadClearancesEvent(userId: 'user-1'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ClearanceLoading>(),
          predicate<ClearanceLoaded>((state) {
            return state.clearances.length == 2 &&
                state.clearances.first.termId == 'term-2' && // reversed: most recent first
                state.clearances.last.termId == 'term-1' &&
                state.totalTerms == 2 &&
                state.clearedCount == 1 &&
                state.withheldCount == 1;
          }),
        ]),
      );
    });

    test('emits ClearanceError when repository throws', () async {
      repo.shouldThrow = true;
      bloc.add(LoadClearancesEvent(userId: 'user-1'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ClearanceLoading>(),
          isA<ClearanceError>(),
        ]),
      );
    });
  });

  group('ClearanceStatusView Widget tests', () {
    late MockStudentRepository repo;

    setUp(() {
      repo = MockStudentRepository();
    });

    Widget createWidgetUnderTest(ClearanceBloc bloc) {
      return MaterialApp(
        home: BlocProvider<ClearanceBloc>.value(
          value: bloc,
          child: const ClearanceStatusView(userId: 'user-1'),
        ),
      );
    }

    testWidgets('renders empty state when student has no clearance records', (tester) async {
      repo.clearances = [];
      final bloc = ClearanceBloc(repo);

      await tester.pumpWidget(createWidgetUnderTest(bloc));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Clearance Status'), findsOneWidget);
      expect(find.text('No clearance records found'), findsOneWidget);

      bloc.close();
    });

    testWidgets('renders one row per term with a status badge', (tester) async {
      repo.clearances = [term1Clearance, term2Clearance];
      final bloc = ClearanceBloc(repo);

      await tester.pumpWidget(createWidgetUnderTest(bloc));
      await tester.pump();
      await tester.pumpAndSettle();

      // One badge per term, no summary strip
      expect(find.byType(StatusBadge), findsNWidgets(2));
      expect(find.text('Total Terms'), findsNothing);
      expect(find.text('Cleared'), findsOneWidget);
      expect(find.text('Withheld'), findsOneWidget);

      // Term 2 row (most recent first, cleared)
      expect(find.text('2025-2026 (Sem 2)'), findsOneWidget);
      expect(find.textContaining('Cleared by Registrar Officer'), findsOneWidget);

      // Term 1 row (withheld)
      expect(find.text('2025-2026 (Sem 1)'), findsOneWidget);
      expect(find.text('Settle requirements with the Registrar'), findsOneWidget);

      // Newest term is listed first
      final term2Y = tester.getTopLeft(find.text('2025-2026 (Sem 2)')).dy;
      final term1Y = tester.getTopLeft(find.text('2025-2026 (Sem 1)')).dy;
      expect(term2Y, lessThan(term1Y));

      bloc.close();
    });
  });
}
