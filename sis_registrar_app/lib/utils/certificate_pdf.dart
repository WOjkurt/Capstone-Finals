import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/grading_models.dart';
import '../models/record_models.dart';
import 'study_load_pdf.dart' show pdfSafe;
import 'transcript_pdf.dart' show kSchoolAddress;

enum CertificateKind { enrollment, grades }

/// What a certificate says. One term only; [subjects] are that term's loads.
class CertificateData {
  final CertificateKind kind;
  final String studentName;
  final String? studentId;

  /// e.g. "Bachelor of Science in Information Technology"; the code is used when the name is unknown.
  final String program;

  /// Only for the student's current term; an older term's year level isn't known.
  final int? yearLevel;
  final String schoolYear;
  final int semester;
  final List<StudentGradeModel> subjects;
  final bool listSubjects;
  final String purpose;
  final String registrar;
  final DateTime issuedOn;

  CertificateData({
    required this.kind,
    required this.studentName,
    this.studentId,
    required this.program,
    this.yearLevel,
    required this.schoolYear,
    required this.semester,
    this.subjects = const [],
    this.listSubjects = true,
    this.purpose = '',
    this.registrar = '',
    DateTime? issuedOn,
  }) : issuedOn = issuedOn ?? DateTime.now();

  String get title => kind == CertificateKind.enrollment ? 'CERTIFICATE OF ENROLLMENT' : 'CERTIFICATE OF GRADES';
}

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

String semesterName(int semester) => switch (semester) { 1 => 'First Semester', 2 => 'Second Semester', 3 => 'Summer', _ => 'Term' };

String _yearWord(int y) => switch (y) { 1 => 'first', 2 => 'second', 3 => 'third', 4 => 'fourth', 5 => 'fifth', _ => '$y' };

/// "12th day of November 2026".
String issuedDay(DateTime d) {
  final n = d.day;
  final suffix = (n % 100 >= 11 && n % 100 <= 13) ? 'th' : switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' };
  return '$n$suffix day of ${_months[d.month - 1]} ${d.year}';
}

/// Subjects that count on a certificate: enrolled (or pending) loads, not dropped, withdrawn or rejected.
List<StudentGradeModel> certificateSubjects(CertificateData c) =>
    c.subjects.where((g) => g.loadStatus == null || g.loadStatus == 1 || g.loadStatus == 4).toList();

double certificateUnits(CertificateData c) => certificateSubjects(c).fold(0.0, (s, g) => s + (g.units ?? 0));

