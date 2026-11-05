import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/record_models.dart';
import '../../repositories/student_record_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/student_record_pdf.dart';
import '../../utils/study_load_pdf.dart' show loadSchoolLogo, printPdf;
import 'standing_card.dart';
import 'status_badge.dart';

/// The student's curriculum checklist: every subject of their program, what is done and what is left.
class StudentEvaluationTab extends StatefulWidget {
  final String userId;

  /// Used on the printout if the record has no name.
  final String studentName;

  const StudentEvaluationTab({super.key, required this.userId, this.studentName = ''});

  @override
  State<StudentEvaluationTab> createState() => _StudentEvaluationTabState();
}

class _StudentEvaluationTabState extends State<StudentEvaluationTab> {
  StudentEvaluation? _data;
  String? _error;
  bool _leftOnly = false;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _data = null;
      _error = null;
    });
    try {
      final data = await getIt<StudentRecordRepository>().evaluation(widget.userId);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : e.toString());
    }
  }

  /// Prints the whole checklist (the "Left to take only" filter does not apply to the printout).
  Future<void> _print(StudentEvaluation data) async {
    setState(() => _printing = true);
    final name = data.fullName.isNotEmpty ? data.fullName : widget.studentName;
    try {
      final bytes = await buildEvaluationPdf(
        data,
        student: RecordStudentInfo(
          name: name,
          lrn: data.lrn,
          programCode: data.programCode,
          programName: data.programName,
          yearLevel: data.yearLevel,
        ),
        logo: await loadSchoolLogo(),
      );
      await printPdf(bytes, 'Evaluation_${name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf');
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

  static String _units(double u) => u.toStringAsFixed(u % 1 == 0 ? 0 : 1);

  static String _yearSem(int year, int sem) {
    const years = {1: '1st Year', 2: '2nd Year', 3: '3rd Year', 4: '4th Year', 5: '5th Year'};
    const sems = {1: '1st Sem', 2: '2nd Sem', 3: 'Summer'};
    return '${years[year] ?? 'Year $year'} · ${sems[sem] ?? 'Sem $sem'}';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final data = _data;
    if (data == null) return const Center(child: CircularProgressIndicator());
    if (data.subjects.isEmpty) {
      return Center(
        child: Text('No curriculum subjects found for ${data.programCode}.',
            style: const TextStyle(color: AppColors.textSecondary)),
      );
    }

    final shown = _leftOnly ? data.subjects.where((s) => !s.isDone).toList() : data.subjects;
    final groups = <String, List<EvaluationSubject>>{};
    for (final s in shown) {
      groups.putIfAbsent(_yearSem(s.yearLevel, s.semester), () => []).add(s);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StandingCard(key: ValueKey('standing_${widget.userId}'), userId: widget.userId),
        _buildSummary(data),
        const SizedBox(height: 12),
        Row(
          children: [
            FilterChip(
              key: const ValueKey('evaluation_left_only'),
              label: const Text('Left to take only'),
              selected: _leftOnly,
              onSelected: (v) => setState(() => _leftOnly = v),
            ),
            const Spacer(),
            OutlinedButton.icon(
              key: const ValueKey('print_evaluation_button'),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Print'),
              onPressed: _printing ? null : () => _print(data),
            ),
            const SizedBox(width: 4),
            IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: shown.isEmpty
              ? const Center(
                  child: Text('All curriculum subjects are passed or credited.',
                      style: TextStyle(color: AppColors.textSecondary)))
              : ListView(
                  children: [
                    for (final g in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(g.key,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ),
                      for (final s in g.value) _buildRow(s),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSummary(StudentEvaluation d) {
    final progress = d.totalUnits == 0 ? 0.0 : (d.earnedUnits / d.totalUnits).clamp(0.0, 1.0);
    Widget stat(String key, String label, String value, Color color) => Expanded(
          child: Column(
            key: ValueKey(key),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        );
    return Container(
      key: const ValueKey('evaluation_summary'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${d.programCode} — ${d.programName}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Row(
            children: [
              stat('evaluation_earned', 'units earned of ${_units(d.totalUnits)}', _units(d.earnedUnits), AppColors.accentGreenDark),
              stat('evaluation_in_progress', 'units in progress', _units(d.inProgressUnits), AppColors.primary),
              stat('evaluation_remaining', 'units left', _units(d.remainingUnits), AppColors.textPrimary),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.border,
              color: AppColors.accentGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text('${(progress * 100).round()}% of the curriculum done',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildRow(EvaluationSubject s) {
    final Widget badge = switch (s.status) {
      'Passed' => StatusBadge.success(label: 'Passed'),
      'Credited' => StatusBadge.info(label: 'Credited'),
      'CrossEnrolled' => StatusBadge.info(label: 'Cross-enrolled'),
      'PartiallyCredited' => StatusBadge.pending(label: 'Partly credited'),
      'InProgress' => StatusBadge.pending(label: 'In progress'),
      'Failed' => StatusBadge.danger(label: 'Failed'),
      'Dropped' => StatusBadge.neutral(label: 'Dropped'),
      _ => StatusBadge.neutral(label: 'Not taken'),
    };
    final detail = [
      '${_units(s.units)} units',
      if (s.isMinor) 'Minor',
      if (s.status == 'Credited') 'from ${s.creditedFrom ?? 'another school'}',
      if (s.status == 'CrossEnrolled') 'at ${s.creditedFrom ?? 'another school'}',
      if (s.status == 'PartiallyCredited')
        '${_units(s.creditedUnits ?? 0)} of ${_units(s.units)} units credited from ${s.creditedFrom ?? 'another school'}',
      if (s.termLabel != null) s.termLabel!,
    ].join(' · ');
    final grade = const {'Credited', 'CrossEnrolled', 'PartiallyCredited'}.contains(s.status)
        ? s.creditedGrade
        : s.finalGrade?.toStringAsFixed(2);

    return Container(
      key: ValueKey('evaluation_row_${s.subjectCode}'),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: s.status == 'Failed' ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s.subjectCode} — ${s.subjectTitle}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                Text(detail,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(grade ?? '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 100, child: Align(alignment: Alignment.centerRight, child: FittedBox(fit: BoxFit.scaleDown, child: badge))),
        ],
      ),
    );
  }
}
