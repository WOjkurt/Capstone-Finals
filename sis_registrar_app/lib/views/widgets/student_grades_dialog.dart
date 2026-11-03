import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/grading_models.dart';
import '../../repositories/grading_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import 'status_badge.dart';

/// Read-only grade history of one student, grouped by term (newest first).
/// Failed subjects that were never passed later are listed at the top as retake candidates.
class StudentGradesDialog extends StatefulWidget {
  final String userId;
  final String studentName;

  const StudentGradesDialog({
    super.key,
    required this.userId,
    required this.studentName,
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

  String _fmt(double? v) => v == null ? '—' : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
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
                FilterChip(
                  key: const ValueKey('failed_only_chip'),
                  label: const Text('Failed only'),
                  selected: _failedOnly,
                  onSelected: (v) => setState(() => _failedOnly = v),
                ),
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
        child: Text('No grades recorded for this student yet.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final unresolved = unresolvedFailedSubjects(grades,
        creditedCodes: _credits.map((c) => c.subjectCode));
    final shown = _failedOnly ? grades.where((g) => g.isFailed).toList() : grades;

    return ListView(
      shrinkWrap: true,
      children: [
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
            child: Text('Credited from other schools',
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
                    'Credited from ${c.sourceSchool}${c.grade != null ? ' · ${c.grade}' : ''}',
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
            child: Text(term.key,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
          for (final g in term.value) _buildRow(g),
        ],
      ],
    );
  }

  Widget _buildRow(StudentGradeModel g) {
    final Widget remark = g.isPassed
        ? StatusBadge.success(label: 'Passed')
        : g.isFailed
            ? StatusBadge.danger(label: 'Failed')
            : StatusBadge.pending(label: 'No grade');
    final notCounted = g.loadStatus != null && g.loadStatus != 1;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: g.isFailed ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${g.subjectCode ?? '?'} — ${g.subjectTitle ?? ''}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  [
                    if (g.className != null) g.className!,
                    if (g.units != null) '${g.units!.toStringAsFixed(g.units! % 1 == 0 ? 0 : 1)} units',
                    if (g.teacherName != null) g.teacherName!,
                    if (notCounted) 'load not enrolled — not counted',
                  ].join(' · '),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(
              width: 90,
              child: Text('Mid ${_fmt(g.midtermGrade)}',
                  style: const TextStyle(fontSize: 12))),
          SizedBox(
              width: 90,
              child: Text('Final ${_fmt(g.finalGrade)}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600))),
          SizedBox(width: 130, child: Align(alignment: Alignment.centerRight, child: FittedBox(fit: BoxFit.scaleDown, child: remark))),
        ],
      ),
    );
  }
}
