import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/views/widgets/enrollment_period.dart';

AcademicTermModel term({DateTime? opens, DateTime? closes, bool open = false}) => AcademicTermModel(
      termId: 't1',
      schoolYear: '2026-2027',
      semester: 2,
      enrollmentOpensOn: opens,
      enrollmentClosesOn: closes,
      isEnrollmentOpen: open,
    );

void main() {
  test('reads the dates from the API', () {
    final t = AcademicTermModel.fromJson({
      'termID': 't1', 'schoolYear': '2026-2027', 'semester': 2,
      'enrollmentOpensOn': '2026-11-17', 'enrollmentClosesOn': '2026-11-28', 'isEnrollmentOpen': true,
    });
    expect(t.enrollmentOpensOn, DateTime(2026, 11, 17));
    expect(t.enrollmentClosesOn, DateTime(2026, 11, 28));
    expect(t.isEnrollmentOpen, isTrue);
    expect(enrollmentPeriodText(t), 'Nov 17 – Nov 28, 2026');
  });

  test('status: not set, opens soon, open, ended', () {
    final opens = DateTime(2026, 11, 17), closes = DateTime(2026, 11, 28);
    expect(enrollmentPeriodStatus(term(), DateTime(2026, 11, 20)), EnrollmentPeriodStatus.notSet);
    expect(enrollmentPeriodStatus(term(opens: opens, closes: closes), DateTime(2026, 11, 10)), EnrollmentPeriodStatus.upcoming);
    expect(enrollmentPeriodStatus(term(opens: opens, closes: closes, open: true), DateTime(2026, 11, 20)), EnrollmentPeriodStatus.open);
    expect(enrollmentPeriodStatus(term(opens: opens, closes: closes), DateTime(2026, 12, 1)), EnrollmentPeriodStatus.ended);
    expect(enrollmentPeriodText(term()), 'Not set');
  });

  Future<EnrollmentPeriodChoice?> openDialog(WidgetTester tester, AcademicTermModel t, Future<void> Function() act) async {
    EnrollmentPeriodChoice? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showEnrollmentPeriodDialog(context, t),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await act();
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('Save is off until both dates are picked', (tester) async {
    await openDialog(tester, term(), () async {
      final save = tester.widget<FilledButton>(find.byKey(const ValueKey('enrollment_save_button')));
      expect(save.onPressed, isNull);
      expect(find.byKey(const ValueKey('enrollment_close_now_button')), findsNothing);
    });
  });

  testWidgets('existing dates are saved again as they are', (tester) async {
    final opens = DateTime(2026, 11, 17), closes = DateTime(2026, 11, 28);
    final result = await openDialog(tester, term(opens: opens, closes: closes),
        () => tester.tap(find.byKey(const ValueKey('enrollment_save_button'))));
    expect(result?.opensOn, opens);
    expect(result?.closesOn, closes);
  });

  testWidgets('Close enrollment clears both dates', (tester) async {
    final result = await openDialog(tester, term(opens: DateTime(2026, 11, 17), closes: DateTime(2026, 11, 28)),
        () => tester.tap(find.byKey(const ValueKey('enrollment_close_now_button'))));
    expect(result, isNotNull);
    expect(result!.opensOn, isNull);
    expect(result.closesOn, isNull);
  });
}
