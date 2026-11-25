import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../injection.dart';
import '../models/activity_log_models.dart';
import '../models/grading_models.dart';
import '../models/report_models.dart';
import '../models/setup_models.dart';
import '../repositories/activity_log_repository.dart';
import '../repositories/enrollment_repository.dart';
import '../repositories/grading_repository.dart';
import '../repositories/report_repository.dart';
import '../services/current_term.dart';
import '../theme/app_theme.dart';
import '../utils/error_handler.dart';
import 'widgets/page_header.dart';
import 'widgets/student_grades_dialog.dart';

/// Everything the Registrar does with grades, in one place.
///
/// These three jobs used to sit in three different parts of the app: releasing a term was a
/// line in a term's "More actions" menu in Setup, the verification state of a sheet could only
/// be read off a printed report, and correcting a mark meant finding the student first. They
/// are one piece of work -- check the sheets, fix what is wrong, then let the term out -- so
/// they are now one page.
///
/// Verifying a sheet is deliberately not here: see the note on the Grade sheets tab.
class GradesView extends StatefulWidget {
  const GradesView({super.key});

  @override
  State<GradesView> createState() => _GradesViewState();
}

class _GradesViewState extends State<GradesView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            title: 'Grades',
            subtitle:
                'Check the sheets behind a term, correct a mark, and release the results to students.',
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(key: ValueKey('grades_sheets_tab'), text: 'Grade sheets'),
                Tab(key: ValueKey('grades_corrections_tab'), text: 'Corrections'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                GradeSheetsTab(),
                GradeCorrectionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grade sheets ─────────────────────────────────────────────────────────────

/// Every class in the term, whether its sheet has been checked, and the one button that
/// lets the whole term out to students.
class GradeSheetsTab extends StatefulWidget {
  const GradeSheetsTab({super.key});

  @override
  State<GradeSheetsTab> createState() => _GradeSheetsTabState();
}

class _GradeSheetsTabState extends State<GradeSheetsTab> with CurrentTermUser {
  static final _day = DateFormat('MMM d, yyyy');

  List<GradeSheet>? _sheets;
  String? _error;
  bool _loading = false;
  bool _releasing = false;

  /// Sheets with a verification call in flight, by class id.
  final _verifying = <String>{};

  /// The term as the server last described it. Release flips a field on the term, and the
  /// shared [CurrentTerm] list is not refetched on every page, so the newer copy wins here.
  AcademicTermModel? _fresher;

  AcademicTermModel? get _term {
    final shared = currentTerm.term;
    if (_fresher != null && _fresher!.termId == shared?.termId) return _fresher;
    return shared;
  }

  int get _unverified => (_sheets ?? const []).where((s) => !s.isVerified).length;

  @override
  void onTermChanged(String termId) {
    _fresher = null;
    _load();
  }

  Future<void> _load() async {
    final termId = currentTerm.termId;
    if (termId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sheets = await getIt<ReportRepository>().gradeSheets(termId);
      if (!mounted) return;
      setState(() {
        _sheets = sheets;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleRelease() async {
    final term = _term;
    if (term == null) return;
    final release = !term.areGradesReleased;
    final unchecked = _unverified;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(release ? 'Release grades?' : 'Withhold grades again?'),
        content: Text(
          release
              ? 'Students will be able to see their grades for ${term.label}.'
                  '${unchecked > 0 ? '\n\n$unchecked of ${_sheets?.length ?? 0} grade sheet(s) have not been verified yet. You can still release.' : ''}'
              : 'Students will stop seeing their grades for ${term.label} until you release them again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm_grades_release'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(release ? 'Release' : 'Withhold'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _releasing = true);
    try {
      final updated =
          await getIt<AcademicSetupRepository>().setGradeRelease(term.termId, release);
      if (!mounted) return;
      setState(() {
        _fresher = updated;
        _releasing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor:
            release && unchecked > 0 ? AppColors.warning : AppColors.success,
        behavior: SnackBarBehavior.floating,
        content: Text(release
            ? unchecked > 0
                ? 'Grades released for ${term.label} — $unchecked sheet(s) had not been verified.'
                : 'Grades released for ${term.label}.'
            : 'Grades withheld for ${term.label}.'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _releasing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        content: Text(e is ApiException ? e.message : e.toString()),
      ));
    }
  }

  /// Records that this sheet was checked, or takes the mark off.
  ///
  /// The office that encodes the marks also checks them, so the rule that matters is not which
  /// office but which person: the server refuses a sheet whose marks the caller entered or
  /// corrected. The button is already hidden in that case; this still shows what it says, in
  /// case the data moved under us.
  Future<void> _toggleVerified(GradeSheet sheet) async {
    setState(() => _verifying.add(sheet.classId));
    try {
      await getIt<ReportRepository>()
          .setGradeSheetVerified(sheet.classId, !sheet.isVerified);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        content: Text(sheet.isVerified
            ? 'Verification taken off ${sheet.subjectCode} ${sheet.className}.'
            : 'Verified ${sheet.subjectCode} ${sheet.className}.'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        content: Text(e is ApiException ? e.message : e.toString()),
      ));
    } finally {
      if (mounted) setState(() => _verifying.remove(sheet.classId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentTerm.isLoaded && currentTerm.terms.isEmpty) {
      return const Center(
        child: Text('No academic terms yet. Add one in Setup.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    if (_loading && _sheets == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final sheets = _sheets ?? const <GradeSheet>[];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _releaseCard(sheets),
          const SizedBox(height: 16),
          _sheetsTable(sheets),
        ],
      ),
    );
  }

  Widget _releaseCard(List<GradeSheet> sheets) {
    final term = _term;
    final released = term?.areGradesReleased ?? false;
    final incomplete = sheets.where((s) => s.isIncomplete).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(released ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
              color: released ? AppColors.success : AppColors.warning, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  released
                      ? 'Students can see their grades for ${term?.label ?? ''}'
                      : 'Grades for ${term?.label ?? ''} are withheld from students',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    '${sheets.length} class${sheets.length == 1 ? '' : 'es'}',
                    '$_unverified not verified',
                    if (incomplete > 0) '$incomplete still missing a final mark',
                    if (released && term?.gradesReleasedAt != null)
                      'released ${_day.format(term!.gradesReleasedAt!.toLocal())}',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (_releasing)
            const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else if (released)
            OutlinedButton.icon(
              key: const ValueKey('grades_release_button'),
              onPressed: _toggleRelease,
              icon: const Icon(Icons.lock_outline_rounded, size: 18),
              label: const Text('Withhold grades'),
            )
          else
            FilledButton.icon(
              key: const ValueKey('grades_release_button'),
              onPressed: _toggleRelease,
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: const Text('Release grades'),
            ),
        ],
      ),
    );
  }

  Widget _sheetsTable(List<GradeSheet> sheets) {
    if (sheets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Text('No classes in this term.',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Grade sheets',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ),
                IconButton(
                  key: const ValueKey('grade_sheets_refresh'),
                  tooltip: 'Refresh',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          // The rule is not which office checks the sheet, it is which person: whoever typed
          // the marks is not the one who certifies them. Since every mark at DBTC is encoded
          // in this office, the second pass happens here too -- by somebody else at this desk.
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'A sheet is verified by somebody other than whoever entered the marks — another '
              'member of this office, the Program Head for that programme, or the College Head. '
              'Sheets you entered or corrected yourself are marked as your own work.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.borderSubtle),
              columns: const [
                DataColumn(label: Text('Subject')),
                DataColumn(label: Text('Class')),
                DataColumn(label: Text('Instructor')),
                DataColumn(label: Text('Passed'), numeric: true),
                DataColumn(label: Text('Failed'), numeric: true),
                DataColumn(label: Text('No final yet'), numeric: true),
                DataColumn(label: Text('Verified')),
              ],
              rows: [
                for (final s in sheets)
                  DataRow(
                    key: ValueKey('grade_sheet_row_${s.classId}'),
                    cells: [
                      DataCell(Text(s.subjectCode,
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(s.className,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      )),
                      DataCell(Text(
                        s.teacherName?.isNotEmpty == true ? s.teacherName! : 'No teacher',
                        style: TextStyle(
                            color: s.teacherName?.isNotEmpty == true
                                ? AppColors.textPrimary
                                : AppColors.textMuted),
                      )),
                      DataCell(Text('${s.passed}')),
                      DataCell(Text('${s.failed}')),
                      DataCell(Text(
                        '${s.noFinalYet}',
                        style: TextStyle(
                            color: s.noFinalYet > 0
                                ? AppColors.warning
                                : AppColors.textSecondary,
                            fontWeight:
                                s.noFinalYet > 0 ? FontWeight.w700 : FontWeight.w400),
                      )),
                      DataCell(_verifiedCell(s)),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _verifiedCell(GradeSheet s) {
    if (_verifying.contains(s.classId)) {
      return const SizedBox(
          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (s.isVerified) {
      final who = s.verifiedByName?.isNotEmpty == true ? s.verifiedByName! : 'somebody';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Verified by $who on ${_day.format(s.verifiedAt!.toLocal())}',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded, size: 15, color: AppColors.success),
                const SizedBox(width: 6),
                Text(_day.format(s.verifiedAt!.toLocal()),
                    style: const TextStyle(color: AppColors.accentGreenDark)),
              ],
            ),
          ),
          // Undoing somebody else's check is allowed; undoing it on your own work is not,
          // or the rule would be one click away from nothing: unverify, then verify.
          if (!s.encodedByCaller)
            IconButton(
              key: ValueKey('unverify_sheet_${s.classId}'),
              icon: const Icon(Icons.close_rounded, size: 14),
              tooltip: 'Take the verification off',
              color: AppColors.textMuted,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 6),
              onPressed: () => _toggleVerified(s),
            ),
        ],
      );
    }

    if (s.encodedByCaller) {
      return Tooltip(
        key: ValueKey('own_work_${s.classId}'),
        message: 'You entered or corrected these marks, so somebody else has to verify '
            'this sheet.',
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline_rounded, size: 15, color: AppColors.textMuted),
            SizedBox(width: 6),
            Text('Your own work', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return TextButton.icon(
      key: ValueKey('verify_sheet_${s.classId}'),
      onPressed: () => _toggleVerified(s),
      icon: const Icon(Icons.check_rounded, size: 16),
      label: const Text('Verify'),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}

// ── Corrections ──────────────────────────────────────────────────────────────

/// Correcting a recorded mark, and the record of every correction already made.
///
/// The student's own Grades window is where a mark is actually changed; this is a way into it
/// that starts from the grade rather than from the student, which is how the work arrives.
class GradeCorrectionsTab extends StatefulWidget {
  const GradeCorrectionsTab({super.key});

  @override
  State<GradeCorrectionsTab> createState() => _GradeCorrectionsTabState();
}

class _GradeCorrectionsTabState extends State<GradeCorrectionsTab> {
  static final _stamp = DateFormat('MMM d, yyyy h:mm a');

  final _search = TextEditingController();
  List<UserSearchResultModel> _results = const [];
  bool _searching = false;
  String? _searchError;

  List<ActivityLogEntry>? _history;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _history = null;
      _historyError = null;
    });
    try {
      final page = await getIt<ActivityLogRepository>()
          .search(action: 'GRADE_MODIFIED', pageSize: 25);
      if (!mounted) return;
      setState(() => _history = page.items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _historyError = e is ApiException ? e.message : e.toString());
    }
  }

  Future<void> _runSearch() async {
    final q = _search.text.trim();
    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final found = await getIt<UserSearchRepository>().search(query: q, role: 5);
      if (!mounted) return;
      setState(() {
        _results = found.take(25).toList();
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = e is ApiException ? e.message : e.toString();
      });
    }
  }

  Future<void> _openGrades(UserSearchResultModel s) async {
    await StudentGradesDialog.show(context, userId: s.userId, studentName: s.fullName);
    if (mounted) _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _card(
            title: 'Correct a grade',
            help: 'Find the student, open their grades, and use the pencil on the mark. '
                'A reason is required, and the change is kept on the record.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('grades_student_search'),
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _runSearch(),
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.search_rounded, size: 20),
                          hintText: 'Student name, student ID or email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      key: const ValueKey('grades_student_search_button'),
                      onPressed: _searching ? null : _runSearch,
                      child: const Text('Search'),
                    ),
                  ],
                ),
                if (_searching) ...[
                  const SizedBox(height: 16),
                  const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                ],
                if (_searchError != null) ...[
                  const SizedBox(height: 12),
                  Text(_searchError!, style: const TextStyle(color: AppColors.error)),
                ],
                if (!_searching && _results.isEmpty && _search.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('No student matched that.',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
                for (final s in _results) ...[
                  const Divider(height: 20, color: AppColors.borderSubtle),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.fullName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            Text(
                              [
                                if (s.studentId?.isNotEmpty == true) s.studentId!,
                                if (s.programCode?.isNotEmpty == true) s.programCode!,
                                if (s.yearLevel != null) 'Year ${s.yearLevel}',
                              ].join(' · '),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        key: ValueKey('open_student_grades_${s.userId}'),
                        onPressed: () => _openGrades(s),
                        icon: const Icon(Icons.fact_check_outlined, size: 18),
                        label: const Text('Open grades'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            title: 'Corrections already made',
            help: 'The last 25 changes to a recorded mark, newest first. '
                'The full history is in Reports → Activity log.',
            action: IconButton(
              key: const ValueKey('grade_corrections_refresh'),
              tooltip: 'Refresh',
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              color: AppColors.textSecondary,
            ),
            child: _historyBody(),
          ),
        ],
      ),
    );
  }

  Widget _historyBody() {
    if (_historyError != null) {
      return Text(_historyError!, style: const TextStyle(color: AppColors.error));
    }
    if (_history == null) {
      return const Center(
          child: SizedBox(
              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_history!.isEmpty) {
      return const Text('No grade has been corrected yet.',
          style: TextStyle(color: AppColors.textSecondary));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in _history!) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.edit_note_rounded, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.summary,
                          style: const TextStyle(color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          _stamp.format(e.occurredAt),
                          if (e.actorName.isNotEmpty) e.actorName,
                          if (e.termLabel?.isNotEmpty == true) e.termLabel!,
                        ].join(' · '),
                        style:
                            const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (e != _history!.last)
            const Divider(height: 1, color: AppColors.borderSubtle),
        ],
      ],
    );
  }

  Widget _card({
    required String title,
    String? help,
    Widget? action,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    if (help != null) ...[
                      const SizedBox(height: 4),
                      Text(help,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
