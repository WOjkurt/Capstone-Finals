import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/repositories/school_settings_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/views/widgets/unit_limits_tab.dart';

class FakeAuthService implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {'Authorization': 'Bearer t'};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Map<String, dynamic>? sent;
  Map<String, dynamic>? deansSent;

  setUp(() async {
    await getIt.reset();
    sent = null;
    deansSent = null;
    getIt.registerSingleton<SchoolSettingsRepository>(SchoolSettingsRepository(FakeAuthService(), client: MockClient((req) async {
      if (req.url.path.endsWith('/deans-list')) {
        if (req.method == 'PUT') {
          deansSent = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({...deansSent!, 'updatedBy': 'Rita Reg', 'updatedAt': '2026-11-13T01:00:00Z'}), 200);
        }
        return http.Response(jsonEncode({'maxGwa': 1.7, 'worstGrade': 2.3}), 200);
      }
      if (req.method == 'PUT') {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        if (sent!['summerMaxUnits'] == 13) {
          return http.Response(jsonEncode({'message': 'The limit for graduating students cannot be lower than the regular summer limit.'}), 400);
        }
        return http.Response(jsonEncode({...sent!, 'updatedBy': 'Rita Reg', 'updatedAt': '2026-11-06T01:00:00Z'}), 200);
      }
      return http.Response(jsonEncode({'summerMaxUnits': 9, 'graduatingSummerMaxUnits': 12}), 200);
    })));
  });

  tearDown(() async => getIt.reset());

  testWidgets('shows the starting values, saves new ones, and shows server refusals', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: UnitLimitsTab())));
    await tester.pumpAndSettle();

    String field(String key) => tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;
    expect((field('summer_limit_field'), field('graduating_limit_field')), ('9', '12'));
    expect(find.text('Using the starting values.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('summer_limit_field')), '6');
    await tester.enterText(find.byKey(const ValueKey('graduating_limit_field')), '10.5');
    await tester.tap(find.byKey(const ValueKey('save_unit_limits_button')));
    await tester.pumpAndSettle();
    expect(sent, {'summerMaxUnits': 6, 'graduatingSummerMaxUnits': 10.5});
    expect(find.textContaining('by Rita Reg'), findsOneWidget);
    expect(find.textContaining('Unit limits saved'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('summer_limit_field')), '13');
    await tester.tap(find.byKey(const ValueKey('save_unit_limits_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('cannot be lower'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('summer_limit_field')), 'abc');
    await tester.tap(find.byKey(const ValueKey('save_unit_limits_button')));
    await tester.pumpAndSettle();
    expect(find.text('Enter both limits as numbers.'), findsOneWidget);
  });

  testWidgets('Dean\'s list rules: DBTC\'s by default, and the Registrar can save new ones', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: UnitLimitsTab())));
    await tester.pumpAndSettle();

    String field(String key) => tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;
    expect((field('deans_rule_gwa'), field('deans_rule_worst')), ('1.7', '2.3'));
    expect(find.textContaining('Using DBTC\'s rules'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('deans_rule_gwa')), '1.75');
    await tester.enterText(find.byKey(const ValueKey('deans_rule_worst')), '2.5');
    await tester.tap(find.byKey(const ValueKey('save_deans_rules_button')));
    await tester.pumpAndSettle();
    expect(deansSent, {'maxGwa': 1.75, 'worstGrade': 2.5});
    expect(find.textContaining('Dean\'s list rules saved'), findsOneWidget);
    expect(find.byKey(const ValueKey('deans_rules_status')), findsOneWidget);
    expect(sent, isNull);   // the summer limits are untouched
  });
}
