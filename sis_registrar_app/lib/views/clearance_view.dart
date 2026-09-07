import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/clearance_bloc.dart';
import 'widgets/page_header.dart';
import 'widgets/status_badge.dart';
import '../theme/app_theme.dart';

class ClearanceView extends StatefulWidget {
  const ClearanceView({super.key});

  @override
  State<ClearanceView> createState() => _ClearanceViewState();
}

class _ClearanceViewState extends State<ClearanceView> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final bloc = context.read<ClearanceBloc>();
    if (bloc.state is ClearanceInitial) {
      bloc.add(SearchStudentsEvent(''));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: BlocConsumer<ClearanceBloc, ClearanceState>(
        listener: (context, state) {
          if (state is ClearanceStateData) {
            if (state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.successMessage!),
                  backgroundColor: const Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: const Color(0xFFDC2626),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
        builder: (context, state) {
          final data = state is ClearanceStateData ? state : ClearanceStateData();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Student Grade Clearance',
                subtitle:
                    'Audit student clearance statuses per academic term. Cleared status permits grade viewing and future term enrollment.',
                action: ElevatedButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    context.read<ClearanceBloc>().add(SearchStudentsEvent(''));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reset'),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final searchWidth = constraints.maxWidth < 900
                          ? (constraints.maxWidth * 0.35).clamp(240.0, 300.0)
                          : 300.0;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Column: Student Search & Selection (compact width for search list)
                          SizedBox(
                            width: searchWidth,
                            child: _buildStudentSearchPanel(context, data),
                          ),
                          const SizedBox(width: 20),
                          // Right Column: Clearance History & Toggle (fills remaining width)
                          Expanded(
                            child: _buildClearanceDetailPanel(context, data),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStudentSearchPanel(BuildContext context, ClearanceStateData data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Input Header
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Student',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    context.read<ClearanceBloc>().add(SearchStudentsEvent(val));
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    hintStyle:
                        TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon:
                        const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                    suffixIcon: data.isSearching
                        ? const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          )
                        : (_searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  context
                                      .read<ClearanceBloc>()
                                      .add(SearchStudentsEvent(''));
                                },
                              )
                            : null),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          // Student List
          Expanded(
            child: data.searchResults.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        data.isSearching
                            ? 'Searching students...'
                            : 'No students found matching "${data.searchQuery}".',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: data.searchResults.length,
                    separatorBuilder: (ctx, i) =>
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (ctx, i) {
                      final s = data.searchResults[i];
                      final isSelected =
                          data.selectedStudent?.userId == s.userId;

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: const Color(0xFFEFF6FF),
                        onTap: () {
                          context
                              .read<ClearanceBloc>()
                              .add(SelectStudentEvent(s));
                        },
                        leading: SizedBox(
                          width: 40,
                          height: 40,
                          child: CircleAvatar(
                            backgroundColor: isSelected
                                ? AppColors.primary
                                : const Color(0xFFE2E8F0),
                            foregroundColor: isSelected
                                ? Colors.white
                                : const Color(0xFF334155),
                            child: Text(
                              s.firstname.isNotEmpty
                                  ? s.firstname[0].toUpperCase()
                                  : 'S',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        title: Text(
                          s.fullName.isNotEmpty ? s.fullName : 'Unnamed Student',
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.email,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (s.programCode != null && s.programCode!.isNotEmpty)
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        s.programCode!,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryDark,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                if (s.yearLevel != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    'Year ${s.yearLevel}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: Color(0xFF94A3B8)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildClearanceDetailPanel(
      BuildContext context, ClearanceStateData data) {
    if (data.selectedStudent == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_search_rounded,
                  size: 56, color: Color(0xFFCBD5E1)),
              SizedBox(height: 16),
              Text(
                'No Student Selected',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Select a student from the left panel to inspect or toggle their term clearances.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    final student = data.selectedStudent!;
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selected Student Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  child: Text(
                    student.firstname.isNotEmpty
                        ? student.firstname[0].toUpperCase()
                        : 'S',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName.isNotEmpty
                            ? student.fullName
                            : 'Student Record',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${student.email} • ${student.programCode ?? "General"} • Year ${student.yearLevel ?? 1}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFBFDBFE),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Clearances list
          Expanded(
            child: data.isClearanceLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : data.clearances.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_toggle_off_rounded,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No Term Clearances Found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'This student has no enrolled terms or clearance records initialized.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: data.clearances.length,
                        separatorBuilder: (ctx, i) =>
                            const SizedBox(height: 14),
                        itemBuilder: (ctx, i) {
                          final c = data.clearances[i];
                          final isToggling =
                              data.togglingTermId == c.termId;

                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: c.isCleared
                                    ? const Color(0xFFA7F3D0)
                                    : const Color(0xFFFECACA),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: c.isCleared
                                        ? const Color(0xFFD1FAE5)
                                        : const Color(0xFFFEE2E2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    c.isCleared
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.lock_outline_rounded,
                                    color: c.isCleared
                                        ? const Color(0xFF065F46)
                                        : const Color(0xFF991B1B),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.termLabel ?? 'Academic Term',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 6),
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final hasAuditInfo = c.clearedByUserName != null || c.clearedAt != null;
                                          final isWide = constraints.maxWidth > 300;

                                          if (isWide && hasAuditInfo) {
                                            return Row(
                                              children: [
                                                c.isCleared
                                                    ? StatusBadge.success(
                                                        label: 'Cleared')
                                                    : StatusBadge.danger(
                                                        label: 'Hold (Uncleared)'),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    [
                                                      if (c.clearedByUserName != null)
                                                        'Audited by: ${c.clearedByUserName}',
                                                      if (c.clearedAt != null)
                                                        dateFormat.format(c.clearedAt!.toLocal()),
                                                    ].join(' • '),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ],
                                            );
                                          }

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              c.isCleared
                                                  ? StatusBadge.success(
                                                      label: 'Cleared')
                                                  : StatusBadge.danger(
                                                      label: 'Hold (Uncleared)'),
                                              if (hasAuditInfo) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  [
                                                    if (c.clearedByUserName != null)
                                                      'Audited by: ${c.clearedByUserName}',
                                                    if (c.clearedAt != null)
                                                      dateFormat.format(c.clearedAt!.toLocal()),
                                                  ].join(' • '),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ],
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Toggle Switch (no label — badge shows state)
                                isToggling
                                    ? const SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : Switch(
                                        value: c.isCleared,
                                        activeThumbColor:
                                            const Color(0xFF10B981),
                                        onChanged: (val) {
                                          context
                                              .read<ClearanceBloc>()
                                              .add(ToggleClearanceEvent(
                                                  c.termId, val));
                                        },
                                      ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
