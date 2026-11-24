import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/grading_models.dart';
import '../../models/record_models.dart';
import '../../models/setup_models.dart';
import '../../repositories/accredited_school_repository.dart';
import '../../repositories/enrollment_repository.dart';
import '../../repositories/grading_repository.dart';
import '../../repositories/student_record_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/numbers.dart';

/// Credits for shiftees name DBTC itself, with the old program, so they need no accredited school.
const _dbtcName = 'Don Bosco Technical College - Cebu';

/// Subjects a transferee or shiftee passed at another school, credited to DBTC subjects.
/// Credited subjects count as passed for prerequisites, the study load builder and year-level promotion.
class CreditedSubjectsDialog extends StatefulWidget {
  final UserSearchResultModel student;

  /// Shown inside the Students page's "Credits" tab instead of as a window.
  final bool embedded;

  const CreditedSubjectsDialog({super.key, required this.student, this.embedded = false});

  static Future<void> show(BuildContext context, {required UserSearchResultModel student}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => CreditedSubjectsDialog(student: student),
    );
  }

  @override
  State<CreditedSubjectsDialog> createState() => _CreditedSubjectsDialogState();
}

class _CreditedSubjectsDialogState extends State<CreditedSubjectsDialog> {
  List<CreditedSubjectModel>? _credits;
  List<SubjectModel> _subjects = [];
  String? _error;
  bool _saving = false;
  String? _formError;

