import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/setup_bloc.dart';
import '../injection.dart';
import '../models/class_models.dart';
import '../models/setup_models.dart';
import '../repositories/class_repository.dart';
import '../theme/app_theme.dart';
import 'widgets/class_roster_dialog.dart';
import 'widgets/open_term_dialog.dart';
import 'widgets/page_header.dart';
import 'widgets/status_badge.dart';
import 'widgets/accredited_schools_tab.dart';
import 'widgets/enrollment_period.dart';
import 'widgets/unit_limits_tab.dart';
import '../repositories/report_repository.dart';
import '../utils/report_pdf.dart';
import '../utils/study_load_pdf.dart' show loadSchoolLogo, printPdf;
import '../services/current_term.dart';

class SetupView extends StatefulWidget {
  const SetupView({super.key});

  @override
  State<SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<SetupView> {
  List<AcademicTermModel>? _lastTerms;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<SetupBloc>();
    if (bloc.state.programs.isEmpty && !bloc.state.isLoading) {
      bloc.add(LoadSetupData(activeTab: 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: BlocConsumer<SetupBloc, SetupState>(
        listener: (context, state) {
          // Adding, deleting or activating a term changes the term the other pages work in.
          if (!identical(state.terms, _lastTerms)) {
            _lastTerms = state.terms;
            CurrentTermScope.maybeOf(context)?.load(force: true);
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
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.errorMessage!)),
                  ],
                ),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Setup',
                subtitle: 'Programs, academic terms, subjects and classes.',
                onRefresh: () => context.read<SetupBloc>().add(LoadSetupData(activeTab: state.activeTab)),
              ),
              // Sub Tabs Navigation
              _buildSubTabBar(context, state),
              // Tab Body
              Expanded(
                child: state.isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary),
                      )
                    : _buildTabContent(context, state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubTabBar(BuildContext context, SetupState state) {
    final tabs = [
      {'title': 'Academic Programs', 'index': 0, 'icon': Icons.school_outlined},
      {'title': 'Academic Terms', 'index': 1, 'icon': Icons.calendar_month_outlined},
      {'title': 'Subjects & Prerequisites', 'index': 2, 'icon': Icons.menu_book_outlined},
      {'title': 'Classes & Rosters', 'index': 3, 'icon': Icons.groups_outlined},
      {'title': 'Accredited Schools', 'index': 4, 'icon': Icons.account_balance_outlined},
      {'title': 'Unit Limits', 'index': 5, 'icon': Icons.tune_rounded},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((t) {
            final isSelected = state.activeTab == t['index'];
            return InkWell(
              onTap: () {
                context
                    .read<SetupBloc>()
                    .add(SwitchSetupTab(t['index'] as int));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      t['icon'] as IconData,
                      size: 18,
                      color: isSelected
                          ? AppColors.primary
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t['title'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                          ? AppColors.primary
                          : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, SetupState state) {
    switch (state.activeTab) {
      case 0:
        return _ProgramsTab(state: state);
      case 1:
        return _TermsTab(state: state);
      case 2:
        return _SubjectsTab(state: state);
      case 4:
        return const AccreditedSchoolsTab();
      case 5:
        return const UnitLimitsTab();
      case 3:
      default:
        return _ClassesTab(state: state);
    }
  }
}

// ==========================================
// 1. PROGRAMS TAB
// ==========================================
class _ProgramsTab extends StatelessWidget {
  final SetupState state;
  const _ProgramsTab({required this.state});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Programs (${state.programs.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openProgramModal(context, null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Academic Program'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        horizontalMargin: 24,
                        columns: const [
                          DataColumn(
                            label: Text('Program Code',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          DataColumn(
                            label: Text('Program Name',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          DataColumn(
                            label: Text('Actions',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                        rows: state.programs.map((p) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  p.programCode,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary),
                                ),
                              ),
                              DataCell(Text(p.programName)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18, color: AppColors.primaryHover),
                                      tooltip: 'Edit Program',
                                      onPressed: () => _openProgramModal(context, p),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: Color(0xFFDC2626)),
                                      tooltip: 'Delete Program',
                                      onPressed: () => _confirmDelete(
                                        context,
                                        title: 'Delete Program',
                                        message:
                                            'Are you sure you want to delete ${p.programCode}?',
                                        onConfirm: () => context
                                            .read<SetupBloc>()
                                            .add(DeleteProgramEvent(p.programId)),
                                      ),
                                    ),
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
        ],
      ),
    );
  }

  void _openProgramModal(BuildContext context, AcademicProgramModel? program) {
    final codeCtrl = TextEditingController(text: program?.programCode ?? '');
    final nameCtrl = TextEditingController(text: program?.programName ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: context.read<SetupBloc>(),
        child: AlertDialog(
          title: Text(program == null ? 'Add Academic Program' : 'Edit Academic Program'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Program Code *',
                  hintText: 'e.g. BSCS, BSIT',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Code required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Program Name *',
                  hintText: 'e.g. Bachelor of Science in Computer Science',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Name required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              if (program == null) {
                context.read<SetupBloc>().add(
                      CreateProgramEvent(codeCtrl.text.trim(), nameCtrl.text.trim()),
                    );
              } else {
                context.read<SetupBloc>().add(
                      UpdateProgramEvent(
                        program.programId,
                        codeCtrl.text.trim(),
                        nameCtrl.text.trim(),
                      ),
                    );
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(program == null ? 'Create' : 'Save Changes'),
          ),
        ],
      ),
    ),
    );
  }
}

// ==========================================
// 2. TERMS TAB
// ==========================================
class _TermsTab extends StatelessWidget {
  final SetupState state;
  const _TermsTab({required this.state});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Academic Terms (${state.terms.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openTermModal(context, null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Academic Term'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        horizontalMargin: 24,
                        columns: const [
                          DataColumn(
                            label: Text('Term',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          DataColumn(
                            label: Text('Status',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          DataColumn(
                            label: Text('Online Enrollment',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          DataColumn(
                            label: Text('Actions',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                        rows: state.terms.map((t) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  t.label,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary),
                                ),
                              ),
                              DataCell(
                                t.isActive
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                              color: const Color(0xFF86EFAC)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle_rounded,
                                                size: 14,
                                                color: Color(0xFF16A34A)),
                                            SizedBox(width: 5),
                                            Text(
                                              'Active Term',
                                              style: TextStyle(
                                                color: Color(0xFF15803D),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                              color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: const Text(
                                          'Inactive',
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                              ),
                              DataCell(EnrollmentPeriodCell(term: t)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!t.isActive) ...[
                                      OutlinedButton.icon(
                                        icon: const Icon(
                                            Icons.check_circle_outline,
                                            size: 14),
                                        label: const Text('Set Active'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF16A34A),
                                          side: const BorderSide(
                                              color: Color(0xFF86EFAC)),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          visualDensity:
                                              VisualDensity.compact,
                                          textStyle: const TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12),
                                        ),
                                        onPressed: () =>
                                            _confirmActivateTerm(context, t),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    IconButton(
                                      icon: const Icon(Icons.groups_outlined,
                                          size: 18,
                                          color: AppColors.primary),
                                      tooltip: 'View Classes & Rosters',
                                      onPressed: () => context
                                          .read<SetupBloc>()
                                          .add(SelectTermForClassesEvent(t.termId)),
                                    ),
                                    IconButton(
                                      key: ValueKey('enrollment_dates_${t.termId}'),
                                      icon: const Icon(Icons.event_available_outlined,
                                          size: 18,
                                          color: AppColors.primary),
                                      tooltip: 'Set Enrollment Dates',
                                      onPressed: () async {
                                        final bloc = context.read<SetupBloc>();
                                        final choice = await showEnrollmentPeriodDialog(context, t);
                                        if (choice != null) {
                                          bloc.add(SetEnrollmentPeriodEvent(t.termId, choice.opensOn, choice.closesOn));
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18,
                                          color: AppColors.primaryHover),
                                      tooltip: 'Edit Term',
                                      onPressed: () =>
                                          _openTermModal(context, t),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: Color(0xFFDC2626)),
                                      tooltip: 'Delete Term',
                                      onPressed: () => _confirmDelete(
                                        context,
                                        title: 'Delete Academic Term',
                                        message:
                                            'Are you sure you want to delete term ${t.label}?',
                                        onConfirm: () => context
                                            .read<SetupBloc>()
                                            .add(DeleteTermEvent(t.termId)),
                                      ),
                                    ),
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
        ],
      ),
    );
  }

  void _confirmActivateTerm(
      BuildContext context, AcademicTermModel targetTerm) {
    final currentActive =
        state.terms.where((term) => term.isActive).firstOrNull;

    final String transitionText;
    if (currentActive != null) {
      transitionText =
          'This will deactivate ${currentActive.label} and activate ${targetTerm.label} as the current academic term.';
    } else {
      transitionText =
          'This will activate ${targetTerm.label} as the current academic term.';
    }

    showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: context.read<SetupBloc>(),
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.published_with_changes_rounded,
                  color: Color(0xFF16A34A), size: 24),
              SizedBox(width: 10),
              Text('Set Active Academic Term'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transitionText,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF1E293B), height: 1.5),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: Color(0xFFB45309)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This immediately affects the default academic term across the Student, Faculty, and Registrar portals.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                context
                    .read<SetupBloc>()
                    .add(ActivateTermEvent(targetTerm.termId));
              },
              child: const Text('Set as Active'),
            ),
          ],
        ),
      ),
    );
  }

  void _openTermModal(BuildContext context, AcademicTermModel? term) {
    final yearCtrl = TextEditingController(text: term?.schoolYear ?? '2025-2026');
    const validSems = [1, 2, 3];
    int semester = (term != null && validSems.contains(term.semester))
        ? term.semester
        : validSems.first;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: context.read<SetupBloc>(),
        child: StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
            title: Text(term == null ? 'Add Academic Term' : 'Edit Academic Term'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: yearCtrl,
                    decoration: const InputDecoration(
                      labelText: 'School Year *',
                      hintText: 'e.g. 2025-2026',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.isEmpty ? 'School year required' : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: semester,
                    decoration: const InputDecoration(
                      labelText: 'Semester *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 1,
                        child: Text(
                          '1st Semester',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 2,
                        child: Text(
                          '2nd Semester',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 3,
                        child: Text(
                          'Summer Term',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => semester = v ?? 1),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  if (term == null) {
                    context.read<SetupBloc>().add(
                          CreateTermEvent(yearCtrl.text.trim(), semester),
                        );
                  } else {
                    context.read<SetupBloc>().add(
                          UpdateTermEvent(term.termId, yearCtrl.text.trim(), semester),
                        );
                  }
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(term == null ? 'Create' : 'Save Changes'),
              ),
            ],
          );
        },
      ),
    ),
    );
  }
}

// ==========================================
// 3. SUBJECTS & PREREQUISITES TAB
// ==========================================
class _SubjectsTab extends StatelessWidget {
  final SetupState state;
  const _SubjectsTab({required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Subjects Table
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subjects (${state.subjects.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openSubjectModal(context, null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Subject'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: DataTable(
                                  showCheckboxColumn: false,
                                  headingRowColor:
                                      WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                  horizontalMargin: 16,
                                  columnSpacing: 16,
                                  columns: const [
                                    DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.w700))),
                                    DataColumn(label: Text('Title', style: TextStyle(fontWeight: FontWeight.w700))),
                                    DataColumn(label: Text('Units (Lec/Lab)', style: TextStyle(fontWeight: FontWeight.w700))),
                                    DataColumn(label: Text('Prog / Year / Sem', style: TextStyle(fontWeight: FontWeight.w700))),
                                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
                                  ],
                                  rows: state.subjects.map((sub) {
                                    final isSelected = state.selectedSubjectForPrereqs?.subjectId == sub.subjectId;

                                    return DataRow(
                                      selected: isSelected,
                                      onSelectChanged: (_) {
                                        context
                                            .read<SetupBloc>()
                                            .add(SelectSubjectForPrereqs(isSelected ? null : sub));
                                      },
                                      cells: [
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                sub.subjectCode,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              if (sub.isMinor) ...[
                                                const SizedBox(width: 6),
                                                StatusBadge.info(label: 'Minor'),
                                              ],
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            sub.subjectTitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DataCell(
                                          Text('${sub.lecUnits.toStringAsFixed(1)} / ${sub.labUnits.toStringAsFixed(1)}'),
                                        ),
                                        DataCell(
                                          Text('${sub.programCode ?? sub.programId} • Y${sub.yearLevel} • S${sub.defaultSemester}'),
                                        ),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.alt_route_rounded,
                                                    size: 18, color: AppColors.primary),
                                                tooltip: 'Manage Prerequisites',
                                                onPressed: () {
                                                  context
                                                      .read<SetupBloc>()
                                                      .add(SelectSubjectForPrereqs(sub));
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined,
                                                    size: 18, color: AppColors.primaryHover),
                                                tooltip: 'Edit Subject',
                                                onPressed: () =>
                                                    _openSubjectModal(context, sub),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline,
                                                    size: 18, color: Color(0xFFDC2626)),
                                                tooltip: 'Delete Subject',
                                                onPressed: () => _confirmDelete(
                                                  context,
                                                  title: 'Delete Subject',
                                                  message:
                                                      'Are you sure you want to delete ${sub.subjectCode} - ${sub.subjectTitle}?',
                                                  onConfirm: () => context
                                                      .read<SetupBloc>()
                                                      .add(DeleteSubjectEvent(sub.subjectId)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Right: Prerequisites Side Panel
          Expanded(
            flex: 4,
            child: _buildPrerequisitesPanel(context, state),
          ),
        ],
      ),
    );
  }

  Widget _buildPrerequisitesPanel(BuildContext context, SetupState state) {
    if (state.selectedSubjectForPrereqs == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.alt_route_rounded,
                  size: 56, color: Color(0xFFCBD5E1)),
              SizedBox(height: 16),
              Text(
                'Prerequisites Inspector',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Select a subject from the table to view, add, or unlink its required prerequisite subjects.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    final subject = state.selectedSubjectForPrereqs!;
    // Candidate subjects to be prerequisites (excluding self)
    final candidateSubjects = state.subjects
        .where((s) => s.subjectId != subject.subjectId)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Panel Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.subjectCode,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subject.subjectTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFBFDBFE),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () {
                    context
                        .read<SetupBloc>()
                        .add(SelectSubjectForPrereqs(null));
                  },
                ),
              ],
            ),
          ),
          // Add Prerequisite Form Row
          Padding(
            padding: const EdgeInsets.all(16),
            child: _AddPrerequisiteRow(
              subjectId: subject.subjectId,
              candidates: candidateSubjects,
              onAdd: (prereqSubId, requisiteType) {
                context
                    .read<SetupBloc>()
                    .add(AddPrerequisiteEvent(
                      subject.subjectId,
                      prereqSubId,
                      requisiteType: requisiteType,
                    ));
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          // Prerequisites List
          Expanded(
            child: state.isPrereqsLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary),
                  )
                : state.prerequisites.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No prerequisites defined for ${subject.subjectCode}.\nStudents can enroll without completing any prior subjects.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.prerequisites.length,
                        separatorBuilder: (ctx, i) =>
                            const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final p = state.prerequisites[i];
                          final isCoreq = p.isCorequisite;

                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.arrow_right_alt_rounded,
                                    color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              p.prerequisiteSubjectCode ??
                                                  'Unknown Subject',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isCoreq
                                                  ? const Color(0xFFFEF3C7)
                                                  : const Color(0xFFDBEAFE),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isCoreq
                                                    ? const Color(0xFFF59E0B)
                                                    : const Color(0xFF3B82F6),
                                              ),
                                            ),
                                            child: Text(
                                              isCoreq
                                                  ? 'Corequisite'
                                                  : 'Prerequisite',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: isCoreq
                                                    ? const Color(0xFF92400E)
                                                    : const Color(0xFF1D4ED8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (p.prerequisiteSubjectTitle != null)
                                        Text(
                                          p.prerequisiteSubjectTitle!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.link_off_rounded,
                                      size: 18, color: Colors.red),
                                  tooltip: 'Unlink',
                                  onPressed: () => _confirmDelete(
                                    context,
                                    title: isCoreq
                                        ? 'Unlink Corequisite'
                                        : 'Unlink Prerequisite',
                                    message:
                                        'Are you sure you want to remove ${p.prerequisiteSubjectCode ?? "this subject"} as a ${isCoreq ? "corequisite" : "prerequisite"} for ${subject.subjectCode}?',
                                    confirmLabel: 'Confirm Unlink',
                                    onConfirm: () => context
                                        .read<SetupBloc>()
                                        .add(RemovePrerequisiteEvent(
                                            p.prerequisiteId)),
                                  ),
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

  void _openSubjectModal(BuildContext context, SubjectModel? sub) {
    final codeCtrl = TextEditingController(text: sub?.subjectCode ?? '');
    final titleCtrl = TextEditingController(text: sub?.subjectTitle ?? '');
    final lecUnitsCtrl =
        TextEditingController(text: (sub?.lecUnits ?? 3.0).toString());
    final labUnitsCtrl =
        TextEditingController(text: (sub?.labUnits ?? 0.0).toString());
    final lecHoursCtrl =
        TextEditingController(text: (sub?.lecHours ?? 3.0).toString());
    final labHoursCtrl =
        TextEditingController(text: (sub?.labHours ?? 0.0).toString());

    final validProgIds = state.programs.map((p) => p.programId).toList();
    int? progId = (sub != null && validProgIds.contains(sub.programId))
        ? sub.programId
        : (validProgIds.isNotEmpty ? validProgIds.first : null);

    const validYears = [1, 2, 3, 4, 5];
    int yearLevel = (sub != null && validYears.contains(sub.yearLevel))
        ? sub.yearLevel
        : validYears.first;

    const validSems = [1, 2, 3];
    int defSem = (sub != null && validSems.contains(sub.defaultSemester))
        ? sub.defaultSemester
        : validSems.first;

    int? standingYear = (sub != null && [1, 2, 3, 4].contains(sub.standingYear))
        ? sub.standingYear
        : null;

    bool isMinor = sub?.isMinor ?? false;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: context.read<SetupBloc>(),
        child: StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
            title: Text(sub == null ? 'Add Subject' : 'Edit Subject'),
            content: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: codeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Subject Code *',
                                hintText: 'e.g. CS101',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v!.isEmpty ? 'Code required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              initialValue: progId,
                              decoration: const InputDecoration(
                                labelText: 'Program *',
                                border: OutlineInputBorder(),
                              ),
                              items: state.programs.map((p) {
                                return DropdownMenuItem(
                                  value: p.programId,
                                  child: Text(
                                    p.programCode,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) => setState(() => progId = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Subject Title *',
                          hintText: 'e.g. Introduction to Computing',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v!.isEmpty ? 'Title required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: lecUnitsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Lec Units *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: labUnitsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Lab Units *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: lecHoursCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Lec Hours *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: labHoursCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Lab Hours *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              initialValue: yearLevel,
                              decoration: const InputDecoration(
                                labelText: 'Year Level *',
                                border: OutlineInputBorder(),
                              ),
                              items: validYears.map((y) {
                                return DropdownMenuItem(
                                  value: y,
                                  child: Text(
                                    'Year $y',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => yearLevel = v ?? validYears.first),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              initialValue: defSem,
                              decoration: const InputDecoration(
                                labelText: 'Default Semester *',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 1,
                                  child: Text(
                                    '1st Semester',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 2,
                                  child: Text(
                                    '2nd Semester',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 3,
                                  child: Text(
                                    'Summer Term',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => defSem = v ?? 1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        isExpanded: true,
                        initialValue: standingYear,
                        decoration: const InputDecoration(
                          labelText: 'Standing Year Requirement (Optional)',
                          hintText: 'None (No standing requirement)',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text('None (No standing requirement)'),
                          ),
                          DropdownMenuItem<int?>(
                            value: 1,
                            child: Text('1st Year Standing'),
                          ),
                          DropdownMenuItem<int?>(
                            value: 2,
                            child: Text('2nd Year Standing'),
                          ),
                          DropdownMenuItem<int?>(
                            value: 3,
                            child: Text('3rd Year Standing'),
                          ),
                          DropdownMenuItem<int?>(
                            value: 4,
                            child: Text('4th Year Standing'),
                          ),
                        ],
                        onChanged: (v) => setState(() => standingYear = v),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        key: const ValueKey('subject_is_minor_checkbox'),
                        value: isMinor,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Minor subject (GE, theology, PE, NSTP…)'),
                        subtitle: const Text(
                          'Teachers and schedules for minor subjects are set by the College Head.',
                          style: TextStyle(fontSize: 12),
                        ),
                        onChanged: (v) => setState(() => isMinor = v ?? false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  final dto = {
                    'subjectCode': codeCtrl.text.trim(),
                    'subjectTitle': titleCtrl.text.trim(),
                    'lecUnits': double.tryParse(lecUnitsCtrl.text) ?? 3.0,
                    'labUnits': double.tryParse(labUnitsCtrl.text) ?? 0.0,
                    'lecHours': double.tryParse(lecHoursCtrl.text) ?? 3.0,
                    'labHours': double.tryParse(labHoursCtrl.text) ?? 0.0,
                    'programID': progId,
                    'yearLevel': yearLevel,
                    'defaultSemester': defSem,
                    'standingYear': standingYear,
                    'isMinor': isMinor,
                  };

                  if (sub == null) {
                    context
                        .read<SetupBloc>()
                        .add(CreateSubjectEvent(dto));
                  } else {
                    context
                        .read<SetupBloc>()
                        .add(UpdateSubjectEvent(sub.subjectId, dto));
                  }
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(sub == null ? 'Create Subject' : 'Save Changes'),
              ),
            ],
          );
        },
      ),
    ),
    );
  }
}

class _AddPrerequisiteRow extends StatefulWidget {
  final String subjectId;
  final List<SubjectModel> candidates;
  /// Called with (prerequisiteSubjectId, requisiteType) when the user taps Add.
  final Function(String prereqSubjectId, int requisiteType) onAdd;

  const _AddPrerequisiteRow({
    required this.subjectId,
    required this.candidates,
    required this.onAdd,
  });

  @override
  State<_AddPrerequisiteRow> createState() => _AddPrerequisiteRowState();
}

class _AddPrerequisiteRowState extends State<_AddPrerequisiteRow> {
  String? _selectedPrereqId;
  // 0 = Prerequisite, 1 = Corequisite
  int _requisiteType = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.candidates.isEmpty) {
      return const Text('No candidate subjects available.');
    }

    final candidateIds = widget.candidates.map((s) => s.subjectId).toSet();
    final effectiveSelectedId =
        candidateIds.contains(_selectedPrereqId) ? _selectedPrereqId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Subject picker
        DropdownButtonFormField<String>(
          key: ValueKey(effectiveSelectedId),
          initialValue: effectiveSelectedId,
          isExpanded: true,
          hint: const Text('Select Subject'),
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            labelText: 'Subject',
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          items: widget.candidates.map((s) {
            return DropdownMenuItem(
              value: s.subjectId,
              child: Text(
                '${s.subjectCode} - ${s.subjectTitle}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedPrereqId = v),
        ),
        const SizedBox(height: 8),
        // Type picker + Add button
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                value: _requisiteType,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  labelText: 'Type',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 0,
                    child: Text('Prerequisite',
                        overflow: TextOverflow.ellipsis, maxLines: 1),
                  ),
                  DropdownMenuItem(
                    value: 1,
                    child: Text('Corequisite',
                        overflow: TextOverflow.ellipsis, maxLines: 1),
                  ),
                ],
                onChanged: (v) => setState(() => _requisiteType = v ?? 0),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _selectedPrereqId == null
                  ? null
                  : () {
                      widget.onAdd(_selectedPrereqId!, _requisiteType);
                      setState(() {
                        _selectedPrereqId = null;
                        _requisiteType = 0;
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                elevation: 0,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ],
    );
  }
}

void _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm Delete',
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    builder: (ctx) => BlocProvider.value(
      value: context.read<SetupBloc>(),
      child: AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onConfirm();
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
}

// ==========================================
// 4. CLASSES & ROSTERS TAB
// ==========================================
class _ClassesTab extends StatefulWidget {
  final SetupState state;
  const _ClassesTab({required this.state});

  @override
  State<_ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<_ClassesTab> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedTermId;
  bool _printing = false;

  /// Prints the class list of one class, or of every class in the chosen term.
  Future<void> _printClassLists({String? classId}) async {
    final termId = _selectedTermId;
    if (termId == null) return;
    setState(() => _printing = true);
    try {
      final lists = await getIt<ReportRepository>().classLists(termId, classId: classId);
      final bytes = await buildClassListsPdf(lists, logo: await loadSchoolLogo());
      final name = classId != null && lists.isNotEmpty
          ? 'Class_List_${lists.first.subjectCode}_${lists.first.className}'
          : 'Class_Lists_${lists.isEmpty ? '' : lists.first.termLabel}';
      await printPdf(bytes, '${name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not print: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }
  List<ClassModel> _classes = [];
  bool _isLoading = false;
  String? _error;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _initTermAndFetch();
  }

  @override
  void didUpdateWidget(covariant _ClassesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.selectedTermIdForClasses != null &&
        widget.state.selectedTermIdForClasses != _selectedTermId) {
      _selectedTermId = widget.state.selectedTermIdForClasses;
      _fetchClasses();
    } else if (_selectedTermId == null && widget.state.terms.isNotEmpty) {
      _initTermAndFetch();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initTermAndFetch() {
    if (widget.state.terms.isEmpty) return;

    if (widget.state.selectedTermIdForClasses != null &&
        widget.state.terms.any((t) => t.termId == widget.state.selectedTermIdForClasses)) {
      _selectedTermId = widget.state.selectedTermIdForClasses;
    } else {
      final activeTerm = widget.state.terms.firstWhere(
        (t) => t.isActive,
        orElse: () => widget.state.terms.first,
      );
      _selectedTermId = activeTerm.termId;
    }

    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    if (_selectedTermId == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = getIt<ClassRepository>();
      final list = await repo.getClasses(termId: _selectedTermId);
      if (mounted) {
        setState(() {
          _classes = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final terms = widget.state.terms;
    final filteredClasses = _classes.where((c) {
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      final code = (c.subjectCode ?? '').toLowerCase();
      final title = (c.subjectTitle ?? '').toLowerCase();
      final name = c.className.toLowerCase();
      final teacher = (c.teacherName ?? '').toLowerCase();
      return code.contains(q) ||
          title.contains(q) ||
          name.contains(q) ||
          teacher.contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with Term Selector & Search
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Classes & Student Rosters (${filteredClasses.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'View enrolled student rosters for each class and manage enrollment statuses (Enrolled, Dropped, Withdrawn).',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Term Selector Dropdown
              if (terms.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTermId,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF64748B)),
                      items: terms.map((t) {
                        return DropdownMenuItem<String>(
                          value: t.termId,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if (t.isActive) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFF86EFAC)),
                                  ),
                                  child: const Text(
                                    'Active',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && val != _selectedTermId) {
                          setState(() {
                            _selectedTermId = val;
                          });
                          _fetchClasses();
                        }
                      },
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                key: const ValueKey('print_all_class_lists_button'),
                icon: const Icon(Icons.print_outlined, size: 16),
                label: const Text('Print all class lists'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onPressed: (_printing || _selectedTermId == null) ? null : () => _printClassLists(),
              ),
              const SizedBox(width: 12),
              // Open Classes for Term Button
              ElevatedButton.icon(
                key: const Key('open_classes_term_button'),
                icon: const Icon(Icons.auto_mode_rounded, size: 16),
                label: const Text('Open Classes for Term...'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  final result = await OpenTermDialog.show(
                    context,
                    terms: widget.state.terms,
                    programs: widget.state.programs,
                    initialTermId: _selectedTermId,
                  );
                  if (result != null && mounted) {
                    _fetchClasses();
                  }
                },
              ),
              const SizedBox(width: 8),
              // Refresh Button
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                tooltip: 'Refresh Classes',
                onPressed: _fetchClasses,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Filter Input
          SizedBox(
            width: double.infinity,
            height: 42,
            child: TextField(
              controller: _searchController,
              onChanged: (val) =>
                  setState(() => _filter = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by subject code, title, section, or instructor...',
                hintStyle:
                    const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: AppColors.textSecondary),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _filter = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),

          // Content Area
          if (terms.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_outlined,
                        size: 48, color: Color(0xFFCBD5E1)),
                    SizedBox(height: 12),
                    Text(
                      'No Academic Terms Found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Please configure an academic term in the Academic Terms tab first.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else if (_isLoading)
            Container(
              padding: const EdgeInsets.all(60),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text('Loading classes...',
                        style: TextStyle(color: Color(0xFF64748B))),
                  ],
                ),
              ),
            )
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFDC2626), size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load classes: $_error',
                      style: const TextStyle(
                          color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _fetchClasses,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          else if (filteredClasses.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.class_outlined,
                        size: 48, color: Color(0xFFCBD5E1)),
                    const SizedBox(height: 12),
                    Text(
                      _filter.isNotEmpty
                          ? 'No classes match "$_filter"'
                          : 'No classes scheduled for this term.',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Classes are configured per academic term.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
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
                        constraints:
                            BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                              const Color(0xFFF8FAFC)),
                          horizontalMargin: 24,
                          columns: const [
                            DataColumn(
                              label: Text('Subject',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            DataColumn(
                              label: Text('Section',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            DataColumn(
                              label: Text('Instructor',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            DataColumn(
                              label: Text('Schedule',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            DataColumn(
                              label: Text('Enrolled',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            DataColumn(
                              label: Text('Actions',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ],
                          rows: filteredClasses.map((c) {
                            return DataRow(
                              cells: [
                                // Subject Code & Title
                                DataCell(
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              c.subjectCode ?? 'N/A',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        c.subjectTitle ?? 'Untitled Subject',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Section / Class Name
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      c.className,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                ),
                                // Instructor
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        c.teacherName != null
                                            ? Icons.person_outline
                                            : Icons.person_off_outlined,
                                        size: 16,
                                        color: c.teacherName != null
                                            ? const Color(0xFF475569)
                                            : const Color(0xFF94A3B8),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        c.teacherName ?? 'Unassigned',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: c.teacherName != null
                                              ? const Color(0xFF334155)
                                              : Colors.grey.shade500,
                                          fontStyle: c.teacherName == null
                                              ? FontStyle.italic
                                              : FontStyle.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Schedule
                                DataCell(
                                  Text(
                                    c.scheduleSummary,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                // Enrolled Count Badge
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.people_alt,
                                            size: 13,
                                            color: Color(0xFF1D4ED8)),
                                        const SizedBox(width: 5),
                                        Text(
                                          '${c.enrolledCount} students',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: Color(0xFF1D4ED8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Actions
                                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconButton(
                                    key: ValueKey('print_class_list_${c.classId}'),
                                    tooltip: 'Print class list',
                                    icon: const Icon(Icons.print_outlined, size: 18, color: AppColors.primary),
                                    onPressed: _printing ? null : () => _printClassLists(classId: c.classId),
                                  ),
                                  const SizedBox(width: 4),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      ClassRosterDialog.show(
                                        context,
                                        classItem: c,
                                        onRosterUpdated: _fetchClasses,
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.people_outline,
                                        size: 16),
                                    label: const Text(
                                      'View Roster',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ])),
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
        ],
      ),
    );
  }
}
