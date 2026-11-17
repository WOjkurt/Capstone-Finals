import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/grading_models.dart';
import '../../repositories/grades_repository.dart';
import '../../theme/app_theme.dart';

/// One term's worth of a student's grades, newest term first.
class StudentGradeTerm {
  final String termLabel;
  final List<GradeModel> grades;

  const StudentGradeTerm({required this.termLabel, required this.grades});

  double get totalUnits =>
      grades.fold<double>(0, (sum, g) => sum + (g.units ?? 0));

  /// Groups a flat grade list by term, preserving the order the API returned
  /// the terms in. Rows with no term fall into one 'Other' group at the end.
  static List<StudentGradeTerm> group(List<GradeModel> grades) {
    final byTerm = <String, List<GradeModel>>{};
    for (final g in grades) {
      final label = (g.termLabel == null || g.termLabel!.isEmpty)
          ? 'Other'
          : g.termLabel!;
      byTerm.putIfAbsent(label, () => []).add(g);
    }

    final terms = byTerm.keys.where((t) => t != 'Other').toList();
    return [
      for (final t in terms) StudentGradeTerm(termLabel: t, grades: byTerm[t]!),
      if (byTerm.containsKey('Other'))
        StudentGradeTerm(termLabel: 'Other', grades: byTerm['Other']!),
    ];
  }
}

/// Read-only grade history for one student, for a Program Head looking at a
/// roster row. Program Heads cannot reach the registrar's evaluation or
/// transcript endpoints, so this is grades only.
class StudentGradeHistoryDialog extends StatefulWidget {
  final String studentUserId;
  final String studentName;

  const StudentGradeHistoryDialog({
    super.key,
    required this.studentUserId,
    required this.studentName,
  });

  static Future<void> show(
    BuildContext context, {
    required String studentUserId,
    required String studentName,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => StudentGradeHistoryDialog(
        studentUserId: studentUserId,
        studentName: studentName,
      ),
    );
  }

  @override
  State<StudentGradeHistoryDialog> createState() =>
      _StudentGradeHistoryDialogState();
}

class _StudentGradeHistoryDialogState extends State<StudentGradeHistoryDialog> {
  List<StudentGradeTerm>? _terms;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final grades =
          await getIt<GradesRepository>().getStudentGrades(widget.studentUserId);
      if (mounted) {
        setState(() {
          _terms = StudentGradeTerm.group(grades);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.studentName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Grade history',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Flexible(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'This student\'s grades could not be loaded.',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final terms = _terms!;
    if (terms.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No grades have been recorded for this student yet.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final term in terms) ...[
            _termHeader(term),
            const SizedBox(height: 8),
            _termTable(term),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }

  Widget _termHeader(StudentGradeTerm term) {
    final units = term.totalUnits;
    return Row(
      children: [
        const Icon(Icons.calendar_today_rounded,
            size: 14, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          term.termLabel,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (units > 0) ...[
          const SizedBox(width: 8),
          Text(
            '${units.toStringAsFixed(units.truncateToDouble() == units ? 0 : 1)} units',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _termTable(StudentGradeTerm term) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < term.grades.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            _gradeRow(term.grades[i]),
          ],
        ],
      ),
    );
  }

  Widget _gradeRow(GradeModel g) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              g.subjectCode ?? '—',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          Expanded(
            child: Text(
              g.subjectTitle ?? 'Untitled subject',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _grade('Mid', g.midtermGrade),
          const SizedBox(width: 12),
          _grade('Final', g.finalGrade),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(
              _remarks(g),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _remarks(GradeModel g) {
    if (g.finalGrade == null) return '—';
    return g.remarksLabel ?? (g.finalGrade! <= 3.00 ? 'Passed' : 'Failed');
  }

  Widget _grade(String label, double? value) {
    return SizedBox(
      width: 64,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            TextSpan(
              text: value == null ? '—' : value.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: value == null
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
