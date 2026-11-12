import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/models/grading_models.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/utils/certificate_pdf.dart';
import 'package:sis_registrar_app/utils/study_load_pdf.dart' show printPdf;
import 'package:sis_registrar_app/views/widgets/record_print_dialogs.dart';

StudentGradeModel _g(String code, double units, String sy, int sem, {double? fg, int? remarks, int load = 1}) => StudentGradeModel(
    gradeId: code + sy + '$sem', subjectCode: code, subjectTitle: '$code title', units: units, finalGrade: fg, remarks: remarks,
    schoolYear: sy, semester: sem, loadStatus: load);

final _grades = [
  _g('IT 211', 3, '2026-2027', 1),
  _g('IT 212', 3, '2026-2027', 1),
  _g('NSTP 02', 3, '2026-2027', 1, load: 2),   // dropped: not counted in units
  _g('IT 111', 3, '2025-2026', 2, fg: 1.5, remarks: 1),
  _g('IT 112', 2, '2025-2026', 2, fg: 5.0, remarks: 2),
  _g('PE 102', 2, '2025-2026', 2, fg: 1.0, remarks: 1),
];

CertificateData _data(CertificateKind kind, String sy, int sem, {int? year, String purpose = ''}) => CertificateData(
      kind: kind,
      studentName: 'Juan Dela Cruz',
      studentId: '25060208',
      program: 'Bachelor of Science in Information Technology',
      yearLevel: year,
      schoolYear: sy,
      semester: sem,
      subjects: _grades.where((g) => g.schoolYear == sy && g.semester == sem).toList(),
      purpose: purpose,
      issuedOn: DateTime(2026, 11, 12),
    );

void main() {
  test('enrollment text: name, ID, year, program, term and enrolled units only', () {
    expect(
      certificateBody(_data(CertificateKind.enrollment, '2026-2027', 1, year: 2)),
      'This is to certify that JUAN DELA CRUZ, Student ID 25060208, is officially enrolled as a second year student of '
      'Bachelor of Science in Information Technology in the First Semester of School Year 2026-2027, carrying 6 units '
      'in the subjects listed below.',
    );
  });

  test('grades text has no year level for an older term; closing has the purpose and the date', () {
    final d = _data(CertificateKind.grades, '2025-2026', 2, purpose: 'Scholarship application.');
    expect(certificateBody(d),
        'This is to certify that JUAN DELA CRUZ, Student ID 25060208, a student of Bachelor of Science in Information Technology, '
        'obtained the following final grades in the Second Semester of School Year 2025-2026.');
    expect(certificateClosing(d),
        'This certification is issued upon the request of the above-named student for Scholarship application. '
        'Issued this 12th day of November 2026 at Don Bosco Technical College - Cebu, Cebu City, Philippines.');
    expect(issuedDay(DateTime(2026, 3, 1)), '1st day of March 2026');
    expect(issuedDay(DateTime(2026, 3, 13)), '13th day of March 2026');
    expect(issuedDay(DateTime(2026, 3, 22)), '22nd day of March 2026');
  });

  test('both certificates build a PDF', () async {
    for (final d in [_data(CertificateKind.enrollment, '2026-2027', 1, year: 2), _data(CertificateKind.grades, '2025-2026', 2)]) {
      final bytes = await buildCertificatePdf(d, compress: false);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    }
  });

  testWidgets('dialog: newest term first with the year level; older term without; prints the chosen certificate', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final printed = <String>[];
    final original = printPdf;
    printPdf = (Uint8List bytes, String name) async => printed.add(name);
    addTearDown(() => printPdf = original);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CertificateDialog(
          kind: CertificateKind.enrollment,
          grades: _grades,
          studentName: 'Juan Dela Cruz',
          studentId: '25060208',
          programCode: 'BSIT',
          yearLevel: 2,
          loadPrograms: () async => const [
            AcademicProgramModel(programId: 1, programCode: 'BSIT', programName: 'Bachelor of Science in Information Technology')
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('a second year student of Bachelor of Science in Information Technology in the First Semester'),
        findsOneWidget);
    expect(find.textContaining('carrying 6 units'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('certificate_kind')).last);
    await tester.tap(find.text('Grades'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('certificate_term')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025-2026 (Second Semester)').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('a student of Bachelor of Science'), findsOneWidget);   // older term: no year level

    await tester.tap(find.byKey(const ValueKey('certificate_print')));
    await tester.pumpAndSettle();
    expect(printed, ['Certificate_of_Grades_Juan_Dela_Cruz.pdf']);
  });
}
