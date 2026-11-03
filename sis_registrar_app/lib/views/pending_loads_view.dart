import 'package:flutter/material.dart';
import '../injection.dart';
import '../models/class_models.dart';
import '../models/grading_models.dart';
import '../models/setup_models.dart';
import '../repositories/class_repository.dart';
import '../repositories/enrollment_repository.dart';
import '../theme/app_theme.dart';
import 'widgets/page_header.dart';
import 'widgets/overload_badge.dart';
import 'widgets/student_study_load_dialog.dart';

class PendingLoadsView extends StatefulWidget {
  const PendingLoadsView({super.key});

  @override
  State<PendingLoadsView> createState() => _PendingLoadsViewState();
}

class _PendingLoadsViewState extends State<PendingLoadsView> {
  bool _isLoading = true;
  String? _error;
  List<AcademicTermModel> _terms = [];
  AcademicTermModel? _selectedTerm;
  List<PendingStudyLoadSummaryModel> _pendingStudents = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final setupRepo = getIt<AcademicSetupRepository>();
      final terms = await setupRepo.getTerms();
      _terms = terms;

      if (_terms.isNotEmpty) {
        _selectedTerm = _terms.firstWhere(
          (t) => t.isActive,
          orElse: () => _terms.first,
        );
      }

      await _fetchPendingStudents();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchPendingStudents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final classRepo = getIt<ClassRepository>();
      final students = await classRepo.getPendingSummary(
        termId: _selectedTerm?.termId,
      );

      if (mounted) {
        setState(() {
          _pendingStudents = students;
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

  Future<void> _openStudyLoadDialog(PendingStudyLoadSummaryModel item) async {
    final termId = _selectedTerm?.termId ?? '';
    final termLabel = _selectedTerm?.label ?? 'Academic Term';

    final student = UserSearchResultModel(
      userId: item.userId,
      firstname: item.fullName,
      lastname: '',
      email: '',
      programCode: item.programCode,
      yearLevel: item.yearLevel,
      role: 5,
      lrn: item.lrn,
      hasLrn: item.lrn != null && item.lrn!.isNotEmpty,
    );

    await StudentStudyLoadDialog.show(
      context,
      student: student,
      termId: termId,
      termLabel: termLabel,
    );

    if (mounted) {
      _fetchPendingStudents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Pending Study Loads',
            subtitle:
                'Review and finalize proposed study loads built by College Heads awaiting Registrar approval.',
            action: ElevatedButton.icon(
              onPressed: _isLoading ? null : _fetchPendingStudents,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text('Loading pending study loads...',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFDC2626), size: 40),
            const SizedBox(height: 8),
            Text(
              'Failed to load pending study loads: $_error',
              style: const TextStyle(fontSize: 14, color: Color(0xFFDC2626)),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadInitialData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final totalStudents = _pendingStudents.length;
    final totalSubjects = _pendingStudents.fold<int>(0, (sum, s) => sum + s.pendingCount);
    final totalUnits = _pendingStudents.fold<double>(0.0, (sum, s) => sum + s.pendingUnits);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Toolbar & Term Picker
          Row(
            children: [
              if (_terms.isNotEmpty) ...[
                const Text(
                  'Academic Term: ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTerm?.termId,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                      items: _terms.map((t) {
                        return DropdownMenuItem<String>(
                          value: t.termId,
                          child: Text(
                            '${t.label}${t.isActive ? " (Active)" : ""}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: t.isActive ? FontWeight.w700 : FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (newTermId) {
                        if (newTermId != null) {
                          setState(() {
                            _selectedTerm = _terms.firstWhere((t) => t.termId == newTermId);
                          });
                          _fetchPendingStudents();
                        }
                      },
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // Summary Pills
              _buildMetricPill(
                icon: Icons.people_outline,
                label: '$totalStudents Students',
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              _buildMetricPill(
                icon: Icons.pending_actions_outlined,
                label: '$totalSubjects Pending Subjects',
                color: const Color(0xFFD97706),
              ),
              const SizedBox(width: 12),
              _buildMetricPill(
                icon: Icons.school_outlined,
                label: '${totalUnits.toStringAsFixed(totalUnits.truncateToDouble() == totalUnits ? 0 : 1)} Total Units',
                color: const Color(0xFF059669),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Students Table Container
          if (_pendingStudents.isEmpty)
            Container(
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 48,
                      color: Colors.green.shade400,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No Pending Study Loads',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'All study loads submitted by College Heads have been finalized or dropped for this term.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: DataTable(
                  horizontalMargin: 24,
                  columnSpacing: 20,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  headingTextStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                    letterSpacing: 0.2,
                  ),
                  dataRowMinHeight: 60,
                  dataRowMaxHeight: 68,
                  columns: const [
                    DataColumn(label: Text('STUDENT')),
                    DataColumn(label: Text('LRN')),
                    DataColumn(label: Text('PROGRAM')),
                    DataColumn(label: Text('YEAR LEVEL')),
                    DataColumn(label: Text('PENDING SUBJECTS')),
                    DataColumn(label: Text('PENDING UNITS')),
                    DataColumn(label: Text('ACTION')),
                  ],
                  rows: _pendingStudents.map((item) {
                    final initials = item.fullName.isNotEmpty
                        ? item.fullName.trim()[0].toUpperCase()
                        : 'S';

                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primaryLight,
                                foregroundColor: AppColors.primary,
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                item.fullName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            item.lrn != null && item.lrn!.isNotEmpty ? item.lrn! : '—',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: item.lrn != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.programCode ?? '—',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (item.programName != null && item.programName!.isNotEmpty)
                                Text(
                                  item.programName!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            item.yearLevel != null ? 'Year ${item.yearLevel}' : 'Unassigned',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Text(
                              '${item.pendingCount} subject${item.pendingCount == 1 ? "" : "s"}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${item.pendingUnits.toStringAsFixed(item.pendingUnits.truncateToDouble() == item.pendingUnits ? 0 : 1)} units',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (item.isOverloaded) ...[
                                const SizedBox(width: 6),
                                OverloadBadge(
                                  termUnits: item.termUnits,
                                  maxUnits: item.maxUnits,
                                  approvedBy: item.overloadApprovedBy,
                                  reason: item.overloadReason,
                                ),
                              ],
                            ],
                          ),
                        ),
                        DataCell(
                          OutlinedButton.icon(
                            onPressed: () => _openStudyLoadDialog(item),
                            icon: const Icon(Icons.rate_review_outlined, size: 14),
                            label: const Text('Review load'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
