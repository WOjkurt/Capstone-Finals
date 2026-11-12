import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/models/grading_models.dart';
import 'package:sis_registrar_app/models/record_models.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/views/records_check_view.dart';

RecordsCheck _data() => RecordsCheck.fromJson({
      'activeStudents': 5,
      'counts': [
        {'key': 'no-email', 'label': 'No school email (can\'t sign in)', 'count': 1},
        {'key': 'no-student-id', 'label': 'No Student ID', 'count': 1},
        {'key': 'no-program', 'label': 'No program', 'count': 0},
        {'key': 'transcript', 'label': 'Missing transcript details', 'count': 2},
        {'key': 'not-signed-in', 'label': 'Email set, not signed in yet', 'count': 1},
      ],
      'rows': [
        {'userId': 'u-lim', 'firstname': 'Cara', 'lastname': 'Lim', 'email': 'cara@dbtc-cebu.edu.ph', 'studentId': '25060210',
         'programId': 2, 'programCode': 'BSME', 'yearLevel': 1, 'hasSignedIn': false, 'role': 5,
         'issues': ['transcript', 'not-signed-in'], 'missing': ['Place of birth']},
        {'userId': 'u-reyes', 'firstname': 'Ben', 'lastname': 'Reyes', 'email': '', 'studentId': null,
         'programId': 1, 'programCode': 'BSIT', 'yearLevel': 1, 'hasSignedIn': false, 'role': 5,
         'issues': ['no-email', 'no-student-id', 'transcript'], 'missing': ['Address', 'Sex']},
      ],
    });

void main() {
  testWidgets('lists students with what they need; chips filter; a click opens the student', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final asked = <int?>[];
    UserSearchResultModel? opened;
    await tester.pumpWidget(MaterialApp(
      home: RecordsCheckView(
        load: (id) async {
          asked.add(id);
          return _data();
        },
        loadPrograms: () async => const [AcademicProgramModel(programId: 1, programCode: 'BSIT', programName: 'BS IT')],
        onOpen: (s) => opened = s,
      ),
    ));
    await tester.pumpAndSettle();

    expect(asked, [null]);
    expect(find.text('2 of 5 active student(s) need something'), findsOneWidget);
    expect(find.text('Lim, Cara'), findsOneWidget);
    expect(find.text('Reyes, Ben'), findsOneWidget);
    expect(find.text('No ID · BSIT · Year 1'), findsOneWidget);
    expect(find.text('Transcript: Address, Sex'), findsOneWidget);
    expect(find.byKey(const ValueKey('issue_no-program')), findsNothing);   // nothing to show

    await tester.tap(find.byKey(const ValueKey('issue_no-email')));
    await tester.pumpAndSettle();
    expect(find.text('Lim, Cara'), findsNothing);
    expect(find.text('Reyes, Ben'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('issue_all')));
    await tester.enterText(find.byKey(const ValueKey('check_search')), '25060210');
    await tester.pumpAndSettle();
    expect(find.text('Reyes, Ben'), findsNothing);

    await tester.tap(find.text('Lim, Cara'));
    expect(opened?.userId, 'u-lim');
    expect(opened?.studentId, '25060210');
    expect(opened?.hasSignedIn, isFalse);

    await tester.tap(find.byKey(const ValueKey('check_program_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BSIT').last);
    await tester.pumpAndSettle();
    expect(asked, [null, 1]);
  });

  testWidgets('everyone complete shows a calm message', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RecordsCheckView(load: (_) async => const RecordsCheck(activeStudents: 3), loadPrograms: () async => const []),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('check_all_done')), findsOneWidget);
  });
}
