import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/clearance_bloc.dart';
import '../models/grading_models.dart';
import '../theme/app_theme.dart';

class ClearanceStatusView extends StatefulWidget {
  final String userId;

  const ClearanceStatusView({super.key, required this.userId});

  @override
  State<ClearanceStatusView> createState() => _ClearanceStatusViewState();
}

class _ClearanceStatusViewState extends State<ClearanceStatusView> {
  @override
  void initState() {
    super.initState();
    _loadClearances();
  }

  void _loadClearances({bool refresh = false}) {
    context.read<ClearanceBloc>().add(
          LoadClearancesEvent(userId: widget.userId, refresh: refresh),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClearanceBloc, ClearanceState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          body: RefreshIndicator(
            onRefresh: () async {
              _loadClearances(refresh: true);
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

  Widget _buildHeader(ClearanceState state) {
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
                      'Clearance Status',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Check your grade viewing clearance across academic terms.',
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
                onPressed: () => _loadClearances(refresh: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Body Slivers ───────────────────────────────────────────────────────────

  List<Widget> _buildBodySlivers(ClearanceState state) {
    if (state is ClearanceLoading || state is ClearanceInitial) {
      return [
        const SliverFillRemaining(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ];
    }

    if (state is ClearanceError) {
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
                        'Failed to Load Clearances',
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
                        onPressed: () => _loadClearances(refresh: true),
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

    if (state is ClearanceLoaded) {
      if (state.clearances.isEmpty) {
        return [
          SliverToBoxAdapter(
            child: _buildEmptyStateCard(),
          ),
        ];
      }

      return [
        SliverToBoxAdapter(
          child: _buildSummaryCountsBar(state),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = state.clearances[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildClearanceCard(item),
                );
              },
              childCount: state.clearances.length,
            ),
          ),
        ),
      ];
    }

    return [];
  }

  // ── Summary Stats Bar (Unified compact card) ───────────────────────────────

  Widget _buildSummaryCountsBar(ClearanceLoaded state) {
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
                  label: 'Total Terms',
                  count: state.totalTerms.toString(),
                  color: AppColors.textPrimary,
                ),
                _buildStatDivider(),
                _buildStatSegment(
                  label: 'Cleared',
                  count: state.clearedCount.toString(),
                  color: AppColors.accentGreenDark,
                ),
                _buildStatDivider(),
                _buildStatSegment(
                  label: 'Withheld',
                  count: state.withheldCount.toString(),
                  color: state.withheldCount > 0
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

  // ── Clearance Card ─────────────────────────────────────────────────────────

  Widget _buildClearanceCard(GradeClearanceModel item) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

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
              // 1. Term Label & Status Badge Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.termLabel ?? 'Academic Term',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(item.isCleared),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Audit Detail Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: item.isCleared
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: item.isCleared
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFDE68A),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          item.isCleared
                              ? Icons.verified_user_rounded
                              : Icons.lock_clock_outlined,
                          size: 13,
                          color: item.isCleared
                              ? AppColors.accentGreenDark
                              : const Color(0xFFB45309),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          item.isCleared
                              ? 'Grade viewing authorized for this term'
                              : 'Grades withheld pending settlement',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: item.isCleared
                                ? AppColors.accentGreenDark
                                : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                    if (item.isCleared &&
                        (item.clearedByUserName != null || item.clearedAt != null)) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (item.clearedByUserName != null)
                            'Audited by: ${item.clearedByUserName}',
                          if (item.clearedAt != null)
                            dateFormat.format(item.clearedAt!.toLocal()),
                        ].join(' • '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ] else if (!item.isCleared) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Please verify accounting, library, and departmental requirements with the Registrar.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF78350F),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isCleared) {
    if (isCleared) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF16A34A).withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF15803D)),
            SizedBox(width: 4),
            Text(
              'Cleared',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF15803D),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFDC2626).withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 11, color: Color(0xFF991B1B)),
            SizedBox(width: 4),
            Text(
              'Withheld',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF991B1B),
              ),
            ),
          ],
        ),
      );
    }
  }

  // ── Empty State ────────────────────────────────────────────────────────────

  Widget _buildEmptyStateCard() {
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
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_toggle_off_rounded,
                size: 46,
                color: AppColors.textMuted,
              ),
              SizedBox(height: 12),
              Text(
                'No clearance records found',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'You have no clearance records initialized yet. Clearance records will appear here once terms are audited by the Registrar.',
                textAlign: TextAlign.center,
                style: TextStyle(
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
}
