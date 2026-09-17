import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/grades_bloc.dart';
import '../models/grading_models.dart';
import '../models/setup_models.dart';
import '../theme/app_theme.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Official midterm and final grades per academic term.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primary),
                onPressed: () => _loadGrades(refresh: true),
              ),
            ],
          ),

          if (state is GradesLoaded) ...[
            const SizedBox(height: 10),
            // Unified controls row: Term Dropdown + subtle secondary clearance status
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (state.terms.isNotEmpty)
                  _buildTermDropdown(state)
                else
                  _buildStaticTermPill(state.selectedTerm),
                _buildClearanceStatusIndicator(state),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTermDropdown(GradesLoaded state) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
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
            fontSize: 12,
            fontWeight: FontWeight.w700,
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
                    size: 13,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(term.label),
                  if (isCurrentActive) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.4,
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
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
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

  /// Compact, secondary clearance status indicator (icon + label)
  Widget _buildClearanceStatusIndicator(GradesLoaded state) {
    final isWithheld = state.isClearanceWithheld;
    final color = isWithheld ? const Color(0xFFB45309) : AppColors.accentGreenDark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isWithheld ? Icons.lock_outline_rounded : Icons.check_circle_rounded,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          isWithheld ? 'Clearance Withheld' : 'Clearance Cleared',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
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
              padding: const EdgeInsets.all(20.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 40, color: AppColors.error),
                      const SizedBox(height: 10),
                      const Text(
                        'Failed to Load Grades',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => _loadGrades(refresh: true),
                        icon: const Icon(Icons.refresh_rounded, size: 15),
                        label: const Text('Try Again', style: TextStyle(fontSize: 12)),
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
      // 1. Clearance Masking Check
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final grade = state.grades[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
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
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.accentAmber.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentAmber.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
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
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Grades Withheld Pending Clearance',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Official grades for ${state.selectedTerm?.label ?? 'this term'} are currently withheld because grade viewing clearance has not been approved yet.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 15, color: Color(0xFFB45309)),
                        SizedBox(width: 5),
                        Text(
                          'Requirements for Clearance',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• Verify that all tuition and accounting balances are settled.\n'
                      '• Clear library, laboratory, and student affairs requirements.\n'
                      '• The Registrar\'s Office will unlock grade viewing once clearance is processed.',
                      style: TextStyle(
                        fontSize: 11,
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
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'No Grades Submitted Yet',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No grades have been submitted yet by your instructors for ${state.selectedTerm?.label ?? 'this term'}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
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

  // ── Summary Stats Bar (Unified compact card) ───────────────────────────────

  Widget _buildSummaryCountsBar(GradesLoaded state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatSegment(
                  label: 'Total Subjects',
                  count: state.totalSubjects.toString(),
                  color: AppColors.textPrimary,
                ),
                _buildStatDivider(),
                _buildStatSegment(
                  label: 'Passed',
                  count: state.passedCount.toString(),
                  color: AppColors.accentGreenDark,
                ),
                if (state.failedCount > 0) ...[
                  _buildStatDivider(),
                  _buildStatSegment(
                    label: 'Failed',
                    count: state.failedCount.toString(),
                    color: const Color(0xFF991B1B),
                  ),
                ],
                _buildStatDivider(),
                _buildStatSegment(
                  label: 'Pending Final',
                  count: state.pendingFinalCount.toString(),
                  color: state.pendingFinalCount > 0
                      ? const Color(0xFFB45309)
                      : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatSegment({
    required String label,
    required String count,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 22,
      color: const Color(0xFFE2E8F0),
    );
  }

  // ── Subject Grade Card ─────────────────────────────────────────────────────

  Widget _buildGradeCard(GradeModel grade) {
    final hasFinal = grade.finalGrade != null;
    final isPassed = hasFinal && grade.finalGrade! <= 3.00;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Primary Focus: Subject Code + Section Tag
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    grade.subjectCode ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (grade.className != null &&
                      grade.className!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        grade.className!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),

              // Subject Title
              Text(
                grade.subjectTitle ?? 'Untitled Subject',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),

              // 2. Grades & Outcome Row (Midterm, Final, Remarks integrated inline)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildGradePeriodColumn(
                        periodName: 'MIDTERM',
                        gradeValue: grade.midtermGrade,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 26,
                      color: const Color(0xFFE2E8F0),
                    ),
                    Expanded(
                      child: _buildGradePeriodColumn(
                        periodName: 'FINAL',
                        gradeValue: grade.finalGrade,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 26,
                      color: const Color(0xFFE2E8F0),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'REMARKS',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          _buildRemarksBadge(grade, hasFinal, isPassed),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Card Footer (tight, instructor info)
              if (grade.teacherName != null && grade.teacherName!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 12,
                      color: AppColors.textMuted,
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
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          '—',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
      );
    }

    if (isPassed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
        ),
        child: Text(
          grade.remarksLabel ?? 'Passed',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF15803D),
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
        ),
        child: Text(
          grade.remarksLabel ?? 'Failed',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF991B1B),
          ),
        ),
      );
    }
  }

  Widget _buildGradePeriodColumn({
    required String periodName,
    required double? gradeValue,
  }) {
    final isSubmitted = gradeValue != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          periodName,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          isSubmitted ? gradeValue.toStringAsFixed(2) : '—',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isSubmitted ? AppColors.textPrimary : AppColors.textMuted,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
