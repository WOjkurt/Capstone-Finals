import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/class_models.dart';

/// What goes on a printed study load.
class StudyLoadPrintData {
  final String studentName;
  final String? lrn;
  final String? programCode;
  final int? yearLevel;
  final String termLabel;
  final List<ClassRosterItemModel> loads;
  final DateTime printedAt;

  StudyLoadPrintData({
    required this.studentName,
    this.lrn,
    this.programCode,
    this.yearLevel,
    required this.termLabel,
    required List<ClassRosterItemModel> loads,
    DateTime? printedAt,
  }) : loads = loads.where((l) => l.isEnrolled).toList()
         ..sort((a, b) => a.subjectCode.compareTo(b.subjectCode)),
       printedAt = printedAt ?? DateTime.now();

  double get totalUnits => loads.fold(0, (sum, l) => sum + l.units);
}

/// The built-in PDF fonts only cover Latin-1, so replace dashes and drop anything else outside it.
String pdfSafe(String text) => text
    .replaceAll('–', '-')
    .replaceAll('—', '-')
    .replaceAll('’', "'")
    .replaceAll(RegExp(r'[^\x00-\xFF]'), '?');

String _units(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

String loadSchedule(ClassRosterItemModel l) {
  if (l.schedules.isEmpty) return 'TBA';
  return l.schedules
      .map((s) => '${s.daysOfWeek} ${s.formattedTime}'.trim())
      .join('\n');
}

String loadRooms(ClassRosterItemModel l) {
  final rooms = l.schedules
      .map((s) => s.room.trim())
      .where((r) => r.isNotEmpty)
      .toSet();
  return rooms.isEmpty ? 'TBA' : rooms.join('\n');
}

String _date(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// DBTC prints three copies of the OES: one each for the College Head, the Registrar and the student.
const int kOesCopies = 3;

/// Builds the Official Enrollment Sheet PDF with [copies] identical copies.
/// [logo] is the school seal (PNG bytes), optional.
Future<Uint8List> buildStudyLoadPdf(
  StudyLoadPrintData data, {
  Uint8List? logo,
  bool compress = true,
  int copies = kOesCopies,
}) async {
  final doc = pw.Document(
    compress: compress,
    title: 'Official Enrollment Sheet - ${pdfSafe(data.studentName)}',
  );
  final small = const pw.TextStyle(fontSize: 8);
  final label = pw.TextStyle(fontSize: 9, color: PdfColors.grey700);
  final value = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);

  pw.Widget info(String l, String v) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      children: [
        pw.SizedBox(width: 70, child: pw.Text(l, style: label)),
        pw.Expanded(child: pw.Text(pdfSafe(v), style: value)),
      ],
    ),
  );

  pw.Widget signature(String role) => pw.Column(
    children: [
      pw.Container(width: 150, height: 0.5, color: PdfColors.black),
      pw.SizedBox(height: 3),
      pw.Text(role, style: label),
    ],
  );

  for (var i = 0; i < copies; i++) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => pw.Column(
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logo != null)
                  pw.Container(
                    width: 48,
                    height: 48,
                    margin: const pw.EdgeInsets.only(right: 10),
                    child: pw.Image(pw.MemoryImage(logo)),
                  ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DON BOSCO TECHNICAL COLLEGE - CEBU',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text('Office of the Registrar', style: label),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'OFFICIAL ENROLLMENT SHEET',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [pw.Text('Printed ${_date(data.printedAt)}', style: small)],
        ),
        build: (ctx) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  children: [
                    info('Name', data.studentName),
                    info('LRN', data.lrn?.isNotEmpty == true ? data.lrn! : '-'),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    info('Program', data.programCode ?? '-'),
                    info(
                      'Year level',
                      data.yearLevel != null ? 'Year ${data.yearLevel}' : '-',
                    ),
                    info('Term', data.termLabel),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: [
              'Code',
              'Subject',
              'Units',
              'Section',
              'Schedule',
              'Room',
              'Teacher',
            ],
            data: [
              for (final l in data.loads)
                [
                  pdfSafe(l.subjectCode),
                  pdfSafe(l.subjectTitle),
                  _units(l.units),
                  pdfSafe(l.className),
                  pdfSafe(loadSchedule(l)),
                  pdfSafe(loadRooms(l)),
                  pdfSafe(l.teacherName ?? 'TBA'),
                ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellStyle: small,
            cellAlignments: {2: pw.Alignment.topCenter},
            columnWidths: {
              0: const pw.FixedColumnWidth(52),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(30),
              3: const pw.FixedColumnWidth(52),
              4: const pw.FlexColumnWidth(2.2),
              5: const pw.FixedColumnWidth(48),
              6: const pw.FlexColumnWidth(1.6),
            },
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                '${data.loads.length} subjects    Total units: ${_units(data.totalUnits)}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 50),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              signature('Student'),
              signature('College Head'),
              signature('Registrar'),
            ],
          ),
        ],
      ),
    );
  }
  return doc.save();
}

/// Opens the browser print dialog for the PDF. Tests replace this.
Future<void> Function(Uint8List bytes, String fileName) printPdf =
    (bytes, fileName) =>
        Printing.layoutPdf(onLayout: (_) async => bytes, name: fileName);

Future<Uint8List?> loadSchoolLogo() async {
  try {
    final data = await rootBundle.load('assets/images/dbtc_logo.png');
    return data.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}
