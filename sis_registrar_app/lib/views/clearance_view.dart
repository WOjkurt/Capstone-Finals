import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/clearance_bloc.dart';
import 'promotion_view.dart';
import 'widgets/page_header.dart';
import 'widgets/student_profile_panel.dart';
import 'widgets/status_badge.dart';
import 'widgets/edit_lrn_dialog.dart';
import '../theme/app_theme.dart';

class ClearanceView extends StatefulWidget {
  /// Focus for the search box, so Ctrl+K anywhere in the app can put the cursor here.
  final FocusNode? searchFocus;

  const ClearanceView({super.key, this.searchFocus});

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
            // A search started elsewhere (the menu's quick search) shows up in this box too.
            if (state.searchQuery != _searchController.text) {
              _searchController.text = state.searchQuery;
            }
            if (state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.successMessage!),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: AppColors.error,
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
                title: 'Students',
                subtitle: 'Find a student to see their study load, grades, credits and history.',
                // Used once a year, so it lives here instead of in the menu.
                action: OutlinedButton.icon(
                  key: const ValueKey('open_promotion_button'),
                  icon: const Icon(Icons.trending_up_rounded, size: 18),
                  label: const Text('End-of-year promotion'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (routeContext) => PromotionView(onBack: () => Navigator.of(routeContext).pop()),
                  )),
                ),
                onRefresh: () {
                  _searchController.clear();
                  context.read<ClearanceBloc>().add(SearchStudentsEvent(''));
                },
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
                  'Find a student',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  focusNode: widget.searchFocus,
                  onChanged: (val) {
                    context.read<ClearanceBloc>().add(SearchStudentsEvent(val));
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by name, email or LRN...',
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
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    label: const Text('Missing LRN only', style: TextStyle(fontSize: 12)),
                    selected: data.missingLrnOnly,
                    onSelected: (selected) {
                      context
                          .read<ClearanceBloc>()
                          .add(ToggleMissingLrnFilterEvent(selected));
                    },
                    selectedColor: const Color(0xFFFEF3C7),
                    checkmarkColor: const Color(0xFFD97706),
                    labelStyle: TextStyle(
                      color: data.missingLrnOnly
                          ? const Color(0xFFB45309)
                          : const Color(0xFF475569),
                      fontWeight:
                          data.missingLrnOnly ? FontWeight.w700 : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(
                        color: data.missingLrnOnly
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFCBD5E1),
                      ),
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
                            : data.searchQuery.trim().isEmpty
                                ? 'Type a name, email or LRN to find a student.'
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
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (s.hasLrn == false)
                                  StatusBadge.noLrn(
                                    onTap: () {
                                      EditLrnDialog.showForStudent(
                                        context,
                                        userId: s.userId,
                                        studentName: s.fullName,
                                        currentLrn: s.lrn,
                                        onSaved: (newLrn) {
                                          context
                                              .read<ClearanceBloc>()
                                              .add(StudentLrnUpdatedEvent(s.userId, newLrn));
                                        },
                                      );
                                    },
                                  )
                                else if (s.lrn != null && s.lrn!.isNotEmpty)
                                  Flexible(
                                    child: Text(
                                      'LRN: ${s.lrn}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
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
                'Choose a student',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Search on the left, then pick a student to see their study load, grades, credits and history.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return StudentProfilePanel(data: data);
  }
}
