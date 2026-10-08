import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/class_models.dart';
import '../../models/grading_models.dart';
import '../../repositories/class_repository.dart';
import '../../theme/app_theme.dart';
import 'status_badge.dart';
import 'edit_lrn_dialog.dart';

class StudentStudyLoadDialog extends StatefulWidget {
  final UserSearchResultModel student;
  final String termId;
  final String termLabel;

  const StudentStudyLoadDialog({
    super.key,
    required this.student,
    required this.termId,
    required this.termLabel,
  });

  static Future<void> show(
    BuildContext context, {
    required UserSearchResultModel student,
    required String termId,
    required String termLabel,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StudentStudyLoadDialog(
        student: student,
        termId: termId,
        termLabel: termLabel,
      ),
    );
  }

  @override
  State<StudentStudyLoadDialog> createState() => _StudentStudyLoadDialogState();
}

class _StudentStudyLoadDialogState extends State<StudentStudyLoadDialog> {
  List<ClassRosterItemModel>? _studyLoads;
  bool _isLoading = true;
  String? _error;
  String? _updatingStudyLoadId;
  late String? _currentLrn;
  late bool? _hasLrn;

  @override
  void initState() {
    super.initState();
    _currentLrn = widget.student.lrn;
    _hasLrn = widget.student.hasLrn;
    _fetchStudyLoads();
  }

