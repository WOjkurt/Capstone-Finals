import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/report_models.dart';
import 'study_load_pdf.dart' show pdfSafe;

/// A plain printed report: school header, title, one bordered table, page numbers.
/// Wide tables ([landscape]) print sideways.
Future<Uint8List> buildReportPdf({
  required String title,
  String? subtitle,
  required List<String> headers,
  required List<List<Object?>> rows,
  bool landscape = false,
  Uint8List? logo,
  bool compress = true,
  DateTime? printedAt,
}) {
  final when = printedAt ?? DateTime.now();
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final doc = pw.Document(compress: compress, title: pdfSafe(title));
  final small = const pw.TextStyle(fontSize: 7);
  doc.addPage(pw.MultiPage(
    pageFormat: landscape ? PdfPageFormat.letter.landscape : PdfPageFormat.letter,
    margin: const pw.EdgeInsets.all(28),
    header: (ctx) => ctx.pageNumber > 1
        ? pw.SizedBox()
        : pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            pw.Row(children: [
              if (logo != null)
                pw.Container(width: 36, height: 36, margin: const pw.EdgeInsets.only(right: 8), child: pw.Image(pw.MemoryImage(logo))),
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('DON BOSCO TECHNICAL COLLEGE - CEBU', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Office of the Registrar', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                ]),
              ),
            ]),
            pw.SizedBox(height: 8),
            pw.Center(child: pw.Text(pdfSafe(title.toUpperCase()), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
            if (subtitle != null) pw.Center(child: pw.Text(pdfSafe(subtitle), style: const pw.TextStyle(fontSize: 9))),
            pw.SizedBox(height: 8),
          ]),
    footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('Printed ${months[when.month - 1]} ${when.day}, ${when.year}', style: small),
      pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: small),
    ]),
    build: (ctx) => [
      pw.TableHelper.fromTextArray(
        headers: headers.map(pdfSafe).toList(),
        data: [for (final r in rows) [for (final c in r) pdfSafe('${c ?? ''}')]],
        headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellStyle: const pw.TextStyle(fontSize: 7.5),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey600),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Text('${rows.where((r) => r.isEmpty || r.first != 'TOTAL').length} row(s)', style: small),
      ),
    ],
  ));
  return doc.save();
}

/// Enrollment statistics: one row per program, columns 1st to 4th Year each split into M and F,
/// then Total M, F and both, with a TOTAL row. [rows] cells are the program then 11 numbers.
Future<Uint8List> buildEnrollmentStatisticsPdf({
  required String termLabel,
  required List<List<Object?>> rows,
  String? note,
  Uint8List? logo,
  bool compress = true,
  DateTime? printedAt,
}) {
  final when = printedAt ?? DateTime.now();
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final doc = pw.Document(compress: compress, title: 'Enrollment Statistics');
  final format = PdfPageFormat.letter.landscape;
  const margin = 28.0;
  const programW = 200.0;
  final numW = (format.width - 2 * margin - programW) / 11;
  const rowH = 18.0;
  final line = pw.BorderSide(color: PdfColors.grey700, width: 0.5);
  final bold = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);

  pw.Widget cell(String text, double width, {pw.TextStyle? style, bool left = false, PdfColor? fill, double? height}) => pw.Container(
        width: width,
        height: height,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        alignment: left ? pw.Alignment.centerLeft : pw.Alignment.center,
        decoration: pw.BoxDecoration(color: fill, border: pw.Border(right: line, bottom: line)),
        child: pw.Text(pdfSafe(text), style: style ?? const pw.TextStyle(fontSize: 9)),
      );

  // Two header rows: year groups over M / F, as on the printed school forms.
  final header = pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border(left: line, top: line)),
    // Fixed heights: a page layout cannot stretch cells to match each other.
    child: pw.Row(children: [
      cell('Program', programW, style: bold, fill: PdfColors.grey200, height: 2 * rowH),
      pw.Column(children: [
        pw.Row(children: [
          for (final y in ['1st Year', '2nd Year', '3rd Year', '4th Year'])
            cell(y, numW * 2, style: bold, fill: PdfColors.grey200, height: rowH),
          cell('Total', numW * 3, style: bold, fill: PdfColors.grey200, height: rowH),
        ]),
        pw.Row(children: [
          for (var i = 0; i < 4; i++) ...[
            cell('M', numW, style: bold, fill: PdfColors.grey100, height: rowH),
            cell('F', numW, style: bold, fill: PdfColors.grey100, height: rowH),
          ],
          cell('M', numW, style: bold, fill: PdfColors.grey100, height: rowH),
          cell('F', numW, style: bold, fill: PdfColors.grey100, height: rowH),
          cell('Total', numW, style: bold, fill: PdfColors.grey100, height: rowH),
        ]),
      ]),
    ]),
  );

  pw.Widget dataRow(List<Object?> r) {
    final total = r.first == 'TOTAL';
    final style = total ? bold : null;
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border(left: line)),
      child: pw.Row(children: [
        cell('${r.first ?? ''}', programW, style: style, left: true),
        for (final c in r.skip(1)) cell('${c ?? ''}', numW, style: style),
      ]),
    );
  }

  doc.addPage(pw.MultiPage(
    pageFormat: format,
    margin: const pw.EdgeInsets.all(margin),
    header: (ctx) => ctx.pageNumber > 1
        ? pw.SizedBox()
        : pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            pw.Row(children: [
              if (logo != null)
                pw.Container(width: 36, height: 36, margin: const pw.EdgeInsets.only(right: 8), child: pw.Image(pw.MemoryImage(logo))),
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('DON BOSCO TECHNICAL COLLEGE - CEBU', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Office of the Registrar', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                ]),
              ),
            ]),
            pw.SizedBox(height: 8),
            pw.Center(child: pw.Text('ENROLLMENT STATISTICS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
            pw.Center(child: pw.Text(pdfSafe(termLabel), style: const pw.TextStyle(fontSize: 10))),
            pw.SizedBox(height: 10),
          ]),
    footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('Printed ${months[when.month - 1]} ${when.day}, ${when.year}', style: const pw.TextStyle(fontSize: 7)),
      pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7)),
    ]),
    build: (ctx) => [
      header,
      for (final r in rows) dataRow(r),
      if (note != null)
        pw.Padding(padding: const pw.EdgeInsets.only(top: 6), child: pw.Text(pdfSafe(note), style: const pw.TextStyle(fontSize: 8))),
    ],
  ));
  return doc.save();
}

