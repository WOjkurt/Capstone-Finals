import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/grade_corrections_bloc.dart';
import '../models/grading_models.dart';
import '../theme/app_theme.dart';
import 'widgets/page_header.dart';
import 'widgets/status_badge.dart';

class GradeCorrectionsView extends StatefulWidget {
  const GradeCorrectionsView({super.key});

  @override
  State<GradeCorrectionsView> createState() => _GradeCorrectionsViewState();
}

class _GradeCorrectionsViewState extends State<GradeCorrectionsView> {
  @override
  void initState() {
    super.initState();
    context.read<GradeCorrectionsBloc>().add(LoadMyCorrectionsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Grade Corrections',
          subtitle: 'Track the status of your submitted grade correction requests.',
          action: OutlinedButton.icon(
            onPressed: () =>
                context.read<GradeCorrectionsBloc>().add(LoadMyCorrectionsEvent()),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        Expanded(
          child: BlocBuilder<GradeCorrectionsBloc, GradeCorrectionsState>(
            builder: (context, state) {
              if (state is GradeCorrectionsLoading) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Loading your correction requests...',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              if (state is GradeCorrectionsError) {
                return Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 440),
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF87171)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Color(0xFFDC2626), size: 36),
                        const SizedBox(height: 12),
                        const Text(
                          'Failed to load corrections',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF991B1B)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          state.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFFB91C1C)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => context
                              .read<GradeCorrectionsBloc>()
                              .add(LoadMyCorrectionsEvent()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (state is GradeCorrectionsLoaded) {
                if (state.corrections.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildCorrectionsList(state.corrections);
              }

              // Initial state — show empty placeholder
              return _buildEmptyState();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.assignment_late_outlined,
                  color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Correction Requests',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'You have not submitted any grade correction requests yet. '
              'To request a correction, open the Grades sheet and tap '
              '"Request Correction" on a locked grade.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorrectionsList(List<GradeCorrectionModel> corrections) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary counts
          _buildSummaryCounts(corrections),
          const SizedBox(height: 16),
          // List
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(11)),
                      border: Border(
                          bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text('SUBJECT / STUDENT',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5)),
                        ),
                        SizedBox(width: 12),
                        SizedBox(
                          width: 80,
                          child: Text('PERIOD',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5)),
                        ),
                        SizedBox(width: 12),
                        SizedBox(
                          width: 110,
                          child: Text('GRADE CHANGE',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5)),
                        ),
                        SizedBox(width: 12),
                        SizedBox(
                          width: 100,
                          child: Text('STATUS',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5)),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Text('REASON',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5)),
                        ),
                        SizedBox(width: 12),
                        SizedBox(
                          width: 100,
                          child: Text('DATE',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                  ),
                  // Rows
                  Expanded(
                    child: ListView.separated(
                      itemCount: corrections.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        return _CorrectionRow(
                          correction: corrections[index],
                          isEven: index % 2 == 0,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCounts(List<GradeCorrectionModel> corrections) {
    final pending =
        corrections.where((c) => c.correctionStatus == 1).length;
    final approved =
        corrections.where((c) => c.correctionStatus == 2).length;
    final rejected =
        corrections.where((c) => c.correctionStatus == 3).length;

    return Row(
      children: [
        _SummaryChip(
          label: 'Total',
          count: corrections.length,
          color: const Color(0xFF1E293B),
          bgColor: const Color(0xFFF1F5F9),
        ),
        const SizedBox(width: 8),
        _SummaryChip(
          label: 'Pending',
          count: pending,
          color: const Color(0xFF92400E),
          bgColor: const Color(0xFFFEF3C7),
        ),
        const SizedBox(width: 8),
        _SummaryChip(
          label: 'Approved',
          count: approved,
          color: const Color(0xFF065F46),
          bgColor: const Color(0xFFD1FAE5),
        ),
        const SizedBox(width: 8),
        _SummaryChip(
          label: 'Rejected',
          count: rejected,
          color: const Color(0xFF991B1B),
          bgColor: const Color(0xFFFEE2E2),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bgColor;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _CorrectionRow extends StatelessWidget {
  final GradeCorrectionModel correction;
  final bool isEven;

  const _CorrectionRow({required this.correction, required this.isEven});

  @override
  Widget build(BuildContext context) {
    final c = correction;
    final dateStr = _formatDate(c.dateRequested);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: isEven ? Colors.white : const Color(0xFFFAFAFA),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Subject / Student
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (c.subjectCode != null) c.subjectCode!,
                    if (c.subjectCode != null && c.subjectTitle != null)
                      ' — ',
                    if (c.subjectTitle != null) c.subjectTitle!,
                  ].join(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (c.studentName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    c.studentName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Period
          SizedBox(
            width: 80,
            child: Text(
              c.correctionPeriodLabel,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151)),
            ),
          ),
          const SizedBox(width: 12),
          // Grade change arrow
          SizedBox(
            width: 110,
            child: Row(
              children: [
                Text(
                  c.oldGrade.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Color(0xFF64748B),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 14, color: AppColors.primary),
                ),
                Text(
                  c.newGrade.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Status badge
          SizedBox(
            width: 100,
            child: _statusBadge(c.correctionStatus, c.correctionStatusLabel),
          ),
          const SizedBox(width: 12),
          // Reason
          Expanded(
            flex: 2,
            child: Text(
              c.reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
          ),
          const SizedBox(width: 12),
          // Date
          SizedBox(
            width: 100,
            child: Text(
              dateStr,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(int status, String label) {
    switch (status) {
      case 1:
        return StatusBadge.pending(label: label);
      case 2:
        return StatusBadge.success(label: label);
      case 3:
        return StatusBadge.danger(label: label);
      default:
        return StatusBadge.neutral(label: label);
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
