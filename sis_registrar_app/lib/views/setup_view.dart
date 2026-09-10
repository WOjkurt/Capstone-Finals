import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/setup_bloc.dart';
import '../models/setup_models.dart';
import 'widgets/page_header.dart';
import '../theme/app_theme.dart';

class SetupView extends StatefulWidget {
  const SetupView({super.key});

  @override
  State<SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<SetupView> {
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
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.errorMessage!)),
                  ],
                ),
                backgroundColor: const Color(0xFFDC2626),
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
                title: 'Academic Setup & Governance',
                subtitle:
                    'Configure programs, terms, subjects, and prerequisite dependency graphs.',
                action: ElevatedButton.icon(
                  onPressed: () => context
                      .read<SetupBloc>()
                      .add(LoadSetupData(activeTab: state.activeTab)),
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
                  label: const Text('Refresh'),
                ),
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
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
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
    );
  }

  Widget _buildTabContent(BuildContext context, SetupState state) {
    switch (state.activeTab) {
      case 0:
        return _ProgramsTab(state: state);
      case 1:
        return _TermsTab(state: state);
      case 2:
      default:
        return _SubjectsTab(state: state);
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
                            label: Text('School Year',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          DataColumn(
                            label: Text('Semester',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          DataColumn(
                            label: Text('Term Label',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          DataColumn(
                            label: Text('Actions',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                        rows: state.terms.map((t) {
                          final semText = t.semester == 1
                              ? '1st Semester'
                              : t.semester == 2
                                  ? '2nd Semester'
                                  : 'Summer / Special';

                          return DataRow(
                            cells: [
                              DataCell(Text(t.schoolYear,
                                  style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(Text(semText)),
                              DataCell(
                                Text(
                                  t.label,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18, color: AppColors.primaryHover),
                                      tooltip: 'Edit Term',
                                      onPressed: () => _openTermModal(context, t),
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
                                          Text(
                                            sub.subjectCode,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
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
              onAdd: (prereqSubId) {
                context
                    .read<SetupBloc>()
                    .add(AddPrerequisiteEvent(subject.subjectId, prereqSubId));
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
                                      Text(
                                        p.prerequisiteSubjectCode ??
                                            'Prerequisite Subject',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: Color(0xFF0F172A),
                                        ),
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
                                  tooltip: 'Unlink Prerequisite',
                                  onPressed: () => _confirmDelete(
                                    context,
                                    title: 'Unlink Prerequisite',
                                    message:
                                        'Are you sure you want to remove ${p.prerequisiteSubjectCode ?? "this subject"} as a prerequisite for ${subject.subjectCode}?',
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
  final Function(String prereqSubjectId) onAdd;

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

  @override
  Widget build(BuildContext context) {
    if (widget.candidates.isEmpty) {
      return const Text('No candidate subjects available.');
    }

    final candidateIds = widget.candidates.map((s) => s.subjectId).toSet();
    final effectiveSelectedId =
        candidateIds.contains(_selectedPrereqId) ? _selectedPrereqId : null;

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: effectiveSelectedId,
            isExpanded: true,
            hint: const Text('Select Prerequisite Subject'),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
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
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _selectedPrereqId == null
              ? null
              : () {
                  widget.onAdd(_selectedPrereqId!);
                  setState(() => _selectedPrereqId = null);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            elevation: 0,
          ),
          child: const Text('Add'),
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
