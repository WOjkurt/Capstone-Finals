import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/grades_bloc.dart';
import '../models/grading_models.dart';
import '../models/setup_models.dart';
import '../theme/app_theme.dart';
import 'widgets/status_badge.dart';

class GradesView extends StatefulWidget {
  final String userId;

  const GradesView({super.key, required this.userId});

  @override
  State<GradesView> createState() => _GradesViewState();
}

class _GradesViewState extends State<GradesView> {
  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  void _loadGrades({bool refresh = false}) {
    context.read<GradesBloc>().add(
          LoadGradesEvent(userId: widget.userId, refresh: refresh),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GradesBloc, GradesState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          body: RefreshIndicator(
            onRefresh: () async {
              _loadGrades(refresh: true);
            },
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(state),
                ),
                ..._buildBodySlivers(state),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Header Section ─────────────────────────────────────────────────────────

  Widget _buildHeader(GradesState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Grades',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'View your official midterm and final grades per academic term.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                onPressed: () => _loadGrades(refresh: true),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (state is GradesLoaded) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Term Dropdown Selector
                if (state.terms.isNotEmpty)
                  _buildTermDropdown(state)
                else
                  _buildStaticTermPill(state.selectedTerm),

                // Clearance Status Pill
                _buildClearanceStatusPill(state),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTermDropdown(GradesLoaded state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AcademicTermModel>(
          value: state.selectedTerm,
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          onChanged: (AcademicTermModel? newTerm) {
            if (newTerm != null) {
              context.read<GradesBloc>().add(
                    SelectTermEvent(term: newTerm, userId: widget.userId),
                  );
            }
          },
          items: state.terms.map((term) {
            final isCurrentActive =
                state.activeTerm?.termId == term.termId || term.isActive;
            return DropdownMenuItem<AcademicTermModel>(
              value: term,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(term.label),
                  if (isCurrentActive) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStaticTermPill(AcademicTermModel? term) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Text(
        term?.label ?? 'No Term Selected',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }

  Widget _buildClearanceStatusPill(GradesLoaded state) {
    final isWithheld = state.isClearanceWithheld;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isWithheld ? AppColors.accentAmberLight : AppColors.accentGreenLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isWithheld
              ? AppColors.accentAmber.withValues(alpha: 0.4)
              : AppColors.accentGreen.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isWithheld ? Icons.lock_clock_outlined : Icons.verified_user_rounded,
            size: 13,
            color: isWithheld ? const Color(0xFFB45309) : AppColors.accentGreenDark,
          ),
          const SizedBox(width: 5),
          Text(
            isWithheld ? 'Clearance Withheld' : 'Clearance Cleared',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isWithheld
                  ? const Color(0xFFB45309)
                  : AppColors.accentGreenDark,
            ),
          ),
        ],
      ),
    );
  }

  // ── Body Slivers ───────────────────────────────────────────────────────────

  List<Widget> _buildBodySlivers(GradesState state) {
    if (state is GradesLoading || state is GradesInitial) {
      return [
        const SliverFillRemaining(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ];
    }

    if (state is GradesError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 44, color: AppColors.error),
                      const SizedBox(height: 12),
                      const Text(
                        'Failed to Load Grades',
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
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _loadGrades(refresh: true),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ];
    }

    if (state is GradesLoaded) {
      // 1. Clearance Masking Check: If clearance is withheld, show explicit banner
      if (state.isClearanceWithheld) {
        return [
          SliverToBoxAdapter(
            child: _buildClearanceWithheldCard(state),
          ),
        ];
      }

      // 2. Loading state when switching terms
      if (state.isTermGradesLoading) {
        return [
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ];
      }

      // 3. Cleared, but empty grades list
      if (state.grades.isEmpty) {
        return [
          SliverToBoxAdapter(
            child: _buildEmptyGradesCard(state),
          ),
        ];
      }

      // 4. Cleared with grades present
      return [
        SliverToBoxAdapter(
          child: _buildSummaryCountsBar(state),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final grade = state.grades[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildGradeCard(grade),
                );
              },
              childCount: state.grades.length,
            ),
          ),
        ),
      ];
    }

    return [];
  }

