import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/repositories/class_repository.dart';
import 'package:sis_registrar_app/repositories/enrollment_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/views/pending_loads_view.dart';

class FakeAuthService implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {'Authorization': 'Bearer t'};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late List<String> finalized;
  late List<Map<String, dynamic>> pending;

  Future<http.Response> api(http.Request req) async {
    final path = req.url.path;
    if (path.endsWith('/api/AcademicTerms')) {
      return http.Response(jsonEncode([
        {'termID': 't1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}
      ]), 200);
    }
    if (path.endsWith('/api/studyloads/pending-summary')) {
      return http.Response(jsonEncode(pending), 200);
    }
    if (path.endsWith('/api/studyloads/finalize')) {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      if (body['userId'] == 'u2') {
        return http.Response(jsonEncode({'message': 'Prerequisite not met: IT 101'}), 400);
      }
      finalized.add('${body['userId']}:${body['termId']}');
      pending.removeWhere((p) => p['userId'] == body['userId']);
      return http.Response(jsonEncode({'success': true, 'finalizedLoads': []}), 200);
    }
    return http.Response('[]', 200);
  }

  setUp(() async {
    await getIt.reset();
    finalized = [];
    pending = [
      {'userId': 'u1', 'fullName': 'Ana Cruz', 'programCode': 'BSIT', 'yearLevel': 1, 'pendingCount': 6, 'pendingUnits': 18},
      {'userId': 'u2', 'fullName': 'Ben Santos', 'programCode': 'BSME', 'yearLevel': 1, 'pendingCount': 6, 'pendingUnits': 18},
      {
        'userId': 'u3', 'fullName': 'Cara Lim', 'programCode': 'BSIT', 'yearLevel': 1, 'pendingCount': 9, 'pendingUnits': 27,
        'termUnits': 27, 'maxUnits': 21, 'isOverloaded': true // no approval recorded
      },
    ];
    getIt.registerSingleton<AuthService>(FakeAuthService());
    getIt.registerSingleton<AcademicSetupRepository>(AcademicSetupRepository(getIt<AuthService>()));
    getIt.registerSingleton<ClassRepository>(ClassRepository(getIt<AuthService>(), MockClient(api)));
  });

  tearDown(() async => getIt.reset());

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: PendingLoadsView()));
    await tester.pumpAndSettle();
  }

  // Checkbox 0 is the table's "select all"; rows follow in order.
  Checkbox rowBox(WidgetTester tester, int row) => tester.widgetList<Checkbox>(find.byType(Checkbox)).elementAt(row + 1);

  testWidgets('finalizes the ticked students, reports failures, and skips unapproved overloads', (tester) async {
    await http.runWithClient(() async {
      await pump(tester);

      expect(find.text('Finalize selected (0)'), findsOneWidget);
      expect(rowBox(tester, 2).onChanged, isNull, reason: 'overloaded with no approval must be reviewed alone');

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.tap(find.byType(Checkbox).at(2));
      await tester.pump();
      expect(find.text('Finalize selected (2)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('finalize_selected_button')));
      await tester.pumpAndSettle();
      expect(finalized, isEmpty, reason: 'nothing happens before confirming');

      await tester.tap(find.byKey(const ValueKey('confirm_finalize_selected')));
      await tester.pumpAndSettle();

      expect(finalized, ['u1:t1']);
      expect(find.text('Finalized 1 of 2'), findsOneWidget);
      expect(find.textContaining('Ben Santos: Prerequisite not met: IT 101'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      // The list reloads without the finalized student, and the selection is cleared.
      expect(find.text('Ana Cruz'), findsNothing);
      expect(find.text('Finalize selected (0)'), findsOneWidget);
    }, () => MockClient(api));
  });

  testWidgets('select all in the header ticks only students that can be finalized together', (tester) async {
    await http.runWithClient(() async {
      await pump(tester);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      expect(find.text('Finalize selected (2)'), findsOneWidget);
    }, () => MockClient(api));
  });
}
