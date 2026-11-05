import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/grading_models.dart';
import '../models/class_models.dart';
import '../models/record_models.dart';
import 'study_load_pdf.dart' show pdfSafe;

/// Who the printout is about, shown under the title.
class RecordStudentInfo {
  final String name;
  final String? lrn;
  final String? programCode;
  final String? programName;
  final int? yearLevel;

  const RecordStudentInfo({required this.name, this.lrn, this.programCode, this.programName, this.yearLevel});
}

String _num(double v) => v.toStringAsFixed(1);

String _hours(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

String _date(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// "FIRST YEAR FIRST SEMESTER", "FIRST YEAR SUMMER", as on the printed curriculum.
String curriculumSectionTitle(int year, int semester) {
  const years = {1: 'FIRST', 2: 'SECOND', 3: 'THIRD', 4: 'FOURTH', 5: 'FIFTH'};
  const sems = {1: 'FIRST SEMESTER', 2: 'SECOND SEMESTER', 3: 'SUMMER'};
  return '${years[year] ?? 'YEAR $year'} YEAR ${sems[semester] ?? 'SEMESTER $semester'}';
}

String evaluationRemark(String status) => switch (status) {
      'Passed' => 'Passed',
      'Credited' => 'Credited',
      'InProgress' => 'In progress',
      'Failed' => 'Failed',
      'Dropped' => 'Dropped',
      _ => '',
    };

final _cell = const pw.TextStyle(fontSize: 7);
final _bold = pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold);
final _label = pw.TextStyle(fontSize: 8, color: PdfColors.grey700);

/// One bordered table: a header row, the rows, then a bold totals row.
pw.Widget _table({
  required List<String> headers,
  required List<List<String>> rows,
  List<String>? totals,
  required Map<int, pw.TableColumnWidth> widths,
  Set<int> centered = const {},
}) {
  pw.Widget cell(String text, int col, pw.TextStyle style) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: pw.Text(pdfSafe(text), style: style, textAlign: centered.contains(col) ? pw.TextAlign.center : pw.TextAlign.left),
      );
  return pw.Table(
    border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey600),
    columnWidths: widths,
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          for (var i = 0; i < headers.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.all(2),
              child: pw.Text(headers[i], style: _bold, textAlign: pw.TextAlign.center),
            ),
        ],
      ),
      for (final r in rows) pw.TableRow(children: [for (var i = 0; i < r.length; i++) cell(r[i], i, _cell)]),
      if (totals != null) pw.TableRow(children: [for (var i = 0; i < totals.length; i++) cell(totals[i], i, _bold)]),
    ],
  );
}

pw.Widget _sectionTitle(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10, bottom: 3),
      child: pw.Center(child: pw.Text(pdfSafe(text), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
    );

pw.Widget _header(String title, RecordStudentInfo s, Uint8List? logo) {
  pw.Widget info(String l, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(children: [
          pw.SizedBox(width: 55, child: pw.Text(l, style: _label)),
          pw.Expanded(child: pw.Text(pdfSafe(v), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
        ]),
      );
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(children: [
        if (logo != null)
          pw.Container(width: 40, height: 40, margin: const pw.EdgeInsets.only(right: 8), child: pw.Image(pw.MemoryImage(logo))),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('DON BOSCO TECHNICAL COLLEGE - CEBU', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text('Office of the Registrar', style: _label),
          ]),
        ),
      ]),
      pw.SizedBox(height: 6),
      pw.Center(child: pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: 8),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Column(children: [
          info('Name', s.name),
          info('LRN', s.lrn?.isNotEmpty == true ? s.lrn! : '-'),
        ])),
        pw.SizedBox(width: 16),
        pw.Expanded(child: pw.Column(children: [
          info('Program', [s.programCode, s.programName].whereType<String>().where((p) => p.isNotEmpty).join(' - ').ifEmpty('-')),
          info('Year level', s.yearLevel != null ? 'Year ${s.yearLevel}' : '-'),
        ])),
      ]),
    ],
  );
}

pw.Widget _signatures(List<String> roles) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 36),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          for (final r in roles)
            pw.Column(children: [
              pw.Container(width: 150, height: 0.5, color: PdfColors.black),
              pw.SizedBox(height: 3),
              pw.Text(r, style: _label),
            ]),
        ],
      ),
    );

