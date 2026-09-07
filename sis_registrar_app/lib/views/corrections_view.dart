import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/corrections_bloc.dart';
import '../models/grading_models.dart';
import 'widgets/page_header.dart';
import 'widgets/status_badge.dart';
import '../theme/app_theme.dart';

class CorrectionsView extends StatefulWidget {
  const CorrectionsView({super.key});

  @override
  State<CorrectionsView> createState() => _CorrectionsViewState();
}

class _CorrectionsViewState extends State<CorrectionsView> {
  @override
  void initState() {
    super.initState();
    final bloc = context.read<CorrectionsBloc>();
    if (bloc.state is CorrectionsInitial) {
      bloc.add(LoadCorrections());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: BlocConsumer<CorrectionsBloc, CorrectionsState>(
        listener: (context, state) {
          if (state is CorrectionsActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is CorrectionsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.message)),
                  ],
                ),
                backgroundColor: const Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Grade Correction Petitions',
                subtitle:
                    'Audit and act upon grade amendment requests filed by instructors for completed evaluation periods.',
                action: ElevatedButton.icon(
                  onPressed: () => context
                      .read<CorrectionsBloc>()
                      .add(LoadCorrections()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ),
              Expanded(
                child: _buildContent(context, state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, CorrectionsState state) {
    if (state is CorrectionsLoading || state is CorrectionsInitial) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final corrections = (state is CorrectionsLoaded)
        ? state.corrections
        : (state is CorrectionsError
            ? state.corrections ?? []
            : <GradeCorrectionModel>[]);

    if (corrections.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_turned_in_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No Pending Grade Corrections',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'All grade amendment petitions have been processed and decided.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    horizontalMargin: 24,
                    columnSpacing: 24,
                    columns: const [
                      DataColumn(
                        label: Text('Student',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('Subject',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('Requested By',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('Period',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('Grade Shift',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('Reason',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('Actions',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                    rows: corrections.map((c) {
                      final isProcessing = (state is CorrectionsLoaded) &&
                          state.processingId == c.correctionId;

                      return DataRow(
                        cells: [
                          DataCell(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  c.studentName ?? 'Student',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  dateFormat.format(c.dateRequested.toLocal()),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              c.subjectCode ?? (c.subjectTitle ?? 'Subject'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(c.requesterName ?? 'Instructor'),
                          ),
                          DataCell(
                            StatusBadge.info(label: c.correctionPeriodLabel),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  c.oldGrade.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF991B1B),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text(
                                  c.newGrade.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Text(
                                c.reason,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                          DataCell(
                            isProcessing
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () {
                                          context.read<CorrectionsBloc>().add(
                                              ApproveCorrectionEvent(c.correctionId));
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          minimumSize: const Size(60, 32),
                                          elevation: 0,
                                        ),
                                        child: const Text('Approve',
                                            style: TextStyle(fontSize: 12)),
                                      ),
                                      const SizedBox(width: 6),
                                      ElevatedButton(
                                        onPressed: () =>
                                            _openRejectDialog(context, c),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFEF4444),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          minimumSize: const Size(60, 32),
                                          elevation: 0,
                                        ),
                                        child: const Text('Reject',
                                            style: TextStyle(fontSize: 12)),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openRejectDialog(BuildContext context, GradeCorrectionModel c) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => BlocProvider.value(
        value: context.read<CorrectionsBloc>(),
        child: AlertDialog(
          title: const Text('Reject Grade Correction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reject grade amendment request for ${c.studentName ?? "Student"} (${c.subjectCode ?? "Subject"}):',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Provide reason for rejection...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<CorrectionsBloc>().add(RejectCorrectionEvent(
                      c.correctionId,
                      reason: reasonCtrl.text.trim().isNotEmpty
                          ? reasonCtrl.text.trim()
                          : null,
                    ));
                Navigator.of(dialogCtx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Rejection'),
            ),
          ],
        ),
      ),
    );
  }
}
