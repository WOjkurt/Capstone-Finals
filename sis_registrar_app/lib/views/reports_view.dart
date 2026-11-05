import 'package:flutter/material.dart';
import '../injection.dart';
import '../models/report_models.dart';
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
import 'widgets/missing_sex_dialog.dart';
import 'widgets/page_header.dart';

/// The four term reports. Each tab shows a table and can be downloaded as CSV (opens in Excel).
enum ReportKind { enrollment, statistics, classSizes, failed, teacherLoads }

extension on ReportKind {
  String get title => switch (this) {
    ReportKind.enrollment => 'Enrollment',
    ReportKind.statistics => 'Statistics',
    ReportKind.classSizes => 'Class sizes',
    ReportKind.failed => 'Failed students',
    ReportKind.teacherLoads => 'Teacher loads',
  };

  String get fileStem => switch (this) {
    ReportKind.enrollment => 'Enrollment_Summary',
    ReportKind.statistics => 'Enrollment_Statistics',
    ReportKind.classSizes => 'Class_Sizes',
    ReportKind.failed => 'Failed_Students',
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
  static const activityLogTab = 2;

  /// Which tab is showing (see the constants above); links elsewhere in the app can change it.
  final ValueNotifier<int>? tab;

  const ReportsView({super.key, this.tab});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView>
    with CurrentTermUser, SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 3,
    vsync: this,
    initialIndex: widget.tab?.value ?? 0,
  );
  ReportKind _kind = ReportKind.enrollment;

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
              subtitle: term.label,
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
                Tab(text: 'Activity log'),
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
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: ActivityLogBrowser(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
        child: Text(
          'Nothing to show for ${_kind.title.toLowerCase()} in this term.',
          style: const TextStyle(color: AppColors.textSecondary),
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