Future<Uint8List> _save(String title, RecordStudentInfo s, Uint8List? logo, List<pw.Widget> body, bool compress, DateTime printedAt) {
  final doc = pw.Document(compress: compress, title: '$title - ${pdfSafe(s.name)}');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.letter,
    margin: const pw.EdgeInsets.all(28),
    header: (ctx) => ctx.pageNumber == 1 ? _header(title, s, logo) : pw.SizedBox(),
    footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('Printed ${_date(printedAt)}', style: const pw.TextStyle(fontSize: 7)),
      pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7)),
    ]),
    build: (ctx) => body,
  ));
  return doc.save();
}

/// The curriculum checklist, one table per year and semester, laid out like DBTC's printed curriculum.
Future<Uint8List> buildEvaluationPdf(
  StudentEvaluation e, {
  required RecordStudentInfo student,
  Uint8List? logo,
  bool compress = true,
  DateTime? printedAt,
}) {
  final groups = <(int, int), List<EvaluationSubject>>{};
  for (final s in e.subjects) {
    groups.putIfAbsent((s.yearLevel, s.semester), () => []).add(s);
  }
  final body = <pw.Widget>[];
  for (final g in groups.entries) {
    final subjects = g.value;
    double sum(double Function(EvaluationSubject) f) => subjects.fold(0, (t, s) => t + f(s));
    body.add(pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(curriculumSectionTitle(g.key.$1, g.key.$2)),
        _table(
          headers: ['Course Code', 'Descriptive Title', 'Lecture Hours', 'Lab Hours', 'Credit', 'Pre-requisite', 'Co-requisite', 'Grade', 'Remarks', 'Term Taken'],
          rows: [
            for (final s in subjects)
              [
                s.subjectCode,
                s.subjectTitle,
                _hours(s.lecHours),
                _hours(s.labHours),
                _num(s.units),
                s.prerequisites ?? 'None',
                s.corequisites ?? '',
                s.status == 'Credited' ? (s.creditedGrade ?? '') : (s.finalGrade?.toStringAsFixed(2) ?? ''),
                evaluationRemark(s.status),
                s.status == 'Credited' ? 'Credited${s.creditedFrom != null ? ' - ${s.creditedFrom}' : ''}' : (s.termLabel ?? ''),
              ],
          ],
          totals: ['', '', _hours(sum((s) => s.lecHours)), _hours(sum((s) => s.labHours)), _num(sum((s) => s.units)), '', '', '', '', ''],
          widths: const {
            0: pw.FixedColumnWidth(44),
            1: pw.FlexColumnWidth(3),
            2: pw.FixedColumnWidth(30),
            3: pw.FixedColumnWidth(26),
            4: pw.FixedColumnWidth(26),
            5: pw.FlexColumnWidth(1.3),
            6: pw.FlexColumnWidth(1),
            7: pw.FixedColumnWidth(28),
            8: pw.FixedColumnWidth(46),
            9: pw.FlexColumnWidth(1.4),
          },
          centered: const {2, 3, 4, 7},
        ),
      ],
    ));
  }
  body.add(pw.Padding(
    padding: const pw.EdgeInsets.only(top: 12),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Text(
        'Units earned: ${_num(e.earnedUnits)} of ${_num(e.totalUnits)}    In progress: ${_num(e.inProgressUnits)}    Units left: ${_num(e.remainingUnits)}',
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    ]),
  ));
  body.add(_signatures(['Evaluated by', 'Registrar']));
  return _save('STUDENT EVALUATION', student, logo, body, compress, printedAt ?? DateTime.now());
}

