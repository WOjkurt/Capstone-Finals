import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/repositories/accredited_school_repository.dart';
import 'package:sis_registrar_app/repositories/enrollment_repository.dart';
import 'package:sis_registrar_app/repositories/report_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/utils/study_load_pdf.dart';
import 'package:sis_registrar_app/views/reports_view.dart';
import 'package:sis_registrar_app/views/widgets/accredited_schools_tab.dart';

class FakeAuthService implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {'Authorization': 'Bearer t'};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSetupRepo implements AcademicSetupRepository {
  @override
  Future<List<AcademicTermModel>> getTerms() async =>
      [AcademicTermModel.fromJson({'termID': 't1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true})];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late List<String> calls;
  late List<Map<String, dynamic>> schools;

  setUp(() async {
    await getIt.reset();
    calls = [];
    schools = [
      {'schoolId': 's1', 'name': 'Cebu Normal University', 'address': 'Cebu City', 'creditCount': 2},
    ];
    final client = MockClient((req) async {
      final path = req.url.path;
      calls.add('${req.method} $path${req.body.isEmpty ? '' : ' ${req.body}'}');
      if (path.endsWith('/api/accredited-schools/unlisted')) {
        return http.Response(jsonEncode([{'name': 'Old School A', 'creditCount': 3}]), 200);
      }
      if (path.endsWith('/api/accredited-schools') && req.method == 'POST') {
        final b = jsonDecode(req.body) as Map<String, dynamic>;
        if ((b['name'] as String).toLowerCase() == 'cebu normal university') {
          return http.Response(jsonEncode({'message': '"Cebu Normal University" is already on the list.'}), 400);
        }
        final s = {'schoolId': 's${schools.length + 1}', 'name': b['name'], 'address': b['address'], 'creditCount': 0};
        schools.add(s);
        return http.Response(jsonEncode(s), 200);
      }
      if (req.method == 'DELETE') {
        schools.removeWhere((s) => path.endsWith('/${s['schoolId']}'));
        return http.Response('', 204);
      }
      if (path.endsWith('/api/accredited-schools')) return http.Response(jsonEncode(schools), 200);
      if (path.endsWith('/api/reports/transferees')) {
        return http.Response(
            jsonEncode([
              {'userId': 'u1', 'studentName': 'Ana Cruz', 'lrn': '1234', 'programCode': 'BSIT', 'yearLevel': 2,
               'previousSchools': ['CTU', 'USC'], 'creditedSubjects': 3, 'creditedUnits': 8, 'creditedCodes': ['GEC 101', 'IT 101']},
              {'userId': 'u2', 'studentName': 'Ben Lim', 'programCode': 'BSME', 'yearLevel': 1, 'previousSchools': [], 'creditedSubjects': 0, 'creditedUnits': 0, 'creditedCodes': []},
            ]),
            200);
      }
      return http.Response('[]', 200);
    });
    final auth = FakeAuthService();
    getIt.registerSingleton<AuthService>(auth);
    getIt.registerSingleton<AccreditedSchoolRepository>(AccreditedSchoolRepository(auth, client: client));
    getIt.registerSingleton<ReportRepository>(ReportRepository(auth, client: client));
    getIt.registerSingleton<AcademicSetupRepository>(FakeSetupRepo());
  });

  tearDown(() async => getIt.reset());

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pumpAndSettle();
  }

  testWidgets('lists schools with credit counts; unlisted names from credits can be added in one click', (tester) async {
    await pump(tester, const AccreditedSchoolsTab());

    expect(find.text('Cebu Normal University'), findsOneWidget);
    expect(find.text('Cebu City · 2 credit(s)'), findsOneWidget);
    expect(find.text('Old School A (3)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add_unlisted_Old School A')));
    await tester.pumpAndSettle();
    expect(calls, contains('POST /api/accredited-schools {"name":"Old School A","address":null}'));
    expect(find.text('Added Old School A.'), findsOneWidget);
    expect(find.byKey(const ValueKey('school_row_Old School A')), findsOneWidget);
  });

  testWidgets('add school: name is required; a duplicate shows the server message; remove asks first', (tester) async {
    await pump(tester, const AccreditedSchoolsTab());

    await tester.tap(find.byKey(const ValueKey('add_school_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save_school_button')));
    await tester.pumpAndSettle();
    expect(find.text('Enter the school\'s name.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('school_name_field')), 'cebu normal university');
    await tester.tap(find.byKey(const ValueKey('save_school_button')));
    await tester.pumpAndSettle();
    expect(find.text('"Cebu Normal University" is already on the list.'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    expect(find.textContaining('keep this school name'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm_remove_school')));
    await tester.pumpAndSettle();
    expect(calls.any((c) => c.startsWith('DELETE /api/accredited-schools/s1')), isTrue);
    expect(find.textContaining('No schools yet'), findsOneWidget);
  });

  testWidgets('Reports → Transferees lists them and prints', (tester) async {
    final printed = <String>[];
    final original = printPdf;
    printPdf = (bytes, name) async => printed.add(name);
    addTearDown(() => printPdf = original);
    await pump(tester, const ReportsView(tab: null));

    await tester.tap(find.text('Transferees'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Cruz'), findsOneWidget);
    expect(find.text('CTU; USC'), findsOneWidget);
    expect(find.text('Not recorded'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('print_transferees_button')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pumpAndSettle();
    expect(printed, ['Transferees.pdf']);
  });
}
