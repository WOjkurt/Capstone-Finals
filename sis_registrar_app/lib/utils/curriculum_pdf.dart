import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/curriculum_models.dart';
import '../models/setup_models.dart';
import 'numbers.dart';
import 'study_load_pdf.dart' show pdfSafe, printPdf;

/// The printed curriculum: every year and semester in order, with hours, units and requisites,
/// and a total under each semester.
///
/// This is the sheet the Registrar hands to a student or checks a study load against, so it
/// follows the shape she already prints from her own system rather than inventing a layout.
Future<void> printCurriculumPdf({
  required CurriculumModel curriculum,
  required List<SubjectModel> subjects,
  bool showGroups = false,
}) async {
  final bytes = await buildCurriculumPdf(
    curriculum: curriculum,
    subjects: subjects,
    showGroups: showGroups,
  );
  await printPdf(bytes, 'Curriculum_${pdfSafe(curriculum.name)}.pdf');
}

Future<Uint8List> buildCurriculumPdf({
  required CurriculumModel curriculum,
  required List<SubjectModel> subjects,
  bool showGroups = false,
}) async {
  final doc = pw.Document(title: pdfSafe('Curriculum ${curriculum.name}'));

  // Year, then semester, then subject code: the order they are meant to be taken in.
  final byYear = <int, Map<int, List<SubjectModel>>>{};
  for (final s in subjects) {
    (byYear[s.yearLevel] ??= <int, List<SubjectModel>>{})
        .putIfAbsent(s.defaultSemester, () => [])
        .add(s);
  }
  for (final year in byYear.values) {
    for (final list in year.values) {
      list.sort((a, b) => a.subjectCode.compareTo(b.subjectCode));
    }
  }

  String requisites(SubjectModel s, {required bool prerequisite}) => s.prerequisites
      .where((p) => (p.requisiteType == 0) == prerequisite)
      .map((p) => p.prerequisiteSubjectCode ?? '')
      .where((c) => c.isNotEmpty)
      .join(', ');

  final header = pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold);
  const cell = pw.TextStyle(fontSize: 7);

  pw.Widget table(List<SubjectModel> rows) {
    double sum(double Function(SubjectModel) pick) => rows.fold(0.0, (t, s) => t + pick(s));

    final widths = showGroups
        ? const {0: pw.FlexColumnWidth(1.1), 1: pw.FlexColumnWidth(2.6), 2: pw.FlexColumnWidth(1.3)}
        : const {0: pw.FlexColumnWidth(1.1), 1: pw.FlexColumnWidth(3.2)};

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: .4),
      columnWidths: {
        ...widths,
        for (var i = showGroups ? 3 : 2; i < (showGroups ? 9 : 8); i++)
          i: const pw.FlexColumnWidth(.75),
        (showGroups ? 7 : 6): const pw.FlexColumnWidth(1.4),
        (showGroups ? 8 : 7): const pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Text('SUBJECT CODE', style: header),
            pw.Text('SUBJECT NAME / DESCRIPTION', style: header),
            if (showGroups) pw.Text('SUBJECT GROUP', style: header),
            pw.Text('LEC HRS', style: header),
            pw.Text('LAB HRS', style: header),
            pw.Text('LEC UNITS', style: header),
            pw.Text('LAB UNITS', style: header),
            pw.Text('PRE-REQUISITE', style: header),
            pw.Text('CO-REQUISITE', style: header),
          ].map((w) => pw.Padding(padding: const pw.EdgeInsets.all(3), child: w)).toList(),
        ),
        for (final s in rows)
          pw.TableRow(
            children: [
              pw.Text(s.subjectCode, style: cell),
              pw.Text(s.subjectTitle, style: cell),
              if (showGroups) pw.Text(s.curriculumName ?? '', style: cell),
              pw.Text(gradeText(s.lecHours), style: cell),
              pw.Text(gradeText(s.labHours), style: cell),
              pw.Text(gradeText(s.lecUnits), style: cell),
              pw.Text(gradeText(s.labUnits), style: cell),
              pw.Text(requisites(s, prerequisite: true), style: cell),
              pw.Text(requisites(s, prerequisite: false), style: cell),
            ].map((w) => pw.Padding(padding: const pw.EdgeInsets.all(3), child: w)).toList(),
          ),
        pw.TableRow(
          children: [
            pw.Text('TOTAL', style: header),
            pw.Text('', style: cell),
            if (showGroups) pw.Text('', style: cell),
            pw.Text(gradeText(sum((s) => s.lecHours)), style: header),
            pw.Text(gradeText(sum((s) => s.labHours)), style: header),
            pw.Text(gradeText(sum((s) => s.lecUnits)), style: header),
            pw.Text(gradeText(sum((s) => s.labUnits)), style: header),
            pw.Text('${gradeText(sum((s) => s.lecUnits + s.labUnits))} academic units', style: header),
            pw.Text('', style: cell),
          ].map((w) => pw.Padding(padding: const pw.EdgeInsets.all(3), child: w)).toList(),
        ),
      ],
    );
  }

  String yearName(int y) => switch (y) {
        1 => 'First Year',
        2 => 'Second Year',
        3 => 'Third Year',
        4 => 'Fourth Year',
        5 => 'Fifth Year',
        _ => 'Year $y',
      };
  String semName(int s) => switch (s) {
        1 => 'First Semester',
        2 => 'Second Semester',
        3 => 'Summer',
        _ => 'Semester $s',
      };

  final years = byYear.keys.toList()..sort();

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.letter.landscape,
    margin: const pw.EdgeInsets.all(24),
    header: (ctx) => ctx.pageNumber > 1
        ? pw.SizedBox()
        : pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('DON BOSCO TECHNICAL COLLEGE - CEBU',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text('Office of the Registrar',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 8),
            pw.Text('Course: ${curriculum.programCode ?? ''}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Text('Curriculum: ${curriculum.name}  -  takes effect ${curriculum.effectiveSchoolYear}',
                style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 10),
          ]),
    footer: (ctx) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
    ),
    build: (ctx) => [
      for (final year in years) ...[
        pw.SizedBox(height: 8),
        pw.Text(yearName(year), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        for (final sem in (byYear[year]!.keys.toList()..sort())) ...[
          pw.SizedBox(height: 4),
          pw.Text(semName(sem),
              style: pw.TextStyle(
                  fontSize: 8, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
          pw.SizedBox(height: 3),
          table(byYear[year]![sem]!),
          pw.SizedBox(height: 6),
        ],
      ],
    ],
  ));

  return doc.save();
}
