import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/class_models.dart';
import '../../models/grading_models.dart';
import '../../repositories/class_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/study_load_pdf.dart';
import 'status_badge.dart';
import 'edit_lrn_dialog.dart';
import 'edit_year_level_dialog.dart';
import 'overload_badge.dart';
import 'student_grades_dialog.dart';
import 'study_load_builder_dialog.dart';

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
  bool _isFinalizingAll = false;
  late String? _currentLrn;
  late bool? _hasLrn;
  late int? _currentYearLevel;
  UnitLimitModel? _unitLimit;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _currentLrn = widget.student.lrn;
    _hasLrn = widget.student.hasLrn;
    _currentYearLevel = widget.student.yearLevel;
    _fetchStudyLoads();
  }

  Future<void> _fetchStudyLoads() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _fetchUnitLimit();

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

  /// Prints the Enrolled subjects only; Pending loads are not official yet.
  Future<void> _printStudyLoad() async {
    setState(() => _isPrinting = true);
    try {
      final data = StudyLoadPrintData(
        studentName: widget.student.fullName,
        lrn: _currentLrn,
        programCode: widget.student.programCode,
        yearLevel: _currentYearLevel,
        termLabel: widget.termLabel,
        loads: _studyLoads ?? const [],
      );
      final bytes = await buildStudyLoadPdf(data, logo: await loadSchoolLogo());
      final safeName = widget.student.fullName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      await printPdf(bytes, 'StudyLoad_$safeName.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not print: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  /// Only used for the overload note, so failures are ignored.
  Future<void> _fetchUnitLimit() async {
    UnitLimitModel? limit;
    try {
      limit = await getIt<ClassRepository>()
          .getUnitLimit(widget.student.userId, widget.termId);
    } catch (_) {
      limit = null;
    }
    if (mounted) setState(() => _unitLimit = limit);
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

  Future<void> _finalizeAll() async {
    final pending = _studyLoads?.where((l) => l.isPending).toList() ?? [];
    if (pending.isEmpty) return;

    setState(() {
      _isFinalizingAll = true;
    });

    try {
      final repo = getIt<ClassRepository>();
      final result = await repo.finalizeStudyLoads(
        userId: widget.student.userId,
        termId: widget.termId,
        studyLoadIds: pending.map((l) => l.studyLoadId).toList(),
      );

      await _fetchStudyLoads();

      if (mounted) {
        final count = (result['finalizedLoads'] as List?)?.length ?? pending.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully finalized $count study load(s).'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to finalize: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFinalizingAll = false;
        });
      }
    }
  }

  Future<void> _finalizeSingle(ClassRosterItemModel load) async {
    setState(() {
      _updatingStudyLoadId = load.studyLoadId;
    });

    try {
      final repo = getIt<ClassRepository>();
      await repo.finalizeStudyLoads(
        userId: widget.student.userId,
        termId: widget.termId,
        studyLoadIds: [load.studyLoadId],
      );

      await _fetchStudyLoads();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${load.subjectCode} finalized and enrolled.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to finalize ${load.subjectCode}: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingStudyLoadId = null;
        });
      }
    }
  }

  Future<void> _rejectPending(ClassRosterItemModel load) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Reject Pending Load?'),
        content: Text(
          'Are you sure you want to reject ${load.subjectCode} - ${load.subjectTitle}? This will reject the load.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
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
      final updated = await repo.updateStudyLoadStatus(load.studyLoadId, 5);

      if (mounted) {
        setState(() {
          if (_studyLoads != null) {
            final idx = _studyLoads!.indexWhere((s) => s.studyLoadId == load.studyLoadId);
            if (idx != -1) {
              _studyLoads![idx] = updated;
            }
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${load.subjectCode} rejected and marked Dropped.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingStudyLoadId = null;
        });
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
                      const SizedBox(height: 4),
                      // ── Year Level row with inline edit ─────────────────
                      Row(
                        children: [
                          const Icon(Icons.bar_chart_rounded,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            _currentYearLevel != null
                                ? 'Year $_currentYearLevel'
                                : 'Year level not set',
                            style: TextStyle(
                              fontSize: 12,
                              color: _currentYearLevel != null
                                  ? AppColors.textSecondary
                                  : const Color(0xFFEF4444),
                              fontWeight: _currentYearLevel != null
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              EditYearLevelDialog.show(
                                context,
                                userId: widget.student.userId,
                                studentName: widget.student.fullName,
                                currentYearLevel: _currentYearLevel,
                                onSaved: (newLevel) {
                                  setState(() => _currentYearLevel = newLevel);
                                },
                              );
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.edit_outlined,
                                  size: 13, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
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
                const Icon(Icons.menu_book_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'Study Load & Enrollment',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
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
                            '${_studyLoads!.length} total classes',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('print_study_load_button'),
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Print', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: (_isPrinting || !(_studyLoads?.any((l) => l.isEnrolled) ?? false))
                      ? null
                      : _printStudyLoad,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const ValueKey('view_grades_button'),
                  icon: const Icon(Icons.grading_rounded, size: 16),
                  label: const Text('Grades', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => StudentGradesDialog.show(
                    context,
                    userId: widget.student.userId,
                    studentName: widget.student.fullName,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const ValueKey('build_study_load_button'),
                  icon: const Icon(Icons.architecture_rounded, size: 16),
                  label: const Text('Build study load', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () async {
                    final updated = await StudyLoadBuilderDialog.show(
                      context,
                      student: widget.student,
                      initialTermId: widget.termId,
                      initialTermLabel: widget.termLabel,
                      onEnrolled: _fetchStudyLoads,
                    );
                    if (updated == true) {
                      _fetchStudyLoads();
                    }
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: AppColors.primary),
                  tooltip: 'Refresh Study Load',
                  onPressed: _fetchStudyLoads,
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_unitLimit != null && _unitLimit!.isOverloaded)
              OverloadBanner(
                termUnits: _unitLimit!.currentUnits,
                maxUnits: _unitLimit!.maxUnits,
                approvedBy: _unitLimit!.overloadApprovedBy,
                reason: _unitLimit!.overloadReason,
              ),

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
                    'Registrar student status governance • Finalize pending loads, or Drop, Withdraw, and Re-enroll classes.',
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

    final pendingLoads = _studyLoads!.where((l) => l.isPending).toList();
    final otherLoads = _studyLoads!.where((l) => !l.isPending).toList();

    return ListView(
      children: [
        if (pendingLoads.isNotEmpty) ...[
          _buildPendingSection(pendingLoads),
          const SizedBox(height: 16),
        ],
        _buildEnrolledSection(otherLoads),
      ],
    );
  }

  Widget _buildPendingSection(List<ClassRosterItemModel> pendingLoads) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFFDE68A))),
            ),
            child: Row(
              children: [
                const Icon(Icons.pending_actions_rounded, size: 20, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'Pending Study Load',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE68A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${pendingLoads.length} pending',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isFinalizingAll ? null : _finalizeAll,
                  icon: _isFinalizingAll
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text('Finalize all'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pendingLoads.length,
            separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFFDE68A)),
            itemBuilder: (ctx, index) {
              final load = pendingLoads[index];
              return _buildPendingLoadRow(load);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPendingLoadRow(ClassRosterItemModel load) {
    final isUpdatingThis = _updatingStudyLoadId == load.studyLoadId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706),
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        load.subjectTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (load.isForced) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Forced enrollment: ${load.forcedReason ?? "No reason specified"}',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_open_rounded, size: 12, color: Color(0xFFB45309)),
                              SizedBox(width: 4),
                              Text(
                                'Forced',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Section: ${load.className} • Instructor: ${load.teacherName ?? "Unassigned"}${load.isForced && load.forcedReason != null ? " • Reason: ${load.forcedReason}" : ""}',
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
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () => _finalizeSingle(load),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF059669),
                    side: const BorderSide(color: Color(0xFF059669)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Finalize', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _rejectPending(load),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEnrolledSection(List<ClassRosterItemModel> enrolledLoads) {
    if (enrolledLoads.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'No enrolled classes found for this student in this term.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Text(
                  'Enrolled & Term Classes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${enrolledLoads.length} classes',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: enrolledLoads.length,
            separatorBuilder: (ctx, i) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (ctx, index) {
              final load = enrolledLoads[index];
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
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  load.subjectTitle,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (load.isForced) ...[
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: 'Forced enrollment: ${load.forcedReason ?? "No reason specified"}',
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      border: Border.all(color: const Color(0xFFF59E0B)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.lock_open_rounded, size: 12, color: Color(0xFFB45309)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Forced',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFB45309),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
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
                    else if (!load.isPending && !load.isRejected)
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
        ],
      ),
    );
  }
}
