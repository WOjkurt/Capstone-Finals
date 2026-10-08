import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/faculty_bloc.dart';
import '../blocs/program_overview_bloc.dart';
import '../injection.dart';
import '../models/class_models.dart';
import '../repositories/class_repository.dart';
import '../theme/app_theme.dart';
import 'widgets/assign_teacher_dialog.dart';
import 'widgets/page_header.dart';
import 'widgets/status_badge.dart';

enum _OverviewViewMode { byFaculty, byClass }

class ProgramOverviewView extends StatefulWidget {
  const ProgramOverviewView({super.key});

  @override
  State<ProgramOverviewView> createState() => _ProgramOverviewViewState();
}

class _ProgramOverviewViewState extends State<ProgramOverviewView> {
  final TextEditingController _searchController = TextEditingController();
  _OverviewViewMode _viewMode = _OverviewViewMode.byFaculty;
  String _searchQuery = '';
  // Cache for the last successfully loaded class list — kept in view state so it
  // stays visible during the transient ProgramOverviewAssigning state.
  List<ClassModel> _lastKnownClasses = [];
  bool _wasAssigning = false;

  @override
  void initState() {
    super.initState();
    context.read<ProgramOverviewBloc>().add(LoadProgramClassesEvent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openClassDetail(BuildContext context, ClassModel classItem) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _ProgramClassDetailDialog(classItem: classItem),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Program Overview',
          subtitle: 'Departmental curriculum oversight, faculty course distribution, and class monitoring.',
          action: OutlinedButton.icon(
            onPressed: () =>
                context.read<ProgramOverviewBloc>().add(LoadProgramClassesEvent()),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        Expanded(
          child: BlocConsumer<ProgramOverviewBloc, ProgramOverviewState>(
            listener: (context, state) {
              // Cache the class list whenever we receive a fresh load.
              if (state is ProgramOverviewAssigning) {
                _wasAssigning = true;
              } else if (state is ProgramOverviewLoaded) {
                _lastKnownClasses = state.classes;
                if (_wasAssigning) {
                  _wasAssigning = false;
                  context.read<FacultyBloc>().add(LoadFacultyEvent());
                }
              } else if (state is ProgramOverviewAssignError) {
                _wasAssigning = false;
                _lastKnownClasses = state.previousClasses;
              }
              // Show a snackbar on assignment error and restore previous data.
              if (state is ProgramOverviewAssignError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(
                          'Failed to assign teacher: ${state.message}',
                          style: const TextStyle(fontSize: 13),
                        )),
                      ],
                    ),
                    backgroundColor: const Color(0xFFDC2626),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            },
            builder: (context, state) {
              // Resolve the class list from whichever state carries it.
              List<ClassModel> classes;
              bool isAssigning = false;
              String? assigningClassId;

              if (state is ProgramOverviewLoaded) {
                classes = state.classes;
              } else if (state is ProgramOverviewAssigning) {
                // Keep the last known list visible while saving.
                isAssigning = true;
                assigningClassId = state.classId;
                classes = _lastKnownClasses;
              } else if (state is ProgramOverviewAssignError) {
                classes = state.previousClasses;
              } else {
                classes = _lastKnownClasses;
              }

              if (state is ProgramOverviewLoading) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Loading department classes...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (state is ProgramOverviewError) {
                return Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 440),
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFDC2626), size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'Failed to load program overview',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => context
                              .read<ProgramOverviewBloc>()
                              .add(LoadProgramClassesEvent()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (state is ProgramOverviewLoaded ||
                  state is ProgramOverviewAssigning ||
                  state is ProgramOverviewAssignError) {
                final all = classes;
                final totalClasses = all.length;
                final activeFaculty = all
                    .where((c) =>
                        c.userId != null &&
                        (c.teacherName?.trim().isNotEmpty ?? false))
                    .map((c) => c.teacherName!.trim().toLowerCase())
                    .toSet()
                    .length;
                final unassignedCount = all.where((c) => c.userId == null).length;

                final filtered = all.where((c) {
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  return (c.subjectCode?.toLowerCase().contains(q) ?? false) ||
                      (c.subjectTitle?.toLowerCase().contains(q) ?? false) ||
                      c.className.toLowerCase().contains(q) ||
                      (c.teacherName?.toLowerCase().contains(q) ?? false);
                }).toList();

                return Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSummaryCards(
                            totalClasses: totalClasses,
                            activeFaculty: activeFaculty,
                            unassignedCount: unassignedCount,
                          ),
                          const SizedBox(height: 20),
                          _buildControlBar(
                              filteredCount: filtered.length,
                              totalCount: totalClasses),
                          const SizedBox(height: 20),
                          if (filtered.isEmpty)
                            _buildEmptyResults()
                          else if (_viewMode == _OverviewViewMode.byFaculty)
                            _buildByFacultyView(filtered,
                                assigningClassId: assigningClassId)
                          else
                            _buildByClassView(filtered,
                                assigningClassId: assigningClassId),
                        ],
                      ),
                    ),
                    // Dimmed overlay while assignment is saving.
                    if (isAssigning)
                      Positioned.fill(
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.6),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 14),
                                Text(
                                  'Saving assignment...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards({
    required int totalClasses,
    required int activeFaculty,
    required int unassignedCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Total Offerings',
            value: '$totalClasses',
            subtitle: 'Department classes scheduled',
            icon: Icons.class_rounded,
            iconColor: AppColors.primary,
            iconBg: AppColors.primary.withValues(alpha: 0.1),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Active Faculty',
            value: '$activeFaculty',
            subtitle: 'Instructors currently assigned',
            icon: Icons.people_alt_rounded,
            iconColor: const Color(0xFF059669),
            iconBg: const Color(0xFFD1FAE5),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Unassigned Offerings',
            value: '$unassignedCount',
            subtitle: unassignedCount > 0
                ? 'Classes requiring instructor'
                : 'All classes assigned',
            icon: Icons.warning_amber_rounded,
            iconColor: unassignedCount > 0
                ? const Color(0xFFD97706)
                : const Color(0xFF6B7280),
            iconBg: unassignedCount > 0
                ? const Color(0xFFFEF3C7)
                : const Color(0xFFF3F4F6),
            borderColor: unassignedCount > 0 ? const Color(0xFFFDE68A) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildControlBar({required int filteredCount, required int totalCount}) {
    return Row(
      children: [
        // Search bar
        Expanded(
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search by subject code, title, section, or faculty name...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                filled: true,
                fillColor: Colors.white,
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
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // View Toggle (By Faculty vs By Class)
        Container(
          height: 42,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ViewToggleButton(
                label: 'By Faculty',
                icon: Icons.badge_outlined,
                isSelected: _viewMode == _OverviewViewMode.byFaculty,
                onTap: () => setState(() => _viewMode = _OverviewViewMode.byFaculty),
              ),
              const SizedBox(width: 2),
              _ViewToggleButton(
                label: 'By Class',
                icon: Icons.grid_view_rounded,
                isSelected: _viewMode == _OverviewViewMode.byClass,
                onTap: () => setState(() => _viewMode = _OverviewViewMode.byClass),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyResults() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No matching classes found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try adjusting your search criteria',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _openAssignDialog(BuildContext context, ClassModel classItem) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AssignTeacherDialog(
        classItem: classItem,
        onAssign: (teacherUserId) {
          context.read<ProgramOverviewBloc>().add(
                AssignTeacherEvent(
                  classId: classItem.classId,
                  teacherUserId: teacherUserId,
                ),
              );
        },
      ),
    );
  }

  // ── By Faculty View ──
  Widget _buildByFacultyView(List<ClassModel> classes,
      {String? assigningClassId}) {
    // Separate unassigned and assigned
    final unassigned = classes.where((c) => c.userId == null).toList();

    final Map<String, List<ClassModel>> facultyMap = {};
    for (final c in classes) {
      if (c.userId != null) {
        final name = (c.teacherName != null && c.teacherName!.trim().isNotEmpty)
            ? c.teacherName!.trim()
            : 'Unknown Faculty';
        facultyMap.putIfAbsent(name, () => []).add(c);
      }
    }

    final sortedFaculty = facultyMap.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Unassigned Offerings at the top for immediate executive attention
        if (unassigned.isNotEmpty) ...[
          _buildUnassignedBanner(unassigned, assigningClassId: assigningClassId),
          const SizedBox(height: 24),
        ],

        // Assigned Faculty groups
        if (sortedFaculty.isEmpty && unassigned.isEmpty)
          const Center(child: Text('No classes available.'))
        else ...[
          for (final facultyName in sortedFaculty) ...[
            _buildFacultyCard(facultyName, facultyMap[facultyName]!,
                assigningClassId: assigningClassId),
            const SizedBox(height: 16),
          ],
        ],
      ],
    );
  }

  Widget _buildUnassignedBanner(List<ClassModel> unassigned,
      {String? assigningClassId}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE68A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFF92400E), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Unassigned Offerings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF92400E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${unassigned.length} Classes',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'These class sections currently have no assigned faculty member and require staffing.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Class list under unassigned
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: unassigned
                .map((c) => _buildCompactClassItem(c,
                    isWarning: true,
                    isSaving: assigningClassId == c.classId))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFacultyCard(String facultyName, List<ClassModel> classes,
      {String? assigningClassId}) {
    final totalStudents = classes.fold<int>(0, (sum, c) => sum + c.enrolledCount);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Faculty Header Row
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                foregroundColor: AppColors.primary,
                child: Text(
                  facultyName.isNotEmpty ? facultyName[0].toUpperCase() : 'F',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facultyName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${classes.length} assigned ${classes.length == 1 ? 'class' : 'classes'} · $totalStudents enrolled students',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.class_outlined, size: 13, color: Color(0xFF1D4ED8)),
                    const SizedBox(width: 6),
                    Text(
                      '${classes.length} Classes',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          // Faculty classes
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: classes
                .map((c) => _buildCompactClassItem(c,
                    isSaving: assigningClassId == c.classId))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactClassItem(ClassModel c,
      {bool isWarning = false, bool isSaving = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: isSaving ? null : () => _openClassDetail(context, c),
      child: Container(
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isWarning ? Colors.white : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isWarning ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isWarning ? const Color(0xFF92400E) : AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    c.subjectCode ?? 'No Code',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    c.className,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              c.subjectTitle ?? 'Untitled Subject',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    c.scheduleSummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline,
                          size: 12, color: Color(0xFF475569)),
                      const SizedBox(width: 4),
                      Text(
                        '${c.enrolledCount} Enrolled',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSaving)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Assign / Change button
                      GestureDetector(
                        onTap: () => _openAssignDialog(context, c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isWarning
                                ? const Color(0xFF92400E)
                                : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isWarning
                                    ? Icons.person_add_rounded
                                    : Icons.swap_horiz_rounded,
                                size: 11,
                                color: isWarning
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isWarning ? 'Assign' : 'Change',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isWarning
                                      ? Colors.white
                                      : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'View Roster',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isWarning
                              ? const Color(0xFFB45309)
                              : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: isWarning
                            ? const Color(0xFFB45309)
                            : AppColors.primary,
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

  // ── By Class View (Flat Grid) ──
  Widget _buildByClassView(List<ClassModel> classes,
      {String? assigningClassId}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 3;
        if (constraints.maxWidth < 760) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth < 1140) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: classes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 290,
          ),
          itemBuilder: (context, index) {
            final classItem = classes[index];
            return _ProgramClassCard(
              classItem: classItem,
              isSaving: assigningClassId == classItem.classId,
              onTap: () => _openClassDetail(context, classItem),
              onAssign: () => _openAssignDialog(context, classItem),
            );
          },
        );
      },
    );
  }
}

// ── Stat Card Component ──
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color? borderColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── View Toggle Button ──
class _ViewToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Flat Class Card for By Class View ──
class _ProgramClassCard extends StatefulWidget {
  final ClassModel classItem;
  final VoidCallback onTap;
  final VoidCallback onAssign;
  final bool isSaving;

  const _ProgramClassCard({
    required this.classItem,
    required this.onTap,
    required this.onAssign,
    this.isSaving = false,
  });

  @override
  State<_ProgramClassCard> createState() => _ProgramClassCardState();
}

class _ProgramClassCardState extends State<_ProgramClassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.classItem;
    final isUnassigned = c.userId == null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? AppColors.primary
                  : (isUnassigned ? const Color(0xFFFDE68A) : AppColors.border),
              width: _isHovered ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: _isHovered ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Code + Section + Enrolled
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      c.subjectCode ?? 'No Code',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
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
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${c.enrolledCount} Enrolled',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Subject Title
              Text(
                c.subjectTitle ?? 'Untitled Subject',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              // Teacher Badge
              if (isUnassigned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 13, color: Color(0xFF92400E)),
                      SizedBox(width: 4),
                      Text(
                        'Unassigned Faculty',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline_rounded,
                              size: 13, color: Color(0xFF475569)),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 130),
                            child: Text(
                              c.teacherName ?? 'Faculty Assigned',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Change teacher affordance
                    if (!widget.isSaving)
                      GestureDetector(
                        onTap: widget.onAssign,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.25)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.swap_horiz_rounded,
                                  size: 12, color: AppColors.primary),
                              SizedBox(width: 3),
                              Text(
                                'Change',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              const Spacer(),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 8),
              // Unassigned: show assign button
              if (isUnassigned && !widget.isSaving) ...[
                GestureDetector(
                  onTap: widget.onAssign,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF92400E),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_add_rounded,
                            size: 13, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          'Assign Teacher',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (isUnassigned && widget.isSaving) ...[
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Saving...',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              // Schedule summary
              Row(
                children: [
                  const Icon(Icons.schedule,
                      size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      c.scheduleSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Detail Dialog (Schedule + Roster) ──
class _ProgramClassDetailDialog extends StatefulWidget {
  final ClassModel classItem;

  const _ProgramClassDetailDialog({required this.classItem});

  @override
  State<_ProgramClassDetailDialog> createState() =>
      _ProgramClassDetailDialogState();
}

class _ProgramClassDetailDialogState extends State<_ProgramClassDetailDialog> {
  final TextEditingController _rosterSearch = TextEditingController();
  List<ClassRosterItemModel>? _roster;
  bool _isLoading = true;
  String? _error;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _fetchRoster();
  }

  @override
  void dispose() {
    _rosterSearch.dispose();
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

  @override
  Widget build(BuildContext context) {
    final c = widget.classItem;
    final isUnassigned = c.userId == null;

    final displayedRoster = (_roster ?? []).where((item) {
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
        width: 820,
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
                  child: const Icon(Icons.class_rounded,
                      color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              c.subjectCode ?? 'No Code',
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
                              border:
                                  Border.all(color: const Color(0xFFE5E7EB)),
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
                          if (isUnassigned)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: const Text(
                                '⚠️ Unassigned Faculty',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
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
                        'Term: ${c.termLabel}',
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

            // Schedule Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Class Schedules',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (c.schedules.isEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'No specific meeting schedules have been assigned to this class yet.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: c.schedules.map((s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                s.daysOfWeek,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              s.formattedTime,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            if (s.room.trim().isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border:
                                      Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 13, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 4),
                                    Text(
                                      s.room,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            // Roster Section Header + Search Bar
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
                      '${_roster!.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                const Spacer(),
                SizedBox(
                  width: 240,
                  height: 36,
                  child: TextField(
                    controller: _rosterSearch,
                    onChanged: (val) =>
                        setState(() => _filter = val.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Filter by student name...',
                      hintStyle: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search,
                          size: 16, color: AppColors.textSecondary),
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

            // Roster Table
            Expanded(
              child: _buildRosterBody(displayedRoster),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
            CircularProgressIndicator(strokeWidth: 2),
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
            TextButton(
              onPressed: _fetchRoster,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (roster.isEmpty) {
      return Center(
        child: Text(
          _filter.isNotEmpty
              ? 'No enrolled students match "$_filter"'
              : 'No students are enrolled in this class yet.',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF475569),
                    child: Text(
                      item.displayName.isNotEmpty
                          ? item.displayName[0].toUpperCase()
                          : 'S',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (item.studentUserId != null && item.studentUserId!.isNotEmpty)
                          Text(
                            'ID: ${item.studentUserId}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  StatusBadge.forLoadStatus(item.loadStatus),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

