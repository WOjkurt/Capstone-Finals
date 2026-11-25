import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../injection.dart';
import '../../models/grading_models.dart';
import '../../models/record_models.dart';
import '../../repositories/grading_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/student_record_pdf.dart';
import '../../utils/study_load_pdf.dart' show loadSchoolLogo, printPdf;
import '../../utils/certificate_pdf.dart' show CertificateKind;
import 'record_print_dialogs.dart';
import 'record_table.dart';
import '../../utils/numbers.dart';

/// Read-only grade history of one student, grouped by term (newest first).
/// Failed subjects that were never passed later are listed at the top as retake candidates.
final _day = DateFormat('MMM d, yyyy');

class StudentGradesDialog extends StatefulWidget {
  final String userId;
  final String studentName;

  /// Printed under the title of the residency record.
  final String? lrn;
  final String? programCode;
  final int? yearLevel;

  /// Printed on certificates.
  final String? studentId;

  /// Shown inside the Students page's "Grades" tab instead of as a window.
  final bool embedded;

  const StudentGradesDialog({
    super.key,
    required this.userId,
    required this.studentName,
    this.lrn,
    this.programCode,
    this.yearLevel,
    this.studentId,
    this.embedded = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required String studentName,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) =>
          StudentGradesDialog(userId: userId, studentName: studentName),
    );
  }

  @override
  State<StudentGradesDialog> createState() => _StudentGradesDialogState();
}