/// Every grade the student earned at DBTC, one table per semester taken, with the semester GWA,
/// then subjects credited from other schools and the overall GWA.
Future<Uint8List> buildResidencyPdf(
  List<StudentGradeModel> grades, {
  required RecordStudentInfo student,
  List<CreditedSubjectModel> credits = const [],
  Uint8List? logo,
  bool compress = true,
  DateTime? printedAt,
}) {
  final counted = grades.where((g) => g.loadStatus == null || g.loadStatus == 1).toList()
    ..sort((a, b) {
      final year = (a.schoolYear ?? '').compareTo(b.schoolYear ?? '');
      if (year != 0) return year;
      final sem = (a.semester ?? 0).compareTo(b.semester ?? 0);
      if (sem != 0) return sem;
      return (a.subjectCode ?? '').compareTo(b.subjectCode ?? '');
    });
  final terms = <String, List<StudentGradeModel>>{};
  for (final g in counted) {
    terms.putIfAbsent(g.termLabel ?? 'Unknown term', () => []).add(g);
  }

  const widths = {
    0: pw.FixedColumnWidth(50),
    1: pw.FlexColumnWidth(3),
    2: pw.FixedColumnWidth(34),
    3: pw.FixedColumnWidth(40),
    4: pw.FixedColumnWidth(40),
    5: pw.FixedColumnWidth(48),
    6: pw.FlexColumnWidth(1.4),
  };
  final body = <pw.Widget>[];
  for (final t in terms.entries) {
    final gwa = computeGwa(t.value);
    body.add(pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      _sectionTitle(t.key.toUpperCase()),
      _table(
        headers: ['Course Code', 'Descriptive Title', 'Credit', 'Midterm', 'Final Grade', 'Remarks', 'Instructor'],
        rows: [
          for (final g in t.value)
            [
              g.subjectCode ?? '',
              g.subjectTitle ?? '',
              g.units != null ? _num(g.units!) : '',
              g.midtermGrade?.toStringAsFixed(2) ?? '',
              g.finalGrade?.toStringAsFixed(2) ?? '',
              g.isPassed ? 'Passed' : g.isFailed ? 'Failed' : 'No grade',
              g.teacherName ?? '',
            ],
        ],
        totals: ['', 'GWA', _num(t.value.fold(0.0, (s, g) => s + (g.units ?? 0))), '', gwa?.toStringAsFixed(2) ?? '-', '', ''],
        widths: widths,
        centered: const {2, 3, 4},
      ),
    ]));
  }
  if (credits.isNotEmpty) {
    body.add(pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      _sectionTitle('CREDITED FROM OTHER SCHOOLS'),
      _table(
        headers: ['Course Code', 'Descriptive Title', 'Credit', 'Grade', 'School', 'School Year'],
        rows: [
          for (final c in credits)
            [c.subjectCode, c.subjectTitle, _num(c.units), c.grade ?? '', c.sourceSchool, c.schoolYear ?? ''],
        ],
        totals: ['', '', _num(credits.fold(0.0, (s, c) => s + c.units)), '', '', ''],
        widths: const {
          0: pw.FixedColumnWidth(50),
          1: pw.FlexColumnWidth(3),
          2: pw.FixedColumnWidth(34),
          3: pw.FixedColumnWidth(34),
          4: pw.FlexColumnWidth(2),
          5: pw.FixedColumnWidth(50),
        },
        centered: const {2, 3},
      ),
    ]));
  }
  final overall = computeGwa(counted);
  body.add(pw.Padding(
    padding: const pw.EdgeInsets.only(top: 12),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Text(
        overall == null ? 'No final grades yet' : 'Overall GWA: ${overall.toStringAsFixed(2)}  (NSTP and PE not included)',
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    ]),
  ));
  if (counted.isEmpty && credits.isEmpty) {
    body.insert(0, pw.Padding(padding: const pw.EdgeInsets.only(top: 12), child: pw.Text('No grades recorded yet.', style: _label)));
  }
  body.add(_signatures(['Prepared by', 'Registrar']));
  return _save('STUDENT RESIDENCY RECORD', student, logo, body, compress, printedAt ?? DateTime.now());
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// A grade sheet for one semester or one subject. [scope] is printed under the student's details,
/// e.g. "Semester: 2025-2026 (1st Sem)" or "Subject: IT 101 - Introduction to Computing".
/// A one-semester sheet ends with that semester's GWA; a one-subject sheet lists every attempt with its term.
Future<Uint8List> buildGradeSheetPdf(
  List<StudentGradeModel> grades, {
  required RecordStudentInfo student,
  required String scope,
  bool bySubject = false,
  Uint8List? logo,
  bool compress = true,
  DateTime? printedAt,
}) {
  final rows = [...grades]..sort((a, b) {
      final year = (a.schoolYear ?? '').compareTo(b.schoolYear ?? '');
      if (year != 0) return year;
      final sem = (a.semester ?? 0).compareTo(b.semester ?? 0);
      if (sem != 0) return sem;
      return (a.subjectCode ?? '').compareTo(b.subjectCode ?? '');
    });
  String remark(StudentGradeModel g) => switch (g.loadStatus) {
        2 => 'Dropped',
        3 => 'Withdrawn',
        _ => g.isPassed ? 'Passed' : g.isFailed ? 'Failed' : 'No grade',
      };
  final gwa = computeGwa(rows);
  final body = <pw.Widget>[
    pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
      child: pw.Text(pdfSafe(scope), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    ),
    _table(
      headers: [if (bySubject) 'Term', 'Course Code', 'Descriptive Title', 'Credit', 'Midterm', 'Final Grade', 'Remarks', 'Instructor'],
      rows: [
        for (final g in rows)
          [
            if (bySubject) g.termLabel ?? '',
            g.subjectCode ?? '',
            g.subjectTitle ?? '',
            g.units != null ? _num(g.units!) : '',
            g.midtermGrade?.toStringAsFixed(2) ?? '',
            g.finalGrade?.toStringAsFixed(2) ?? '',
            remark(g),
            g.teacherName ?? '',
          ],
      ],
      totals: bySubject
          ? null
          : ['', 'GWA', _num(rows.where((g) => g.loadStatus == null || g.loadStatus == 1).fold(0.0, (s, g) => s + (g.units ?? 0))), '',
              gwa?.toStringAsFixed(2) ?? '-', '', ''],
      widths: {
        if (bySubject) 0: const pw.FixedColumnWidth(84),
        (bySubject ? 1 : 0): const pw.FixedColumnWidth(50),
        (bySubject ? 2 : 1): const pw.FlexColumnWidth(3),
        (bySubject ? 3 : 2): const pw.FixedColumnWidth(34),
        (bySubject ? 4 : 3): const pw.FixedColumnWidth(40),
        (bySubject ? 5 : 4): const pw.FixedColumnWidth(40),
        (bySubject ? 6 : 5): const pw.FixedColumnWidth(48),
        (bySubject ? 7 : 6): const pw.FlexColumnWidth(1.4),
      },
      centered: bySubject ? const {3, 4, 5} : const {2, 3, 4},
    ),
    if (!bySubject)
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: pw.Text('GWA leaves out NSTP, PE and dropped or withdrawn subjects.', style: _label),
      ),
    _signatures(['Prepared by', 'Registrar']),
  ];
  return _save('GRADE SHEET', student, logo, body, compress, printedAt ?? DateTime.now());
}

