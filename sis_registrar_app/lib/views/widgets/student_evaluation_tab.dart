import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../injection.dart';
import '../../models/record_models.dart';
import '../../repositories/student_record_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/numbers.dart';
import '../../utils/student_record_pdf.dart';
import '../../utils/study_load_pdf.dart' show loadSchoolLogo, printPdf;
import 'record_table.dart';
import 'standing_card.dart';

/// The student's curriculum checklist: every subject of their program, what is done and what is left.
class StudentEvaluationTab extends StatefulWidget {
  final String userId;

  /// Used on the printout if the record has no name.
  final String studentName;

  const StudentEvaluationTab({super.key, required this.userId, this.studentName = ''});

  @override
  State<StudentEvaluationTab> createState() => _StudentEvaluationTabState();
}

class _StudentEvaluationTabState extends State<StudentEvaluationTab> {
  StudentEvaluation? _data;
  String? _error;
  bool _leftOnly = false;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _data = null;
      _error = null;
    });
    try {
      final data = await getIt<StudentRecordRepository>().evaluation(widget.userId);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : e.toString());
    }
  }

  /// Prints the whole checklist (the "Left to take only" filter does not apply to the printout).
  Future<void> _print(StudentEvaluation data) async {
    setState(() => _printing = true);
    final name = data.fullName.isNotEmpty ? data.fullName : widget.studentName;
    try {
      final bytes = await buildEvaluationPdf(
        data,
        student: RecordStudentInfo(
          name: name,
          lrn: data.lrn,
          programCode: data.programCode,
          programName: data.programName,
          yearLevel: data.yearLevel,
        ),
        logo: await loadSchoolLogo(),
      );
      await printPdf(bytes, 'Evaluation_${name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf');
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

  static String _units(double u) => unitsText(u);

  /// How much of the screen the summary is allowed to take.
  ///
  /// The Registrar's complaint was that the checklist -- the part she actually reads -- was a
  /// sliver at the bottom while the standing and summary cards filled the screen. Collapsing
  /// folds both into a single line and hands the rest to the table. It stays collapsed per
  /// session once she chooses, because she reopens this tab all day.
  bool _summaryCollapsed = false;

  /// Ctrl + scroll zoom, for reading a dense table without changing the browser's own zoom.
  double _zoom = 1.0;
  static const _minZoom = 0.8;
  static const _maxZoom = 2.0;

  void _zoomBy(double delta) =>
      setState(() => _zoom = (_zoom + delta).clamp(_minZoom, _maxZoom));

  static const _columns = [
    RecordColumn('Course Code', 1.1),
    RecordColumn('Descriptive Title', 2.5),
    RecordColumn('Lecture Hours', 1.05, center: true),
    RecordColumn('Lab Hours', .85, center: true),
    RecordColumn('Credit', .95, center: true),
    RecordColumn('Pre-requisite', 1.25),
    RecordColumn('Co-requisite', 1.2),
    RecordColumn('Grade', .95, center: true),
    RecordColumn('Remarks', 1.15),
    RecordColumn('Term Taken', 1.5),
  ];

  static Color _rowColor(String status) => switch (status) {
        'Passed' || 'Credited' || 'CrossEnrolled' => RecordColors.taken,
        'InProgress' => RecordColors.inProgress,
        'PartiallyCredited' => RecordColors.partial,
        'Failed' => RecordColors.failed,
        'Dropped' || 'Withdrawn' => RecordColors.droppedOrWithdrawn,
        _ => RecordColors.notTaken,
      };

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final data = _data;
    if (data == null) return const Center(child: CircularProgressIndicator());
    if (data.subjects.isEmpty) {
      return Center(
        child: Text('No curriculum subjects found for ${data.programCode}.',
            style: const TextStyle(color: AppColors.textSecondary)),
      );
    }

    final shown = _leftOnly ? data.subjects.where((s) => !s.isDone).toList() : data.subjects;
    final groups = <String, List<EvaluationSubject>>{};
    for (final s in shown) {
      groups.putIfAbsent(curriculumSectionTitle(s.yearLevel, s.semester), () => []).add(s);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_summaryCollapsed)
          _buildCollapsedSummary(data)
        else ...[
          StandingCard(key: ValueKey('standing_${widget.userId}'), userId: widget.userId),
          _buildSummary(data),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            FilterChip(
              key: const ValueKey('evaluation_left_only'),
              label: const Text('Left to take only'),
              selected: _leftOnly,
              onSelected: (v) => setState(() => _leftOnly = v),
            ),
            const Spacer(),
            _zoomControls(),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              key: const ValueKey('print_evaluation_button'),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Print'),
              onPressed: _printing ? null : () => _print(data),
            ),
            const SizedBox(width: 4),
            IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: shown.isEmpty
              ? const Center(
                  child: Text('All curriculum subjects are passed or credited.',
                      style: TextStyle(color: AppColors.textSecondary)))
              // Ctrl + wheel zooms the checklist rather than the whole page, so the summary
              // and the menu stay put while the table gets bigger.
              : Listener(
                  onPointerSignal: (event) {
                    if (event is! PointerScrollEvent) return;
                    if (!HardwareKeyboard.instance.isControlPressed &&
                        !HardwareKeyboard.instance.isMetaPressed) {
                      return;
                    }
                    _zoomBy(event.scrollDelta.dy > 0 ? -0.1 : 0.1);
                  },
                  child: MediaQuery.withClampedTextScaling(
                    minScaleFactor: _zoom,
                    maxScaleFactor: _zoom,
                    child: ListView(
                      children: [
                        const RecordLegend(items: {
                          'Taken': RecordColors.taken,
                          'In progress': RecordColors.inProgress,
                          'Partly credited': RecordColors.partial,
                          'Not yet taken': RecordColors.notTaken,
                          'Dropped or withdrawn': RecordColors.droppedOrWithdrawn,
                          'Failed': RecordColors.failed,
                        }),
                        for (final g in groups.entries) ...[
                          // The year/semester heading reads as a band rather than small blue
                          // text, so the eye can find where one block ends and the next starts.
                          Container(
                            margin: const EdgeInsets.only(top: 12, bottom: 4),
                            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(g.key,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                    letterSpacing: .2)),
                          ),
                          RecordTable(
                            minWidth: 740,
                            columns: _columns,
                            rows: [
                              for (final s in g.value)
                                RecordRow(evaluationCells(s),
                                    color: _rowColor(s.status), key: ValueKey('evaluation_row_${s.subjectCode}')),
                            ],
                            totals: evaluationTotals(g.value),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _zoomControls() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const ValueKey('evaluation_zoom_out'),
            tooltip: 'Smaller (Ctrl and scroll down)',
            icon: const Icon(Icons.zoom_out, size: 20),
            onPressed: _zoom <= _minZoom ? null : () => _zoomBy(-0.1),
          ),
          SizedBox(
            width: 42,
            child: Text('${(_zoom * 100).round()}%',
                key: const ValueKey('evaluation_zoom_level'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          IconButton(
            key: const ValueKey('evaluation_zoom_in'),
            tooltip: 'Bigger (Ctrl and scroll up)',
            icon: const Icon(Icons.zoom_in, size: 20),
            onPressed: _zoom >= _maxZoom ? null : () => _zoomBy(0.1),
          ),
        ],
      );

  /// The summary folded to one line, so the checklist gets the screen.
  Widget _buildCollapsedSummary(StudentEvaluation d) => InkWell(
        key: const ValueKey('evaluation_summary_collapsed'),
        onTap: () => setState(() => _summaryCollapsed = false),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.scaffoldBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Text('${_units(d.earnedUnits)} of ${_units(d.totalUnits)} units',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accentGreenDark)),
              const SizedBox(width: 10),
              Text('${_units(d.remainingUnits)} left',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              const Icon(Icons.expand_more, size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      );

  Widget _buildSummary(StudentEvaluation d) {
    final progress = d.totalUnits == 0 ? 0.0 : (d.earnedUnits / d.totalUnits).clamp(0.0, 1.0);
    // The numbers sit on one line with their labels beside them rather than stacked under
    // headline figures. Same information, roughly half the height.
    Widget stat(String key, String label, String value, Color color) => Expanded(
          child: Row(
            key: ValueKey(key),
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        );
    return Container(
      key: const ValueKey('evaluation_summary'),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${d.programCode} — ${d.programName}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('${(progress * 100).round()}% done',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              IconButton(
                key: const ValueKey('evaluation_summary_collapse'),
                tooltip: 'Hide the summary and give the checklist more room',
                icon: const Icon(Icons.expand_less, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _summaryCollapsed = true),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              stat('evaluation_earned', 'earned of ${_units(d.totalUnits)}', _units(d.earnedUnits), AppColors.accentGreenDark),
              stat('evaluation_in_progress', 'in progress', _units(d.inProgressUnits), AppColors.primary),
              stat('evaluation_remaining', 'units left', _units(d.remainingUnits), AppColors.textPrimary),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.border,
              color: AppColors.accentGreen,
            ),
          ),
        ],
      ),
    );
  }
}
