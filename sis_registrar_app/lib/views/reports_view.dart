import 'package:flutter/material.dart';
import '../injection.dart';
import '../models/setup_models.dart';
import '../repositories/enrollment_repository.dart';
import '../repositories/report_repository.dart';
import '../theme/app_theme.dart';
import '../utils/csv.dart';
import '../utils/error_handler.dart';
import '../utils/file_download.dart';
import 'widgets/page_header.dart';

/// The four term reports. Each tab shows a table and can be downloaded as CSV (opens in Excel).
enum ReportKind { enrollment, classSizes, failed, teacherLoads }

extension on ReportKind {
  String get title => switch (this) {
        ReportKind.enrollment => 'Enrollment',
        ReportKind.classSizes => 'Class sizes',
        ReportKind.failed => 'Failed students',
        ReportKind.teacherLoads => 'Teacher loads',
      };

  String get fileStem => switch (this) {
        ReportKind.enrollment => 'Enrollment_Summary',
        ReportKind.classSizes => 'Class_Sizes',
        ReportKind.failed => 'Failed_Students',
        ReportKind.teacherLoads => 'Teacher_Loads',
      };
}

/// A report ready to show and export: column headers and rows of cells.
class ReportTable {
  final List<String> headers;
  final List<List<Object?>> rows;
  const ReportTable(this.headers, this.rows);
}

String _num(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  List<AcademicTermModel> _terms = [];
  AcademicTermModel? _term;
  ReportKind _kind = ReportKind.enrollment;
  ReportTable? _table;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  String _message(Object e) => e is ApiException ? e.message : e.toString();

  Future<void> _loadTerms() async {
    try {
      final terms = await getIt<AcademicSetupRepository>().getTerms();
      if (!mounted) return;
      setState(() {
        _terms = terms;
        _term = terms.isEmpty ? null : terms.firstWhere((t) => t.isActive, orElse: () => terms.first);
      });
      await _loadReport();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

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
              [r.programCode, r.yearLevel != null ? 'Year ${r.yearLevel}' : '-', r.enrolledStudents, r.pendingOnlyStudents],
            if (rows.isNotEmpty)
              [
                'TOTAL',
                '',
                rows.fold<int>(0, (s, r) => s + r.enrolledStudents),
                rows.fold<int>(0, (s, r) => s + r.pendingOnlyStudents),
              ],
          ],
        );
      case ReportKind.classSizes:
        final rows = await repo.classSizes(termId);
        return ReportTable(
          ['Program', 'Section', 'Subject', 'Title', 'Teacher', 'Enrolled', 'Pending'],
          [
            for (final r in rows)
              [r.programCode, r.className, r.subjectCode, r.subjectTitle, r.teacherName ?? 'Unassigned', r.enrolled, r.pending],
          ],
        );
      case ReportKind.failed:
        final rows = await repo.failedStudents(termId);
        return ReportTable(
          ['Student', 'LRN', 'Program', 'Year', 'Subject', 'Title', 'Section', 'Final grade', 'Teacher'],
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
              [r.teacherName, r.classes, _num(r.units), r.students, r.subjectCodes.join(' ')],
          ],
        );
    }
  }

  void _download() {
    final table = _table;
    final term = _term;
    if (table == null || term == null) return;
    final termPart = term.label.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    try {
      downloadFile(buildCsv(table.headers, table.rows), '${_kind.fileStem}_$termPart.csv', 'text/csv');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not download: ${_message(e)}'),
        backgroundColor: AppColors.error,
      ));
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
            subtitle: 'Term reports for the Registrar and the Dean. Download any report as CSV to open it in Excel.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<String>(
                    key: const ValueKey('report_term_dropdown'),
                    initialValue: _term?.termId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Term', isDense: true, border: OutlineInputBorder()),
                    items: [
                      for (final t in _terms)
                        DropdownMenuItem(value: t.termId, child: Text('${t.label}${t.isActive ? ' (Active)' : ''}')),
                    ],
                    onChanged: (v) {
                      setState(() => _term = _terms.firstWhere((t) => t.termId == v));
                      _loadReport();
                    },
                  ),
                ),
                SegmentedButton<ReportKind>(
                  key: const ValueKey('report_kind_selector'),
                  segments: [
                    for (final k in ReportKind.values) ButtonSegment(value: k, label: Text(k.title)),
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
                  onPressed: (_table == null || _loading || _table!.rows.isEmpty) ? null : _download,
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)));
    }
    if (_terms.isEmpty && !_loading && _table == null) {
      return const Center(child: Text('No academic terms yet.', style: TextStyle(color: AppColors.textSecondary)));
    }
    final table = _table;
    if (_loading || table == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (table.rows.isEmpty) {
      return Center(
        child: Text('Nothing to show for ${_kind.title.toLowerCase()} in this term.',
            style: const TextStyle(color: AppColors.textSecondary)),
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
            key: const ValueKey('report_table'),
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
            columns: [for (final h in table.headers) DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.w700)))],
            rows: [
              for (final r in table.rows)
                DataRow(
                  cells: [
                    for (final c in r)
                      DataCell(Text(
                        '${c ?? ''}',
                        style: TextStyle(fontWeight: r.first == 'TOTAL' ? FontWeight.w700 : FontWeight.normal),
                      )),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
