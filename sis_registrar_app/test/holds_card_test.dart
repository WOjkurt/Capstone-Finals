import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/models/hold_models.dart';
import 'package:sis_registrar_app/repositories/hold_repository.dart';
import 'package:sis_registrar_app/views/widgets/holds_card.dart';

class FakeHoldRepository implements HoldRepository {
  final holds = <EnrollmentHold>[];
  final calls = <String>[];

  @override
  Future<List<EnrollmentHold>> forStudent(String userId) async => List.of(holds);

  @override
  Future<EnrollmentHold> add(String userId, {required String reason, String? note}) async {
    calls.add('add $reason ${note ?? '-'}');
    final h = EnrollmentHold(
        holdId: 'h${holds.length + 1}',
        reason: reason,
        reasonLabel: reason == EnrollmentHoldReasons.unpaidBalance ? 'Unpaid balance' : 'Other',
        note: note,
        addedByName: 'Rita Reg',
        isOpen: true);
    holds.add(h);
    return h;
  }

  @override
  Future<EnrollmentHold> remove(String holdId, {String? note}) async {
    calls.add('remove $holdId ${note ?? '-'}');
    final i = holds.indexWhere((h) => h.holdId == holdId);
    final h = holds[i];
    holds[i] = EnrollmentHold(
        holdId: h.holdId, reason: h.reason, reasonLabel: h.reasonLabel, note: h.note, removalNote: note, isOpen: false);
    return holds[i];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> pumpCard(WidgetTester tester, FakeHoldRepository repo) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: HoldsCard(userId: 's1', repository: repo))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no holds says the student can enroll', (tester) async {
    await pumpCard(tester, FakeHoldRepository());
    expect(find.text('No holds. This student can enroll online.'), findsOneWidget);
  });

  testWidgets('add an unpaid balance hold, then remove it with a note', (tester) async {
    final repo = FakeHoldRepository();
    await pumpCard(tester, repo);

    await tester.tap(find.byKey(const ValueKey('add_hold_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('hold_note_field')), 'Balance of P2,500');
    await tester.tap(find.byKey(const ValueKey('save_hold_button')));
    await tester.pumpAndSettle();

    expect(repo.calls, ['add UnpaidBalance Balance of P2,500']);
    expect(find.text('On hold: cannot enroll online'), findsOneWidget);
    expect(find.text('Unpaid balance: Balance of P2,500'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('remove_hold_h1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Paid, OR #12345');
    await tester.tap(find.text('Remove hold'));
    await tester.pumpAndSettle();

    expect(repo.calls.last, 'remove h1 Paid, OR #12345');
    expect(find.text('No holds. This student can enroll online.'), findsOneWidget);
    expect(find.text('Show removed holds (1)'), findsOneWidget);
  });

  testWidgets('Other needs a note', (tester) async {
    final repo = FakeHoldRepository();
    await pumpCard(tester, repo);

    await tester.tap(find.byKey(const ValueKey('add_hold_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hold_reason_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save_hold_button')));
    await tester.pumpAndSettle();

    expect(find.text('Write what the hold is for.'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });
}
