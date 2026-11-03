import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/models/grading_models.dart';
import 'package:sis_registrar_app/repositories/grading_repository.dart';
import 'package:sis_registrar_app/views/widgets/edit_year_level_dialog.dart';

class FakeUserSearchRepository implements UserSearchRepository {
  YearLevelSuggestionModel? suggestion;
  int? savedYearLevel;

  @override
  Future<YearLevelSuggestionModel> getYearLevelSuggestion(String userId) async {
    if (suggestion == null) throw Exception('offline');
    return suggestion!;
  }

  @override
  Future<void> updateStudentYearLevel(String userId, int yearLevel) async {
    savedYearLevel = yearLevel;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeUserSearchRepository repo;

  setUp(() async {
    await getIt.reset();
    repo = FakeUserSearchRepository();
    getIt.registerSingleton<UserSearchRepository>(repo);
  });

  tearDown(() async => getIt.reset());

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: EditYearLevelDialog(
            userId: 'u1', studentName: 'Ana Cruz', currentYearLevel: 1),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows a move-up suggestion; Use fills the field, then Save sends it',
      (tester) async {
    repo.suggestion = const YearLevelSuggestionModel(
      currentYearLevel: 1,
      suggestedYearLevel: 2,
      isFinalYear: false,
      reason: 'Passed 9 of 12 units (75%) of Year 1 subjects; 75% is needed to move up.',
      failedSubjectCodes: ['THEO 101'],
    );
    await pumpDialog(tester);

    expect(find.text('Suggested: move up to Year 2'), findsOneWidget);
    expect(find.textContaining('Passed 9 of 12 units'), findsOneWidget);
    expect(find.text('Failed: THEO 101'), findsOneWidget);
    // Nothing changes until the Registrar acts.
    expect(tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text, '1');

    await tester.tap(find.byKey(const ValueKey('use_suggestion_button')));
    await tester.pump();
    expect(tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text, '2');

    await tester.tap(find.text('Save Year Level'));
    await tester.pumpAndSettle();
    expect(repo.savedYearLevel, 2);
  });

  testWidgets('shows a stay suggestion', (tester) async {
    repo.suggestion = const YearLevelSuggestionModel(
      currentYearLevel: 1,
      suggestedYearLevel: 1,
      isFinalYear: false,
      reason: 'Passed 6 of 12 units (50%).',
    );
    await pumpDialog(tester);

    expect(find.text('Suggested: stay in Year 1'), findsOneWidget);
  });

  testWidgets('Registrar can still save another year level', (tester) async {
    repo.suggestion = const YearLevelSuggestionModel(
      currentYearLevel: 1,
      suggestedYearLevel: 1,
      isFinalYear: false,
      reason: 'Passed 6 of 12 units (50%).',
    );
    await pumpDialog(tester);

    await tester.enterText(find.byType(TextFormField), '2');
    await tester.tap(find.text('Save Year Level'));
    await tester.pumpAndSettle();

    expect(repo.savedYearLevel, 2);
  });

  testWidgets('if the suggestion fails to load, the dialog still works', (tester) async {
    await pumpDialog(tester);

    expect(find.byKey(const ValueKey('year_level_suggestion')), findsNothing);
    expect(find.text('Save Year Level'), findsOneWidget);
  });
}