/// Class lists, one class per page (a long class continues on the next page): class details,
/// a numbered list of Enrolled students, Male/Female/Total counts and the teacher's signature line.
Future<Uint8List> buildClassListsPdf(
  List<ClassList> classes, {
  Uint8List? logo,
  bool compress = true,
  DateTime? printedAt,
}) {
  final when = printedAt ?? DateTime.now();
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final doc = pw.Document(compress: compress, title: 'Class Lists');
  final label = const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700);
  final value = pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold);

  pw.Widget info(String l, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: 60, child: pw.Text(l, style: label)),
          pw.Expanded(child: pw.Text(pdfSafe(v), style: value)),
        ]),
      );

  for (final c in classes) {
    final male = c.students.where((s) => s.sex == 'M').length;
    final female = c.students.where((s) => s.sex == 'F').length;
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Row(children: [
          if (logo != null)
            pw.Container(width: 36, height: 36, margin: const pw.EdgeInsets.only(right: 8), child: pw.Image(pw.MemoryImage(logo))),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('DON BOSCO TECHNICAL COLLEGE - CEBU', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text('Office of the Registrar', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            ]),
          ),
        ]),
        pw.SizedBox(height: 6),
        pw.Center(child: pw.Text('CLASS LIST', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 8),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Column(children: [
            info('Subject', '${c.subjectCode} - ${c.subjectTitle}'),
            info('Section', c.className),
            info('Units', c.units.toStringAsFixed(c.units.truncateToDouble() == c.units ? 0 : 1)),
          ])),
          pw.SizedBox(width: 16),
          pw.Expanded(child: pw.Column(children: [
            info('Term', c.termLabel),
            info('Teacher', c.teacherName ?? 'TBA'),
            info('Schedule', c.schedules.isEmpty ? 'TBA' : c.schedules.join('\n')),
          ])),
        ]),
        pw.SizedBox(height: 8),
      ]),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(pdfSafe('${c.subjectCode} ${c.className} · Printed ${months[when.month - 1]} ${when.day}, ${when.year}'),
            style: const pw.TextStyle(fontSize: 7)),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7)),
      ]),
      build: (ctx) => [
        pw.TableHelper.fromTextArray(
          headers: ['No.', 'Student name', 'LRN', 'Program & Year', 'Sex'],
          data: [
            for (final (i, s) in c.students.indexed)
              [
                '${i + 1}',
                pdfSafe(s.name),
                s.lrn ?? '',
                [s.programCode, if (s.yearLevel != null) '${s.yearLevel}'].whereType<String>().join(' '),
                s.sex ?? '',
              ],
          ],
          headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellStyle: const pw.TextStyle(fontSize: 8.5),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey600),
          columnWidths: const {
            0: pw.FixedColumnWidth(30),
            1: pw.FlexColumnWidth(3),
            2: pw.FixedColumnWidth(90),
            3: pw.FixedColumnWidth(80),
            4: pw.FixedColumnWidth(32),
          },
          cellAlignments: const {0: pw.Alignment.center, 4: pw.Alignment.center},
        ),
        if (c.students.isEmpty)
          pw.Padding(padding: const pw.EdgeInsets.only(top: 6), child: pw.Text('No enrolled students.', style: label)),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Male: $male    Female: $female    Total: ${c.students.length}'
            '${c.students.length - male - female > 0 ? '    (sex not on record: ${c.students.length - male - female})' : ''}',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 40),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Column(children: [
              pw.Container(width: 180, height: 0.5, color: PdfColors.black),
              pw.SizedBox(height: 3),
              pw.Text(pdfSafe(c.teacherName ?? 'Teacher'), style: value),
              pw.Text('Teacher', style: label),
            ]),
          ]),
        ),
      ],
    ));
  }
  if (classes.isEmpty) {
    doc.addPage(pw.Page(build: (_) => pw.Center(child: pw.Text('No classes in this term.'))));
  }
  return doc.save();
}
