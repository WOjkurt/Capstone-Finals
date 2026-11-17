import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/irregular_bloc.dart';
import '../models/grading_models.dart';
import '../theme/app_theme.dart';
import 'widgets/page_header.dart';
import 'widgets/status_badge.dart';

/// Students on irregular standing across the college, and how close each is to
/// returning to regular. Read-only: changing a standing is the Registrar's.
class IrregularView extends StatefulWidget {
  const IrregularView({super.key});

  @override
  State<IrregularView> createState() => _IrregularViewState();
}

class _IrregularViewState extends State<IrregularView> {
  @override
  void initState() {
    super.initState();
    context.read<IrregularBloc>().add(IrregularStarted());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<IrregularBloc, IrregularState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Irregular students',
              subtitle:
                  'Progress back to regular standing. The Registrar makes the change.',
              onRefresh: () =>
                  context.read<IrregularBloc>().add(IrregularStarted()),
            ),
            if (!state.isLoading && state.students.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 20, 32, 4),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(width: 240, child: _programFilter(state)),
                    Text(
                      '${state.visible.length} student${state.visible.length == 1 ? '' : 's'}'
                      '${state.ready.isEmpty ? '' : ' · ${state.ready.length} ready to be regular'}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(child: _buildBody(state)),
          ],
        );
      },
    );
  }

  Widget _programFilter(IrregularState state) {
    return DropdownButtonFormField<String?>(
      key: const ValueKey('program_filter'),
      initialValue: state.programCode,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Program',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('All programs'),
        ),
        ...state.programCodes.map(
          (c) => DropdownMenuItem<String?>(value: c, child: Text(c)),
        ),
      ],
      onChanged: (v) =>
          context.read<IrregularBloc>().add(IrregularProgramFiltered(v)),
    );
  }

  Widget _buildBody(IrregularState state) {
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

    if (state.students.isEmpty) {
      return const Center(
        child: Text(
          'No students are on irregular standing.',
          key: ValueKey('irregular_empty'),
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );
    }

    if (state.visible.isEmpty) {
      return const Center(
        child: Text(
          'No irregular students in that program.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 24),
      children: [
        if (state.ready.isNotEmpty) ...[
          _sectionLabel('Ready to be regular', state.ready.length),
          const SizedBox(height: 8),
          ...state.ready.map(_row),
          const SizedBox(height: 20),
        ],
        if (state.stillShort.isNotEmpty) ...[
          _sectionLabel('Still earning back units', state.stillShort.length),
          const SizedBox(height: 8),
          ...state.stillShort.map(_row),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text, int count) {
    return Text(
      '$text ($count)',
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _row(IrregularStudentModel s) {
    final since = s.irregularSince;
    return Container(
      key: ValueKey('irregular_row_${s.userId}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.studentName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (s.programCode != null && s.programCode!.isNotEmpty)
                      s.programCode!,
                    if (s.yearLevel != null) 'Year ${s.yearLevel}',
                    if (s.lrn != null && s.lrn!.isNotEmpty) 'LRN ${s.lrn}',
                    if (since != null)
                      'Irregular since ${DateFormat('MMM d, yyyy').format(since.toLocal())}',
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
            s.progressLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          if (s.readyToBeRegular)
            StatusBadge.success(label: 'Ready')
          else
            StatusBadge.neutral(label: 'In progress'),
        ],
      ),
    );
  }
}
