import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/grades_bloc.dart';
import '../models/grading_models.dart';
import '../models/setup_models.dart';
import '../theme/app_theme.dart';
import 'widgets/page_header.dart';
import 'widgets/stat_strip.dart';
import 'widgets/status_badge.dart';
import 'widgets/term_dropdown.dart';
import '../utils/numbers.dart';

final _changedOn = DateFormat('MMM d, yyyy');

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
                SliverToBoxAdapter(child: _buildHeader(state)),
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
    return PageHeader(
      title: 'My Grades',
      onRefresh: () => _loadGrades(refresh: true),
      below: state is! GradesLoaded
          ? null
          : (state.terms.isNotEmpty
                ? _buildTermDropdown(state)
                : _buildStaticTermPill(state.selectedTerm)),
    );
  }

  Widget _buildTermDropdown(GradesLoaded state) {
    return TermDropdown(
      terms: state.terms,
      selected: state.selectedTerm,
      activeTerm: state.activeTerm,
      onChanged: (newTerm) {
        context.read<GradesBloc>().add(
          SelectTermEvent(term: newTerm, userId: widget.userId),
        );
      },
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

  // ── Body Slivers ───────────────────────────────────────────────────────────

  List<Widget> _buildBodySlivers(GradesState state) {
    if (state is GradesLoading || state is GradesInitial) {
      return [
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
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
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 40,
                        color: AppColors.error,
                      ),
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
                        label: const Text(
                          'Try Again',
                          style: TextStyle(fontSize: 12),
                        ),
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
        return [SliverToBoxAdapter(child: _buildClearanceWithheldCard(state))];
      }

      // 2. Loading state when switching terms
      if (state.isTermGradesLoading) {
        return [
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      }

      // 3. The term's results are not out yet. Checked before the empty-grades card, because
      // "nothing submitted yet" and "finished but not published" look identical from here and
      // only one of them is worth asking the Registrar about.
      final term = state.selectedTerm;
      if (term != null && !term.areGradesReleased) {
        return [SliverToBoxAdapter(child: _buildNotReleasedCard(term))];
      }

      // 4. Cleared, but empty grades list
      if (state.grades.isEmpty) {
        return [SliverToBoxAdapter(child: _buildEmptyGradesCard(state))];
      }

      // 4. Cleared with grades present
      return [
        SliverToBoxAdapter(child: _buildSummaryCountsBar(state)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: _buildGradesList(state),
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
                        Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: Color(0xFFB45309),
                        ),
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

  /// Said plainly, and without pointing them at an office. Nobody can hurry this along, and a
  /// student who walks to the Registrar over it has wasted the trip.
  Widget _buildNotReleasedCard(AcademicTermModel term) {
    return Center(
      key: const ValueKey('grades_not_released'),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty_rounded, size: 40, color: Color(0xFFB45309)),
            const SizedBox(height: 12),
            const Text(
              'Grades for this term have not been released yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Your grades for ${term.schoolYear}, semester ${term.semester} will appear here once '
              'the Registrar releases them. There is nothing you need to do.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

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
              Text(
                state.withheldMessage != null
                    ? 'Grades On Hold'
                    : 'No Grades Submitted Yet',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                // An empty list means either "nothing entered yet" or "withheld", and only the
                // API knows which. Saying the wrong one sends the student to the wrong office.
                state.withheldMessage ??
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
    return StatStrip(
      items: [
        StatStripItem(
          label: 'Total Subjects',
          count: state.totalSubjects.toString(),
          color: AppColors.textPrimary,
        ),
        StatStripItem(
          label: 'Passed',
          count: state.passedCount.toString(),
          color: AppColors.accentGreenDark,
        ),
        if (state.failedCount > 0)
          StatStripItem(
            label: 'Failed',
            count: state.failedCount.toString(),
            color: const Color(0xFF991B1B),
          ),
        StatStripItem(
          label: 'Pending Final',
          count: state.pendingFinalCount.toString(),
          color: state.pendingFinalCount > 0
              ? const Color(0xFFB45309)
              : AppColors.textSecondary,
        ),
      ],
    );
  }

  // ── Grades List (responsive: table ≥700px, compact rows on phones) ─────────

  Widget _buildGradesList(GradesLoaded state) {
    final isPhone = MediaQuery.sizeOf(context).width < 700;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isPhone ? 800 : 900),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: isPhone ? _buildCompactRows(state) : _buildGradesTable(state),
        ),
      ),
    );
  }

  static String _formatGrade(double? value) =>
      gradeOrDash(value, dash: '—');

  static String _formatUnits(double? value) => value == null
      ? '—'
      : unitsText(value);

  /// Plain wording for the phone rows, where a coloured pill would shout over
  /// the grades themselves.
  static String _remarksText(GradeModel grade) {
    if (grade.finalGrade == null) return '—';
    return grade.finalGrade! <= 3.00
        ? (grade.remarksLabel ?? 'Passed')
        : (grade.remarksLabel ?? 'Failed');
  }

  Widget _remarksBadge(GradeModel grade) {
    if (grade.finalGrade == null) {
      return StatusBadge.neutral(label: '—');
    }
    return grade.finalGrade! <= 3.00
        ? StatusBadge.success(label: grade.remarksLabel ?? 'Passed')
        : StatusBadge.danger(label: grade.remarksLabel ?? 'Failed');
  }

  Widget _buildGradesTable(GradesLoaded state) {
    // Fill the card's width; scroll sideways only when it can't fit (700-760px).
    return LayoutBuilder(
      builder: (context, constraints) {
        // The other five columns need roughly this much; whatever is left
        // belongs to SUBJECT, so a long title ellipsizes instead of pushing
        // the grade columns out of view.
        final subjectWidth = (constraints.maxWidth - 440)
            .clamp(150.0, 440.0)
            .toDouble();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              dataRowMinHeight: 52,
              dataRowMaxHeight: 68,
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('CODE')),
                DataColumn(label: Text('SUBJECT')),
                DataColumn(label: Text('UNITS'), numeric: true),
                DataColumn(label: Text('MIDTERM'), numeric: true),
                DataColumn(label: Text('FINAL'), numeric: true),
                DataColumn(label: Text('REMARKS')),
              ],
              rows: state.grades
                  .map((g) => _buildGradeRow(g, subjectWidth))
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  DataRow _buildGradeRow(GradeModel grade, double subjectWidth) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            grade.subjectCode ?? 'N/A',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        DataCell(
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: subjectWidth),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        grade.subjectTitle ?? 'Untitled Subject',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (grade.className != null &&
                        grade.className!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
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
                // Said plainly rather than left for them to notice the number has moved.
                // Why it changed is an internal note and stays with the Registrar.
                if (grade.modifiedAt != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    key: ValueKey('grade_changed_${grade.gradeId}'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history_rounded, size: 12, color: Color(0xFFB45309)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Corrected by the Registrar on '
                          '${_changedOn.format(grade.modifiedAt!.toLocal())}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (grade.teacherName != null &&
                    grade.teacherName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    grade.teacherName!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        DataCell(
          Text(
            _formatUnits(grade.units),
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
        DataCell(
          Text(
            _formatGrade(grade.midtermGrade),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: grade.midtermGrade != null
                  ? AppColors.textPrimary
                  : AppColors.textMuted,
            ),
          ),
        ),
        DataCell(
          Text(
            _formatGrade(grade.finalGrade),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: grade.finalGrade != null
                  ? AppColors.textPrimary
                  : AppColors.textMuted,
            ),
          ),
        ),
        DataCell(_remarksBadge(grade)),
      ],
    );
  }

  Widget _buildCompactRows(GradesLoaded state) {
    return Column(
      children: [
        for (var i = 0; i < state.grades.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, thickness: 1, color: AppColors.border),
          _buildCompactRow(state.grades[i]),
        ],
      ],
    );
  }

  Widget _buildCompactRow(GradeModel grade) {
    const labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    );
    const valueStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: grade.subjectCode ?? 'N/A',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const TextSpan(
                  text: ' · ',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                TextSpan(
                  text: grade.subjectTitle ?? 'Untitled Subject',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 13, height: 1.3),
          ),
          const SizedBox(height: 8),
          // The grades lead this line; the remark is a quiet trailing note.
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Mid ', style: labelStyle),
                      TextSpan(
                        text: _formatGrade(grade.midtermGrade),
                        style: valueStyle,
                      ),
                      const TextSpan(text: '   Final ', style: labelStyle),
                      TextSpan(
                        text: _formatGrade(grade.finalGrade),
                        style: valueStyle,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(_remarksText(grade), style: labelStyle),
            ],
          ),
        ],
      ),
    );
  }
}
