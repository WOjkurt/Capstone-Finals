// Parses real API output (saved by Api.Tests' SchoolYearPostgresTests with TEST_JSON_OUT) with the app's models,
// so a field name or type that differs from the hand-written test data fails here.
// Run: API_JSON=/that/dir flutter test test_screens/api_contract_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/models/class_models.dart';
import 'package:sis_registrar_app/models/grading_models.dart';
import 'package:sis_registrar_app/models/record_models.dart';
import 'package:sis_registrar_app/models/report_models.dart';
import 'package:sis_registrar_app/models/school_models.dart';
import 'package:sis_registrar_app/utils/report_pdf.dart';
import 'package:sis_registrar_app/utils/student_record_pdf.dart';
import 'package:sis_registrar_app/utils/transcript_pdf.dart';

void main() {
  final dir = Platform.environment['API_JSON'];
  Object? read(String name) => jsonDecode(File('$dir/$name.json').readAsStringSync());
  Map<String, dynamic> one(String name) => read(name) as Map<String, dynamic>;
  List<Map<String, dynamic>> many(String name) => (read(name) as List).cast<Map<String, dynamic>>();

  test('evaluation', () async {
    final e = StudentEvaluation.fromJson(one('evaluation'));
    expect(e.fullName, startsWith('Test Student'));
    expect(e.lrn, isNotNull);
    expect(e.programCode, startsWith('T'));
    expect(e.yearLevel, 2);
    expect(e.totalUnits, greaterThan(0));
    expect(e.earnedUnits, greaterThan(0));
    final by = {for (final s in e.subjects) s.subjectCode: s};
    expect(by['MJ 101']!.status, 'Passed');
    expect(by['MJ 101']!.finalGrade, 2.0);
    expect(by['MJ 101']!.lecHours, isNotNull);
    expect(by['MJ 101']!.units, 3);
    expect(by['MJ 201']!.prerequisites, 'MJ 101');
    expect(by['MJ 103']!.status, 'Dropped');
    expect(by['GE 202']!.status, 'PartiallyCredited');
    expect(by['GE 202']!.creditedUnits, 2);
    expect(by['GE 202']!.isDone, isFalse);
    expect(by['GE 203']!.status, 'CrossEnrolled');
    expect(by['GE 203']!.isDone, isTrue);
    expect(by['GE 203']!.creditedFrom, startsWith('Test College'));
    expect(by['GE 203']!.termLabel, contains('2nd Sem'));
    expect(by['GE 101']!.isMinor, isTrue);
    expect(by['MJ 204']!.creditedGrade, '1.5');
    await buildEvaluationPdf(e, student: RecordStudentInfo(name: e.fullName, programCode: e.programCode));
  });

  test('transcript', () async {
    final t = Transcript.fromJson(one('transcript'));
    expect(t.fullName, contains(', Test Reyes'));
    expect(t.address, contains('Punta Princesa'));
    expect(t.dateOfBirth, DateTime(2007, 5, 1));
    expect(t.placeOfBirth, 'Cebu City');
    expect(t.dateAdmitted, '1st Semester, 2024-2025');
    expect(t.entranceData, 'Abellana National School');
    expect(t.terms, hasLength(2));
    expect(t.terms.first.heading, startsWith('1st Semester'));
    expect(t.terms.first.rows.map((r) => r.finalGrade), containsAll(['5.00', 'DO', '2.00']));
    expect(t.terms.first.rows.first.units, greaterThan(0));
    expect(t.credits, hasLength(2));
    expect(t.credits.first.heading, startsWith('Credited from'));
    await buildTranscriptPdf(t, options: TranscriptPrintOptions());
  });

  test('personal details', () {
    final d = PersonalDetails.fromJson(one('personal_details'));
    expect(d.firstname, 'Test');
    expect(d.middleName, 'Reyes');
    expect(d.sex, 'Female');
    expect(d.dateOfBirth, DateTime(2007, 5, 1));
    expect(d.dateAdmitted, isNotNull);
    expect(d.firstTermEnrolled, startsWith('1st Semester'));
    expect(d.hasEnrollmentForm, isTrue);
    expect(d.fromForm, contains('address'));
    expect(d.fromForm, isNot(contains('sex')));
    expect(d.updatedBy, 'Rita Staff');
    expect(d.updatedAt, isNotNull);
  });

  test('credits', () {
    final c = many('credits').map(CreditedSubjectModel.fromJson).toList();
    final by = {for (final x in c) x.subjectCode: x};
    expect(by['GE 202']!.isPartial, isTrue);
    expect(by['GE 202']!.creditedUnits, 2);
    expect(by['GE 202']!.units, 3);
    expect(by['GE 203']!.isCrossEnrollment, isTrue);
    expect(by['GE 203']!.termLabel, contains('2nd Sem'));
    expect(by['MJ 204']!.isPartial, isFalse);
    expect(by['MJ 204']!.recordedBy, 'Rita Staff');
  });

  test('adds and drops', () async {
    final c = many('changes').map(StudyLoadChangeModel.fromJson).toList();
    expect(c.map((x) => x.kind), ['Added', 'Dropped']);
    expect(c.last.reason, 'Schedule conflict');
    expect(c.last.subjectCode, 'MJ 103');
    expect(c.last.className, 'Sec MJ 103');
    expect(c.last.units, 3);
    expect(c.last.changedBy, 'Rita Staff');
    expect(c.last.changedAt, isNotNull);
    await buildAddDropPdf(c, student: const RecordStudentInfo(name: 'x'), termLabel: 'x');
  });

  test('grades: GWA leaves out NSTP and non-enrolled loads', () async {
    final g = many('grades').map(StudentGradeModel.fromJson).toList();
    final nstp = g.firstWhere((x) => x.subjectCode == 'NSTP 1');
    expect(nstp.units, 3);
    expect(nstp.finalGrade, 1.5);
    expect(nstp.loadStatus, 1);
    expect(nstp.termLabel, contains('Sem'));
    expect(nstp.schoolYear, isNotNull);
    expect(nstp.semester, 1);
    expect(countsInGwa(nstp.subjectCode), isFalse);
    expect(computeGwa(g), isNotNull);
    await buildResidencyPdf(g, student: const RecordStudentInfo(name: 'x'));
    await buildGradeSheetPdf(g, student: const RecordStudentInfo(name: 'x'), scope: 'x');
  });

  test('statistics', () async {
    final rows = many('statistics').map(EnrollmentStatisticsRow.fromJson).toList();
    final mine = rows.firstWhere((r) => r.total > 0);
    expect(mine.programCode, isNotEmpty);
    expect(mine.female, hasLength(4));
    expect(mine.totalFemale, greaterThan(0));
    await buildEnrollmentStatisticsPdf(termLabel: 'x', rows: [
      [mine.programCode, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3]
    ]);
  });

  test('class lists', () async {
    final lists = many('class_lists').map(ClassList.fromJson).toList();
    final c = lists.firstWhere((x) => x.subjectCode == 'MJ 101');
    expect(c.className, 'Sec MJ 101');
    expect(c.units, 3);
    expect(c.teacherName, 'Ben Staff');
    expect(c.termLabel, contains('1st Sem'));
    expect(c.schedules.single, contains('M/W/F'));
    expect(c.students.single.name, contains('STUDENT'));
    expect(c.students.single.sex, 'F');
    expect(c.students.single.lrn, isNotNull);
    expect(c.students.single.programCode, isNotNull);
    expect(c.students.single.yearLevel, isNotNull);
    await buildClassListsPdf(lists);
  });

  test('transferees, schools', () {
    final t = many('transferees').map(TransfereeRow.fromJson).toList();
    final row = t.lastWhere((x) => x.creditedSubjects == 2);
    expect(row.userId, isNotEmpty);
    expect(row.studentName, isNotEmpty);
    expect(row.previousSchools, hasLength(2));
    expect(row.creditedUnits, 5);
    expect(row.creditedCodes, ['GE 202', 'MJ 204']);
    final s = many('schools').map(AccreditedSchool.fromJson).toList();
    expect(s.last.schoolId, isNotEmpty);
    expect(s.map((x) => x.creditCount).reduce((a, b) => a + b), greaterThan(0));
    expect(many('unlisted').map(UnlistedSchool.fromJson).last.creditCount, 1);
  });

  test('standing, irregular list', () {
    final s = Standing.fromJson(one('standing'));
    expect(s.isRegular, isFalse);
    expect(s.irregularSince, isNotNull);
    expect(s.unitsToRegular, 6);
    final row = many('irregular').map(IrregularStudent.fromJson).first;
    expect(row.userId, isNotEmpty);
    expect(row.studentName, isNotEmpty);
    expect(row.programCode, isNotNull);
    expect(row.irregularSince, isNotNull);
  });

  test('shifting', () {
    final r = ShiftResult.fromJson(one('shift'));
    expect(r.programId, greaterThan(0));
    expect(r.programCode, startsWith('U'));
    final p = many('previous_subjects').map(PreviousProgramSubject.fromJson).firstWhere((x) => x.subjectCode == 'GE 101');
    expect(p.status, 'Passed');
    expect(p.finalGrade, 2.0);
    expect(p.programCode, startsWith('T'));
    expect(p.schoolYear, isNotEmpty);
    expect(p.termLabel, contains('Sem'));
    expect(p.suggestedSubjectId, isNotNull);
    expect(p.suggestedSubjectCode, 'GE 101');
    expect(p.suggestedUnits, 3);
  });
}
