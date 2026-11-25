import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/curriculum_models.dart';
import '../../models/setup_models.dart';
import '../../repositories/enrollment_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/curriculum_pdf.dart';
import '../../utils/error_handler.dart';
import '../../utils/numbers.dart';
import 'record_table.dart';

/// The whole of one curriculum on a page of its own: every year, every semester, with the
/// hours, units and requisites, and a total under each semester.
///
/// The Subjects tab can already filter by curriculum, but it answers "what is in this list"
/// one screenful at a time. This answers "what does this course look like", which is the thing
/// the Registrar prints, hands to a student, and checks a study load against. It is a page
/// rather than a dialog for the same reason -- a dialog cannot be scrolled through next to
/// something else, and this runs to four years of tables.
class CurriculumViewPage extends StatefulWidget {
  final CurriculumModel curriculum;

  const CurriculumViewPage({super.key, required this.curriculum});

  @override
  State<CurriculumViewPage> createState() => _CurriculumViewPageState();
}

class _CurriculumViewPageState extends State<CurriculumViewPage> {
  List<SubjectModel>? _subjects;
  String? _error;
  bool _printing = false;

  /// Subject groups appear on the Registrar's own printout only when she asks for them.
  bool _showGroups = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final all = await getIt<AcademicSetupRepository>().getSubjects();
      if (!mounted) return;
      setState(() => _subjects =
          all.where((s) => s.curriculumId == widget.curriculum.curriculumId).toList());
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _error = getFriendlyErrorMessage(e, st));
    }
  }

  /// Year level, then semester, then the order they are meant to be taken in.
  Map<int, Map<int, List<SubjectModel>>> get _byYearAndSemester {
    final out = <int, Map<int, List<SubjectModel>>>{};
    for (final s in _subjects ?? <SubjectModel>[]) {
      (out[s.yearLevel] ??= <int, List<SubjectModel>>{})
          .putIfAbsent(s.defaultSemester, () => [])
          .add(s);
    }
    for (final year in out.values) {
      for (final list in year.values) {
        list.sort((a, b) => a.subjectCode.compareTo(b.subjectCode));
      }
    }
    return out;
  }

  Future<void> _print() async {
    final subjects = _subjects;
    if (subjects == null || subjects.isEmpty) return;
    setState(() => _printing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await printCurriculumPdf(
        curriculum: widget.curriculum,
        subjects: subjects,
        showGroups: _showGroups,
      );
    } catch (e, st) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.error,
        content: Text(getFriendlyErrorMessage(e, st)),
      ));
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.curriculum;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('curriculum_view_back'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Go back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('${c.programCode ?? ''} — ${c.name}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          Row(
            children: [
              Checkbox(
                key: const ValueKey('curriculum_show_groups'),
                value: _showGroups,
                onChanged: (v) => setState(() => _showGroups = v ?? false),
              ),
              const Text('Show subject group in printout', style: TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            key: const ValueKey('curriculum_print'),
            onPressed: (_subjects?.isEmpty ?? true) || _printing ? null : _print,
            icon: const Icon(Icons.print_outlined, size: 16),
            label: Text(_printing ? 'Preparing…' : 'Print curriculum'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        key: const ValueKey('curriculum_view_error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_subjects == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_subjects!.isEmpty) {
      return const Center(
        key: ValueKey('curriculum_view_empty'),
        child: Text('No subjects have been added to this curriculum yet.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final grouped = _byYearAndSemester;
    final years = grouped.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      children: [
        _header(),
        for (final year in years) ...[
          const SizedBox(height: 20),
          Text(_yearName(year),
              key: ValueKey('curriculum_year_$year'),
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          for (final sem in (grouped[year]!.keys.toList()..sort())) ...[
            const SizedBox(height: 12),
            Text(_semesterName(sem),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
            const SizedBox(height: 6),
            _semesterTable(grouped[year]![sem]!),
          ],
        ],
      ],
    );
  }

  Widget _header() {
    final c = widget.curriculum;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Course: ${c.programCode ?? ''}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Curriculum: ${c.name}  ·  takes effect ${c.effectiveSchoolYear}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('${_subjects!.length} subjects  ·  ${gradeText(_totalUnits(_subjects!))} units in total',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  static double _totalUnits(List<SubjectModel> rows) =>
      rows.fold(0.0, (sum, s) => sum + s.lecUnits + s.labUnits);

  Widget _semesterTable(List<SubjectModel> rows) {
    return RecordTable(
      columns: const [
        RecordColumn('Subject Code', 1.1),
        RecordColumn('Subject Name / Description', 3),
        RecordColumn('Lec hrs', .7, center: true),
        RecordColumn('Lab hrs', .7, center: true),
        RecordColumn('Lec units', .8, center: true),
        RecordColumn('Lab units', .8, center: true),
        RecordColumn('Pre-requisite', 1.6),
        RecordColumn('Co-requisite', 1.3),
      ],
      rows: [
        for (final s in rows)
          RecordRow([
            s.subjectCode,
            s.subjectTitle,
            gradeText(s.lecHours),
            gradeText(s.labHours),
            gradeText(s.lecUnits),
            gradeText(s.labUnits),
            _requisites(s, prerequisite: true),
            _requisites(s, prerequisite: false),
          ], key: ValueKey('curriculum_row_${s.subjectId}')),
      ],
      totals: [
        'TOTAL',
        '',
        gradeText(rows.fold(0.0, (t, s) => t + s.lecHours)),
        gradeText(rows.fold(0.0, (t, s) => t + s.labHours)),
        gradeText(rows.fold(0.0, (t, s) => t + s.lecUnits)),
        gradeText(rows.fold(0.0, (t, s) => t + s.labUnits)),
        '${gradeText(_totalUnits(rows))} academic units',
        '',
      ],
    );
  }

  /// Requisite type 0 is a prerequisite, 1 a co-requisite. Several of either are comma separated,
  /// the way the Registrar's own printout lists them.
  static String _requisites(SubjectModel s, {required bool prerequisite}) => s.prerequisites
      .where((p) => (p.requisiteType == 0) == prerequisite)
      .map((p) => p.prerequisiteSubjectCode ?? '')
      .where((code) => code.isNotEmpty)
      .join(', ');

  static String _yearName(int year) => switch (year) {
        1 => 'First Year',
        2 => 'Second Year',
        3 => 'Third Year',
        4 => 'Fourth Year',
        5 => 'Fifth Year',
        _ => 'Year $year',
      };

  static String _semesterName(int semester) => switch (semester) {
        1 => 'First Semester',
        2 => 'Second Semester',
        3 => 'Summer',
        _ => 'Semester $semester',
      };
}
