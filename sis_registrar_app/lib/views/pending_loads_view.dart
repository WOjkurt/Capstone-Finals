import 'package:flutter/material.dart';
import '../injection.dart';
import '../models/class_models.dart';
import '../models/grading_models.dart';
import '../models/setup_models.dart';
import '../repositories/class_repository.dart';
import '../services/current_term.dart';
import '../theme/app_theme.dart';
import '../utils/error_handler.dart';
import 'widgets/page_header.dart';
import 'widgets/overload_badge.dart';
import 'widgets/student_study_load_dialog.dart';

class PendingLoadsView extends StatefulWidget {
  const PendingLoadsView({super.key});

  @override
  State<PendingLoadsView> createState() => _PendingLoadsViewState();
}

class _PendingLoadsViewState extends State<PendingLoadsView> with CurrentTermUser {
  bool _isLoading = true;
  String? _error;
  List<PendingStudyLoadSummaryModel> _pendingStudents = [];
  final Set<String> _selected = {};
  bool _finalizing = false;

  AcademicTermModel? get _selectedTerm => currentTerm.term;

  /// Over the unit limit with no recorded approval: review that student on their own.
  bool _canBulkFinalize(PendingStudyLoadSummaryModel s) => !s.isOverloaded || s.overloadApprovedBy != null;

  Future<void> _finalizeSelected() async {
    final term = _selectedTerm;
    final chosen = _pendingStudents.where((s) => _selected.contains(s.userId)).toList();
    if (term == null || chosen.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalize study loads?'),
        content: Text('All pending subjects of ${chosen.length} student(s) will be enrolled for ${term.label}.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('confirm_finalize_selected'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Finalize'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _finalizing = true);
    final failures = <String>[];
    for (final s in chosen) {
      try {
        await getIt<ClassRepository>().finalizeStudyLoads(userId: s.userId, termId: term.termId);
      } catch (e) {
        failures.add('${s.fullName}: ${e is ApiException ? e.message : e}');
      }
    }
    if (!mounted) return;
    setState(() {
      _finalizing = false;
      _selected.clear();
    });

    final done = chosen.length - failures.length;
    if (failures.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Finalized $done student(s).'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Finalized $done of ${chosen.length}'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Text('These were not finalized; open them to review:\n\n${failures.join('\n\n')}'),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
        ),
      );
    }
    await _fetchPendingStudents();
  }

  @override
  void onTermChanged(String termId) => _fetchPendingStudents();

  Future<void> _reload() async {
    await currentTerm.load(force: true);
    await _fetchPendingStudents();
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
          _selected.removeWhere((id) => !students.any((s) => s.userId == id));
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
            title: 'Pending Loads',
            subtitle: 'Study loads built by College Heads, waiting for you to finalize.',
            onRefresh: _isLoading ? null : _fetchPendingStudents,
          ),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (currentTerm.isLoaded && currentTerm.terms.isEmpty) {
      return const Center(
        child: Text('No academic terms yet. Add one in Setup.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
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
              onPressed: _reload,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final totalStudents = _pendingStudents.length;
    final totalSubjects = _pendingStudents.fold<int>(0, (sum, s) => sum + s.pendingCount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Toolbar & Term Picker
          Row(
            children: [
              // Shared with the other pages: changing it here changes it everywhere.
              if (currentTerm.terms.isNotEmpty) CurrentTermPicker(term: currentTerm),
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
              FilledButton.icon(
                key: const ValueKey('finalize_selected_button'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.accentGreenDark),
                icon: _finalizing
                    ? const SizedBox(
                        width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.done_all_rounded, size: 18),
                label: Text('Finalize selected (${_selected.length})'),
                onPressed: (_selected.isEmpty || _finalizing) ? null : _finalizeSelected,
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

                    final selectable = _canBulkFinalize(item);
                    return DataRow(
                      key: ValueKey('pending_row_${item.userId}'),
                      selected: _selected.contains(item.userId),
                      onSelectChanged: (selectable && !_finalizing)
                          ? (v) => setState(() => v == true ? _selected.add(item.userId) : _selected.remove(item.userId))
                          : null,
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
                                fontFamily: AppTheme.fontFamily,
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
