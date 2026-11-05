import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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