  // ── Clearance Withheld Banner ──────────────────────────────────────────────

  Widget _buildClearanceWithheldCard(GradesLoaded state) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.accentAmber.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentAmber.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accentAmberLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accentAmber.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFFB45309),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Grades Withheld Pending Clearance',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Official grades for ${state.selectedTerm?.label ?? 'this term'} are currently withheld because grade viewing clearance has not been approved yet.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: Color(0xFFB45309)),
                        SizedBox(width: 6),
                        Text(
                          'Requirements for Clearance',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Verify that all tuition and accounting balances are settled.\n'
                      '• Clear library, laboratory, and student affairs requirements.\n'
                      '• The Registrar\'s Office will unlock grade viewing once clearance is processed.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF78350F),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cleared But Empty State ────────────────────────────────────────────────

  Widget _buildEmptyGradesCard(GradesLoaded state) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Grades Submitted Yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No grades have been submitted yet by your instructors for ${state.selectedTerm?.label ?? 'this term'}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Summary Counts Bar ─────────────────────────────────────────────────────

  Widget _buildSummaryCountsBar(GradesLoaded state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildCountChip(
                label: 'Total Subjects',
                count: state.totalSubjects.toString(),
                color: AppColors.primary,
                bgColor: AppColors.primaryLight,
                icon: Icons.menu_book_rounded,
              ),
              _buildCountChip(
                label: 'Passed',
                count: state.passedCount.toString(),
                color: AppColors.accentGreenDark,
                bgColor: AppColors.accentGreenLight,
                icon: Icons.check_circle_outline_rounded,
              ),
              if (state.failedCount > 0)
                _buildCountChip(
                  label: 'Failed',
                  count: state.failedCount.toString(),
                  color: const Color(0xFF991B1B),
                  bgColor: const Color(0xFFFEE2E2),
                  icon: Icons.cancel_outlined,
                ),
              _buildCountChip(
                label: 'Pending Final',
                count: state.pendingFinalCount.toString(),
                color: const Color(0xFFB45309),
                bgColor: AppColors.accentAmberLight,
                icon: Icons.access_time_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountChip({
    required String label,
    required String count,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Grade Card ─────────────────────────────────────────────────────────────

  Widget _buildGradeCard(GradeModel grade) {
    final hasFinal = grade.finalGrade != null;
    final isPassed = hasFinal && grade.finalGrade! <= 3.00;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Container(
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Code, Section & Remarks Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          grade.subjectCode ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        if (grade.className != null &&
                            grade.className!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              grade.className!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Remarks Status Badge
                  _buildRemarksBadge(grade, hasFinal, isPassed),
                ],
              ),
              const SizedBox(height: 4),

              // Subject Title
              Text(
                grade.subjectTitle ?? 'Untitled Subject',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),

              // Midterm & Final Grade Display Boxes
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildGradePeriodColumn(
                        periodName: 'MIDTERM GRADE',
                        gradeValue: grade.midtermGrade,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: const Color(0xFFCBD5E1),
                    ),
                    Expanded(
                      child: _buildGradePeriodColumn(
                        periodName: 'FINAL GRADE',
                        gradeValue: grade.finalGrade,
                      ),
                    ),
                  ],
                ),
              ),

              // Footer: Instructor info
              if (grade.teacherName != null && grade.teacherName!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Instructor: ${grade.teacherName}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemarksBadge(
      GradeModel grade, bool hasFinal, bool isPassed) {
    if (!hasFinal) {
      return StatusBadge.neutral(label: '—');
    }

    if (isPassed) {
      return StatusBadge.success(label: grade.remarksLabel ?? 'Passed');
    } else {
      return StatusBadge.danger(label: grade.remarksLabel ?? 'Failed');
    }
  }

  Widget _buildGradePeriodColumn({
    required String periodName,
    required double? gradeValue,
  }) {
    final isSubmitted = gradeValue != null;
    return Column(
      children: [
        Text(
          periodName,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isSubmitted ? gradeValue.toStringAsFixed(2) : '—',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isSubmitted ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
