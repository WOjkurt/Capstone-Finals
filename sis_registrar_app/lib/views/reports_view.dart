import 'package:flutter/material.dart';
import '../injection.dart';
import '../models/report_models.dart';
import '../utils/formatters.dart';
import '../repositories/student_record_repository.dart';
import '../models/record_models.dart';
import '../models/setup_models.dart';
import '../services/current_term.dart';
import '../repositories/report_repository.dart';
import '../theme/app_theme.dart';
import '../utils/csv.dart';
import '../utils/error_handler.dart';
import '../utils/file_download.dart';
import '../utils/report_pdf.dart';
import '../utils/study_load_pdf.dart' show loadSchoolLogo, printPdf;
import 'widgets/activity_log_browser.dart';
import 'widgets/graduation_candidates_report.dart';
import 'widgets/missing_sex_dialog.dart';
import 'widgets/page_header.dart';

/// The four term reports. Each tab shows a table and can be downloaded as CSV (opens in Excel).
enum ReportKind { enrollment, statistics, classSizes, failed, deansList, teacherLoads }

extension on ReportKind {
  String get title => switch (this) {
    ReportKind.enrollment => 'Enrollment',
    ReportKind.statistics => 'Statistics',
    ReportKind.classSizes => 'Class sizes',
    ReportKind.failed => 'Failed students',
    ReportKind.deansList => 'Dean\'s list',
    ReportKind.teacherLoads => 'Teacher loads',
  };

  String get fileStem => switch (this) {
    ReportKind.enrollment => 'Enrollment_Summary',
    ReportKind.statistics => 'Enrollment_Statistics',
    ReportKind.classSizes => 'Class_Sizes',
    ReportKind.failed => 'Failed_Students',
    ReportKind.deansList => 'Deans_List',
    ReportKind.teacherLoads => 'Teacher_Loads',
  };
}

/// A report ready to show and export: column headers and rows of cells, and an optional note under it.
class ReportTable {
  final List<String> headers;
  final List<List<Object?>> rows;
  final String? note;

  /// Enrolled students with no sex on record (Statistics); offers the "Fill in missing sex" list.
  final int missingSex;
  const ReportTable(this.headers, this.rows, {this.note, this.missingSex = 0});
}

