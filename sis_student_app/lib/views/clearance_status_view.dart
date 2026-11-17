import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/clearance_bloc.dart';
import '../models/grading_models.dart';
import '../theme/app_theme.dart';
import 'widgets/page_header.dart';
import 'widgets/status_badge.dart';

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
    return PageHeader(
      title: 'Clearance Status',
      onRefresh: () => _loadClearances(refresh: true),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: _buildClearanceList(state),
          ),
        ),
      ];
    }

    return [];
  }

  // ── Clearance List (one row per term) ──────────────────────────────────────

  Widget _buildClearanceList(ClearanceLoaded state) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < state.clearances.length; i++) ...[
                if (i > 0)
                  const Divider(
                      height: 1, thickness: 1, color: AppColors.border),
                _buildClearanceRow(state.clearances[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClearanceRow(GradeClearanceModel item) {
    final dateFormat = DateFormat('MMM d, yyyy');

    final String detail;
    if (item.isCleared) {
      detail = [
        if (item.clearedByUserName != null)
          'Cleared by ${item.clearedByUserName}',
        if (item.clearedAt != null)
          dateFormat.format(item.clearedAt!.toLocal()),
      ].join(' · ');
    } else {
      detail = 'Settle requirements with the Registrar';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.termLabel ?? 'Academic Term',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          item.isCleared
              ? StatusBadge.success(label: 'Cleared')
              : StatusBadge.danger(label: 'Withheld'),
        ],
      ),
    );
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