  String? _subjectId;
  // Bumped after each add so the subject dropdown starts empty again.
  int _formVersion = 0;
  final _school = TextEditingController();
  final _schoolFocus = FocusNode();
  final _units = TextEditingController();
  // Cross-enrolled during a DBTC term, rather than taken before DBTC.
  bool _cross = false;
  String? _termId;
  List<AcademicTermModel> _terms = [];
  List<PreviousProgramSubject> _previous = [];
  List<String> _schoolNames = [];
  final _theirCode = TextEditingController();
  final _grade = TextEditingController();
  final _schoolYear = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _school.dispose();
    _schoolFocus.dispose();
    _units.dispose();
    _theirCode.dispose();
    _grade.dispose();
    _schoolYear.dispose();
    super.dispose();
  }

  String _message(Object e) => e is ApiException ? e.message : e.toString();

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final credits =
          await getIt<CreditedSubjectRepository>().getForStudent(widget.student.userId);
      final subjects = widget.student.programId == null
          ? <SubjectModel>[]
          : await getIt<AcademicSetupRepository>()
              .getSubjects(programId: widget.student.programId);
      subjects.sort((a, b) {
        final y = a.yearLevel.compareTo(b.yearLevel);
        return y != 0 ? y : a.subjectCode.compareTo(b.subjectCode);
      });
      // The school list only helps with spelling; credits still load if it fails.
      var schoolNames = <String>[];
      try {
        schoolNames = [for (final s in await getIt<AccreditedSchoolRepository>().getAll()) s.name];
      } catch (_) {}
      // Only a shiftee has these; the rest of the tab works without them.
      var previous = <PreviousProgramSubject>[];
      try {
        previous = await getIt<StudentRecordRepository>().previousProgramSubjects(widget.student.userId);
      } catch (_) {}
      var terms = <AcademicTermModel>[];
      try {
        terms = await getIt<AcademicSetupRepository>().getTerms();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _credits = credits;
          _subjects = subjects;
          _schoolNames = schoolNames;
          _terms = terms;
          _previous = previous;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  double? get _subjectUnits {
    final s = _subjects.where((s) => s.subjectId == _subjectId).firstOrNull;
    return s == null ? null : s.lecUnits + s.labUnits;
  }

  static String _fmtUnits(double v) => unitsText(v);

  List<SubjectModel> get _available {
    final credited = (_credits ?? []).map((c) => c.subjectId).toSet();
    return _subjects.where((s) => !credited.contains(s.subjectId)).toList();
  }

  Future<void> _add() async {
    if (_subjectId == null) {
      setState(() => _formError = 'Choose the DBTC subject.');
      return;
    }
    if (_school.text.trim().isEmpty) {
      setState(() => _formError = 'Enter the school where it was taken.');
      return;
    }
    final subjectUnits = _subjectUnits ?? 0;
    final units = double.tryParse(_units.text.trim());
    if (units == null || units <= 0) {
      setState(() => _formError = 'Enter the units to credit.');
      return;
    }
    if (units > subjectUnits) {
      setState(() => _formError = 'This subject has only ${_fmtUnits(subjectUnits)} units.');
      return;
    }
    if (_cross && _termId == null) {
      setState(() => _formError = 'Choose the DBTC term it was cross-enrolled in.');
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      await getIt<CreditedSubjectRepository>().create(
        userId: widget.student.userId,
        subjectId: _subjectId!,
        sourceSchool: _school.text.trim(),
        sourceSubjectCode: _theirCode.text.trim(),
        grade: _grade.text.trim(),
        schoolYear: _cross ? null : _schoolYear.text.trim(),
        creditedUnits: units,
        crossEnrollment: _cross,
        termId: _cross ? _termId : null,
      );
      // Keep the school and year filled in: transferees usually bring several subjects from one school.
      _theirCode.clear();
      _grade.clear();
      _units.clear();
      _subjectId = null;
      _formVersion++;
      await _load();
    } catch (e) {
      if (mounted) setState(() => _formError = _message(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Corrects a credit already recorded, rather than removing it and typing it again.
  Future<void> _editCredit(CreditedSubjectModel c) async {
    // Every subject in the program except those another credit already covers; the credit's own
    // subject stays on the list so it can be left alone, even if the student has since shifted
    // program and it is no longer among the subjects loaded for the current one.
    final covered = (_credits ?? [])
        .where((x) => x.creditedSubjectId != c.creditedSubjectId)
        .map((x) => x.subjectId)
        .toSet();
    final choices = _subjects.where((s) => !covered.contains(s.subjectId)).toList();
    if (!choices.any((s) => s.subjectId == c.subjectId)) {
      choices.insert(
        0,
        SubjectModel(
          subjectId: c.subjectId,
          subjectCode: c.subjectCode,
          subjectTitle: c.subjectTitle,
          lecUnits: c.units,
          labUnits: 0,
          lecHours: 0,
          labHours: 0,
          programId: widget.student.programId ?? 0,
          yearLevel: c.yearLevel,
          defaultSemester: 1,
        ),
      );
    }

    final edit = await showDialog<CreditEdit>(
      context: context,
      builder: (_) => _EditCreditDialog(
        credit: c,
        subjects: choices,
        schoolNames: _schoolNames,
        terms: _terms,
      ),
    );
    if (edit == null) return;
    try {
      await getIt<CreditedSubjectRepository>().update(
        creditedSubjectId: c.creditedSubjectId,
        subjectId: edit.subjectId,
        sourceSchool: edit.school,
        sourceSubjectCode: edit.theirCode,
        grade: edit.grade,
        schoolYear: edit.schoolYear,
        creditedUnits: edit.units,
        crossEnrollment: edit.crossEnrollment,
        termId: edit.termId,
      );
      if (mounted) setState(() => _formError = null);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _formError = _message(e));
    }
  }

  Future<void> _remove(CreditedSubjectModel c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove credit?'),
        content: Text(
            '${c.subjectCode} will no longer count as passed for ${widget.student.fullName}.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('confirm_remove_credit'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await getIt<CreditedSubjectRepository>().delete(c.creditedSubjectId);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _formError = _message(e));
    }
  }

  static const _helpText = 'Subjects passed at another school. Credited subjects count as passed for prerequisites, '
      'the study load builder and year-level promotion.';

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(_helpText, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Expanded(child: _buildBody()),
        ],
      );
    }
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 760,
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school_outlined, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Credited subjects — ${widget.student.fullName}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Text(_helpText, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Flexible(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Could not load credits: $_error', style: const TextStyle(color: Color(0xFFDC2626))),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ]);
    }
    final credits = _credits;
    if (credits == null) {
      return const Padding(
          padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    }
    return ListView(
      shrinkWrap: true,
      children: [
        if (credits.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No credited subjects yet.',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        for (final c in credits) _buildCreditRow(c),
        if (_previous.isNotEmpty) _buildPrevious(),
        const Divider(height: 28),
        _buildForm(),
      ],
    );
  }

  /// Shiftees: subjects from the old program, each with a Use button that fills the form below.
  Widget _buildPrevious() => Container(
        key: const ValueKey('previous_program_subjects'),
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.scaffoldBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Taken in a previous program',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const Text('Click Use to fill in the form below, then set the units that match the time taken.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            for (final p in _previous)
              Padding(
                key: ValueKey('previous_${p.subjectCode}'),
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${p.subjectCode} — ${p.subjectTitle}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                          Text(
                            [
                              p.programCode,
                              '${_fmtUnits(p.units)} units',
                              p.status == 'InProgress' ? 'in progress' : 'grade ${gradeOrDash(p.finalGrade)}',
                              p.termLabel,
                              p.suggestedSubjectCode != null ? 'matches ${p.suggestedSubjectCode}' : 'no match in the new curriculum',
                            ].join(' · '),
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    p.alreadyCredited
                        ? const Text('Credited', style: TextStyle(fontSize: 12, color: AppColors.accentGreenDark))
                        : TextButton(
                            key: ValueKey('use_previous_${p.subjectCode}'),
                            onPressed: () => _usePrevious(p),
                            child: const Text('Use'),
                          ),
                  ],
                ),
              ),
          ],
        ),
      );

  void _usePrevious(PreviousProgramSubject p) {
    setState(() {
      _cross = false;
      _subjectId = p.suggestedSubjectId;
      _formVersion++;
      _school.text = '$_dbtcName (${p.programCode})';
      _theirCode.text = p.subjectCode;
      _grade.text = gradeOrDash(p.finalGrade, dash: '');
      _schoolYear.text = p.schoolYear;
      // Never more than the new subject has; the Registrar lowers it to match the time taken.
      final most = p.suggestedUnits ?? p.units;
      _units.text = _fmtUnits(p.units < most ? p.units : most);
      _formError = null;
    });
  }

  Widget _buildCreditRow(CreditedSubjectModel c) {
    final details = [
      c.isCrossEnrollment
          ? 'Cross-enrolled at ${c.sourceSchool}${c.termLabel != null ? ' in ${c.termLabel}' : ''}'
          : 'From ${c.sourceSchool}',
      if (c.sourceSubjectCode != null) 'as ${c.sourceSubjectCode}',
      if (c.grade != null) 'grade ${c.grade}',
      c.isPartial
          ? '${_fmtUnits(c.creditedUnits)} of ${_fmtUnits(c.units)} units (partial, still to take)'
          : '${_fmtUnits(c.creditedUnits)} units',
      if (c.schoolYear != null && !c.isCrossEnrollment) 'SY ${c.schoolYear}',
      if (c.recordedBy != null) 'recorded by ${c.recordedBy}',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.isPartial ? AppColors.accentAmberLight : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.isPartial ? const Color(0xFFFCD34D) : const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c.subjectCode} — ${c.subjectTitle}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(details,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('edit_credit_${c.subjectCode}'),
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
            tooltip: 'Correct this credit',
            onPressed: () => _editCredit(c),
          ),
          IconButton(
            key: ValueKey('remove_credit_${c.subjectCode}'),
            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
            tooltip: 'Remove credit',
            onPressed: () => _remove(c),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Add a credited subject',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (widget.student.programId == null)
          const Text('Set the student\'s program first.', style: TextStyle(color: Color(0xFFDC2626)))
        else
          CreditFields(
            keyPrefix: 'credit',
            formVersion: _formVersion,
            subjects: _available,
            subjectId: _subjectId,
            onSubjectChanged: (v) => setState(() {
              _subjectId = v;
              // Start from the full units; the Registrar lowers it when only part of the class was taken.
              final u = _subjectUnits;
              _units.text = u == null ? '' : _fmtUnits(u);
            }),
            cross: _cross,
            onCrossChanged: (v) => setState(() => _cross = v),
            school: _school,
            schoolFocus: _schoolFocus,
            schoolNames: _schoolNames,
            theirCode: _theirCode,
            grade: _grade,
            schoolYear: _schoolYear,
            units: _units,
            subjectUnits: _subjectUnits,
            terms: _terms,
            termId: _termId,
            onTermChanged: (v) => setState(() => _termId = v),
            onAnyChanged: () => setState(() {}),
          ),
        if (_formError != null) ...[
          const SizedBox(height: 8),
          Text(_formError!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const ValueKey('add_credit_button'),
            icon: _saving
                ? const SizedBox(
                    width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add, size: 16),
            label: const Text('Add credit'),
            onPressed: _saving || widget.student.programId == null ? null : _add,
          ),
        ),
      ],
    );
  }
}