String _num(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

class ReportsView extends StatefulWidget {
  static const termReportsTab = 0;
  static const transfereesTab = 1;
  static const irregularTab = 2;
  static const activityLogTab = 3;
  static const graduationTab = 4;

  /// Which tab is showing (see the constants above); links elsewhere in the app can change it.
  final ValueNotifier<int>? tab;

  const ReportsView({super.key, this.tab});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView>
    with CurrentTermUser, SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 5,
    vsync: this,
    initialIndex: widget.tab?.value ?? 0,
  );
  ReportKind _kind = ReportKind.enrollment;

  // Dean's list rules, DBTC's by default; the Registrar can change them here.
  final _maxGwa = TextEditingController(text: '1.7');
  final _minUnits = TextEditingController(text: '15');
  final _worstGrade = TextEditingController(text: '2.3');
  String? _deansRules;

  @override
  void initState() {
    super.initState();
    widget.tab?.addListener(_followLink);
  }

  void _followLink() => _tabs.animateTo(widget.tab!.value);

  @override
  void dispose() {
    widget.tab?.removeListener(_followLink);
    _tabs.dispose();
    for (final c in [_maxGwa, _minUnits, _worstGrade]) {
      c.dispose();
    }
    super.dispose();
  }

  ReportTable? _table;
  bool _loading = false;
  String? _error;

  AcademicTermModel? get _term => currentTerm.term;

  @override
  void onTermChanged(String termId) => _loadReport();

  String _message(Object e) => e is ApiException ? e.message : e.toString();

  Future<void> _loadReport() async {
    final term = _term;
    if (term == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final table = await _fetch(_kind, term.termId);
      if (mounted) {
        setState(() {
          _table = table;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _message(e);
          _loading = false;
        });
      }
    }
  }

  Future<ReportTable> _fetch(ReportKind kind, String termId) async {
    final repo = getIt<ReportRepository>();
    switch (kind) {
      case ReportKind.enrollment:
        final rows = await repo.enrollmentSummary(termId);
        return ReportTable(
          ['Program', 'Year level', 'Enrolled students', 'Pending only'],
          [
            for (final r in rows)
              [
                r.programCode,
                r.yearLevel != null ? 'Year ${r.yearLevel}' : '-',
                r.enrolledStudents,
                r.pendingOnlyStudents,
              ],
            if (rows.isNotEmpty)
              [
                'TOTAL',
                '',
                rows.fold<int>(0, (s, r) => s + r.enrolledStudents),
                rows.fold<int>(0, (s, r) => s + r.pendingOnlyStudents),
              ],
          ],
        );
      case ReportKind.statistics:
        final rows = await repo.enrollmentStatistics(termId);
        List<Object?> cells(String program, List<int> m, List<int> f) {
          final tm = m.fold(0, (a, b) => a + b),
              tf = f.fold(0, (a, b) => a + b);
          return [
            program,
            for (var i = 0; i < 4; i++) ...[m[i], f[i]],
            tm,
            tf,
            tm + tf,
          ];
        }
        List<int> sum(List<int> Function(EnrollmentStatisticsRow) pick) => [
          for (var i = 0; i < 4; i++) rows.fold(0, (a, r) => a + pick(r)[i]),
        ];
        final noSex = rows.fold(0, (a, r) => a + r.sexNotRecorded);
        final noYear = rows.fold(0, (a, r) => a + r.yearNotRecorded);
        return ReportTable(
          [
            'Program',
            '1st Year M',
            '1st Year F',
            '2nd Year M',
            '2nd Year F',
            '3rd Year M',
            '3rd Year F',
            '4th Year M',
            '4th Year F',
            'Total M',
            'Total F',
            'Total',
          ],
          [
            for (final r in rows) cells(r.programCode, r.male, r.female),
            if (rows.isNotEmpty)
              cells('TOTAL', sum((r) => r.male), sum((r) => r.female)),
          ],
          missingSex: noSex,
          note: noSex + noYear == 0
              ? null
              : '${[
                  if (noSex > 0) '$noSex enrolled student(s) have no sex on record',
                  if (noYear > 0) '$noYear have no year level',
                ].join('; ')} and are not counted above. Fill in Sex on the student\'s Details tab, or set the year level.',
        );
      case ReportKind.classSizes:
        final rows = await repo.classSizes(termId);
        return ReportTable(
          [
            'Program',
            'Section',
            'Subject',
            'Title',
            'Teacher',
            'Enrolled',
            'Pending',
          ],
          [
            for (final r in rows)
              [
                r.programCode,
                r.className,
                r.subjectCode,
                r.subjectTitle,
                r.teacherName ?? 'Unassigned',
                r.enrolled,
                r.pending,
              ],
          ],
        );
      case ReportKind.failed:
        final rows = await repo.failedStudents(termId);
        return ReportTable(
          [
            'Student',
            'LRN',
            'Program',
            'Year',
            'Subject',
            'Title',
            'Section',
            'Final grade',
            'Teacher',
          ],
          [
            for (final r in rows)
              [
                r.studentName,
                r.lrn ?? '',
                r.programCode ?? '',
                r.yearLevel ?? '',
                r.subjectCode,
                r.subjectTitle,
                r.className,
                r.finalGrade?.toStringAsFixed(2) ?? '',
                r.teacherName ?? '',
              ],
          ],
        );
      case ReportKind.deansList:
        double? read(TextEditingController c) => double.tryParse(c.text.trim());
        final list = await repo.deansList(termId, maxGwa: read(_maxGwa), minUnits: read(_minUnits), worstGrade: read(_worstGrade));
        _deansRules = list.rules;
        return ReportTable(
          ['Rank', 'Student', 'Student ID', 'Program', 'Year', 'Units', 'GWA', 'Lowest grade'],
          [
            for (final r in list.rows)
              [
                r.rank,
                r.studentName,
                r.studentId ?? '',
                r.programCode ?? '',
                r.yearLevel ?? '',
                _num(r.units),
                r.gwa.toStringAsFixed(2),
                r.lowestGrade.toStringAsFixed(2),
              ],
          ],
          note: 'Rules: ${list.rules}. Every subject counts in the GWA, NSTP and PE included.'
              '${list.studentsWithMissingGrades > 0 ? ' ${list.studentsWithMissingGrades} student(s) still have a subject without a final grade and are not checked yet, so this list is not final.' : ''}',
        );
      case ReportKind.teacherLoads:
        final rows = await repo.teacherLoads(termId);
        return ReportTable(
          ['Teacher', 'Classes', 'Units', 'Enrolled students', 'Subjects'],
          [
            for (final r in rows)
              [
                r.teacherName,
                r.classes,
                _num(r.units),
                r.students,
                r.subjectCodes.join(' '),
              ],
          ],
        );
    }
  }

  /// The term report as a printout; wide reports print sideways.
  Future<void> _print() async {
    final table = _table;
    final term = _term;
    if (table == null || term == null) return;
    try {
      final bytes = _kind == ReportKind.statistics
          ? await buildEnrollmentStatisticsPdf(
              termLabel: term.label,
              rows: table.rows,
              note: table.note,
              logo: await loadSchoolLogo(),
            )
          : await buildReportPdf(
              title: _kind.title,
              subtitle: _kind == ReportKind.deansList && _deansRules != null ? '${term.label} - ${_deansRules!}' : term.label,
              headers: table.headers,
              rows: table.rows,
              landscape: table.headers.length > 6,
              logo: await loadSchoolLogo(),
            );
      await printPdf(
        bytes,
        '${_kind.fileStem}_${term.label.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not print: ${_message(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _download() {
    final table = _table;
    final term = _term;
    if (table == null || term == null) return;
    final termPart = term.label.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    try {
      downloadFile(
        buildCsv(table.headers, table.rows),
        '${_kind.fileStem}_$termPart.csv',
        'text/csv',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not download: ${_message(e)}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            title: 'Reports',
            subtitle:
                'Term reports and the transferee list (print, or download as CSV for Excel), and the log of who did what.',
          ),
          Container(
            color: Colors.white,
            child: TabBar(
              key: const ValueKey('reports_tabs'),
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              labelStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Term reports'),
                Tab(text: 'Transferees'),
                Tab(text: 'Irregular students'),
                Tab(text: 'Activity log'),
                Tab(text: 'Graduation'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Shared with the other pages: changing it here changes it everywhere.
                          if (currentTerm.terms.isNotEmpty)
                            CurrentTermPicker(term: currentTerm, width: 280),
                          SegmentedButton<ReportKind>(
                            key: const ValueKey('report_kind_selector'),
                            segments: [
                              for (final k in ReportKind.values)
                                ButtonSegment(value: k, label: Text(k.title)),
                            ],
                            selected: {_kind},
                            onSelectionChanged: (s) {
                              setState(() => _kind = s.first);
                              _loadReport();
                            },
                          ),
                          if (_kind == ReportKind.deansList) ...[
                            _ruleField('deans_max_gwa', _maxGwa, 'GWA at most'),
                            _ruleField('deans_min_units', _minUnits, 'Units at least'),
                            _ruleField('deans_worst_grade', _worstGrade, 'No grade below'),
                            TextButton(
                              key: const ValueKey('deans_apply'),
                              onPressed: _loading ? null : _loadReport,
                              child: const Text('Apply'),
                            ),
                          ],
                          OutlinedButton.icon(
                            key: const ValueKey('download_csv_button'),
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('Download CSV'),
                            onPressed:
                                (_table == null ||
                                    _loading ||
                                    _table!.rows.isEmpty)
                                ? null
                                : _download,
                          ),
                          OutlinedButton.icon(
                            key: const ValueKey('print_report_button'),
                            icon: const Icon(Icons.print_outlined, size: 18),
                            label: const Text('Print'),
                            onPressed:
                                (_table == null ||
                                    _loading ||
                                    _table!.rows.isEmpty)
                                ? null
                                : _print,
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _buildBody()),
                  ],
                ),
                const TransfereesReport(),
                const IrregularStudentsReport(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: ActivityLogBrowser(),
                ),
                const GraduationCandidatesReport(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruleField(String key, TextEditingController c, String label) => SizedBox(
        width: 120,
        child: TextField(
          key: ValueKey(key),
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (_) => _loadReport(),
          decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        ),
      );

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: AppColors.error)),
      );
    }
    if (currentTerm.isLoaded && currentTerm.terms.isEmpty) {
      return const Center(
        child: Text(
          'No academic terms yet.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    final table = _table;
    if (_loading || table == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (table.rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Nothing to show for ${_kind.title.toLowerCase()} in this term.'
            '${_kind == ReportKind.deansList && table.note != null ? '\n\n${table.note}' : ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (table.note != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      table.note!,
                      key: const ValueKey('report_note'),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
                  if (table.missingSex > 0 && _term != null)
                    TextButton.icon(
                      key: const ValueKey('fill_missing_sex_button'),
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: Text('Fill in missing sex (${table.missingSex})'),
                      onPressed: () async {
                        final term = _term!;
                        final changed = await MissingSexDialog.show(context, termId: term.termId, termLabel: term.label);
                        if (changed == true) _loadReport();
                      },
                    ),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                key: const ValueKey('report_table'),
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF8FAFC),
                ),
                columns: [
                  for (final h in table.headers)
                    DataColumn(
                      label: Text(
                        h,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
                rows: [
                  for (final r in table.rows)
                    DataRow(
                      cells: [
                        for (final c in r)
                          DataCell(
                            Text(
                              '${c ?? ''}',
                              style: TextStyle(
                                fontWeight: r.first == 'TOTAL'
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Every transferee (or student with credits from another school), with where they came from
/// and what was credited. Not tied to a term.
class TransfereesReport extends StatefulWidget {
  const TransfereesReport({super.key});

  @override
  State<TransfereesReport> createState() => _TransfereesReportState();
}

class _TransfereesReportState extends State<TransfereesReport> {
  List<TransfereeRow>? _rows;
  String? _error;

  static const _headers = [
    'Student',
    'LRN',
    'Program',
    'Year',
    'Previous school(s)',
    'Credited subjects',
    'Credited units',
    'Subjects',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _message(Object e) => e is ApiException ? e.message : e.toString();

  Future<void> _load() async {
    setState(() {
      _rows = null;
      _error = null;
    });
    try {
      final rows = await getIt<ReportRepository>().transferees();
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  List<List<Object?>> get _cells => [
    for (final r in _rows ?? const <TransfereeRow>[])
      [
        r.studentName,
        r.lrn ?? '',
        r.programCode ?? '',
        r.yearLevel != null ? 'Year ${r.yearLevel}' : '',
        r.previousSchools.isEmpty
            ? 'Not recorded'
            : r.previousSchools.join('; '),
        r.creditedSubjects,
        _num(r.creditedUnits),
        r.creditedCodes.join(' '),
      ],
  ];

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), backgroundColor: AppColors.error),
  );

  void _download() {
    try {
      downloadFile(buildCsv(_headers, _cells), 'Transferees.csv', 'text/csv');
    } catch (e) {
      _snack('Could not download: ${_message(e)}');
    }
  }

  Future<void> _print() async {
    try {
      final bytes = await buildReportPdf(
        title: 'Transferee list',
        subtitle:
            'Students from other schools and the subjects credited to them',
        headers: _headers,
        rows: _cells,
        landscape: true,
        logo: await loadSchoolLogo(),
      );
      await printPdf(bytes, 'Transferees.pdf');
    } catch (e) {
      if (mounted) _snack('Could not print: ${_message(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final empty = rows == null || rows.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Transferees and students with credits from other schools.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              OutlinedButton.icon(
                key: const ValueKey('download_transferees_csv'),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download CSV'),
                onPressed: empty ? null : _download,
              ),
              OutlinedButton.icon(
                key: const ValueKey('print_transferees_button'),
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Print'),
                onPressed: empty ? null : _print,
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: _load,
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: AppColors.error)),
      );
    }
    final rows = _rows;
    if (rows == null) return const Center(child: CircularProgressIndicator());
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'No transferees yet. Students marked as transferees, or with credits from another school, show here.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            key: const ValueKey('transferees_table'),
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: [
              for (final h in _headers)
                DataColumn(
                  label: Text(
                    h,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
            rows: [
              for (final r in _cells)
                DataRow(
                  cells: [for (final c in r) DataCell(Text('${c ?? ''}'))],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Irregular students and their progress back to regular (6 units of back major subjects passed).
/// Students who reached it are listed first with a "Mark regular" button.
class IrregularStudentsReport extends StatefulWidget {
  const IrregularStudentsReport({super.key});

  @override
  State<IrregularStudentsReport> createState() => _IrregularStudentsReportState();
}

class _IrregularStudentsReportState extends State<IrregularStudentsReport> {
  List<IrregularStudent>? _rows;
  String? _error;
  final Set<String> _saving = {};

  static String _units(double u) => u.toStringAsFixed(u % 1 == 0 ? 0 : 1);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _rows = null;
      _error = null;
    });
    try {
      final rows = await getIt<StudentRecordRepository>().irregularStudents();
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : e.toString());
    }
  }

  Future<void> _markRegular(IrregularStudent r) async {
    setState(() => _saving.add(r.userId));
    try {
      await getIt<StudentRecordRepository>().setStanding(r.userId, isRegular: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${r.studentName} is now regular.'), backgroundColor: AppColors.success),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException ? e.message : e.toString()),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(r.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final ready = rows?.where((r) => r.readyToBeRegular).length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  rows == null
                      ? 'An irregular student becomes regular again after passing 6 units of back major subjects.'
                      : '${rows.length} irregular student(s)${ready > 0 ? ', $ready ready to be regular again' : ''}. '
                          'Back major subjects are majors the student had failed or dropped.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _load),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)));
    }
    final rows = _rows;
    if (rows == null) return const Center(child: CircularProgressIndicator());
    if (rows.isEmpty) {
      return const Center(
        child: Text('No irregular students. Mark a student irregular from their Evaluation tab.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final r = rows[i];
        return Container(
          key: ValueKey('irregular_${r.userId}'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: r.readyToBeRegular ? const Color(0xFFF0FDF4) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: r.readyToBeRegular ? const Color(0xFFBBF7D0) : AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.studentName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(
                      [
                        if (r.programCode != null) r.programCode!,
                        if (r.yearLevel != null) 'Year ${r.yearLevel}',
                        if (r.irregularSince != null) 'irregular since ${formatDate(r.irregularSince!)}',
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_units(r.backMajorUnitsPassed)} of 6 back major units',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: (r.backMajorUnitsPassed / 6).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      color: r.readyToBeRegular ? AppColors.accentGreen : AppColors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 130,
                child: r.readyToBeRegular
                    ? FilledButton(
                        key: ValueKey('mark_regular_${r.userId}'),
                        onPressed: _saving.contains(r.userId) ? null : () => _markRegular(r),
                        child: const Text('Mark regular'),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}
