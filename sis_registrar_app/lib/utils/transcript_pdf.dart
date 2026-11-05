import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/record_models.dart';
import 'study_load_pdf.dart' show pdfSafe;

/// What the Registrar fills in before printing a transcript. Empty names print as blank signature lines.
class TranscriptPrintOptions {
  final String remarks;
  final String preparedBy;
  final String checkedBy;
  final String registrar;
  final DateTime releasedOn;

  TranscriptPrintOptions({
    this.remarks = '',
    this.preparedBy = '',
    this.checkedBy = '',
    this.registrar = '',
    DateTime? releasedOn,
  }) : releasedOn = releasedOn ?? DateTime.now();
}

const kSchoolAddress = 'Pleasant Homes Subdivision, Punta Princesa, Cebu City, 6000 Cebu, Philippines';

const kTranscriptGradingSystem =
    '1.0 - 3.0, Passed (in steps of 0.1);   5.0, Failed;   DO, Dropped Officially;   W, Withdrawn.';
const kTranscriptCredits =
    'One unit of credit is one hour of lecture or recitation, or three hours of laboratory or shopwork, '
    'each week for the period of a complete semester.';
const kTranscriptValidity =
    'This transcript is valid only when it bears the school seal and the original signature of the Registrar. '
    'Any erasure or alteration made on this document renders it void unless initialed by the Registrar.';

String _date(DateTime d) {
  const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String _units(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

// Column widths of the grades table, in points (letter width 612 - 2 × 30 margin = 552).
const double _codeW = 78;
const double _finalW = 52;
const double _completionW = 62;
const double _unitsW = 48;

final _line = PdfColors.grey700;

const _columns = {
  0: pw.FixedColumnWidth(_codeW),
  1: pw.FlexColumnWidth(),
  2: pw.FixedColumnWidth(_finalW),
  3: pw.FixedColumnWidth(_completionW),
  4: pw.FixedColumnWidth(_unitsW),
};

/// One table line with the column dividers. A one-row table per line keeps the dividers the full
/// height of the line when a title wraps, and still lets the page break between lines.
pw.Widget _row(String code, pw.Widget title, String finalGrade, String completion, String units, {bool bold = false}) {
  final style = pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
  pw.Widget cell(pw.Widget child) => pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.2), child: child);
  return pw.Table(
    columnWidths: _columns,
    border: pw.TableBorder(
      left: pw.BorderSide(color: _line, width: 0.8),
      right: pw.BorderSide(color: _line, width: 0.8),
      verticalInside: pw.BorderSide(color: _line, width: 0.5),
    ),
    children: [
      pw.TableRow(children: [
        cell(pw.Text(pdfSafe(code), style: style)),
        cell(title),
        cell(pw.Text(pdfSafe(finalGrade), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
        cell(pw.Text(pdfSafe(completion), style: style, textAlign: pw.TextAlign.center)),
        cell(pw.Text(units, style: style, textAlign: pw.TextAlign.center)),
      ]),
    ],
  );
}

pw.Widget _subjectLine(TranscriptRow r) =>
    _row(r.subjectCode, pw.Text(pdfSafe(r.subjectTitle), style: const pw.TextStyle(fontSize: 8.5)), r.finalGrade, '', _units(r.units));

/// A heading line such as "1st Semester, 2025-2026", underlined like a printed transcript.
pw.Widget _heading(String text, {bool center = false}) => _row(
      '',
      pw.Text(pdfSafe(text),
          textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
      '',
      '',
      '',
    );

pw.Widget _tableHeader() {
  final style = pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold);
  pw.Widget head(String t) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Text(t, style: style, textAlign: pw.TextAlign.center),
      );
  return pw.Table(
    columnWidths: _columns,
    border: pw.TableBorder.all(color: _line, width: 0.8),
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [head('Course No.'), head('Descriptive Title'), head('Final\nGrade'), head('Completion'), head('Units of\nCredit')],
      ),
    ],
  );
}

pw.Widget _info(Transcript t) {
  final label = const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800);
  final value = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
  pw.Widget field(String l, String? v, {double labelWidth = 78}) => pw.Expanded(
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.SizedBox(width: labelWidth, child: pw.Text(l, style: label)),
            pw.Expanded(child: pw.Text(pdfSafe(v?.trim().isNotEmpty == true ? v!.trim() : '-'), style: value)),
          ]),
        ),
      );
  pw.Widget line(List<pw.Widget> fields) => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: fields);
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: _line, width: 0.8)),
    child: pw.Column(children: [
      line([field('Name:', t.fullName), field('Address:', t.address, labelWidth: 70)]),
      line([field('Date Admitted:', t.dateAdmitted), field('Entrance Data:', t.entranceData, labelWidth: 70)]),
      line([
        field('Date of Birth:', t.dateOfBirth == null ? null : _date(t.dateOfBirth!)),
        field('Place of Birth:', t.placeOfBirth, labelWidth: 70),
      ]),
      line([
        field('Sex:', t.sex),
        field('Nationality:', t.nationality, labelWidth: 70),
      ]),
      line([field('LRN:', t.lrn), field('Program:', t.programCode, labelWidth: 70)]),
    ]),
  );
}