/// Every field of a credit, shared by the "Add a credited subject" form and the correction dialog so
/// the two always offer and check the same things. The state lives with whoever shows the fields;
/// [keyPrefix] keeps the two sets of widget keys apart.
class CreditFields extends StatelessWidget {
  final String keyPrefix;

  /// Bumped by the add form after each save, so the subject dropdown starts empty again.
  final int formVersion;

  final List<SubjectModel> subjects;
  final String? subjectId;
  final ValueChanged<String?> onSubjectChanged;

  /// Cross-enrolled during a DBTC term, rather than taken before DBTC.
  final bool cross;
  final ValueChanged<bool> onCrossChanged;

  final TextEditingController school;
  final FocusNode schoolFocus;
  final List<String> schoolNames;

  final TextEditingController theirCode;
  final TextEditingController grade;
  final TextEditingController schoolYear;
  final TextEditingController units;

  /// The picked DBTC subject's full units, which the credited units cannot exceed.
  final double? subjectUnits;

  final List<AcademicTermModel> terms;
  final String? termId;
  final ValueChanged<String?> onTermChanged;

  /// Called when typing or picking changes what the rest of the fields should show.
  final VoidCallback onAnyChanged;

  const CreditFields({
    super.key,
    required this.keyPrefix,
    this.formVersion = 0,
    required this.subjects,
    required this.subjectId,
    required this.onSubjectChanged,
    required this.cross,
    required this.onCrossChanged,
    required this.school,
    required this.schoolFocus,
    required this.schoolNames,
    required this.theirCode,
    required this.grade,
    required this.schoolYear,
    required this.units,
    required this.subjectUnits,
    required this.terms,
    required this.termId,
    required this.onTermChanged,
    required this.onAnyChanged,
  });

