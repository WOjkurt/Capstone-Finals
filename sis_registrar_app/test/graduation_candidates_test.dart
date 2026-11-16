import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/models/record_models.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/utils/file_download.dart';
import 'package:sis_registrar_app/views/widgets/graduation_candidates_report.dart';

GraduationCandidates _data() => GraduationCandidates.fromJson({
      'complete': 1,
      'finishingThisTerm': 1,
      'lacking': 1,
      'rows': [
        {'userId': 'u1', 'firstname': 'Ana', 'lastname': 'Cruz', 'studentId': '22060001', 'programCode': 'BSIT', 'yearLevel': 4,
         'status': 'Complete', 'totalUnits': 150, 'earnedUnits': 150},
        {'userId': 'u2', 'firstname': 'Cara', 'lastname': 'Lim', 'studentId': '22060002', 'programCode': 'BSIT', 'yearLevel': 4,
         'status': 'Lacking', 'totalUnits': 150, 'earnedUnits': 141,
         'inProgress': [{'subjectCode': 'CAP 402', 'subjectTitle': 'Capstone 2', 'units': 3, 'yearLevel': 4, 'status': 'InProgress'}],
         'lackingSubjects': [
           {'subjectCode': 'IT 301', 'subjectTitle': 'Networks', 'units': 3, 'yearLevel': 3, 'status': 'Failed'},
           {'subjectCode': 'OJT 401', 'subjectTitle': 'Practicum', 'units': 6, 'yearLevel': 4, 'status': 'NotTaken'},
         ]},
        {'userId': 'u3', 'firstname': 'Ben', 'lastname': 'Reyes', 'studentId': '22060003', 'programCode': 'BSIT', 'yearLevel': 4,
         'status': 'FinishingThisTerm', 'totalUnits': 150, 'earnedUnits': 144,
         'inProgress': [{'subjectCode': 'CAP 402', 'subjectTitle': 'Capstone 2', 'units': 3, 'yearLevel': 4, 'status': 'InProgress'}]},
      ],
    });

void main() {
  testWidgets('lists final-year students by status; opening one shows what they still need; CSV has every column', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final asked = <int?>[];
    final downloads = <String>[];
    final original = downloadFile;
    downloadFile = (bytes, name, type) => downloads.add('$name:${String.fromCharCodes(bytes)}');
    addTearDown(() => downloadFile = original);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GraduationCandidatesReport(
          load: (id) async {
            asked.add(id);
            return _data();
          },
          loadPrograms: () async => const [AcademicProgramModel(programId: 1, programCode: 'BSIT', programName: 'BS IT')],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(asked, [null]);
    expect(find.text('Complete (1)'), findsOneWidget);
    expect(find.text('Finishing this term'), findsOneWidget);
    expect(find.text('Lacking subjects'), findsOneWidget);
    expect(find.textContaining('141 of 150 units earned'), findsOneWidget);

    await tester.tap(find.text('Lim, Cara'));
    await tester.pumpAndSettle();
    // One table of open subjects, grouped by year and semester, each with its status.
    Finder inRow(String code, String text) =>
        find.descendant(of: find.byKey(ValueKey('grad_subject_$code')), matching: find.text(text));
    expect(inRow('IT 301', 'Networks'), findsOneWidget);
    expect(inRow('IT 301', 'Failed'), findsOneWidget);
    expect(inRow('OJT 401', 'Not taken'), findsOneWidget);
    expect(inRow('OJT 401', '6'), findsOneWidget);
    expect(inRow('CAP 402', 'Taking now'), findsOneWidget);
    expect(find.textContaining('Year 3 · '), findsOneWidget);
    expect(find.text('STILL NEEDS'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('grad_Lacking')));
    await tester.pumpAndSettle();
    expect(find.text('Cruz, Ana'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('graduation_csv')));
    expect(downloads.single, startsWith('Graduation_Candidates.csv:'));
    expect(downloads.single, contains('IT 301 (failed), OJT 401 (not taken)'));
    expect(downloads.single, isNot(contains('Cruz')));
  });
}
