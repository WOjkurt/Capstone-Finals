import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/grading_models.dart';
import '../../repositories/student_record_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/student_record_pdf.dart';
import '../../utils/study_load_pdf.dart' show loadSchoolLogo, printPdf;
import '../../utils/transcript_pdf.dart';

String _fileName(String prefix, String name) => '${prefix}_${name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf';

/// Pick one semester or one subject, then print its grade sheet.
class GradeSheetDialog extends StatefulWidget {
  final List<StudentGradeModel> grades;
  final RecordStudentInfo student;

  const GradeSheetDialog({super.key, required this.grades, required this.student});

  static Future<void> show(BuildContext context, {required List<StudentGradeModel> grades, required RecordStudentInfo student}) =>
      showDialog<void>(context: context, builder: (_) => GradeSheetDialog(grades: grades, student: student));

  @override
  State<GradeSheetDialog> createState() => _GradeSheetDialogState();
}

class _GradeSheetDialogState extends State<GradeSheetDialog> {
  bool _bySubject = false;
  String? _term;
  String? _subject;
  bool _printing = false;

  /// Terms newest first, as on the Grades tab.
  late final List<String> _terms = () {
    final sorted = [...widget.grades]..sort((a, b) {
        final year = (b.schoolYear ?? '').compareTo(a.schoolYear ?? '');
        return year != 0 ? year : (b.semester ?? 0).compareTo(a.semester ?? 0);
      });
    return sorted.map((g) => g.termLabel ?? 'Unknown term').toSet().toList();
  }();

  late final Map<String, String> _subjects = {
    for (final g in [...widget.grades]..sort((a, b) => (a.subjectCode ?? '').compareTo(b.subjectCode ?? '')))
      if (g.subjectCode != null) g.subjectCode!: '${g.subjectCode} — ${g.subjectTitle ?? ''}',
  };

  @override
  void initState() {
    super.initState();
    _term = _terms.firstOrNull;
    _subject = _subjects.keys.firstOrNull;
  }

  Future<void> _print() async {
    final picked = _bySubject
        ? widget.grades.where((g) => g.subjectCode == _subject).toList()
        : widget.grades.where((g) => (g.termLabel ?? 'Unknown term') == _term).toList();
    // A student with no subjects yet still gets a blank sheet.
    if (picked.isEmpty && widget.grades.isNotEmpty) return;
    setState(() => _printing = true);
    try {
      final bytes = await buildGradeSheetPdf(
        picked,
        student: widget.student,
        scope: widget.grades.isEmpty
            ? 'No subjects on record yet'
            : _bySubject
                ? 'Subject: ${_subjects[_subject]}'
                : 'Semester: $_term',
        bySubject: _bySubject,
        logo: await loadSchoolLogo(),
      );
      await printPdf(bytes, _fileName('Grade_Sheet', widget.student.name));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _printing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not print: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Print grade sheet'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              key: const ValueKey('grade_sheet_mode'),
              segments: const [
                ButtonSegment(value: false, label: Text('One semester'), icon: Icon(Icons.calendar_month_outlined)),
                ButtonSegment(value: true, label: Text('One subject'), icon: Icon(Icons.menu_book_outlined)),
              ],
              selected: {_bySubject},
              onSelectionChanged: (s) => setState(() => _bySubject = s.first),
            ),
            const SizedBox(height: 16),
            if (_bySubject)
              DropdownButtonFormField<String>(
                key: const ValueKey('grade_sheet_subject'),
                initialValue: _subject,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder(), isDense: true),
                items: [
                  for (final e in _subjects.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _subject = v),
              )
            else
              DropdownButtonFormField<String>(
                key: const ValueKey('grade_sheet_term'),
                initialValue: _term,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Semester', border: OutlineInputBorder(), isDense: true),
                items: [for (final t in _terms) DropdownMenuItem(value: t, child: Text(t))],
                onChanged: (v) => setState(() => _term = v),
              ),
            const SizedBox(height: 8),
            Text(
              widget.grades.isEmpty
                  ? 'This student has no subjects yet, so the sheet prints blank.'
                  : _bySubject
                      ? 'Lists every time the student took this subject.'
                      : 'Lists the semester\'s subjects, with or without grades, and its GWA.',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton.icon(
          key: const ValueKey('grade_sheet_print'),
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('Print'),
          onPressed: _printing ? null : _print,
        ),
      ],
    );
  }
}

/// Fill in the remarks and signatories, then print the Transcript of Records.
class TranscriptPrintDialog extends StatefulWidget {
  final String userId;
  final String studentName;

  const TranscriptPrintDialog({super.key, required this.userId, required this.studentName});

  static Future<void> show(BuildContext context, {required String userId, required String studentName}) =>
      showDialog<void>(context: context, builder: (_) => TranscriptPrintDialog(userId: userId, studentName: studentName));

  @override
  State<TranscriptPrintDialog> createState() => _TranscriptPrintDialogState();
}

class _TranscriptPrintDialogState extends State<TranscriptPrintDialog> {
  final _remarks = TextEditingController();
  final _preparedBy = TextEditingController();
  final _checkedBy = TextEditingController();
  final _registrar = TextEditingController();
  bool _printing = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_remarks, _preparedBy, _checkedBy, _registrar]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _print() async {
    setState(() {
      _printing = true;
      _error = null;
    });
    try {
      final transcript = await getIt<StudentRecordRepository>().transcript(widget.userId);
      final bytes = await buildTranscriptPdf(
        transcript,
        options: TranscriptPrintOptions(
          remarks: _remarks.text,
          preparedBy: _preparedBy.text.trim(),
          checkedBy: _checkedBy.text.trim(),
          registrar: _registrar.text.trim(),
        ),
        logo: await loadSchoolLogo(),
      );
      await printPdf(bytes, _fileName('TOR', widget.studentName));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _printing = false;
          _error = e is ApiException ? e.message : e.toString();
        });
      }
    }
  }

  Widget _field(String key, TextEditingController c, String label, {String? hint, int maxLines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: ValueKey(key),
          controller: c,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), isDense: true),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Transcript of Records — ${widget.studentName}'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text(
                'The transcript lists every semester and credited subject. Leave a name empty to sign by hand.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            _field('tor_remarks', _remarks, 'Remarks', hint: 'e.g. For transfer purposes', maxLines: 2),
            _field('tor_prepared_by', _preparedBy, 'Prepared by'),
            _field('tor_checked_by', _checkedBy, 'Checked by'),
            _field('tor_registrar', _registrar, 'Registrar'),
            if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton.icon(
          key: const ValueKey('tor_print'),
          icon: _printing
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.print_outlined, size: 18),
          label: const Text('Print'),
          onPressed: _printing ? null : _print,
        ),
      ],
    );
  }
}