  static String _fmtUnits(double v) => unitsText(v);

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<bool>(
          key: ValueKey('${keyPrefix}_kind'),
          segments: const [
            ButtonSegment(value: false, label: Text('From a previous school'), icon: Icon(Icons.history_edu_outlined)),
            ButtonSegment(value: true, label: Text('Cross-enrolled while at DBTC'), icon: Icon(Icons.compare_arrows_rounded)),
          ],
          selected: {cross},
          onSelectionChanged: (v) => onCrossChanged(v.first),
        ),
        const SizedBox(height: 10),
        KeyedSubtree(
          key: ValueKey('${keyPrefix}_form_$formVersion'),
          child: DropdownButtonFormField<String>(
            key: ValueKey('${keyPrefix}_subject_dropdown'),
            initialValue: subjectId,
            isExpanded: true,
            decoration: deco('DBTC subject *'),
            items: [
              for (final s in subjects)
                DropdownMenuItem(
                  value: s.subjectId,
                  child: Text('Y${s.yearLevel} · ${s.subjectCode} — ${s.subjectTitle}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onSubjectChanged,
          ),
        ),
        const SizedBox(height: 10),
        SchoolAutocompleteField(
          controller: school,
          focusNode: schoolFocus,
          schoolNames: schoolNames,
          fieldKey: ValueKey('${keyPrefix}_school_field'),
          onChanged: onAnyChanged,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: ValueKey('${keyPrefix}_their_code_field'),
                controller: theirCode,
                decoration: deco('Their subject code'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: ValueKey('${keyPrefix}_grade_field'),
                controller: grade,
                decoration: deco('Grade (as written)'),
              ),
            ),
            const SizedBox(width: 10),
            if (!cross)
              Expanded(
                child: TextField(
                  key: ValueKey('${keyPrefix}_school_year_field'),
                  controller: schoolYear,
                  decoration: deco('School year'),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: ValueKey('${keyPrefix}_units_field'),
                controller: units,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: deco('Units credited *').copyWith(
                  suffixText: subjectUnits == null ? null : 'of ${_fmtUnits(subjectUnits!)}',
                ),
                onChanged: (_) => onAnyChanged(),
              ),
            ),
          ],
        ),
        if (cross) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey('${keyPrefix}_term_dropdown'),
            initialValue: termId,
            isExpanded: true,
            decoration: deco('DBTC term it was taken during *'),
            items: [for (final t in terms) DropdownMenuItem(value: t.termId, child: Text(t.label))],
            onChanged: onTermChanged,
          ),
        ],
        if (subjectUnits != null && (double.tryParse(units.text.trim()) ?? subjectUnits!) < subjectUnits!)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Partial credit: the units count toward units earned, but the subject is still left to take '
              '(prerequisites and promotion need the full units).',
              key: ValueKey('${keyPrefix}_partial_note'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
      ],
    );
  }
}