class _StudentGradesDialogState extends State<StudentGradesDialog> {
  List<StudentGradeModel>? _grades;
  List<CreditedSubjectModel> _credits = [];
  String? _error;
  bool _failedOnly = false;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _grades = null;
      _error = null;
    });
    try {
      final grades =
          await getIt<StudentGradeRepository>().getStudentGrades(widget.userId);
      // Credits are extra information; the grades still show if they fail to load.
      var credits = <CreditedSubjectModel>[];
      try {
        credits = await getIt<CreditedSubjectRepository>().getForStudent(widget.userId);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _grades = grades;
          _credits = credits;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : e.toString());
      }
    }
  }

  /// Groups grades by term, newest term first.
  List<MapEntry<String, List<StudentGradeModel>>> _byTerm(
      List<StudentGradeModel> grades) {
    final sorted = [...grades]..sort((a, b) {
        final year = (b.schoolYear ?? '').compareTo(a.schoolYear ?? '');
        if (year != 0) return year;
        final sem = (b.semester ?? 0).compareTo(a.semester ?? 0);
        if (sem != 0) return sem;
        return (a.subjectCode ?? '').compareTo(b.subjectCode ?? '');
      });
    final groups = <String, List<StudentGradeModel>>{};
    for (final g in sorted) {
      groups.putIfAbsent(g.termLabel ?? 'Unknown term', () => []).add(g);
    }
    return groups.entries.toList();
  }

  /// Prints every semester's grades (the "Failed only" filter does not apply to the printout).
  Future<void> _print() async {
    final grades = _grades;
    if (grades == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The grades are still loading. Try again in a moment.')),
      );
      return;
    }
    setState(() => _printing = true);
    try {
      final bytes = await buildResidencyPdf(
        grades,
        credits: _credits,
        student: _info,
        logo: await loadSchoolLogo(),
      );
      await printPdf(bytes, 'Residency_${widget.studentName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not print: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  RecordStudentInfo get _info => RecordStudentInfo(
        name: widget.studentName,
        lrn: widget.lrn,
        programCode: widget.programCode,
        yearLevel: widget.yearLevel,
      );

  /// Residency record, grade sheet (one semester or subject) and Transcript of Records.
  Widget get _printButton => PopupMenuButton<String>(
        key: const ValueKey('print_menu'),
        enabled: !_printing && _grades != null,
        tooltip: 'Print',
        onSelected: (choice) {
          switch (choice) {
            case 'residency':
              _print();
            case 'grade_sheet':
              GradeSheetDialog.show(context, grades: _grades ?? const [], student: _info);
            case 'tor':
              TranscriptPrintDialog.show(context, userId: widget.userId, studentName: widget.studentName);
            case 'coe' || 'cog':
              CertificateDialog.show(context,
                  kind: choice == 'coe' ? CertificateKind.enrollment : CertificateKind.grades,
                  grades: _grades ?? const [],
                  studentName: widget.studentName,
                  studentId: widget.studentId,
                  programCode: widget.programCode,
                  yearLevel: widget.yearLevel);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            key: ValueKey('print_residency_button'),
            value: 'residency',
            child: ListTile(leading: Icon(Icons.history_edu_outlined), title: Text('Residency record'), subtitle: Text('All semesters with GWA')),
          ),
          PopupMenuItem(
            key: const ValueKey('print_grade_sheet_button'),
            value: 'grade_sheet',
            child: const ListTile(leading: Icon(Icons.description_outlined), title: Text('Grade sheet…'), subtitle: Text('One semester or one subject')),
          ),
          const PopupMenuItem(
            key: ValueKey('print_tor_button'),
            value: 'tor',
            child: ListTile(leading: Icon(Icons.workspace_premium_outlined), title: Text('Transcript of Records…'), subtitle: Text('Official TOR')),
          ),
          const PopupMenuItem(
            key: ValueKey('print_coe_button'),
            value: 'coe',
            child: ListTile(leading: Icon(Icons.how_to_reg_outlined), title: Text('Certificate of Enrollment…'), subtitle: Text('One term')),
          ),
          const PopupMenuItem(
            key: ValueKey('print_cog_button'),
            value: 'cog',
            child: ListTile(leading: Icon(Icons.grading_outlined), title: Text('Certificate of Grades…'), subtitle: Text('One term, with GWA')),
          ),
        ],
        child: AbsorbPointer(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Print'),
            onPressed: (_printing || _grades == null) ? null : () {},
          ),
        ),
      );

  Widget get _failedOnlyChip => FilterChip(
        key: const ValueKey('failed_only_chip'),
        label: const Text('Failed only'),
        selected: _failedOnly,
        onSelected: (v) => setState(() => _failedOnly = v),
      );

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_failedOnlyChip, const SizedBox(width: 8), _printButton],
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ],
      );
    }
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 760,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grading_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Grades — ${widget.studentName}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _failedOnlyChip,
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Could not load grades: $_error',
              style: const TextStyle(color: Color(0xFFDC2626))),
          const SizedBox(height: 8),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }
    final grades = _grades;
    if (grades == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (grades.isEmpty && _credits.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('No subjects on record for this student yet.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final unresolved = unresolvedFailedSubjects(grades,
        // Only a full-units credit settles a failed subject.
        creditedCodes: _credits.where((c) => !c.isPartial).map((c) => c.subjectCode));
    final shown = _failedOnly ? grades.where((g) => g.isFailed).toList() : grades;

    final gwa = computeGwa(grades);
    return ListView(
      shrinkWrap: true,
      children: [
        if (gwa != null && !_failedOnly)
          Container(
            key: const ValueKey('overall_gwa'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.scaffoldBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Text(averageText(gwa),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Overall GWA — graded subjects taken at DBTC, weighted by units (NSTP and PE not included)',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        if (unresolved.isNotEmpty)
          Container(
            key: const ValueKey('retake_summary'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Text(
              'Not yet passed (retake needed): ${unresolved.join(', ')}. '
              'Add them under "Retake candidates" when building a later term\'s study load.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
            ),
          ),
        if (_credits.isNotEmpty && !_failedOnly) ...[
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 4),
            child: Text('Credited from other schools and cross-enrollment',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentGreenDark)),
          ),
          for (final c in _credits)
            Container(
              key: ValueKey('credited_row_${c.subjectCode}'),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${c.subjectCode} — ${c.subjectTitle}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${c.isCrossEnrollment ? 'Cross-enrolled at' : 'Credited from'} ${c.sourceSchool}'
                    '${c.grade != null ? ' · ${c.grade}' : ''}'
                    '${c.isPartial ? ' · ${c.creditedUnits.toStringAsFixed(c.creditedUnits % 1 == 0 ? 0 : 1)} of ${c.units.toStringAsFixed(c.units % 1 == 0 ? 0 : 1)} units' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.accentGreenDark),
                  ),
                ],
              ),
            ),
        ],
        if (shown.isEmpty && (grades.isNotEmpty || _failedOnly))
          const Text('No failed subjects.',
              style: TextStyle(color: AppColors.textSecondary)),
        for (final term in _byTerm(shown)) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(term.key,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
                if (!_failedOnly && computeGwa(term.value) != null)
                  Text('GWA ${averageText(computeGwa(term.value)!)}',
                      key: ValueKey('term_gwa_${term.key}'),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          RecordTable(
            columns: _columns,
            rows: [
              for (final g in term.value)
                RecordRow(
                  // The last cell is screen-only: the printed record has no buttons in it.
                  [...gradeCells(g), ''],
                  color: _rowColor(g),
                  widgets: {gradeCells(g).length: _rowActions(g)},
                ),
            ],
            // The screen-only actions column needs a cell here too, or the table has a hole.
            totals: _failedOnly ? null : [...gradeTotals(term.value), ''],
          ),
        ],
      ],
    );
  }

  /// A pencil on every recorded mark, and a mark of its own where one has already been changed.
  /// Any term, not only the active one: on the live data every grade belongs to a past term, so
  /// restricting it to the active term left nothing to edit anywhere.
  Widget _rowActions(StudentGradeModel g) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (g.modifiedAt != null)
            Tooltip(
              key: ValueKey('grade_changed_${g.gradeId}'),
              message: 'Changed by the Registrar on ${_day.format(g.modifiedAt!.toLocal())}',
              child: const Icon(Icons.history_rounded, size: 15, color: AppColors.textMuted),
            ),
          if (g.canModify)
            IconButton(
              key: ValueKey('edit_grade_${g.gradeId}'),
              icon: const Icon(Icons.edit_outlined, size: 15),
              tooltip: 'Change this grade',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 2),
              onPressed: () => _editGrade(g),
            ),
        ],
      );

  /// Changing a recorded mark. The reason is required because it is the only thing separating
  /// a correction from a quiet rewrite of somebody's record.
  Future<void> _editGrade(StudentGradeModel g) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditGradeDialog(grade: g, studentName: widget.studentName),
    );
    if (saved == true && mounted) await _load();
  }

  static const _columns = [
    RecordColumn('Course Code', 1.1),
    RecordColumn('Descriptive Title', 3),
    RecordColumn('Credit', .7, center: true),
    RecordColumn('Midterm', .8, center: true),
    RecordColumn('Final Grade', .8, center: true),
    RecordColumn('Remarks', 1.1),
    RecordColumn('Instructor', 1.6),
    // Screen only. gradeCells() still returns the seven the printout uses.
    RecordColumn('', .85, center: true),
  ];

  static Color _rowColor(StudentGradeModel g) => g.loadStatus == 2 || g.loadStatus == 3
      ? RecordColors.droppedOrWithdrawn
      : g.isFailed
          ? RecordColors.failed
          : g.isPassed
              ? RecordColors.taken
              : RecordColors.inProgress;
}


