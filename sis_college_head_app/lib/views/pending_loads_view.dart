import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/pending_loads_bloc.dart';
import '../models/class_models.dart';
import '../theme/app_theme.dart';
import 'widgets/page_header.dart';
import 'widgets/status_badge.dart';

/// What this College Head has sent to the Registrar and is still waiting on.
/// Read-only: only the Registrar can finalize or reject a pending load.
class PendingLoadsView extends StatefulWidget {
  const PendingLoadsView({super.key});

  @override
  State<PendingLoadsView> createState() => _PendingLoadsViewState();
}

class _PendingLoadsViewState extends State<PendingLoadsView> {
  @override
  void initState() {
    super.initState();
    context.read<PendingLoadsBloc>().add(PendingLoadsStarted());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PendingLoadsBloc, PendingLoadsState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Pending loads',
              subtitle:
                  'Study loads you saved that the Registrar has not finalized yet.',
              onRefresh: () =>
                  context.read<PendingLoadsBloc>().add(PendingLoadsRefreshed()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 20, 32, 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(width: 300, child: _buildTermDropdown(state)),
                  if (!state.isLoading && state.pending.isNotEmpty)
                    _summary(state),
                ],
              ),
            ),
            Expanded(child: _buildBody(state)),
          ],
        );
      },
    );
  }

  Widget _buildTermDropdown(PendingLoadsState state) {
    if (state.isLoadingTerms) {
      return const LinearProgressIndicator();
    }
    return DropdownButtonFormField<String>(
      key: const ValueKey('term_dropdown'),
      initialValue: state.selectedTermId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Term',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      items: state.terms
          .map((t) => DropdownMenuItem(
                value: t.termId,
                child: Text(t.isActive ? '${t.label} (active)' : t.label,
                    overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) {
          context.read<PendingLoadsBloc>().add(PendingLoadsTermSelected(v));
        }
      },
    );
  }

  Widget _summary(PendingLoadsState state) {
    final parts = [
      '${state.studentCount} student${state.studentCount == 1 ? '' : 's'}',
      '${state.subjectCount} subject${state.subjectCount == 1 ? '' : 's'}',
      if (state.overloadedCount > 0) '${state.overloadedCount} over the limit',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        parts.join(' · '),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildBody(PendingLoadsState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.error),
          ),
        ),
      );
    }

    if (state.selectedTermId == null) {
      return const Center(
        child: Text(
          'Pick a term to see what is waiting with the Registrar.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );
    }

    if (state.pending.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nothing is waiting for the Registrar this term.',
            key: ValueKey('pending_empty'),
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
      itemCount: state.pending.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _row(state.pending[i]),
    );
  }

  Widget _row(PendingStudyLoadSummaryModel p) {
    return Container(
      key: ValueKey('pending_row_${p.userId}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.fullName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (p.programCode != null && p.programCode!.isNotEmpty)
                          p.programCode!,
                        if (p.yearLevel != null) 'Year ${p.yearLevel}',
                        if (p.lrn != null && p.lrn!.isNotEmpty) 'LRN ${p.lrn}',
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${p.pendingCount} subject${p.pendingCount == 1 ? '' : 's'} · ${p.pendingUnitsLabel} units',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge.pending(label: 'Waiting'),
            ],
          ),
          if (p.isOverloaded) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Over the limit — ${p.termUnitsLabel} units',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                    ),
                  ),
                  if (p.overloadReason != null &&
                      p.overloadReason!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      [
                        p.overloadReason!,
                        if (p.overloadApprovedBy != null &&
                            p.overloadApprovedBy!.isNotEmpty)
                          '— ${p.overloadApprovedBy}',
                      ].join(' '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF78350F),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