/// The "school where it was taken" field: free text, suggesting the schools on
/// Setup → Accredited schools so the same school is spelled one way on every record. A school that is
/// not on the list can still be typed — it then shows up there as an unlisted school to add.
class SchoolAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> schoolNames;
  final Key fieldKey;

  /// Called on every keystroke and pick, so the caller can redraw its helper text.
  final VoidCallback onChanged;

  const SchoolAutocompleteField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.schoolNames,
    required this.fieldKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final typed = controller.text.trim();
    final helper = schoolNames.isEmpty
        ? 'Tip: add schools in Setup → Accredited Schools to pick them here.'
        : (typed.isNotEmpty &&
                !controller.text.startsWith(_dbtcName) &&
                !schoolNames.any((n) => n.toLowerCase() == typed.toLowerCase()))
            ? 'Not on the accredited list. Check the spelling, or add it in Setup.'
            : null;
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        return q.isEmpty ? schoolNames : schoolNames.where((n) => n.toLowerCase().contains(q));
      },
      fieldViewBuilder: (context, textController, node, onSubmit) => TextField(
        key: fieldKey,
        controller: textController,
        focusNode: node,
        decoration: InputDecoration(
          labelText: 'School where it was taken *',
          isDense: true,
          border: const OutlineInputBorder(),
          helperText: helper,
        ),
        onChanged: (_) => onChanged(),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 520),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final o in options)
                  ListTile(
                    key: ValueKey('school_option_$o'),
                    dense: true,
                    leading: const Icon(Icons.account_balance_outlined, size: 18),
                    title: Text(o),
                    onTap: () => onSelected(o),
                  ),
              ],
            ),
          ),
        ),
      ),
      onSelected: (_) => onChanged(),
    );
  }
}

/// What the Registrar entered in the correction dialog.
class CreditEdit {
  final String subjectId;
  final String school;
  final String? theirCode;
  final String? grade;
  final String? schoolYear;
  final double units;
  final bool crossEnrollment;
  final String? termId;

  const CreditEdit({
    required this.subjectId,
    required this.school,
    this.theirCode,
    this.grade,
    this.schoolYear,
    required this.units,
    required this.crossEnrollment,
    this.termId,
  });
}

/// Corrects a credit already recorded. Every detail can be changed — a credit recorded against the
/// wrong subject, with the wrong units or on the wrong side of a cross-enrollment is put right here
/// instead of being removed and typed again. The server checks a correction the way it checks a new
/// credit, so the record cannot end up in a state this form would have refused.
class _EditCreditDialog extends StatefulWidget {
  final CreditedSubjectModel credit;
  final List<SubjectModel> subjects;
  final List<String> schoolNames;
  final List<AcademicTermModel> terms;