/// Remarks, grading system, validity notice and signatures, repeated on every page.
/// [studentName] goes in the corner so loose pages can be matched up.
pw.Widget _footer(pw.Context ctx, TranscriptPrintOptions o, String studentName) {
  final small = const pw.TextStyle(fontSize: 8);
  final bold = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);
  pw.Widget signer(String label, String name, {String? caption}) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: bold),
          pw.SizedBox(height: 16),
          pw.Container(width: 150, height: 0.5, color: PdfColors.black),
          pw.SizedBox(height: 2),
          pw.Text(pdfSafe(name.isEmpty ? (caption ?? '') : name), style: name.isEmpty ? small : bold),
          if (caption != null && name.isNotEmpty) pw.Text(caption, style: small),
        ],
      );
  final last = ctx.pageNumber == ctx.pagesCount;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      // Closes the table on every page and says whether more follows.
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _line, width: 0.8)),
        child: pw.Center(
          child: pw.Text(
            last ? 'x x x x x   NOTHING FOLLOWS   x x x x x' : 'x x x x x   TURN TO NEXT PAGE   x x x x x',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: _line, width: 0.8), right: pw.BorderSide(color: _line, width: 0.8), bottom: pw.BorderSide(color: _line, width: 0.8))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.RichText(text: pw.TextSpan(children: [
            pw.TextSpan(text: 'Remarks:  ', style: bold),
            pw.TextSpan(text: pdfSafe(o.remarks.trim().isEmpty ? '' : o.remarks.trim()), style: small),
          ])),
          pw.SizedBox(height: 4),
          pw.RichText(text: pw.TextSpan(children: [
            pw.TextSpan(text: 'Grading System:  ', style: bold),
            pw.TextSpan(text: kTranscriptGradingSystem, style: small),
          ])),
          pw.SizedBox(height: 2),
          pw.RichText(text: pw.TextSpan(children: [
            pw.TextSpan(text: 'Credits:  ', style: bold),
            pw.TextSpan(text: kTranscriptCredits, style: small),
          ])),
        ]),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: _line, width: 0.8), right: pw.BorderSide(color: _line, width: 0.8), bottom: pw.BorderSide(color: _line, width: 0.8))),
        child: pw.Text(kTranscriptValidity, style: bold),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: _line, width: 0.8), right: pw.BorderSide(color: _line, width: 0.8), bottom: pw.BorderSide(color: _line, width: 0.8))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              signer('Prepared by:', o.preparedBy),
              pw.SizedBox(height: 6),
              signer('Checked by:', o.checkedBy),
            ]),
            signer('', o.registrar, caption: 'Registrar'),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Released:', style: bold),
              pw.SizedBox(height: 6),
              pw.Text('on  ${_date(o.releasedOn)}', style: small),
              pw.SizedBox(height: 10),
              pw.Text('by:  ____________________', style: small),
            ]),
          ],
        ),
      ),
      pw.SizedBox(height: 3),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(pdfSafe(studentName), style: const pw.TextStyle(fontSize: 7)),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7)),
      ]),
    ],
  );
}

/// The Official Transcript of Records, laid out like a standard Philippine college transcript.
Future<Uint8List> buildTranscriptPdf(
  Transcript tr, {
  required TranscriptPrintOptions options,
  Uint8List? logo,
  bool compress = true,
}) {
  final doc = pw.Document(compress: compress, title: 'Transcript of Records - ${pdfSafe(tr.fullName)}');
  final lines = <pw.Widget>[
    _heading(tr.programName.isNotEmpty ? tr.programName.toUpperCase() : tr.programCode, center: true),
    for (final section in [...tr.credits, ...tr.terms])
      for (final (i, r) in section.rows.indexed)
        // The heading travels with the first subject, so it never sits alone at the bottom of a page.
        i == 0 ? pw.Inseparable(child: pw.Column(children: [_heading(section.heading), _subjectLine(r)])) : _subjectLine(r),
    if (tr.terms.isEmpty && tr.credits.isEmpty)
      _row('', pw.Text('No subjects recorded yet.', style: const pw.TextStyle(fontSize: 8.5)), '', '', ''),
  ];

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.letter,
    margin: const pw.EdgeInsets.fromLTRB(30, 24, 30, 20),
    header: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.SizedBox(width: 64, height: 64, child: logo != null ? pw.Image(pw.MemoryImage(logo)) : null),
        pw.Expanded(
          child: pw.Column(children: [
            pw.Text('DON BOSCO TECHNICAL COLLEGE - CEBU', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.Text(kSchoolAddress, style: const pw.TextStyle(fontSize: 9)),
            pw.Text('Office of the Registrar', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 4),
            pw.Text('OFFICIAL TRANSCRIPT OF RECORDS', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
        // 2x2 photo, pasted on by the Registrar.
        pw.Container(
          width: 64,
          height: 64,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _line, width: 0.5)),
          child: pw.Text('2x2\nPHOTO', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ),
      ]),
      pw.SizedBox(height: 6),
      _info(tr),
      pw.SizedBox(height: 4),
      _tableHeader(),
    ]),
    footer: (ctx) => _footer(ctx, options, tr.fullName),
    build: (ctx) => lines,
  ));
  return doc.save();
}
