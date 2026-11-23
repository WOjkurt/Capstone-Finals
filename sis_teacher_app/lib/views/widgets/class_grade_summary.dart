import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/grading_models.dart';
import '../../repositories/grades_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/numbers.dart';

/// How a class is doing, derived from its grade rows.
///
/// Pure so it can be tested without a widget. Passing is a final grade of 3.00
/// or better, matching the server (Api/Common/GradeScale.cs).
class ClassGradeStats {
  final int passed;
  final int failed;
  final int ungraded;

  /// Mean of the submitted final grades, or null when none are in yet.
  final double? average;

  /// Students who failed, or whose midterm is already failing with no final
  /// yet — the ones worth a conversation before the term ends.
  final List<GradeModel> atRisk;

  const ClassGradeStats({
    required this.passed,
    required this.failed,
    required this.ungraded,
    required this.average,
    required this.atRisk,
  });

  static const double passingGrade = 3.00;

  int get total => passed + failed + ungraded;

  String get averageLabel =>
      gradeOrDash(average, dash: '—');

  factory ClassGradeStats.from(List<GradeModel> grades) {
    var passed = 0;
    var failed = 0;
    var ungraded = 0;
    final finals = <double>[];
    final atRisk = <GradeModel>[];

    for (final g in grades) {
      final finalGrade = g.finalGrade;
      if (finalGrade != null) {
        finals.add(finalGrade);
        if (finalGrade <= passingGrade) {
          passed++;
        } else {
          failed++;
          atRisk.add(g);
        }
      } else {
        ungraded++;
        final midterm = g.midtermGrade;
        if (midterm != null && midterm > passingGrade) {
          atRisk.add(g);
        }
      }
    }

    return ClassGradeStats(
      passed: passed,
      failed: failed,
      ungraded: ungraded,
      average: finals.isEmpty
          ? null
          : finals.reduce((a, b) => a + b) / finals.length,
      atRisk: atRisk,
    );
  }
}

/// Read-only grade summary for one class, for a Program Head looking at a
/// class they do not teach themselves.
class ClassGradeSummary extends StatefulWidget {
  final String classId;

  const ClassGradeSummary({super.key, required this.classId});

  @override
  State<ClassGradeSummary> createState() => _ClassGradeSummaryState();
}

class _ClassGradeSummaryState extends State<ClassGradeSummary> {
  ClassGradeStats? _stats;
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
      final grades = await getIt<GradesRepository>().getClassGrades(
        widget.classId,
      );
      if (mounted) {
        setState(() {
          _stats = ClassGradeStats.from(grades);
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
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_error != null) {
      return Text(
        'Grades could not be loaded for this class.',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      );
    }

    final stats = _stats!;
    if (stats.total == 0) {
      return const Text(
        'No grades have been submitted for this class yet.',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _figure('Passed', '${stats.passed}', AppColors.accentGreenDark),
            _figure('Failed', '${stats.failed}', const Color(0xFF991B1B)),
            _figure('No grade yet', '${stats.ungraded}',
                AppColors.textSecondary),
            _figure('Class average', stats.averageLabel, AppColors.primaryDark),
          ],
        ),
        if (stats.atRisk.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stats.atRisk.length} student${stats.atRisk.length == 1 ? '' : 's'} at risk',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 6),
                ...stats.atRisk.map(
                  (g) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      _atRiskLine(g),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF78350F),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _atRiskLine(GradeModel g) {
    final name = g.studentName ?? 'Unknown student';
    if (g.finalGrade != null) {
      return '$name — final ${gradeText(g.finalGrade!)}';
    }
    return '$name — midterm ${gradeText(g.midtermGrade!)}, no final yet';
  }

  Widget _figure(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