/// Changing one recorded grade.
///
/// Replaces the correction request, which asked somebody to approve what the Registrar was
/// going to do anyway — with almost no class having a teacher, there was nobody else in it.
/// What the request did carry was a reason and a trail, and both are kept here.
class _EditGradeDialog extends StatefulWidget {
  final StudentGradeModel grade;
  final String studentName;

  const _EditGradeDialog({required this.grade, required this.studentName});

  @override
  State<_EditGradeDialog> createState() => _EditGradeDialogState();
}

class _EditGradeDialogState extends State<_EditGradeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _midterm =
      TextEditingController(text: widget.grade.midtermGrade?.toStringAsFixed(2) ?? '');
  late final TextEditingController _finalGrade =
      TextEditingController(text: widget.grade.finalGrade?.toStringAsFixed(2) ?? '');
  final _reason = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _midterm.dispose();
    _finalGrade.dispose();
    _reason.dispose();
    super.dispose();
  }

  /// The same scale the server enforces: 1.0 to 5.0, in tenths or quarters.
  static String? _gradeProblem(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null) return 'Numbers only';
    if (value < 1.0 || value > 5.0) return '1.00 to 5.00';
    final hundredths = (value * 100).round();
    if (hundredths % 10 != 0 && hundredths % 25 != 0) return 'Steps of 0.1, or .25 / .75';
    return null;
  }

  static double? _value(TextEditingController c) =>
      c.text.trim().isEmpty ? null : double.tryParse(c.text.trim());

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_value(_midterm) == null && _value(_finalGrade) == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Give a midterm grade, a final grade, or both.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      await getIt<StudentGradeRepository>().modifyGrade(
        gradeId: widget.grade.gradeId,
        midtermGrade: _value(_midterm),
        finalGrade: _value(_finalGrade),
        reason: _reason.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(getFriendlyErrorMessage(e, st)),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.grade;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text('Change grade — ${g.subjectCode ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${widget.studentName} · ${g.subjectTitle ?? ''} · ${g.termLabel ?? ''}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('edit_grade_midterm'),
                      controller: _midterm,
                      decoration: const InputDecoration(labelText: 'Midterm', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: _gradeProblem,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('edit_grade_final'),
                      controller: _finalGrade,
                      decoration: const InputDecoration(labelText: 'Final', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: _gradeProblem,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Leave a box empty to keep the mark that is there. Changing the final '
                  'decides passed or failed again.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('edit_grade_reason'),
                controller: _reason,
                decoration: const InputDecoration(
                  labelText: 'Why is it being changed? *',
                  hintText: 'e.g. encoded from the wrong column of the sheet',
                  border: OutlineInputBorder(),
                ),
                maxLength: 300,
                maxLines: 2,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Say why the grade is being changed' : null,
              ),
              const Text('This is kept on the activity log with the old and new marks. The '
                  'student is shown that the grade changed, but not this note.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('edit_grade_save'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save change'),
        ),
      ],
    );
  }
}