  Future<void> _fetchStudyLoads() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = getIt<ClassRepository>();
      final list = await repo.getStudentStudyLoads(
        widget.student.userId,
        widget.termId,
      );
      if (mounted) {
        setState(() {
          _studyLoads = list;
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

  Future<void> _confirmAndUpdateStatus(
    ClassRosterItemModel load,
    int targetStatus,
  ) async {
    final statusName = targetStatus == 1
        ? 'Enrolled'
        : targetStatus == 2
            ? 'Dropped'
            : 'Withdrawn';

    final isDestructive = targetStatus == 2 || targetStatus == 3;
    final actionVerb = targetStatus == 1
        ? 'Re-enroll'
        : targetStatus == 2
            ? 'Drop'
            : 'Withdraw';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(
              isDestructive
                  ? Icons.warning_amber_rounded
                  : Icons.replay_circle_filled_rounded,
              color: isDestructive
                  ? (targetStatus == 2 ? const Color(0xFFDC2626) : const Color(0xFFD97706))
                  : AppColors.primary,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$actionVerb in ${load.subjectCode}?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.5),
                children: [
                  const TextSpan(text: 'Are you sure you want to change enrollment in '),
                  TextSpan(
                    text: '${load.subjectCode} - ${load.subjectTitle}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const TextSpan(text: ' for student '),
                  TextSpan(
                    text: widget.student.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const TextSpan(text: ' to '),
                  TextSpan(
                    text: statusName,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: targetStatus == 1
                          ? const Color(0xFF059669)
                          : targetStatus == 2
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFD97706),
                    ),
                  ),
                  const TextSpan(text: '?'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isDestructive
                          ? 'This status will immediately sync to the teacher grade book.'
                          : 'Student will be restored to active enrolled standing in this class.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: targetStatus == 1
                  ? const Color(0xFF059669)
                  : targetStatus == 2
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              '$actionVerb Student',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _updatingStudyLoadId = load.studyLoadId;
    });

    try {
      final repo = getIt<ClassRepository>();
      final updated = await repo.updateStudyLoadStatus(load.studyLoadId, targetStatus);

      if (mounted) {
        setState(() {
          if (_studyLoads != null) {
            final index = _studyLoads!.indexWhere((s) => s.studyLoadId == load.studyLoadId);
            if (index != -1) {
              _studyLoads![index] = updated;
            }
          }
          _updatingStudyLoadId = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${load.subjectCode} updated to $statusName successfully.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _updatingStudyLoadId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildLoadBadge(String status) => StatusBadge.forLoadStatus(status);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        width: 820,
        height: 640,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  child: Text(
                    widget.student.firstname.isNotEmpty
                        ? widget.student.firstname[0].toUpperCase()
                        : 'S',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.student.fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (_hasLrn == false) ...[
                            const SizedBox(width: 8),
                            StatusBadge.noLrn(
                              onTap: () {
                                EditLrnDialog.showForStudent(
                                  context,
                                  userId: widget.student.userId,
                                  studentName: widget.student.fullName,
                                  currentLrn: _currentLrn,
                                  onSaved: (newLrn) {
                                    setState(() {
                                      _currentLrn = newLrn;
                                      _hasLrn = newLrn != null && newLrn.isNotEmpty;
                                    });
                                  },
                                );
                              },
                            ),
                          ] else if (_currentLrn != null && _currentLrn!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                EditLrnDialog.showForStudent(
                                  context,
                                  userId: widget.student.userId,
                                  studentName: widget.student.fullName,
                                  currentLrn: _currentLrn,
                                  onSaved: (newLrn) {
                                    setState(() {
                                      _currentLrn = newLrn;
                                      _hasLrn = newLrn != null && newLrn.isNotEmpty;
                                    });
                                  },
                                );
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'LRN: $_currentLrn',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.edit_outlined,
                                        size: 11, color: Color(0xFF64748B)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.student.email} • Term: ${widget.termLabel}',
                        style: const TextStyle(
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
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            // Study Load Header & Count
            Row(
              children: [
                const Icon(Icons.menu_book_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Enrolled Study Load (Classes)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                if (_studyLoads != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_studyLoads!.length} classes',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: AppColors.primary),
                  tooltip: 'Refresh Study Load',
                  onPressed: _fetchStudyLoads,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Classes List Content
            Expanded(
              child: _buildContent(),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Registrar student status governance • Use actions menu to Drop, Withdraw, or Re-enroll.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            SizedBox(height: 12),
            Text('Loading student study load...',
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
                color: Color(0xFFDC2626), size: 36),
            const SizedBox(height: 8),
            Text(
              'Failed to load study load: $_error',
              style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _fetchStudyLoads,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_studyLoads == null || _studyLoads!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 42, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            const Text(
              'No enrolled classes found for this student in this term.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ListView.separated(
          itemCount: _studyLoads!.length,
          separatorBuilder: (ctx, i) =>
              const Divider(height: 1, color: AppColors.border),
          itemBuilder: (ctx, index) {
            final load = _studyLoads![index];
            final isUpdatingThis = _updatingStudyLoadId == load.studyLoadId;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      load.subjectCode,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          load.subjectTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Section: ${load.className} • Instructor: ${load.teacherName ?? "Unassigned"}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildLoadBadge(load.loadStatus),
                  const SizedBox(width: 16),
                  if (isUpdatingThis)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  else if (!load.isPending)
                    PopupMenuButton<int>(
                      tooltip: 'Change Status',
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                      onSelected: (targetStatus) {
                        _confirmAndUpdateStatus(load, targetStatus);
                      },
                      itemBuilder: (ctx) {
                        final currentStatus = load.loadStatusInt;
                        return [
                          if (currentStatus != 1)
                            const PopupMenuItem<int>(
                              value: 1,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.undo_rounded,
                                      size: 18, color: Color(0xFF059669)),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Re-enroll Student',
                                      style: TextStyle(
                                        color: Color(0xFF059669),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (currentStatus != 2)
                            const PopupMenuItem<int>(
                              value: 2,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_remove_outlined,
                                      size: 18, color: Color(0xFFDC2626)),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Drop Student',
                                      style: TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (currentStatus != 3)
                            const PopupMenuItem<int>(
                              value: 3,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.exit_to_app_rounded,
                                      size: 18, color: Color(0xFFD97706)),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Withdraw Student',
                                      style: TextStyle(
                                        color: Color(0xFFD97706),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ];
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