  const _EditCreditDialog({
    required this.credit,
    required this.subjects,
    required this.schoolNames,
    required this.terms,
  });

  @override
  State<_EditCreditDialog> createState() => _EditCreditDialogState();
}

class _EditCreditDialogState extends State<_EditCreditDialog> {
  late String? _subjectId = widget.credit.subjectId;
  late bool _cross = widget.credit.isCrossEnrollment;
  late String? _termId = widget.credit.termId;

  late final _school = TextEditingController(text: widget.credit.sourceSchool);
  late final _theirCode = TextEditingController(text: widget.credit.sourceSubjectCode ?? '');
  late final _grade = TextEditingController(text: widget.credit.grade ?? '');
  late final _schoolYear = TextEditingController(text: widget.credit.schoolYear ?? '');
  late final _units = TextEditingController(text: unitsText(widget.credit.creditedUnits));
  final _schoolFocus = FocusNode();
  String? _error;

  @override
  void dispose() {
    _school.dispose();
    _theirCode.dispose();
    _grade.dispose();
    _schoolYear.dispose();
    _units.dispose();
    _schoolFocus.dispose();
    super.dispose();
  }

  double? get _subjectUnits {
    final s = widget.subjects.where((s) => s.subjectId == _subjectId).firstOrNull;
    return s == null ? null : s.lecUnits + s.labUnits;
  }

  void _save() {
    if (_subjectId == null) {
      setState(() => _error = 'Choose the DBTC subject.');
      return;
    }
    if (_school.text.trim().isEmpty) {
      setState(() => _error = 'Enter the school where it was taken.');
      return;
    }
    final subjectUnits = _subjectUnits ?? 0;
    final units = double.tryParse(_units.text.trim());
    if (units == null || units <= 0) {
      setState(() => _error = 'Enter the units to credit.');
      return;
    }
    if (units > subjectUnits) {
      setState(() => _error = 'This subject has only ${unitsText(subjectUnits)} units.');
      return;
    }
    if (_cross && _termId == null) {
      setState(() => _error = 'Choose the DBTC term it was cross-enrolled in.');
      return;
    }
    final theirCode = _theirCode.text.trim();
    final grade = _grade.text.trim();
    final schoolYear = _schoolYear.text.trim();
    Navigator.pop(
      context,
      CreditEdit(
        subjectId: _subjectId!,
        school: _school.text.trim(),
        theirCode: theirCode.isEmpty ? null : theirCode,
        grade: grade.isEmpty ? null : grade,
        // A cross-enrollment takes its school year from the DBTC term.
        schoolYear: _cross || schoolYear.isEmpty ? null : schoolYear,
        units: units,
        crossEnrollment: _cross,
        termId: _cross ? _termId : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.credit;
    return AlertDialog(
      title: const Text('Correct this credit'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Recorded as ${c.subjectCode}'
                '${c.recordedBy != null ? ' by ${c.recordedBy}' : ''}. '
                'Changing the subject or the units changes what this credit counts for.',
                key: const ValueKey('edit_credit_note'),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              CreditFields(
                keyPrefix: 'edit_credit',
                subjects: widget.subjects,
                subjectId: _subjectId,
                onSubjectChanged: (v) => setState(() {
                  _subjectId = v;
                  // A different subject brings its own units; the Registrar lowers them for a partial credit.
                  final u = _subjectUnits;
                  _units.text = u == null ? '' : unitsText(u);
                }),
                cross: _cross,
                onCrossChanged: (v) => setState(() => _cross = v),
                school: _school,
                schoolFocus: _schoolFocus,
                schoolNames: widget.schoolNames,
                theirCode: _theirCode,
                grade: _grade,
                schoolYear: _schoolYear,
                units: _units,
                subjectUnits: _subjectUnits,
                terms: widget.terms,
                termId: _termId,
                onTermChanged: (v) => setState(() => _termId = v),
                onAnyChanged: () => setState(() {}),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('save_credit_edit_button'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
