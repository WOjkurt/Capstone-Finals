import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/faculty_bloc.dart';
import '../injection.dart';
import '../models/class_models.dart';
import '../theme/app_theme.dart';

enum _FacultyFilterMode { all, withClasses, zeroClasses }

class FacultyView extends StatelessWidget {
  const FacultyView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FacultyBloc>(
      create: (_) => getIt<FacultyBloc>()..add(LoadFacultyEvent()),
      child: const _FacultyViewContent(),
    );
  }
}

class _FacultyViewContent extends StatefulWidget {
  const _FacultyViewContent();

  @override
  State<_FacultyViewContent> createState() => _FacultyViewContentState();
}

class _FacultyViewContentState extends State<_FacultyViewContent> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _FacultyFilterMode _filterMode = _FacultyFilterMode.all;
  final Set<String> _expandedTeacherIds = {};

  List<FacultyMember> _lastKnownFaculty = [];
  List<ClassModel> _lastKnownUnassigned = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleExpanded(String userId) {
    setState(() {
      if (_expandedTeacherIds.contains(userId)) {
        _expandedTeacherIds.remove(userId);
      } else {
        _expandedTeacherIds.add(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          _buildHeader(context),
          const Divider(height: 1, color: AppColors.border),

          // ── Content ─────────────────────────────────────────────────────────
          Expanded(
            child: BlocConsumer<FacultyBloc, FacultyState>(
              listener: (context, state) {
                if (state is FacultyLoaded) {
                  _lastKnownFaculty = state.faculty;
                  _lastKnownUnassigned = state.unassignedClasses;
                } else if (state is FacultyAssignError) {
                  _lastKnownFaculty = state.previousFaculty;
                  _lastKnownUnassigned = state.previousUnassignedClasses;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Failed to assign class: ${state.message}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
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
                List<FacultyMember> facultyList;
                List<ClassModel> unassignedClasses;
                bool isAssigning = false;
                String? assigningTeacherId;

                if (state is FacultyLoaded) {
                  facultyList = state.faculty;
                  unassignedClasses = state.unassignedClasses;
                } else if (state is FacultyAssigning) {
                  isAssigning = true;
                  assigningTeacherId = state.teacherUserId;
                  facultyList = _lastKnownFaculty;
                  unassignedClasses = _lastKnownUnassigned;
                } else if (state is FacultyAssignError) {
                  facultyList = state.previousFaculty;
                  unassignedClasses = state.previousUnassignedClasses;
                } else {
                  facultyList = _lastKnownFaculty;
                  unassignedClasses = _lastKnownUnassigned;
                }

                if (state is FacultyLoading) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading faculty roster...',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (state is FacultyError) {
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
                            'Failed to Load Faculty',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => context
                                .read<FacultyBloc>()
                                .add(LoadFacultyEvent()),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (state is FacultyLoaded ||
                    state is FacultyAssigning ||
                    state is FacultyAssignError) {
                  final totalFaculty = facultyList.length;
                  final withClassesCount =
                      facultyList.where((f) => f.hasClasses).length;
                  final zeroClassesCount =
                      facultyList.where((f) => !f.hasClasses).length;

                  // Apply search and filter
                  final filtered = facultyList.where((member) {
                    if (_filterMode == _FacultyFilterMode.withClasses &&
                        !member.hasClasses) {
                      return false;
                    }
                    if (_filterMode == _FacultyFilterMode.zeroClasses &&
                        member.hasClasses) {
                      return false;
                    }
                    if (_searchQuery.isNotEmpty) {
                      final q = _searchQuery.toLowerCase();
                      final matchesName = member.fullName.toLowerCase().contains(q);
                      final matchesEmail = member.email.toLowerCase().contains(q);
                      return matchesName || matchesEmail;
                    }
                    return true;
                  }).toList();

                  return Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Summary Cards ───────────────────────────────
                            _buildSummaryCards(
                              totalFaculty: totalFaculty,
                              withClasses: withClassesCount,
                              zeroClasses: zeroClassesCount,
                            ),
                            const SizedBox(height: 24),

                            // ── Search & Filter Controls ────────────────────
                            _buildControlBar(
                              totalFaculty: totalFaculty,
                              withClasses: withClassesCount,
                              zeroClasses: zeroClassesCount,
                            ),
                            const SizedBox(height: 20),

                            // ── Faculty Roster ──────────────────────────────
                            if (filtered.isEmpty)
                              _buildEmptyResults()
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 14),
                                itemBuilder: (ctx, i) {
                                  final member = filtered[i];
                                  final isExpanded =
                                      _expandedTeacherIds.contains(member.userId);
                                  final isCurrentlyAssigning = isAssigning &&
                                      assigningTeacherId == member.userId;

                                  return _buildFacultyCard(
                                    member: member,
                                    isExpanded: isExpanded,
                                    isAssigning: isCurrentlyAssigning,
                                    unassignedClasses: unassignedClasses,
                                    onToggleExpand: () =>
                                        _toggleExpanded(member.userId),
                                    onAssignClass: (classId) {
                                      context.read<FacultyBloc>().add(
                                            AssignFacultyToClassEvent(
                                              classId: classId,
                                              teacherUserId: member.userId,
                                            ),
                                          );
                                    },
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
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
                                    'Assigning teacher to class...',
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
      ),
    );
  }

  // ── Header Bar ─────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.badge_outlined,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Department Faculty',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Instructors roster and teaching workload in your academic program',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh Faculty Roster',
            onPressed: () =>
                context.read<FacultyBloc>().add(LoadFacultyEvent()),
            style: IconButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              hoverColor: AppColors.primaryLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary Cards ──────────────────────────────────────────────────────────

  Widget _buildSummaryCards({
    required int totalFaculty,
    required int withClasses,
    required int zeroClasses,
  }) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Total Faculty',
            value: '$totalFaculty',
            subtitle: 'Instructors in program roster',
            icon: Icons.people_alt_rounded,
            iconColor: AppColors.primary,
            iconBg: AppColors.primary.withValues(alpha: 0.1),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Teachers with Classes',
            value: '$withClasses',
            subtitle: 'Currently assigned to offerings',
            icon: Icons.check_circle_outline_rounded,
            iconColor: const Color(0xFF059669),
            iconBg: const Color(0xFFD1FAE5),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Zero Classes Assigned',
            value: '$zeroClasses',
            subtitle: zeroClasses > 0
                ? 'Faculty without teaching load'
                : 'All faculty have assignments',
            icon: Icons.warning_amber_rounded,
            iconColor: zeroClasses > 0
                ? const Color(0xFFD97706)
                : const Color(0xFF6B7280),
            iconBg: zeroClasses > 0
                ? const Color(0xFFFEF3C7)
                : const Color(0xFFF3F4F6),
            borderColor: zeroClasses > 0 ? const Color(0xFFFDE68A) : null,
          ),
        ),
      ],
    );
  }

  // ── Control Bar (Search & Filter) ──────────────────────────────────────────

  Widget _buildControlBar({
    required int totalFaculty,
    required int withClasses,
    required int zeroClasses,
  }) {
    return Row(
      children: [
        // Search Input
        Expanded(
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search faculty by name or email...',
                hintStyle:
                    const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: AppColors.textSecondary),
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
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Filter Segments
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
              _FilterToggleButton(
                label: 'All ($totalFaculty)',
                icon: Icons.people_outline,
                isSelected: _filterMode == _FacultyFilterMode.all,
                onTap: () =>
                    setState(() => _filterMode = _FacultyFilterMode.all),
              ),
              const SizedBox(width: 2),
              _FilterToggleButton(
                label: 'With Classes ($withClasses)',
                icon: Icons.check_circle_outline,
                isSelected: _filterMode == _FacultyFilterMode.withClasses,
                onTap: () => setState(
                    () => _filterMode = _FacultyFilterMode.withClasses),
              ),
              const SizedBox(width: 2),
              _FilterToggleButton(
                label: 'Zero Classes ($zeroClasses)',
                icon: Icons.warning_amber_rounded,
                isSelected: _filterMode == _FacultyFilterMode.zeroClasses,
                highlightAmber: zeroClasses > 0,
                onTap: () => setState(
                    () => _filterMode = _FacultyFilterMode.zeroClasses),
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
            'No matching faculty members found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try adjusting your search query or filter mode',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Faculty Card Widget ────────────────────────────────────────────────────

  Widget _buildFacultyCard({
    required FacultyMember member,
    required bool isExpanded,
    required bool isAssigning,
    required List<ClassModel> unassignedClasses,
    required VoidCallback onToggleExpand,
    required ValueChanged<String> onAssignClass,
  }) {
    final hasClasses = member.hasClasses;
    final initials = member.fullName.isNotEmpty
        ? member.fullName
            .trim()
            .split(' ')
            .where((w) => w.isNotEmpty)
            .map((w) => w[0].toUpperCase())
            .take(2)
            .join()
        : 'T';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: !hasClasses ? const Color(0xFFFDE68A) : AppColors.border,
          width: !hasClasses ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: !hasClasses
                ? Colors.amber.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row (clickable to expand/collapse)
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: hasClasses
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : const Color(0xFFFEF3C7),
                    foregroundColor: hasClasses
                        ? AppColors.primary
                        : const Color(0xFFD97706),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Name and Email
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                member.fullName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (member.programCode != null &&
                                member.programCode!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border:
                                      Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  member.programCode!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          member.email,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Class Count Badge
                  if (hasClasses)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.class_outlined,
                              size: 14, color: Color(0xFF1D4ED8)),
                          const SizedBox(width: 6),
                          Text(
                            '${member.classCount} ${member.classCount == 1 ? 'Class' : 'Classes'} · ${member.totalEnrolledStudents} Students',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 14, color: Color(0xFFB45309)),
                          SizedBox(width: 6),
                          Text(
                            '0 Classes · Unassigned',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(width: 14),

                  // Chevron indicator
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded Area ──────────────────────────────────────────────────
          if (isExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(20),
              child: hasClasses
                  ? _buildAssignedClassesSection(member.assignedClasses)
                  : _buildZeroClassesSection(
                      context: context,
                      member: member,
                      unassignedClasses: unassignedClasses,
                      onAssignClass: onAssignClass,
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssignedClassesSection(List<ClassModel> classes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.school_outlined,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              'Assigned Class Sections (${classes.length})',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: classes.map((c) => _buildClassCard(c)).toList(),
        ),
      ],
    );
  }

  Widget _buildClassCard(ClassModel c) {
    final scheduleSummary =
        c.schedules.isNotEmpty ? c.schedules.first.summary : 'No schedule set';

    return Container(
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 340),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            c.subjectTitle ?? 'Untitled Subject',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  scheduleSummary,
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
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.people_alt_outlined,
                  size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${c.enrolledCount} enrolled students',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZeroClassesSection({
    required BuildContext context,
    required FacultyMember member,
    required List<ClassModel> unassignedClasses,
    required ValueChanged<String> onAssignClass,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.assignment_late_outlined,
                color: Color(0xFFD97706), size: 20),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No classes currently assigned',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'This faculty member has zero teaching loads assigned in your program this term.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (unassignedClasses.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () => _openAssignClassDialog(
                context: context,
                teacher: member,
                unassignedClasses: unassignedClasses,
                onAssign: onAssignClass,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'Assign to a Class',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Text(
                'All classes staffed',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF92400E),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openAssignClassDialog({
    required BuildContext context,
    required FacultyMember teacher,
    required List<ClassModel> unassignedClasses,
    required ValueChanged<String> onAssign,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AssignClassToTeacherDialog(
        teacher: teacher,
        unassignedClasses: unassignedClasses,
        onAssign: onAssign,
      ),
    );
  }
}

// ── Stat Card Component ──────────────────────────────────────────────────────

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
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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

// ── Filter Toggle Button ─────────────────────────────────────────────────────

class _FilterToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool highlightAmber;
  final VoidCallback onTap;

  const _FilterToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.highlightAmber = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 3,
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
              size: 14,
              color: isSelected
                  ? (highlightAmber ? const Color(0xFFD97706) : AppColors.primary)
                  : (highlightAmber
                      ? const Color(0xFFD97706)
                      : AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (highlightAmber ? const Color(0xFFD97706) : AppColors.primary)
                    : (highlightAmber
                        ? const Color(0xFFD97706)
                        : AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Assign Class to Teacher Dialog ───────────────────────────────────────────

class _AssignClassToTeacherDialog extends StatefulWidget {
  final FacultyMember teacher;
  final List<ClassModel> unassignedClasses;
  final ValueChanged<String> onAssign;

  const _AssignClassToTeacherDialog({
    required this.teacher,
    required this.unassignedClasses,
    required this.onAssign,
  });

  @override
  State<_AssignClassToTeacherDialog> createState() =>
      _AssignClassToTeacherDialogState();
}

class _AssignClassToTeacherDialogState
    extends State<_AssignClassToTeacherDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';
  ClassModel? _selectedClass;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.unassignedClasses.where((c) {
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      final code = (c.subjectCode ?? '').toLowerCase();
      final title = (c.subjectTitle ?? '').toLowerCase();
      final section = c.className.toLowerCase();
      return code.contains(q) || title.contains(q) || section.contains(q);
    }).toList();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded,
                        color: Color(0xFFD97706), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign Class to ${widget.teacher.fullName}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select an unassigned class offering in your program',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 14),

              // Search field
              SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _filter = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search unassigned offerings by code or title...',
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
                    fillColor: const Color(0xFFF8FAFC),
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
              const SizedBox(height: 14),

              // Available classes list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 36, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            const Text(
                              'No matching unassigned classes',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(
                            height: 1, color: AppColors.border),
                        itemBuilder: (ctx, i) {
                          final c = filtered[i];
                          final isSelected = _selectedClass?.classId == c.classId;
                          final schedule = c.schedules.isNotEmpty
                              ? c.schedules.first.summary
                              : 'No schedule set';

                          return InkWell(
                            onTap: () => setState(() => _selectedClass = c),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryLight
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                c.subjectCode ?? 'No Code',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              c.className,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          c.subjectTitle ?? 'Untitled',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$schedule · ${c.enrolledCount} enrolled',
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
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 18),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 14),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _selectedClass == null
                        ? null
                        : () {
                            final classId = _selectedClass!.classId;
                            Navigator.of(context).pop();
                            widget.onAssign(classId);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Confirm Assignment',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
