import 'dart:async';
import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/class_models.dart';
import '../../models/grading_models.dart';
import '../../repositories/grading_repository.dart';
import '../../theme/app_theme.dart';

/// Shared dialog for assigning, reassigning, or removing teacher assignments for a class.
class AssignTeacherDialog extends StatefulWidget {
  final ClassModel classItem;
  final String? currentTeacherName;

  /// Called with the selected [teacherUserId], or `null` if removing the assignment.
  final void Function(String? teacherUserId) onAssign;

  const AssignTeacherDialog({
    super.key,
    required this.classItem,
    required this.onAssign,
    this.currentTeacherName,
  });

  @override
  State<AssignTeacherDialog> createState() => _AssignTeacherDialogState();
}

class _AssignTeacherDialogState extends State<AssignTeacherDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<UserSearchResultModel> _results = [];
  bool _isSearching = false;
  String? _searchError;
  UserSearchResultModel? _selected;

  @override
  void initState() {
    super.initState();
    // Load the full list on open (no query = all Teachers and Program Heads).
    _runSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
        const Duration(milliseconds: 350), () => _runSearch(value.trim()));
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final repo = getIt<UserSearchRepository>();
      final results =
          await repo.searchTeachingStaff(query: query.isEmpty ? null : query);
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _handleRemove(BuildContext context) async {
    final c = widget.classItem;
    final currentTeacher = (c.teacherName != null && c.teacherName!.trim().isNotEmpty)
        ? c.teacherName!.trim()
        : (widget.currentTeacherName?.trim() ?? 'assigned teacher');
    final classIdentifier = (c.subjectCode != null && c.subjectCode!.trim().isNotEmpty)
        ? '${c.subjectCode!.trim()} — ${c.className}'
        : c.className;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Assignment?'),
        content: Text(
          'Remove $currentTeacher from $classIdentifier? This class will become unassigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF991B1B),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop();
      widget.onAssign(null);
    }
  }

  Future<void> _handleAssign(BuildContext context) async {
    if (_selected == null) return;

    final c = widget.classItem;
    final hasAssignedTeacher = c.userId != null && c.userId!.trim().isNotEmpty;

    if (hasAssignedTeacher) {
      final currentTeacher = (c.teacherName != null && c.teacherName!.trim().isNotEmpty)
          ? c.teacherName!.trim()
          : (widget.currentTeacherName?.trim() ?? 'Current Teacher');
      final classIdentifier = (c.subjectCode != null && c.subjectCode!.trim().isNotEmpty)
          ? '${c.subjectCode!.trim()} — ${c.className}'
          : c.className;

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reassign Class?'),
          content: Text(
            'Reassign $classIdentifier from $currentTeacher to ${_selected!.fullName}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('Reassign'),
            ),
          ],
        ),
      );

      if (confirmed == true && context.mounted) {
        Navigator.of(context).pop();
        widget.onAssign(_selected!.userId);
      }
    } else {
      // Lower-risk action with nothing to lose — assign immediately on selection.
      Navigator.of(context).pop();
      widget.onAssign(_selected!.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.classItem;
    final hasAssignedTeacher =
        c.userId != null && c.userId!.trim().isNotEmpty;
    final isReassigning = hasAssignedTeacher;
    final currentTeacher = (c.teacherName != null && c.teacherName!.trim().isNotEmpty)
        ? c.teacherName!.trim()
        : widget.currentTeacherName?.trim();

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isReassigning
                        ? Icons.swap_horiz_rounded
                        : Icons.person_add_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isReassigning ? 'Reassign Teacher' : 'Assign Teacher',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${c.subjectCode ?? ''} · ${c.titleWithCurriculum()} · ${c.className}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                  tooltip: 'Cancel',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Current teacher note (reassign context)
            if (isReassigning && currentTeacher != null && currentTeacher.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    const Text(
                      'Currently assigned: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        currentTeacher,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            // ── Search Bar ──
            SizedBox(
              height: 42,
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search teacher by name or email...',
                  hintStyle: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search,
                      size: 18, color: AppColors.textSecondary),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            _runSearch('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
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
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),

            // ── Results List ──
            Flexible(
              child: _buildResultsList(),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),

            // ── Selected Teacher Preview ──
            if (_selected != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Selected: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _selected!.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Actions ──
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                // "Remove Assignment" clearly separated action button (only if class has assigned teacher)
                if (hasAssignedTeacher)
                  OutlinedButton.icon(
                    key: const ValueKey('remove_assignment_button'),
                    onPressed: () => _handleRemove(context),
                    icon: const Icon(Icons.person_remove_rounded,
                        size: 15, color: Color(0xFFDC2626)),
                    label: const Text(
                      'Remove Assignment',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      backgroundColor: const Color(0xFFFEF2F2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _selected == null
                          ? null
                          : () => _handleAssign(context),
                      style: ElevatedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        disabledForegroundColor: AppColors.textSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                      icon: const Icon(Icons.person_add_rounded, size: 16),
                      label: Text(isReassigning ? 'Reassign' : 'Assign'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    if (_isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(height: 10),
              Text('Searching teachers...',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (_searchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFDC2626), size: 32),
              const SizedBox(height: 8),
              Text(
                'Failed to search: $_searchError',
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _runSearch(_searchCtrl.text.trim()),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_search_rounded,
                  size: 36, color: Color(0xFFCBD5E1)),
              SizedBox(height: 8),
              Text(
                'No teachers found',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _results.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, color: AppColors.border),
          itemBuilder: (ctx, index) {
            final teacher = _results[index];
            final isSelected = _selected?.userId == teacher.userId;
            final isCurrentlyAssigned = widget.classItem.userId == teacher.userId;

            return InkWell(
              onTap: () => setState(() =>
                  _selected = isSelected ? null : teacher),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.07)
                    : Colors.white,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : const Color(0xFFF1F5F9),
                      foregroundColor: isSelected
                          ? AppColors.primary
                          : const Color(0xFF64748B),
                      child: Text(
                        teacher.fullName.isNotEmpty
                            ? teacher.fullName[0].toUpperCase()
                            : 'T',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  teacher.fullName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurrentlyAssigned) ...[
                                const SizedBox(width: 6),
                                const _CurrentBadge(),
                              ],
                            ],
                          ),
                          Text(
                            teacher.email,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          size: 18, color: AppColors.primary)
                    else
                      const SizedBox(width: 18),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF6EE7B7)),
      ),
      child: const Text(
        'Current',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Color(0xFF065F46),
        ),
      ),
    );
  }
}
