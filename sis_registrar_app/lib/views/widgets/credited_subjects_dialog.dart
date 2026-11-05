import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/grading_models.dart';
import '../../models/setup_models.dart';
import '../../repositories/accredited_school_repository.dart';
import '../../repositories/enrollment_repository.dart';
import '../../repositories/grading_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';

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

  static String _fmtUnits(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

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
        const Divider(height: 28),
        _buildForm(),
      ],
    );
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
    final available = _available;
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Add a credited subject',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        SegmentedButton<bool>(
          key: const ValueKey('credit_kind'),
          segments: const [
            ButtonSegment(value: false, label: Text('From a previous school'), icon: Icon(Icons.history_edu_outlined)),
            ButtonSegment(value: true, label: Text('Cross-enrolled while at DBTC'), icon: Icon(Icons.compare_arrows_rounded)),
          ],
          selected: {_cross},
          onSelectionChanged: (v) => setState(() => _cross = v.first),
        ),
        const SizedBox(height: 10),
        if (widget.student.programId == null)
          const Text('Set the student\'s program first.',
              style: TextStyle(color: Color(0xFFDC2626)))
        else
          KeyedSubtree(
            key: ValueKey('credit_form_$_formVersion'),
            child: DropdownButtonFormField<String>(
            key: const ValueKey('credit_subject_dropdown'),
            initialValue: _subjectId,
            isExpanded: true,
            decoration: deco('DBTC subject *'),
            items: [
              for (final s in available)
                DropdownMenuItem(
                  value: s.subjectId,
                  child: Text('Y${s.yearLevel} · ${s.subjectCode} — ${s.subjectTitle}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() {
              _subjectId = v;
              // Start from the full units; the Registrar lowers it when only part of the class was taken.
              final u = _subjectUnits;
              _units.text = u == null ? '' : _fmtUnits(u);
            }),
            ),
          ),
        const SizedBox(height: 10),
        // Picks from Setup → Accredited schools; a school not on the list can still be typed.
        RawAutocomplete<String>(
          textEditingController: _school,
          focusNode: _schoolFocus,
          optionsBuilder: (value) {
            final q = value.text.trim().toLowerCase();
            return q.isEmpty ? _schoolNames : _schoolNames.where((n) => n.toLowerCase().contains(q));
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmit) => TextField(
            key: const ValueKey('credit_school_field'),
            controller: controller,
            focusNode: focusNode,
            decoration: deco('School where it was taken *').copyWith(
              helperText: _schoolNames.isEmpty
                  ? 'Tip: add schools in Setup → Accredited Schools to pick them here.'
                  : (_school.text.trim().isNotEmpty &&
                          !_schoolNames.any((n) => n.toLowerCase() == _school.text.trim().toLowerCase()))
                      ? 'Not on the accredited list. Check the spelling, or add it in Setup.'
                      : null,
            ),
            onChanged: (_) => setState(() {}),
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
          onSelected: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('credit_their_code_field'),
                controller: _theirCode,
                decoration: deco('Their subject code'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const ValueKey('credit_grade_field'),
                controller: _grade,
                decoration: deco('Grade (as written)'),
              ),
            ),
            const SizedBox(width: 10),
            if (!_cross)
              Expanded(
                child: TextField(
                  key: const ValueKey('credit_school_year_field'),
                  controller: _schoolYear,
                  decoration: deco('School year'),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const ValueKey('credit_units_field'),
                controller: _units,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: deco('Units credited *').copyWith(
                  suffixText: _subjectUnits == null ? null : 'of ${_fmtUnits(_subjectUnits!)}',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        if (_cross) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: const ValueKey('credit_term_dropdown'),
            initialValue: _termId,
            isExpanded: true,
            decoration: deco('DBTC term it was taken during *'),
            items: [for (final t in _terms) DropdownMenuItem(value: t.termId, child: Text(t.label))],
            onChanged: (v) => setState(() => _termId = v),
          ),
        ],
        if (_subjectUnits != null && (double.tryParse(_units.text.trim()) ?? _subjectUnits!) < _subjectUnits!)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Partial credit: the units count toward units earned, but the subject is still left to take '
              '(prerequisites and promotion need the full units).',
              key: ValueKey('partial_credit_note'),
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
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