/// The Adding/Dropping form for one term: every subject added, dropped, withdrawn or re-enrolled
/// after enrollment, with the date and reason, and lines for the student and Registrar to sign.
Future<Uint8List> buildAddDropPdf(
  List<StudyLoadChangeModel> changes, {
  required RecordStudentInfo student,
  required String termLabel,
  Uint8List? logo,
  bool compress = true,
  DateTime? printedAt,
}) {
  String day(DateTime? d) => d == null ? '' : _date(d);
  final body = <pw.Widget>[
    pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
      child: pw.Text(pdfSafe('Term: $termLabel'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    ),
    _table(
      headers: ['Action', 'Course Code', 'Descriptive Title', 'Section', 'Units', 'Date', 'Reason'],
      rows: [
        for (final c in changes)
          [c.kind, c.subjectCode, c.subjectTitle, c.className, _num(c.units), day(c.changedAt), c.reason ?? ''],
      ],
      widths: const {
        0: pw.FixedColumnWidth(52),
        1: pw.FixedColumnWidth(50),
        2: pw.FlexColumnWidth(2.4),
        3: pw.FixedColumnWidth(48),
        4: pw.FixedColumnWidth(30),
        5: pw.FixedColumnWidth(58),
        6: pw.FlexColumnWidth(2),
      },
      centered: const {4},
    ),
    _signatures(['Student', 'Registrar']),
  ];
  return _save('ADDING / DROPPING FORM', student, logo, body, compress, printedAt ?? DateTime.now());
}
