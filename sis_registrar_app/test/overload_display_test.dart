import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/models/class_models.dart';
import 'package:sis_registrar_app/views/widgets/overload_badge.dart';

void main() {
  test('pending summary parses overload fields', () {
    final m = PendingStudyLoadSummaryModel.fromJson({
      'userId': 'u1',
      'fullName': 'Ana Cruz',
      'pendingCount': 8,
      'pendingUnits': 24,
      'termUnits': 24,
      'maxUnits': 21,
      'isOverloaded': true,
      'overloadReason': 'catching up',
      'overloadApprovedBy': 'Carla Head',
    });
    expect(m.isOverloaded, isTrue);
    expect(m.maxUnits, 21);
    expect(m.overloadApprovedBy, 'Carla Head');
  });

  test('unit limit knows when it is overloaded', () {
    expect(UnitLimitModel.fromJson({'maxUnits': 21, 'currentUnits': 24}).isOverloaded, isTrue);
    expect(UnitLimitModel.fromJson({'maxUnits': 21, 'currentUnits': 21}).isOverloaded, isFalse);
  });

  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: child))));

  testWidgets('badge shows units; banner names the approver and reason', (tester) async {
    await pump(tester, const Column(children: [
      OverloadBadge(termUnits: 24, maxUnits: 21, approvedBy: 'Carla Head', reason: 'catching up'),
      SizedBox(width: 600, child: OverloadBanner(termUnits: 24, maxUnits: 21, approvedBy: 'Carla Head', reason: 'catching up')),
    ]));

    expect(find.text('Overload 24/21'), findsOneWidget);
    expect(find.textContaining('Approved by Carla Head — "catching up"'), findsOneWidget);
  });

  testWidgets('banner says when no approval is recorded', (tester) async {
    await pump(tester, const SizedBox(width: 600, child: OverloadBanner(termUnits: 24.5, maxUnits: 21)));

    expect(find.textContaining('24.5 of 21 units. No approval is recorded.'), findsOneWidget);
  });
}
