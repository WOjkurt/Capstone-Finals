import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/models/grading_models.dart';
import 'package:sis_registrar_app/utils/error_handler.dart';
import 'package:sis_registrar_app/views/widgets/edit_student_id_dialog.dart';

void main() {
  test('student ID rule matches the API', () {
    expect(studentIdProblem('25060208'), isNull);
    expect(studentIdProblem('2506 0208'), isNull);
    expect(studentIdProblem(''), isNull); // empty clears it
    expect(studentIdProblem('2.5060208E7'), 'Use digits only, e.g. 25060208.');
    expect(studentIdProblem('123'), 'A student ID has 4 to 15 digits.');
  });

  test('UserSearchResultModel reads studentId', () {
    final m = UserSearchResultModel.fromJson({'userId': 'u', 'fullName': 'Ana Cruz', 'studentID': '25060208'});
    expect(m.studentId, '25060208');
    expect(m.copyWith(firstname: 'Bea').studentId, '25060208');
  });

  Future<List<String?>> open(WidgetTester tester, Future<String?> Function(String, String?) save, {String? current}) async {
    final results = <String?>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(await showDialog<String>(
              context: context,
              builder: (_) => EditStudentIdDialog(userId: 'u1', studentName: 'Ana Cruz', current: current, save: save),
            )),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('saves the cleaned number', (tester) async {
    final sent = <String?>[];
    final results = await open(tester, (id, n) async {
      sent.add(n);
      return n;
    });
    await tester.enterText(find.byKey(const ValueKey('student_id_field')), ' 2506-0208 ');
    await tester.tap(find.byKey(const ValueKey('save_student_id')));
    await tester.pumpAndSettle();

    expect(sent, ['25060208']);
    expect(results, ['25060208']);
  });

  testWidgets('a bad number is caught before saving; a taken number shows the server message', (tester) async {
    var calls = 0;
    await open(tester, (id, n) async {
      calls++;
      throw ApiException(statusCode: 409, message: 'Student ID 25060208 already belongs to Ben Cruz.');
    });

    await tester.enterText(find.byKey(const ValueKey('student_id_field')), '12A');
    await tester.tap(find.byKey(const ValueKey('save_student_id')));
    await tester.pumpAndSettle();
    expect(find.text('Use digits only, e.g. 25060208.'), findsOneWidget);
    expect(calls, 0);

    await tester.enterText(find.byKey(const ValueKey('student_id_field')), '25060208');
    await tester.tap(find.byKey(const ValueKey('save_student_id')));
    await tester.pumpAndSettle();
    expect(find.text('Student ID 25060208 already belongs to Ben Cruz.'), findsOneWidget);
  });

  testWidgets('clearing returns an empty string', (tester) async {
    final results = await open(tester, (id, n) async => n, current: '25060208');
    await tester.enterText(find.byKey(const ValueKey('student_id_field')), '');
    await tester.tap(find.byKey(const ValueKey('save_student_id')));
    await tester.pumpAndSettle();
    expect(results, ['']);
  });
}
