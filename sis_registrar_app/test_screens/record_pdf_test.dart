import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/models/class_models.dart';
import 'package:sis_registrar_app/models/grading_models.dart';
import 'package:sis_registrar_app/models/report_models.dart';
import 'package:sis_registrar_app/models/record_models.dart';
import 'package:sis_registrar_app/utils/report_pdf.dart';
import 'package:sis_registrar_app/utils/student_record_pdf.dart';
import 'package:sis_registrar_app/utils/transcript_pdf.dart';

/// Writes sample Evaluation and Residency PDFs to $OUT for a visual check.
void main() {
  test('sample record PDFs', () async {
    final out = Platform.environment['OUT'] ?? Directory.systemTemp.path;
    EvaluationSubject s(String code, String title, int y, int sem, double lec, double lab, String status,
            {String? pre, String? co, double? grade, String? term}) =>
        EvaluationSubject(subjectId: code, subjectCode: code, subjectTitle: title, units: 3, lecHours: lec, labHours: lab,
            prerequisites: pre, corequisites: co, yearLevel: y, semester: sem, isMinor: false, status: status, finalGrade: grade, termLabel: term);
    final e = StudentEvaluation(
      fullName: 'Ana Cruz', lrn: '123456789012', programCode: 'BTVTED', programName: 'Bachelor of Technical-Vocational Teacher Education',
      yearLevel: 2, totalUnits: 30, earnedUnits: 15, inProgressUnits: 6, remainingUnits: 15,
      subjects: [
        s('FT 101', 'Basic Occupational Safety and Health', 1, 1, 3, 0, 'Passed', grade: 1.5, term: '2025-2026 (1st Sem)'),
        s('FT 102', 'Engineering Drawing', 1, 1, 2, 3, 'Passed', grade: 2.0, term: '2025-2026 (1st Sem)'),
        s('GEC 101A', 'Understanding the Self with Mental Health', 1, 1, 3, 0, 'Failed', grade: 5.0, term: '2025-2026 (1st Sem)'),
        const EvaluationSubject(subjectId: 'g', subjectCode: 'GEC 102A', subjectTitle: 'Readings in the Philippine History', units: 3, lecHours: 3,
            yearLevel: 1, semester: 1, isMinor: true, status: 'Credited', creditedFrom: 'Cebu Technological University', creditedGrade: '1.5'),
        s('FT 105', 'Computer-Aided Designing (SolidWorks)', 1, 2, 2, 3, 'Passed', pre: 'FT 101', grade: 1.75, term: '2025-2026 (2nd Sem)'),
        s('THEO 102A', 'Scriptures, the Sacraments and Liturgy', 1, 2, 3, 0, 'Dropped', pre: 'THEO 101A', term: '2025-2026 (2nd Sem)'),
        s('GEC 106A', 'Arts Appreciation', 1, 3, 3, 0, 'NotTaken'),
        s('FT 208', 'Wood Finishing Techniques', 2, 1, 2, 3, 'InProgress', term: '2026-2027 (1st Sem)'),
        s('TLEC 308A', 'Teaching the Common Competencies in AFA', 3, 1, 3, 0, 'NotTaken', co: 'TLEC 307A'),
        s('STC 301A', 'Supervised Industry Training (In-house Industry Training)', 3, 2, 3, 0, 'NotTaken', pre: '3rd year standing'),
      ],
    );
    const info = RecordStudentInfo(name: 'Ana Cruz', lrn: '123456789012', programCode: 'BTVTED', programName: 'Bachelor of Technical-Vocational Teacher Education', yearLevel: 2);
    await File('$out/evaluation.pdf').writeAsBytes(await buildEvaluationPdf(e, student: info, printedAt: DateTime(2026, 11, 4)));

    StudentGradeModel g(String code, String title, double fin, String term, String sy, int sem, {int load = 1}) => StudentGradeModel(
        gradeId: code, subjectCode: code, subjectTitle: title, units: 3, midtermGrade: 2.0, finalGrade: fin, remarks: fin > 3 ? 2 : 1,
        termLabel: term, schoolYear: sy, semester: sem, loadStatus: load, teacherName: 'Ben Teach');
    await File('$out/residency.pdf').writeAsBytes(await buildResidencyPdf([
      g('FT 101', 'Basic Occupational Safety and Health', 1.5, '2025-2026 (1st Sem)', '2025-2026', 1),
      g('FT 102', 'Engineering Drawing', 2.0, '2025-2026 (1st Sem)', '2025-2026', 1),
      g('GEC 101A', 'Understanding the Self with Mental Health', 5.0, '2025-2026 (1st Sem)', '2025-2026', 1),
      g('FT 105', 'Computer-Aided Designing (SolidWorks)', 1.75, '2025-2026 (2nd Sem)', '2025-2026', 2),
      g('THEO 102A', 'Scriptures', 5.0, '2025-2026 (2nd Sem)', '2025-2026', 2, load: 2),
    ], credits: const [
      CreditedSubjectModel(creditedSubjectId: 'c', subjectId: 's', subjectCode: 'GEC 102A', subjectTitle: 'Readings in the Philippine History', units: 3, yearLevel: 1, sourceSchool: 'Cebu Technological University', grade: '1.5', schoolYear: '2024-2025'),
    ], student: info, printedAt: DateTime(2026, 11, 4)));

    final sem1 = [
      g('FT 101', 'Basic Occupational Safety and Health', 1.5, '2025-2026 (1st Sem)', '2025-2026', 1),
      g('FT 102', 'Engineering Drawing', 2.0, '2025-2026 (1st Sem)', '2025-2026', 1),
      g('GEC 101A', 'Understanding the Self with Mental Health', 5.0, '2025-2026 (1st Sem)', '2025-2026', 1),
    ];
    await File('$out/grade_sheet_term.pdf').writeAsBytes(await buildGradeSheetPdf(sem1,
        student: info, scope: 'Semester: 2025-2026 (1st Sem)', printedAt: DateTime(2026, 11, 4)));
    await File('$out/grade_sheet_subject.pdf').writeAsBytes(await buildGradeSheetPdf([
      g('GEC 101A', 'Understanding the Self with Mental Health', 5.0, '2025-2026 (1st Sem)', '2025-2026', 1),
      g('GEC 101A', 'Understanding the Self with Mental Health', 2.25, '2025-2026 (Summer)', '2025-2026', 3),
    ], student: info, scope: 'Subject: GEC 101A - Understanding the Self with Mental Health', bySubject: true, printedAt: DateTime(2026, 11, 4)));

    await File('$out/add_drop.pdf').writeAsBytes(await buildAddDropPdf([
      StudyLoadChangeModel(changeId: '1', kind: 'Dropped', subjectCode: 'FT 208', subjectTitle: 'Wood Finishing Techniques', className: 'BTVTED 2A', units: 3, reason: 'Schedule conflict with OJT', changedAt: DateTime(2026, 8, 20)),
      StudyLoadChangeModel(changeId: '2', kind: 'Added', subjectCode: 'GEC 106A', subjectTitle: 'Arts Appreciation', className: 'BTVTED 2B', units: 3, reason: 'Replacement subject, approved by College Head', changedAt: DateTime(2026, 8, 21)),
      StudyLoadChangeModel(changeId: '3', kind: 'Withdrawn', subjectCode: 'NSTP 201A', subjectTitle: 'Literacy Training Service 1', className: 'BTVTED 2A', units: 3, reason: 'Medical', changedAt: DateTime(2026, 10, 2)),
    ], student: info, termLabel: '2026-2027 (1st Sem)', printedAt: DateTime(2026, 11, 5)));

    await File('$out/statistics.pdf').writeAsBytes(await buildEnrollmentStatisticsPdf(
      termLabel: '2026-2027 (1st Sem)',
      rows: const [
        ['BSIT', 42, 18, 35, 15, 30, 12, 25, 10, 132, 55, 187],
        ['BSME', 38, 4, 30, 3, 26, 2, 20, 1, 114, 10, 124],
        ['BTVTED', 20, 22, 18, 20, 15, 17, 12, 14, 65, 73, 138],
        ['TOTAL', 100, 44, 83, 38, 71, 31, 57, 25, 311, 138, 449],
      ],
      note: '3 enrolled student(s) have no sex on record and are not counted above.',
      printedAt: DateTime(2026, 11, 5),
    ));

    const names = ['ABELLA, Mark', 'BACALSO, Joy', 'CRUZ, Ana', 'DELA CRUZ, Paolo', 'ESPINA, Leah', 'FLORES, Jun', 'GARCIA, Mae', 'HERRERA, Rico'];
    await File('$out/class_list.pdf').writeAsBytes(await buildClassListsPdf([
      ClassList(
        classId: 'c1', className: 'BTVTED 2A', subjectCode: 'FT 208', subjectTitle: 'Wood Finishing Techniques', units: 3,
        termLabel: '2026-2027 (1st Sem)', teacherName: 'Ben Teach',
        schedules: const ['M/W 8:00 AM - 9:30 AM · Shop 2', 'F 1:00 PM - 4:00 PM · Shop 2'],
        students: [
          for (final (i, n) in names.indexed)
            ClassListStudent(name: n, lrn: '1234567890${10 + i}', programCode: 'BTVTED', yearLevel: 2, sex: i == 7 ? null : (i.isEven ? 'M' : 'F')),
        ],
      ),
    ], printedAt: DateTime(2026, 11, 5)));

    const titles = ['Basic Occupational Safety and Health', 'Engineering Drawing', 'Wood and Lumber (Wood Joints and Wood Cuts)',
      'Basic Machine Tools & Bench Work', 'Teaching ICT as an Exploratory Course', 'Teaching the Common Competencies in ICT',
      'The Child and Adolescent Learner and Learning Principles', 'Understanding the Self with Mental Health', 'Movement Competency Training',
      'Introduction to the Catholic Faith', 'Readings in the Philippine History'];
    final terms = <TranscriptSection>[];
    for (final (i, h) in ['1st Semester, 2025-2026', '2nd Semester, 2025-2026', 'Summer, 2025-2026', '1st Semester, 2026-2027'].indexed) {
      terms.add(TranscriptSection(heading: h, rows: [
        for (var j = 0; j < (i == 2 ? 3 : 11); j++)
          TranscriptRow(subjectCode: 'FT ${i + 1}0${j + 1}', subjectTitle: titles[j], finalGrade: j == 4 && i == 0 ? 'DO' : j == 7 && i == 1 ? '5.00' : i == 3 ? '' : '1.${(j * 3) % 10}0', units: j == 9 ? 2 : 3),
      ]));
    }
    final tr = Transcript(
      fullName: 'CRUZ, Ana Reyes', lrn: '123456789012', programCode: 'BTVTED', programName: 'Bachelor of Technical-Vocational Teacher Education',
      address: '12 Rizal St, Punta Princesa, Cebu City, Cebu', dateOfBirth: DateTime(2007, 5, 1), placeOfBirth: 'Cebu City', sex: 'Female',
      nationality: 'Filipino', dateAdmitted: '1st Semester, 2025-2026', entranceData: 'Abellana National School', terms: terms,
      credits: const [TranscriptSection(heading: 'Credited from Cebu Technological University', rows: [
        TranscriptRow(subjectCode: 'GEC 102A', subjectTitle: 'Readings in the Philippine History', finalGrade: '1.5', units: 3),
      ])],
    );
    await File('$out/tor.pdf').writeAsBytes(await buildTranscriptPdf(tr,
        options: TranscriptPrintOptions(remarks: 'For transfer purposes', preparedBy: 'Maria Santos', registrar: 'Rita Reg', releasedOn: DateTime(2026, 11, 5))));
  });
}
