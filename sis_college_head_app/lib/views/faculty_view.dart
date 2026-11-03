import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/faculty_bloc.dart';
import '../models/class_models.dart';
import '../theme/app_theme.dart';
import 'widgets/assign_teacher_dialog.dart';
import 'widgets/class_schedule_dialog.dart';
import 'widgets/page_header.dart';
import 'widgets/status_badge.dart';

class FacultyView extends StatefulWidget {
  const FacultyView({super.key});

  @override
  State<FacultyView> createState() => _FacultyViewState();
}

class _FacultyViewState extends State<FacultyView> {
  @override
  void initState() {
    super.initState();
    context.read<FacultyBloc>().add(FacultyStarted());
  }

  void _openAssign(ClassModel classItem) {
    final bloc = context.read<FacultyBloc>();
    showDialog(
      context: context,
      builder: (ctx) => AssignTeacherDialog(
        classItem: classItem,
        onAssign: (teacherUserId) => bloc.add(FacultyAssignRequested(
          classId: classItem.classId,
          teacherUserId: teacherUserId,
        )),
      ),
    );
  }

  Future<void> _openSchedule(ClassModel classItem) async {
    final bloc = context.read<FacultyBloc>();
    final changed = await ClassScheduleDialog.show(context, classItem);
    if (changed == true) bloc.add(FacultyRefreshRequested());
  }

  Widget _scheduleButton(FacultyState state, ClassModel c) {
    return TextButton.icon(
      onPressed: state.isAssigning ? null : () => _openSchedule(c),
      icon: const Icon(Icons.schedule_rounded, size: 16),
      label: const Text('Schedule'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FacultyBloc, FacultyState>(
      listenWhen: (prev, curr) =>
          curr.successMessage != null && curr.successMessage != prev.successMessage,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.successMessage!)),
        );
      },
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Faculty',
              subtitle:
                  'Assign teachers to minor subjects, and to majors as a backup, across all programs.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(width: 260, child: _buildTermDropdown(state)),
                  SizedBox(width: 220, child: _buildProgramDropdown(state)),
                ],
              ),
            ),
            if (state.isAssigning) const LinearProgressIndicator(),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
                child: Text(state.errorMessage!,
                    style: const TextStyle(color: AppColors.error)),
              ),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(state),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTermDropdown(FacultyState state) {
    return DropdownButtonFormField<String>(
      key: ValueKey('faculty_term_${state.selectedTermId}'),
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
        if (v != null) context.read<FacultyBloc>().add(FacultyTermSelected(v));
      },
    );
  }

  Widget _buildProgramDropdown(FacultyState state) {
    return DropdownButtonFormField<int?>(
      key: const ValueKey('faculty_program_dropdown'),
      initialValue: state.selectedProgramId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Program',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('All programs')),
        ...state.programs.map((p) => DropdownMenuItem<int?>(
              value: p.programId,
              child: Text(p.programCode, overflow: TextOverflow.ellipsis),
            )),
      ],
      onChanged: (v) =>
          context.read<FacultyBloc>().add(FacultyProgramSelected(v)),
    );
  }

  Widget _buildContent(FacultyState state) {
    final unassigned = state.unassignedClasses;
    final faculty = state.faculty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
      children: [
        _sectionTitle('Classes without a teacher (${unassigned.length})'),
        if (unassigned.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Every class in this view has a teacher.',
                style: TextStyle(color: AppColors.textSecondary)),
          )
        else
          ...unassigned.map((c) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: _classTitle(c),
                  subtitle: Text(
                      '${c.className} · ${state.programCodeFor(c.programId)} · ${c.scheduleSummary}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _scheduleButton(state, c),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: state.isAssigning ? null : () => _openAssign(c),
                        child: const Text('Assign teacher'),
                      ),
                    ],
                  ),
                ),
              )),
        const SizedBox(height: 24),
        _sectionTitle('Teachers (${faculty.length})'),
        if (faculty.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No teachers found.',
                style: TextStyle(color: AppColors.textSecondary)),
          )
        else
          ...faculty.map((f) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  title: Text(
                      f.teacher.fullName.isNotEmpty ? f.teacher.fullName : f.teacher.email,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${state.programCodeFor(f.teacher.programId)} · ${f.classes.length} class(es) this term'),
                  children: f.classes.isEmpty
                      ? const [
                          ListTile(
                            dense: true,
                            title: Text('No classes this term.',
                                style: TextStyle(color: AppColors.textSecondary)),
                          ),
                        ]
                      : f.classes
                          .map((c) => ListTile(
                                dense: true,
                                title: _classTitle(c),
                                subtitle: Text(
                                    '${c.className} · ${state.programCodeFor(c.programId)} · ${c.scheduleSummary}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _scheduleButton(state, c),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: state.isAssigning
                                          ? null
                                          : () => _openAssign(c),
                                      child: const Text('Change'),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                ),
              )),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    );
  }

  Widget _classTitle(ClassModel c) {
    return Row(
      children: [
        Flexible(
          child: Text('${c.subjectCode ?? ''} - ${c.subjectTitle ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        c.isMinor
            ? StatusBadge.info(label: 'Minor')
            : StatusBadge.neutral(label: 'Major'),
      ],
    );
  }
}
