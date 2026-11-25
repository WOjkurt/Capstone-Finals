import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/utils/student_record_pdf.dart';

/// The standing summary at the head of the residency sheet: what the course asks for, what has
/// been earned, and the average. It is the question the sheet is usually pulled to answer.
void main() {
  test('says what the course asks for, what was earned, and the average', () {
    final parts = residencySummaryParts(
      const RecordStudentInfo(name: 'Ana Cruz', programCode: 'BSIT', unitsRequired: 163, unitsEarned: 136),
      1.94,
    );

    expect(parts, ['Units required: 163', 'Credit earned: 136', 'GWA: 1.94']);
  });

  test('leaves out what is not known rather than printing a zero', () {
    // A nil evaluation means the numbers were not loaded, not that nothing was earned.
    expect(residencySummaryParts(const RecordStudentInfo(name: 'Ana Cruz'), null), isEmpty);
  });

  test('a student with no final grades still shows the units', () {
    final parts = residencySummaryParts(
      const RecordStudentInfo(name: 'Ana Cruz', unitsRequired: 163, unitsEarned: 0),
      null,
    );

    // Nothing graded yet is a real state, and zero earned is a fact here rather than a guess.
    expect(parts, ['Units required: 163', 'Credit earned: 0']);
  });
}
