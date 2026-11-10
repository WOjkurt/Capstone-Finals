import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_registrar_app/models/records_import_models.dart';
import 'package:sis_registrar_app/repositories/records_import_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/utils/file_pick.dart';
import 'package:sis_registrar_app/views/widgets/credits_import_dialog.dart';
import 'package:sis_registrar_app/views/widgets/forms_import_dialog.dart';

class _FakeAuth implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {'Authorization': 'Bearer t', 'Content-Type': 'application/json'};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('CreditsImportResult reads the preview', () {
    final r = CreditsImportResult.fromJson({
      'credits': 2,
      'students': 1,
      'alreadyCredited': 3,
      'rows': [
        {'studentId': '25060208', 'studentName': 'Cruz, Ana', 'subjectCode': 'GEC 102', 'creditedUnits': 2, 'units': 3, 'sourceSchool': 'UC', 'kind': 1}
      ],
      'problems': [
        {'file': 'Credits', 'sheet': 'Sheet1', 'row': 4, 'message': 'No Student ID.'}
      ],
      'totalProblems': 1,
    });
    expect(r.credits, 2);
    expect(r.alreadyCredited, 3);
    expect(r.rows.single.isPartial, isTrue);
    expect(r.problems.single.label, 'Credits › Sheet1, row 4: No Student ID.');
  });

  testWidgets('choose a file → preview → import', (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final calls = <String>[];
    final names = <String>[];
    final repo = RecordsImportRepository(_FakeAuth(), client: MockClient.streaming((request, body) async {
      final raw = utf8.decode(await body.toBytes(), allowMalformed: true);
      calls.add(RegExp(r'name="dryRun"\r\n\r\n([^\r]*)').firstMatch(raw)!.group(1)!);
      names.add(RegExp(r'filename="([^"]+)"').firstMatch(raw)!.group(1)!);
      expect(request.url.path, '/api/import/credits');
      final result = {
        'dryRun': calls.last == 'true',
        'credits': 1,
        'students': 1,
        'alreadyCredited': 0,
        'rows': [
          {'studentId': '25060208', 'studentName': 'Cruz, Ana', 'subjectCode': 'GEC 102', 'creditedUnits': 3, 'units': 3,
           'sourceSchool': 'University of Cebu', 'grade': '1.5', 'kind': 1}
        ],
        'problems': [
          {'file': 'Credits', 'sheet': 'Sheet1', 'row': 3, 'message': 'No student with Student ID 99999999 in the system.'}
        ],
        'totalProblems': 1,
      };
      return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(result))), 200);
    }));
    pickFile = ({String accept = ''}) async => PickedFile('credits.csv', Uint8List.fromList([1]));
    addTearDown(() => pickFile = ({String accept = ''}) async => null);

    bool? closed;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                closed = await showDialog<bool>(context: context, builder: (_) => CreditsImportDialog(repository: repo)),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('run_credits_import'))).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('choose_credits_file')));
    await tester.pumpAndSettle();
    expect(calls, ['true']);
    expect(names, ['credits.csv']);
    expect(find.text('1 subject(s) to credit for 1 student(s)'), findsOneWidget);
    expect(find.text('Cruz, Ana (25060208)'), findsOneWidget);
    expect(find.textContaining('row 3: No student with Student ID 99999999'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('run_credits_import')));
    await tester.pumpAndSettle();
    expect(calls, ['true', 'false']);
    expect(closed, isTrue);
    expect(find.text('Credited 1 subject(s) for 1 student(s).'), findsOneWidget);
  });

  testWidgets('enrollment forms: preview lists matched students, then import', (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final dry = <String>[];
    final repo = RecordsImportRepository(_FakeAuth(), client: MockClient.streaming((request, body) async {
      final raw = utf8.decode(await body.toBytes(), allowMalformed: true);
      dry.add(RegExp(r'name="dryRun"\r\n\r\n([^\r]*)').firstMatch(raw)!.group(1)!);
      expect(request.url.path, '/api/import/enrollment-forms');
      final result = {
        'forms': 1,
        'notInSystem': 1,
        'olderAnswersSkipped': 1,
        'rows': [
          {'row': 2, 'studentId': '23017245', 'studentName': 'Rizal, Kurt', 'matchedBy': 'school email', 'contacts': 2}
        ],
        'problems': [
          {'file': 'Form responses', 'sheet': 'Form Responses 1', 'row': 3, 'message': 'Carlo Lim is not in the system.'}
        ],
        'totalProblems': 1,
      };
      return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(result))), 200);
    }));
    pickFile = ({String accept = ''}) async => PickedFile('Responses.xlsx', Uint8List.fromList([1]));
    addTearDown(() => pickFile = ({String accept = ''}) async => null);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FormsImportDialog(repository: repo))));
    await tester.tap(find.byKey(const ValueKey('choose_forms_file')));
    await tester.pumpAndSettle();
    expect(dry, ['true']);
    expect(find.text('1 student(s) get their enrollment form'), findsOneWidget);
    expect(find.text('• Rizal, Kurt (23017245) — matched by school email, 2 parent/guardian'), findsOneWidget);
    expect(find.textContaining('only each student\'s newest answer is kept'), findsOneWidget);
    expect(find.textContaining('row 3: Carlo Lim is not in the system.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('run_forms_import')));
    await tester.pumpAndSettle();
    expect(dry, ['true', 'false']);
  });
}
