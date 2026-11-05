import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/class_models.dart';
import '../../repositories/class_repository.dart';
import '../../theme/app_theme.dart';
import 'status_badge.dart';
import 'edit_lrn_dialog.dart';
import 'reason_dialog.dart';

class ClassRosterDialog extends StatefulWidget {
  final ClassModel classItem;
  final VoidCallback? onRosterUpdated;

  const ClassRosterDialog({
    super.key,
    required this.classItem,
    this.onRosterUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required ClassModel classItem,
    VoidCallback? onRosterUpdated,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ClassRosterDialog(
        classItem: classItem,
        onRosterUpdated: onRosterUpdated,
      ),
    );
  }

  @override
  State<ClassRosterDialog> createState() => _ClassRosterDialogState();
}

class _ClassRosterDialogState extends State<ClassRosterDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<ClassRosterItemModel>? _roster;
  bool _isLoading = true;
  String? _error;
  String _filter = '';
  String? _updatingStudyLoadId;

  @override
  void initState() {
    super.initState();
    _fetchRoster();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRoster() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = getIt<ClassRepository>();
      final list = await repo.getClassRoster(widget.classItem.classId);
      if (mounted) {
        setState(() {
          _roster = list;
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
    ClassRosterItemModel student,
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

    // Dropping and withdrawing need a reason; it is printed on the Adding/Dropping form.
    final reason = await ReasonDialog.ask(
      context,
      title: '$actionVerb Student?',
      message: 'Change ${student.displayName}\'s enrollment in ${widget.classItem.subjectCode} to $statusName. '
          '${isDestructive ? 'The teacher\'s grade book updates right away.' : 'The student goes back on the class list.'}',
      hint: isDestructive ? 'e.g. Schedule conflict, student request, medical' : null,
      confirmLabel: '$actionVerb Student',
      confirmColor: targetStatus == 1
          ? const Color(0xFF059669)
          : targetStatus == 2
              ? const Color(0xFFDC2626)
              : const Color(0xFFD97706),
      required: isDestructive,
    );
    if (reason == null || !mounted) return;

    setState(() {
      _updatingStudyLoadId = student.studyLoadId;
    });

    try {
      final repo = getIt<ClassRepository>();
      final updated = await repo.updateStudyLoadStatus(student.studyLoadId, targetStatus, reason: reason.isEmpty ? null : reason);

      if (mounted) {
        setState(() {
          if (_roster != null) {
            final index = _roster!.indexWhere((s) => s.studyLoadId == student.studyLoadId);
            if (index != -1) {
              _roster![index] = updated;
            }
          }
          _updatingStudyLoadId = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${student.displayName} updated to $statusName successfully.',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        widget.onRosterUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _updatingStudyLoadId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildLoadBadge(String status) => StatusBadge.forLoadStatus(status);

  @override
  Widget build(BuildContext context) {
    final c = widget.classItem;
    final displayedRoster = (_roster ?? []).where((item) {
      if (item.isRejected) return false;
      if (_filter.isEmpty) return true;
      return item.displayName.toLowerCase().contains(_filter) ||
          (item.studentUserId?.toLowerCase().contains(_filter) ?? false);
    }).toList();

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        width: 880,
        height: 720,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (c.subjectCode != null && c.subjectCode!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                c.subjectCode!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Text(
                              c.className,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (c.teacherName != null && c.teacherName!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                '👤 ${c.teacherName}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.subjectTitle ?? 'Untitled Subject',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Term: ${c.termLabel} • Schedule: ${c.scheduleSummary}',
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

            // Controls & Filter Bar
            Row(
              children: [
                const Icon(Icons.people_alt_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Enrolled Students Roster',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                if (_roster != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_roster!.where((item) => !item.isRejected).length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                const Spacer(),
                SizedBox(
                  width: 260,
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) =>
                        setState(() => _filter = val.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Filter students by name or ID...',
                      hintStyle: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search,
                          size: 16, color: AppColors.textSecondary),
                      suffixIcon: _filter.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _filter = '');
                              },
                            )
                          : null,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Roster Table Content
            Expanded(
              child: _buildRosterBody(displayedRoster),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Registrar enrollment governance • Changes immediately sync to teacher grade sheets',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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

  Widget _buildRosterBody(List<ClassRosterItemModel> roster) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            SizedBox(height: 12),
            Text('Loading student roster...',
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
              'Failed to load roster: $_error',
              style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _fetchRoster,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (roster.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 42, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              _filter.isNotEmpty
                  ? 'No enrolled students match "$_filter"'
                  : 'No students are enrolled in this class yet.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
          itemCount: roster.length,
          separatorBuilder: (ctx, i) =>
              const Divider(height: 1, color: AppColors.border),
          itemBuilder: (ctx, index) {
            final item = roster[index];
            final isUpdatingThis = _updatingStudyLoadId == item.studyLoadId;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF475569),
                    child: Text(
                      item.displayName.isNotEmpty
                          ? item.displayName[0].toUpperCase()
                          : 'S',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.displayName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (item.hasLrn == false) ...[
                              const SizedBox(width: 8),
                              StatusBadge.noLrn(
                                onTap: item.studentUserId != null
                                    ? () => EditLrnDialog.showForStudent(
                                          context,
                                          userId: item.studentUserId!,
                                          studentName: item.displayName,
                                          currentLrn: item.lrn,
                                          onSaved: (_) => _fetchRoster(),
                                        )
                                    : null,
                              ),
                            ] else if (item.lrn != null && item.lrn!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: item.studentUserId != null
                                    ? () => EditLrnDialog.showForStudent(
                                          context,
                                          userId: item.studentUserId!,
                                          studentName: item.displayName,
                                          currentLrn: item.lrn,
                                          onSaved: (_) => _fetchRoster(),
                                        )
                                    : null,
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
                                        'LRN: ${item.lrn}',
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
                        if (item.studentUserId != null &&
                            item.studentUserId!.isNotEmpty)
                          Text(
                            'User ID: ${item.studentUserId}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildLoadBadge(item.loadStatus),
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
                  else if (!item.isPending)
                    PopupMenuButton<int>(
                      tooltip: 'Change Status',
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                      onSelected: (targetStatus) {
                        _confirmAndUpdateStatus(item, targetStatus);
                      },
                      itemBuilder: (ctx) {
                        final currentStatus = item.loadStatusInt;
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
