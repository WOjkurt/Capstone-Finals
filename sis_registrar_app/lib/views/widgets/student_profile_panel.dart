import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/clearance_bloc.dart';
import '../../models/grading_models.dart';
import '../../services/current_term.dart';
import '../../theme/app_theme.dart';
import 'activity_log_browser.dart';
import 'credited_subjects_dialog.dart';
import 'edit_lrn_dialog.dart';
import 'edit_year_level_dialog.dart';
import 'initialize_clearance_dialog.dart';
import 'shift_program_dialog.dart';
import 'status_badge.dart';
import 'student_details_tab.dart';
import 'student_evaluation_tab.dart';
import 'student_grades_dialog.dart';
import 'student_study_load_dialog.dart';
import '../../utils/formatters.dart';

/// Everything about one student in one place: a header with their details, and tabs for
/// study load, grades, curriculum evaluation, credits, personal details, grade release (clearance) and history.
class StudentProfilePanel extends StatefulWidget {
  final ClearanceStateData data;

  const StudentProfilePanel({super.key, required this.data});

  @override
  State<StudentProfilePanel> createState() => _StudentProfilePanelState();
}

class _StudentProfilePanelState extends State<StudentProfilePanel>
    with SingleTickerProviderStateMixin, CurrentTermUser {
  static const _tabs = ['Study load', 'Grades', 'Evaluation', 'Credits', 'Details', 'Grade release', 'History'];

  late final TabController _tabController = TabController(length: _tabs.length, vsync: this);
  int? _yearLevel;

  String? get _termId => currentTerm.termId;

  UserSearchResultModel get _student => widget.data.selectedStudent!;

  @override
  void initState() {
    super.initState();
    _yearLevel = _student.yearLevel;
  }

  @override
  void onTermChanged(String termId) => setState(() {});

  @override
  void didUpdateWidget(StudentProfilePanel old) {
    super.didUpdateWidget(old);
    if (old.data.selectedStudent?.userId != _student.userId) {
      _yearLevel = _student.yearLevel;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _editLrn() {
    EditLrnDialog.showForStudent(
      context,
      userId: _student.userId,
      studentName: _student.fullName,
      currentLrn: _student.lrn,
      onSaved: (newLrn) => context.read<ClearanceBloc>().add(StudentLrnUpdatedEvent(_student.userId, newLrn)),
    );
  }

  void _editYearLevel() {
    EditYearLevelDialog.show(
      context,
      userId: _student.userId,
      studentName: _student.fullName,
      currentYearLevel: _yearLevel,
      onSaved: (level) => setState(() => _yearLevel = level),
    );
  }

  Future<void> _shiftProgram() async {
    final bloc = context.read<ClearanceBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await ShiftProgramDialog.show(
      context,
      userId: _student.userId,
      studentName: _student.fullName,
      currentProgramId: _student.programId,
      currentProgramCode: _student.programCode,
    );
    if (result == null) return;
    bloc.add(StudentProgramShiftedEvent(_student.userId, result.programId, result.programCode));
    final open = [
      if (result.inProgressSubjects > 0) '${result.inProgressSubjects} subject(s) still in progress',
      if (result.pendingSubjects > 0) '${result.pendingSubjects} pending subject(s)',
    ];
    messenger.showSnackBar(SnackBar(
      backgroundColor: AppColors.success,
      content: Text('Shifted to ${result.programCode}.'
          '${open.isEmpty ? '' : ' From the old program: ${open.join(' and ')}. Review them on the Study load tab.'}'
          ' Enter the credits on the Credits tab.'),
    ));
    if (mounted) _tabController.animateTo(_tabs.indexOf('Credits'));
  }

  /// Opens the Study load tab on a given term (used by the Grade release rows).
  void _openStudyLoad(String termId) {
    currentTerm.select(termId);
    _tabController.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: TabBar(
              key: const ValueKey('student_tabs'),
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              labelStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w700, fontSize: 13),
              tabs: [for (final t in _tabs) Tab(text: t)],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _padded(_buildStudyLoadTab()),
                _padded(StudentGradesDialog(
                  key: ValueKey('grades_${_student.userId}'),
                  userId: _student.userId,
                  studentName: _student.fullName,
                  lrn: _student.lrn,
                  programCode: _student.programCode,
                  yearLevel: _yearLevel,
                  embedded: true,
                )),
                _padded(StudentEvaluationTab(key: ValueKey('evaluation_${_student.userId}_${_student.programId}'), userId: _student.userId, studentName: _student.fullName)),
                _padded(CreditedSubjectsDialog(
                  key: ValueKey('credits_${_student.userId}_${_student.programId}'),
                  student: _student,
                  embedded: true,
                )),
                _padded(StudentDetailsTab(key: ValueKey('details_${_student.userId}'), userId: _student.userId)),
                _buildGradeReleaseTab(),
                _padded(ActivityLogBrowser(key: ValueKey('history_${_student.userId}'), studentId: _student.userId, pageSize: 25)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _padded(Widget child) => Padding(padding: const EdgeInsets.all(20), child: child);

  Widget _buildHeader() {
    final s = _student;
    Widget chip(IconData icon, String text, {VoidCallback? onEdit, Key? key, Color? color}) => InkWell(
          key: key,
          onTap: onEdit,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color ?? AppColors.textSecondary),
                const SizedBox(width: 5),
                Text(text,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color ?? const Color(0xFF334155))),
                if (onEdit != null) ...[
                  const SizedBox(width: 5),
                  const Icon(Icons.edit_outlined, size: 13, color: AppColors.textMuted),
                ],
              ],
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryLight,
            foregroundColor: AppColors.primary,
            child: Text(
              s.firstname.isNotEmpty ? s.firstname[0].toUpperCase() : 'S',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.fullName.isNotEmpty ? s.fullName : s.email,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(s.email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    s.hasLrn == false || (s.lrn ?? '').isEmpty
                        ? chip(Icons.badge_outlined, 'No LRN', onEdit: _editLrn, key: const ValueKey('profile_lrn'),
                            color: const Color(0xFFB45309))
                        : chip(Icons.badge_outlined, 'LRN ${s.lrn}', onEdit: _editLrn, key: const ValueKey('profile_lrn')),
                    chip(Icons.school_outlined, s.programCode ?? 'No program', onEdit: _shiftProgram, key: const ValueKey('profile_program')),
                    _yearLevel == null
                        ? chip(Icons.stairs_outlined, 'Year not set', onEdit: _editYearLevel,
                            key: const ValueKey('profile_year'), color: AppColors.error)
                        : chip(Icons.stairs_outlined, 'Year $_yearLevel', onEdit: _editYearLevel,
                            key: const ValueKey('profile_year')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyLoadTab() {
    if (_termId == null) {
      return const Center(
        child: Text('No academic term yet. Add one in Setup.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    // Shared with the other pages: changing it here changes it everywhere.
    final Widget termPicker = CurrentTermPicker(term: currentTerm, width: 270);
    return StudentStudyLoadDialog(
      // A new term or student starts a fresh study load view.
      key: ValueKey('load_${_student.userId}_$_termId'),
      student: _student,
      termId: _termId!,
      termLabel: currentTerm.term?.label ?? 'Academic Term',
      embedded: true,
      toolbarLeading: termPicker,
    );
  }

  Widget _buildGradeReleaseTab() {
    final data = widget.data;

    void addTerm() => InitializeClearanceDialog.show(
          context,
          student: _student,
          existingTermIds: data.clearances.map((c) => c.termId).toList(),
          onConfirmed: (termId, isCleared) => context
              .read<ClearanceBloc>()
              .add(InitializeClearanceEvent(termId: termId, isCleared: isCleared)),
        );

    final explanation = Row(
      children: [
        const Expanded(
          child: Text(
            'A released term lets the student see their grades and enroll in the next term.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          key: const ValueKey('add_clearance_term_button'),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add term'),
          onPressed: addTerm,
        ),
      ],
    );

    if (data.isClearanceLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          explanation,
          const SizedBox(height: 14),
          Expanded(
            child: data.clearances.isEmpty
                ? const Center(
                    child: Text('No terms added yet. Use "Add term" to start one.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.separated(
                    itemCount: data.clearances.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final c = data.clearances[i];
                      final toggling = data.togglingTermId == c.termId;
                      final audit = [
                        if (c.clearedByUserName != null) 'by ${c.clearedByUserName}',
                        if (c.clearedAt != null) formatDateTime(c.clearedAt!.toLocal()),
                      ].join(' • ');
                      return Container(
                        key: ValueKey('release_row_${c.termId}'),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.isCleared ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              c.isCleared ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                              color: c.isCleared ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.termLabel ?? 'Academic Term',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      c.isCleared
                                          ? StatusBadge.success(label: 'Released')
                                          : StatusBadge.danger(label: 'On hold'),
                                      if (audit.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(audit,
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => _openStudyLoad(c.termId),
                              child: const Text('Study load'),
                            ),
                            const SizedBox(width: 4),
                            toggling
                                ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2))
                                : Tooltip(
                                    message: c.isCleared ? 'Put grades on hold' : 'Release grades',
                                    child: Switch(
                                      key: ValueKey('release_switch_${c.termId}'),
                                      value: c.isCleared,
                                      activeThumbColor: const Color(0xFF10B981),
                                      onChanged: (val) =>
                                          context.read<ClearanceBloc>().add(ToggleClearanceEvent(c.termId, val)),
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
}
