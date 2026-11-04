import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/models/grading_models.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/repositories/enrollment_repository.dart';
import 'package:sis_registrar_app/repositories/grading_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/views/main_layout_view.dart';
import 'package:sis_registrar_app/views/promotion_view.dart';

class FakeAuthService implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {'Authorization': 'Bearer t'};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSetupRepo implements AcademicSetupRepository {
  @override
  Future<List<AcademicProgramModel>> getPrograms() async =>
      const [AcademicProgramModel(programId: 1, programCode: 'BSIT', programName: 'BS IT')];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePromotionRepo implements PromotionRepository {
  List<StudentPromotionModel> rows = [];
  Map<String, int>? applied;
  int? lastYear;

  @override
  Future<List<StudentPromotionModel>> getSuggestions({required int programId, int? yearLevel}) async {
    lastYear = yearLevel;
    return rows;
  }

  @override
  Future<int> applyYearLevels(Map<String, int> changes) async {
    applied = changes;
    return changes.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StudentPromotionModel _row(String id, int current, int suggested, {int ungraded = 0, bool finalYear = false}) =>
    StudentPromotionModel(
      userId: id,
      fullName: 'Student $id',
      suggestion: YearLevelSuggestionModel(
        currentYearLevel: current,
        suggestedYearLevel: suggested,
        isFinalYear: finalYear,
        reason: 'r',
        passedUnits: 18,
        totalUnits: 21,
        ungradedSubjects: ungraded,
        failedSubjectCodes: suggested > current ? const [] : const ['IT 101'],
      ),
    );

void main() {
  test('repository calls the list and apply endpoints', () async {
    final calls = <String>[];
    final client = MockClient((req) async {
      calls.add('${req.method} ${req.url.path}?${req.url.query}');
      if (req.method == 'GET') {
        return http.Response(jsonEncode([
          {
            'userId': 'u1',
            'fullName': 'Ana',
            'suggestion': {'currentYearLevel': 1, 'suggestedYearLevel': 2, 'isFinalYear': false, 'reason': 'r', 'passedUnits': 21, 'totalUnits': 21}
          }
        ]), 200);
      }
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['changes'], [
        {'userId': 'u1', 'yearLevel': 2}
      ]);
      return http.Response(jsonEncode({'updated': 1}), 200);
    });
    final repo = PromotionRepository(FakeAuthService(), client: client);

    final rows = await repo.getSuggestions(programId: 1, yearLevel: 1);
    expect(rows.single.suggestion.movesUp, isTrue);
    expect(await repo.applyYearLevels({'u1': 2}), 1);
    expect(calls, [
      'GET /api/studyloads/year-level-suggestions?programId=1&yearLevel=1',
      'POST /api/studyloads/apply-year-levels?',
    ]);
  });

  test('Promotion is opened from the Students page, not the menu', () {
    final items = MainLayoutView.buildNavItems(role: 2, roleName: 'Registrar');
    expect(items.map((i) => i['title']), isNot(contains('Promotion')));
  });

  testWidgets('opened from Students it shows a back arrow that closes it', (tester) async {
    await getIt.reset();
    getIt.registerSingleton<PromotionRepository>(FakePromotionRepo());
    getIt.registerSingleton<AcademicSetupRepository>(FakeSetupRepo());
    var closed = false;
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: PromotionView(onBack: () => closed = true)));
    await tester.pumpAndSettle();

    expect(find.text('End-of-Year Promotion'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('page_back_button')));
    expect(closed, isTrue);
    await getIt.reset();
  });

  group('PromotionView', () {
    late FakePromotionRepo repo;

    setUp(() async {
      await getIt.reset();
      repo = FakePromotionRepo();
      getIt.registerSingleton<PromotionRepository>(repo);
      getIt.registerSingleton<AcademicSetupRepository>(FakeSetupRepo());
    });

    tearDown(() async => getIt.reset());

    Future<void> pumpAndPickProgram(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: PromotionView()));
      await tester.pumpAndSettle();
      expect(find.text('Choose a program to see suggestions.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('promotion_program_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BSIT').last);
      await tester.pumpAndSettle();
    }

    bool? checked(WidgetTester tester, String id) =>
        tester.widget<Checkbox>(find.byKey(ValueKey('promotion_check_$id'))).value;

    testWidgets('pre-ticks students moving up with all grades in; stays cannot be ticked', (tester) async {
      repo.rows = [
        _row('a', 1, 2),
        _row('b', 1, 2, ungraded: 2),
        _row('c', 1, 1),
        _row('d', 4, 4, finalYear: true),
      ];
      await pumpAndPickProgram(tester);

      expect(find.text('Year 1 → Year 2'), findsNWidgets(2));
      expect(find.text('Stay in Year 1'), findsOneWidget);
      expect(find.text('Stay in Year 4 (final year)'), findsOneWidget);
      expect(find.text('2 subject(s) without a final grade'), findsOneWidget);

      expect(checked(tester, 'a'), isTrue);
      expect(checked(tester, 'b'), isFalse);
      expect(tester.widget<Checkbox>(find.byKey(const ValueKey('promotion_check_c'))).onChanged, isNull);
      expect(find.text('Apply to 1 student(s)'), findsOneWidget);
    });

    testWidgets('apply sends only the ticked students after confirming', (tester) async {
      repo.rows = [_row('a', 1, 2), _row('b', 1, 2, ungraded: 1), _row('c', 1, 1)];
      await pumpAndPickProgram(tester);

      await tester.tap(find.byKey(const ValueKey('promotion_check_b')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('apply_promotion_button')));
      await tester.pumpAndSettle();
      expect(repo.applied, isNull, reason: 'nothing is saved before confirming');

      await tester.tap(find.byKey(const ValueKey('confirm_apply_promotion')));
      await tester.pumpAndSettle();

      expect(repo.applied, {'a': 2, 'b': 2});
      expect(find.text('Updated 2 student(s).'), findsOneWidget);
    });

    testWidgets('year filter is passed to the server', (tester) async {
      await pumpAndPickProgram(tester);

      await tester.tap(find.byKey(const ValueKey('promotion_year_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Year 3').last);
      await tester.pumpAndSettle();

      expect(repo.lastYear, 3);
      expect(find.text('No active students found.'), findsOneWidget);
    });
  });
}