String _units(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

/// The main paragraph, e.g. "This is to certify that JUAN DELA CRUZ, Student ID 25060208, is officially enrolled ...".
String certificateBody(CertificateData c) {
  final hasId = c.studentId?.isNotEmpty == true;
  final who = '${c.studentName.toUpperCase()}${hasId ? ', Student ID ${c.studentId}' : ''}';
  final term = '${c.semester == 3 ? 'the Summer term' : 'the ${semesterName(c.semester)}'} of School Year ${c.schoolYear}';
  final asWhat = c.yearLevel != null ? 'a ${_yearWord(c.yearLevel!)} year student of ${c.program}' : 'a student of ${c.program}';
  if (c.kind == CertificateKind.enrollment) {
    return 'This is to certify that $who${hasId ? ',' : ''} is officially enrolled as $asWhat in $term, '
        'carrying ${_units(certificateUnits(c))} units${c.listSubjects ? ' in the subjects listed below' : ''}.';
  }
  return 'This is to certify that $who, $asWhat, obtained the following final grades in $term.';
}

String certificateClosing(CertificateData c) {
  final purpose = c.purpose.trim().replaceAll(RegExp(r'[.\s]+$'), '');
  return 'This certification is issued upon the request of the above-named student'
      '${purpose.isEmpty ? '' : ' ${purpose.toLowerCase().startsWith('for ') ? purpose : 'for $purpose'}'}. '
      'Issued this ${issuedDay(c.issuedOn)} at Don Bosco Technical College - Cebu, Cebu City, Philippines.';
}

String _grade(StudentGradeModel g) {
  if (g.loadStatus == 2) return 'DO';
  if (g.loadStatus == 3) return 'W';
  final f = g.finalGrade;
  return f == null ? 'No grade yet' : f.toStringAsFixed(f * 10 == (f * 10).roundToDouble() ? 1 : 2);
}

String _remark(StudentGradeModel g) => g.finalGrade == null ? '' : (g.remarks == 1 ? 'Passed' : g.remarks == 2 ? 'Failed' : '');

Future<Uint8List> buildCertificatePdf(CertificateData c, {Uint8List? logo, bool compress = true}) {
  final doc = pw.Document(compress: compress, title: '${c.title} - ${pdfSafe(c.studentName)}');
  final body = pw.TextStyle(fontSize: 11, lineSpacing: 4);
  final small = const pw.TextStyle(fontSize: 9);
  final bold9 = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
  // A certificate of grades lists every subject of the term (dropped ones as DO/W) so nothing is hidden.
  final rows = c.kind == CertificateKind.grades ? c.subjects.where((g) => g.loadStatus != 5).toList() : certificateSubjects(c);
  final gwa = c.kind == CertificateKind.grades ? computeGwa(rows) : null;

  pw.Widget cell(String t, {pw.TextStyle? style, pw.Alignment align = pw.Alignment.centerLeft}) => pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(pdfSafe(t), style: style ?? small),
      );

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.letter,
    margin: const pw.EdgeInsets.fromLTRB(56, 40, 56, 40),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
          if (logo != null) pw.Container(width: 52, height: 52, margin: const pw.EdgeInsets.only(right: 10), child: pw.Image(pw.MemoryImage(logo))),
          pw.Column(children: [
            pw.Text('DON BOSCO TECHNICAL COLLEGE - CEBU', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text(kSchoolAddress, style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 2),
            pw.Text('OFFICE OF THE REGISTRAR', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ]),
        ]),
        pw.Divider(thickness: 0.8),
        pw.SizedBox(height: 18),
        pw.Center(child: pw.Text(c.title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5))),
        pw.SizedBox(height: 24),
        pw.Text('TO WHOM IT MAY CONCERN:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Text(pdfSafe(certificateBody(c)), style: body, textAlign: pw.TextAlign.justify),
        if (rows.isNotEmpty && (c.kind == CertificateKind.grades || c.listSubjects)) ...[
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey600),
            columnWidths: c.kind == CertificateKind.grades
                ? const {0: pw.FixedColumnWidth(70), 1: pw.FlexColumnWidth(), 2: pw.FixedColumnWidth(36), 3: pw.FixedColumnWidth(62), 4: pw.FixedColumnWidth(48)}
                : const {0: pw.FixedColumnWidth(70), 1: pw.FlexColumnWidth(), 2: pw.FixedColumnWidth(40)},
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  cell('Code', style: bold9),
                  cell('Descriptive title', style: bold9),
                  cell('Units', style: bold9, align: pw.Alignment.center),
                  if (c.kind == CertificateKind.grades) ...[
                    cell('Final grade', style: bold9, align: pw.Alignment.center),
                    cell('Remarks', style: bold9, align: pw.Alignment.center),
                  ],
                ],
              ),
              for (final g in rows)
                pw.TableRow(children: [
                  cell(g.subjectCode ?? ''),
                  cell(g.subjectTitle ?? ''),
                  cell(_units(g.units ?? 0), align: pw.Alignment.center),
                  if (c.kind == CertificateKind.grades) ...[
                    cell(_grade(g), align: pw.Alignment.center),
                    cell(_remark(g), align: pw.Alignment.center),
                  ],
                ]),
              pw.TableRow(children: [
                cell(''),
                cell('Total units', style: bold9),
                cell(_units(rows.where((g) => g.loadStatus == null || g.loadStatus == 1 || g.loadStatus == 4).fold(0.0, (s, g) => s + (g.units ?? 0))),
                    style: bold9, align: pw.Alignment.center),
                if (c.kind == CertificateKind.grades) ...[cell(''), cell('')],
              ]),
            ],
          ),
          if (c.kind == CertificateKind.grades)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: pw.Text(
                gwa == null ? 'General weighted average: no final grades yet' : 'General weighted average: ${gwa.toStringAsFixed(2)}  (NSTP and PE not included)',
                style: bold9,
              ),
            ),
        ],
        pw.SizedBox(height: 16),
        pw.Text(pdfSafe(certificateClosing(c)), style: body, textAlign: pw.TextAlign.justify),
        pw.SizedBox(height: 56),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(children: [
            pw.SizedBox(
              width: 200,
              child: pw.Text(pdfSafe(c.registrar.trim().toUpperCase()), textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Container(width: 200, height: 0.6, color: PdfColors.black),
            pw.SizedBox(height: 3),
            pw.Text('College Registrar', style: const pw.TextStyle(fontSize: 10)),
          ]),
        ),
        pw.Spacer(),
        pw.Text('Not valid without the school seal and the Registrar\'s original signature.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ],
    ),
  ));
  return doc.save();
}
