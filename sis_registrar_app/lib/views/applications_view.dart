import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/applications_bloc.dart';
import '../models/enrollment_models.dart';
import '../models/setup_models.dart';
import '../theme/app_theme.dart';
import 'widgets/page_header.dart';
import 'widgets/status_badge.dart';
import 'widgets/edit_lrn_dialog.dart';
import 'widgets/edit_school_email_dialog.dart';
import '../utils/formatters.dart';

class ApplicationsView extends StatefulWidget {
  /// False inside the Admissions page, whose tabs already name this page.
  final bool showHeader;

  const ApplicationsView({super.key, this.showHeader = true});

  @override
  State<ApplicationsView> createState() => _ApplicationsViewState();
}

class _ApplicationsViewState extends State<ApplicationsView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final bloc = context.read<ApplicationsBloc>();
    if (bloc.state is ApplicationsInitial) {
      bloc.add(LoadApplications());
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: BlocConsumer<ApplicationsBloc, ApplicationsState>(
        listener: (context, state) {
          if (state is ApplicationsActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is ApplicationsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showHeader)
                PageHeader(
                title: 'Applications',
                subtitle: 'Review enrollment applications and approve or reject them.',
                onRefresh: () => context.read<ApplicationsBloc>().add(
                    LoadApplications(
                        statusFilter: (state is ApplicationsLoaded)
                            ? state.statusFilter
                            : null)),
              ),
              // Status Filter Tabs & Search
              _buildFilterTabs(context, state),
              // Content Area
              Expanded(
                child: _buildContent(context, state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context, ApplicationsState state) {
    final currentFilter =
        (state is ApplicationsLoaded) ? state.statusFilter : null;

    final filters = [
      {'label': 'All Applications', 'value': null},
      {'label': 'Pending', 'value': 'pending'},
      {'label': 'Approved', 'value': 'approved'},
      {'label': 'Active', 'value': 'active'},
      {'label': 'Rejected', 'value': 'rejected'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters.map((f) {
                  final isSelected = currentFilter == f['value'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f['label'] as String),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          context.read<ApplicationsBloc>().add(
                                LoadApplications(statusFilter: f['value']),
                              );
                        }
                      },
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                      backgroundColor: const Color(0xFFF1F5F9),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFFE2E8F0),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 320,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by name, program, or status...',
                hintStyle:
                    TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
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
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ApplicationsState state) {
    if (state is ApplicationsLoading || state is ApplicationsInitial) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final apps = (state is ApplicationsLoaded)
        ? state.applications
        : (state is ApplicationsError ? state.applications ?? [] : <EnrollmentApplicationModel>[]);
    final programs = (state is ApplicationsLoaded)
        ? state.programs
        : (state is ApplicationsError ? state.programs ?? [] : <AcademicProgramModel>[]);
    final terms = (state is ApplicationsLoaded)
        ? state.terms
        : (state is ApplicationsError ? state.terms ?? [] : <AcademicTermModel>[]);

    if (apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No Applications Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No applications match the currently selected filter.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    // Lookup maps
    final programMap = {for (var p in programs) p.programId: p.programCode};
    final programNameMap = {for (var p in programs) p.programId: p.programName};
    final termMap = {for (var t in terms) t.termId: t.label};

    final query = _searchController.text.trim().toLowerCase();
    final filteredApps = query.isEmpty
        ? apps
        : apps.where((app) {
            final name = (app.form?.fullName ?? '').toLowerCase();
            final progCode = (programMap[app.programId] ?? '').toLowerCase();
            final progName = (programNameMap[app.programId] ?? '').toLowerCase();
            final statusLabel = app.statusLabel.toLowerCase();
            final appId = app.applicationId.toLowerCase();

            return name.contains(query) ||
                progCode.contains(query) ||
                progName.contains(query) ||
                statusLabel.contains(query) ||
                appId.contains(query);
          }).toList();

    if (filteredApps.isEmpty && query.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No applications found matching "$query"',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear search'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Container(
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    horizontalMargin: 24,
                    columnSpacing: 28,
                    columns: const [
                      DataColumn(
                        label: Text('Applicant Name',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('Program',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('Term',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('Status',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('Year Level',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('School Email',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('Actions',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                    rows: filteredApps.map((app) {
                      final name = app.form?.fullName ?? 'Unnamed Applicant';
                      final prog = programMap[app.programId] ?? 'Prog #${app.programId}';
                      final term = termMap[app.termId] ?? 'Term';

                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                if (app.isReturning) ...[
                                  const SizedBox(width: 8),
                                  const _ReturningChip(),
                                ],
                              ],
                            ),
                          ),
                          DataCell(Text(prog,
                              style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text(term)),
                          DataCell(_renderStatusBadge(app.status)),
                          DataCell(Text((app.form?.yearLevel != null && app.form!.yearLevel > 0)
                              ? 'Year ${app.form!.yearLevel}'
                              : '—')),
                          DataCell(_buildSchoolEmailCell(context, app, state)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Review button
                                OutlinedButton(
                                  onPressed: () => _openReviewModal(
                                      context, app, programs, terms),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    minimumSize: const Size(60, 32),
                                  ),
                                  child: const Text('Review',
                                      style: TextStyle(fontSize: 12)),
                                ),
                                if (app.status == 1) ...[
                                  const SizedBox(width: 6),
                                  ElevatedButton(
                                    onPressed: () =>
                                        _openApproveDialog(context, app),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      minimumSize: const Size(60, 32),
                                      elevation: 0,
                                    ),
                                    child: const Text('Approve',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                  const SizedBox(width: 6),
                                  ElevatedButton(
                                    onPressed: () =>
                                        _openRejectDialog(context, app),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF4444),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      minimumSize: const Size(60, 32),
                                      elevation: 0,
                                    ),
                                    child: const Text('Reject',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _renderStatusBadge(int status) {
    switch (status) {
      case 1:
        return StatusBadge.pending(label: 'Pending');
      case 2:
        return StatusBadge.success(label: 'Approved');
      case 3:
        return StatusBadge.danger(label: 'Rejected');
      case 4:
        return StatusBadge.info(label: 'Active');
      default:
        return StatusBadge.neutral(label: 'Unknown');
    }
  }

  Widget _buildSchoolEmailCell(
    BuildContext context,
    EnrollmentApplicationModel app,
    ApplicationsState state,
  ) {
    final hasSchoolEmail =
        app.schoolEmail != null && app.schoolEmail!.trim().isNotEmpty;

    if (hasSchoolEmail) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            app.schoolEmail!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          if (app.status == 1 || app.status == 2) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF64748B)),
              tooltip: 'Edit School Email',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _openEditSchoolEmailDialog(context, app, state),
            ),
          ],
        ],
      );
    }

    if (app.status == 2) {
      return ActionChip(
        avatar: const Icon(Icons.add, size: 13, color: Color(0xFFD97706)),
        label: const Text(
          'Not set',
          style: TextStyle(
            color: Color(0xFFB45309),
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
        backgroundColor: const Color(0xFFFEF3C7),
        side: const BorderSide(color: Color(0xFFFDE68A)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        visualDensity: VisualDensity.compact,
        onPressed: () => _openEditSchoolEmailDialog(context, app, state),
      );
    }

    if (app.status == 1) {
      return TextButton.icon(
        onPressed: () => _openEditSchoolEmailDialog(context, app, state),
        icon: const Icon(Icons.add, size: 13),
        label: const Text('Add email', style: TextStyle(fontSize: 11)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    return const Text('—', style: TextStyle(color: Color(0xFF94A3B8)));
  }

  void _openEditSchoolEmailDialog(
    BuildContext context,
    EnrollmentApplicationModel app,
    ApplicationsState state,
  ) {
    EditSchoolEmailDialog.show(
      context,
      applicationId: app.applicationId,
      applicantName: app.form?.fullName ?? 'Applicant',
      currentSchoolEmail: app.schoolEmail,
      onSaved: (_) {
        context.read<ApplicationsBloc>().add(
              LoadApplications(
                statusFilter: (state is ApplicationsLoaded)
                    ? state.statusFilter
                    : null,
              ),
            );
      },
    );
  }

  void _openReviewModal(
    BuildContext context,
    EnrollmentApplicationModel app,
    List<AcademicProgramModel> programs,
    List<AcademicTermModel> terms,
  ) {
    // Request full detail
    context.read<ApplicationsBloc>().add(ViewApplicationDetail(app.applicationId));

    showDialog(
      context: context,
      builder: (dialogCtx) => BlocProvider.value(
        value: context.read<ApplicationsBloc>(),
        child: _ApplicationDetailDialog(
          fallbackApp: app,
          programs: programs,
          terms: terms,
        ),
      ),
    ).then((_) {
      if (context.mounted) {
        context.read<ApplicationsBloc>().add(ClearApplicationDetail());
      }
    });
  }  void _openApproveDialog(
      BuildContext context, EnrollmentApplicationModel app) {
    const validYearLevels = [1, 2, 3, 4, 5];
    final currentYear = app.form?.yearLevel;
    int selectedYearLevel = (currentYear != null && validYearLevels.contains(currentYear))
        ? currentYear
        : validYearLevels.first;

    showDialog(
      context: context,
      builder: (dialogCtx) => BlocProvider.value(
        value: context.read<ApplicationsBloc>(),
        child: StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Approve Application'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to approve the application for ${app.form?.fullName ?? "this applicant"}?',
                  ),
                  if (app.isReturning) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Returning student. ${app.changedFields.isEmpty ? 'No changes since the last enrollment.' : 'Changed: ${app.changedFields.join(', ')}.'}\n'
                      'No login is needed: approving enrolls them for this term, ready for their study load.',
                      key: const ValueKey('approve_returning_note'),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Confirmed Year Level (Registrar Override):',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: selectedYearLevel,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: validYearLevels.map((y) {
                      return DropdownMenuItem(
                        value: y,
                        child: Text(
                          'Year $y',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => selectedYearLevel = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    context.read<ApplicationsBloc>().add(ApproveApplicationEvent(
                          app.applicationId,
                          yearLevel: selectedYearLevel,
                        ));
                    Navigator.of(dialogCtx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm Approval'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openRejectDialog(
      BuildContext context, EnrollmentApplicationModel app) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => BlocProvider.value(
        value: context.read<ApplicationsBloc>(),
        child: AlertDialog(
          title: const Text('Reject Application'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Specify reason for rejecting ${app.form?.fullName ?? "this applicant"}:',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g. Incomplete requirements, invalid credentials...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<ApplicationsBloc>().add(RejectApplicationEvent(
                      app.applicationId,
                      reason: reasonCtrl.text.trim().isNotEmpty
                          ? reasonCtrl.text.trim()
                          : null,
                    ));
                Navigator.of(dialogCtx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Rejection'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationDetailDialog extends StatelessWidget {
  final EnrollmentApplicationModel fallbackApp;
  final List<AcademicProgramModel> programs;
  final List<AcademicTermModel> terms;

  const _ApplicationDetailDialog({
    required this.fallbackApp,
    required this.programs,
    required this.terms,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ApplicationsBloc, ApplicationsState>(
      builder: (context, state) {
        final detail = (state is ApplicationsLoaded &&
                state.selectedDetail != null &&
                state.selectedDetail!.applicationId == fallbackApp.applicationId)
            ? state.selectedDetail!
            : fallbackApp;

        final form = detail.form;
        final changed = {for (final f in detail.changedFields) f.toLowerCase()};
        Widget pair(String label, String value) =>
            _buildInfoPair(label, value, changed: changed.contains(label.toLowerCase()));
        final progName = programs
            .firstWhere((p) => p.programId == detail.programId,
                orElse: () => AcademicProgramModel(
                    programId: 0, programCode: '—', programName: '—'))
            .programName;
        final termLabel = terms
            .firstWhere((t) => t.termId == detail.termId,
                orElse: () => AcademicTermModel(
                    termId: '', schoolYear: '—', semester: 0))
            .label;

        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          child: Container(
            width: 800,
            height: 680,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            form?.fullName ?? 'Application Review',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Application ID: ${detail.applicationId}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFBFDBFE),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                // Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: pair('Program', progName),
                              ),
                              Expanded(
                                child: pair('Term', termLabel),
                              ),
                              Expanded(
                                child: pair('Year Level',
                                     (form != null && form.yearLevel > 0) ? 'Year ${form.yearLevel}' : '—'),
                              ),
                              Expanded(
                                child: pair(
                                    'Submission Date',
                                    formatDate(detail.createdAt)),
                              ),
                            ],
                          ),
                        ),
                        if (detail.isReturning) ...[
                          const SizedBox(height: 12),
                          Container(
                            key: const ValueKey('returning_banner'),
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFCD34D)),
                            ),
                            child: Text(
                              detail.changedFields.isEmpty
                                  ? 'Returning student, enrolled online. No changes since the last enrollment.'
                                  : 'Returning student, enrolled online. Changed since the last enrollment: '
                                      '${detail.changedFields.join(', ')}. Changed fields are highlighted below.',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Section 1
                        _buildSectionTitle('Biographical Details'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: pair('First Name', form?.firstName ?? '—')),
                            Expanded(child: pair('Middle Name', form?.middleName.isNotEmpty == true ? form!.middleName : '—')),
                            Expanded(child: pair('Last Name', form?.lastName ?? '—')),
                            Expanded(child: pair('Suffix', form?.suffix.isNotEmpty == true ? form!.suffix : '—')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: pair('Date of Birth', form?.dateOfBirth ?? '—')),
                            Expanded(child: pair('Place of Birth', form?.placeOfBirth ?? '—')),
                            Expanded(child: pair('Sex', form?.sex ?? '—')),
                            Expanded(child: pair('Civil Status', form?.civilStatus ?? '—')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: pair('Nationality', form?.nationality ?? '—')),
                            Expanded(child: pair('Mobile Number', form?.mobileNumber ?? '—')),
                            Expanded(child: pair('Previous Physical Student ID', form?.previousStudentID ?? 'None')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'LRN (Learner Reference Number)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        form?.lrn?.isNotEmpty == true
                                            ? form!.lrn!
                                            : 'No LRN recorded',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: form?.lrn?.isNotEmpty == true
                                              ? const Color(0xFF0F172A)
                                              : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (detail.status == 1 || detail.status == 2)
                                        TextButton.icon(
                                          onPressed: () {
                                            EditLrnDialog.showForApplication(
                                              context,
                                              applicationId: detail.applicationId,
                                              applicantName: form?.fullName ?? 'Applicant',
                                              currentLrn: form?.lrn,
                                              onSaved: (_) {
                                                context.read<ApplicationsBloc>().add(
                                                      ViewApplicationDetail(detail.applicationId),
                                                    );
                                              },
                                            );
                                          },
                                          icon: const Icon(Icons.edit_outlined, size: 14),
                                          label: const Text('Edit LRN', style: TextStyle(fontSize: 12)),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        )
                                      else
                                        Tooltip(
                                          message: detail.status == 4
                                              ? 'Application already linked to student. Edit LRN in student profile instead.'
                                              : 'Cannot edit LRN for rejected application.',
                                          child: Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'School Email (@dbtc-cebu.edu.ph)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (detail.isReturning)
                                    const Text(
                                      'Already has a student account',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                    )
                                  else
                                  Row(
                                    children: [
                                      if (detail.schoolEmail != null && detail.schoolEmail!.isNotEmpty)
                                        Text(
                                          detail.schoolEmail!,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F172A),
                                          ),
                                        )
                                      else if (detail.status == 2)
                                        ActionChip(
                                          avatar: const Icon(Icons.add, size: 13, color: Color(0xFFD97706)),
                                          label: const Text(
                                            'Not set',
                                            style: TextStyle(
                                              color: Color(0xFFB45309),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
                                            ),
                                          ),
                                          backgroundColor: const Color(0xFFFEF3C7),
                                          side: const BorderSide(color: Color(0xFFFDE68A)),
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () {
                                            EditSchoolEmailDialog.show(
                                              context,
                                              applicationId: detail.applicationId,
                                              applicantName: form?.fullName ?? 'Applicant',
                                              currentSchoolEmail: detail.schoolEmail,
                                              onSaved: (_) {
                                                context.read<ApplicationsBloc>().add(
                                                      ViewApplicationDetail(detail.applicationId),
                                                    );
                                              },
                                            );
                                          },
                                        )
                                      else
                                        const Text(
                                          'No school email set',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      if (detail.status == 1 || detail.status == 2)
                                        TextButton.icon(
                                          onPressed: () {
                                            EditSchoolEmailDialog.show(
                                              context,
                                              applicationId: detail.applicationId,
                                              applicantName: form?.fullName ?? 'Applicant',
                                              currentSchoolEmail: detail.schoolEmail,
                                              onSaved: (_) {
                                                context.read<ApplicationsBloc>().add(
                                                      ViewApplicationDetail(detail.applicationId),
                                                    );
                                              },
                                            );
                                          },
                                          icon: const Icon(Icons.edit_outlined, size: 14),
                                          label: const Text('Edit Email', style: TextStyle(fontSize: 12)),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        )
                                      else
                                        Tooltip(
                                          message: detail.status == 4
                                              ? 'Application already linked to student.'
                                              : 'Cannot edit school email for rejected application.',
                                          child: Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Section 2
                        _buildSectionTitle('Address'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: pair('Barangay', form?.barangay ?? '—')),
                            Expanded(child: pair('City / Municipality', form?.cityMunicipality ?? '—')),
                            Expanded(child: pair('Province', form?.province ?? '—')),
                            Expanded(child: pair('ZIP Code', form?.zipCode ?? '—')),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Section 3
                        _buildSectionTitle('Educational Background'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: pair('Last School Attended', form?.lastSchoolAttended ?? '—')),
                            Expanded(child: pair('School Address', form?.schoolAddress ?? '—')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: pair('SHS Strand', form?.strandName ?? '—')),
                            Expanded(child: pair('Year Graduated', form?.yearGraduated ?? '—')),
                            Expanded(child: pair('Previous College', form?.previousCollege.isNotEmpty == true ? form!.previousCollege : 'None')),
                            Expanded(child: pair('Previous Course', form?.previousCourse.isNotEmpty == true ? form!.previousCourse : 'None')),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Section 4: Contacts
                        _buildSectionTitle('Emergency Contacts (${detail.contacts.length})'),
                        const SizedBox(height: 12),
                        if (detail.contacts.isEmpty)
                          const Text('No emergency contacts recorded.',
                              style: TextStyle(color: Colors.grey))
                        else
                          ...detail.contacts.map((c) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(child: pair('Name', '${c.firstName} ${c.lastName}')),
                                  Expanded(child: pair('Relation', c.relationName)),
                                  Expanded(child: pair('Occupation', c.occupation)),
                                  Expanded(child: pair('Phone', c.contactNo)),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                // Footer
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                        ),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildInfoPair(String label, String value, {bool changed = false}) {
    final pair = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        if (changed)
          const Text('changed', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
      ],
    );
    if (!changed) return pair;
    return Container(
      key: ValueKey('changed_$label'),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
      child: pair,
    );
  }
}

/// Small label for an old student who enrolled again online.
class _ReturningChip extends StatelessWidget {
  const _ReturningChip();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F2FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF93C5FD)),
        ),
        child: const Text('Returning',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF014F8E))),
      );
}
