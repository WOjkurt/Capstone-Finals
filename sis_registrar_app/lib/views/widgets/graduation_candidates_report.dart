import 'package:flutter/material.dart';

import '../../injection.dart';
import '../../models/record_models.dart';
import '../../models/setup_models.dart';
import '../../repositories/enrollment_repository.dart';
import '../../repositories/student_record_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/csv.dart';
import '../../utils/error_handler.dart';
import '../../utils/file_download.dart';
import '../../utils/report_pdf.dart';
import '../../utils/study_load_pdf.dart' show loadSchoolLogo, printPdf;

/// Reports → Graduation: students in the final year of their curriculum, and what each still needs, from the
/// same checklist as the Evaluation tab. Printable for the Registrar and the College Head.
class GraduationCandidatesReport extends StatefulWidget {
  /// For tests; the app uses the registered repositories.
  final Future<GraduationCandidates> Function(int? programId)? load;
  final Future<List<AcademicProgramModel>> Function()? loadPrograms;

  const GraduationCandidatesReport({super.key, this.load, this.loadPrograms});

  @override
  State<GraduationCandidatesReport> createState() => _GraduationCandidatesReportState();
}

class _GraduationCandidatesReportState extends State<GraduationCandidatesReport> {
  List<AcademicProgramModel> _programs = [];
  int? _programId;
  String? _status; // null = all
  GraduationCandidates? _data;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    (widget.loadPrograms ?? getIt<AcademicSetupRepository>().getPrograms)()
        .then((p) => mounted ? setState(() => _programs = p) : null)
        .catchError((_) => null);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await (widget.load ?? ((id) => getIt<StudentRecordRepository>().graduationCandidates(programId: id)))(_programId);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<GraduationCandidate> get _visible =>
      [for (final r in _data?.rows ?? const <GraduationCandidate>[]) if (_status == null || r.status == _status) r];

  static String _units(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

  static const _headers = ['Student', 'Student ID', 'Program', 'Year', 'Status', 'Units earned', 'Taking now', 'Lacking'];

  List<List<Object?>> get _tableRows => [
        for (final r in _visible)
          [
            r.name,
            r.studentId ?? '',
            r.programCode ?? '',
            r.yearLevel ?? '',
            r.statusLabel,
            '${_units(r.earnedUnits)} of ${_units(r.totalUnits)}',
            r.inProgress.map((s) => s.subjectCode).join(', '),
            r.lacking.map((s) => '${s.subjectCode} (${s.statusLabel})').join(', '),
          ],
      ];

  String get _fileStem {
    final program = _programs.where((p) => p.programId == _programId).firstOrNull?.programCode;
    return 'Graduation_Candidates${program != null ? '_$program' : ''}';
  }

  /// The printout lists open subjects once per status ("Not taken (12): GEC 01, GEC 02 …") instead of
  /// repeating the status after every code, and gives each column a fixed share of the page.
  static const _pdfHeaders = ['Student', 'Student ID', 'Program', 'Year', 'Status', 'Units earned', 'Taking now', 'Still needs'];
  static const _pdfFlex = [2.2, 1.3, 1.2, 0.6, 1.3, 1.1, 2.0, 5.5];

  static String _byStatus(List<GraduationSubject> list) {
    final groups = <String, List<String>>{};
    for (final s in list) {
      groups.putIfAbsent(s.statusLabel, () => []).add(s.subjectCode);
    }
    return [
      for (final e in groups.entries)
        '${e.key[0].toUpperCase()}${e.key.substring(1)} (${e.value.length}): ${e.value.join(', ')}',
    ].join('\n');
  }

  List<List<Object?>> get _pdfRows => [
        for (final r in _visible)
          [
            r.name,
            r.studentId ?? '',
            r.programCode ?? '',
            r.yearLevel ?? '',
            r.statusLabel,
            '${_units(r.earnedUnits)} of ${_units(r.totalUnits)}',
            r.inProgress.map((s) => s.subjectCode).join(', '),
            r.lacking.isEmpty ? '-' : '${_units(_sumUnits(r.lacking))} units\n${_byStatus(r.lacking)}',
          ],
      ];

  Future<void> _print() async {
    try {
      final bytes = await buildReportPdf(
        title: 'Candidates for Graduation',
        subtitle: [
          _programs.where((p) => p.programId == _programId).firstOrNull?.programCode ?? 'All programs',
          _status == null ? 'all final-year students' : _visible.first.statusLabel,
        ].join(' - '),
        headers: _pdfHeaders,
        rows: _pdfRows,
        columnFlex: _pdfFlex,
        landscape: true,
        logo: await loadSchoolLogo(),
      );
      await printPdf(bytes, '$_fileStem.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not print: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  void _download() => downloadFile(buildCsv(_headers, _tableRows), '$_fileStem.csv', 'text/csv');

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final rows = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<int?>(
                key: const ValueKey('graduation_program_dropdown'),
                initialValue: _programId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Program', isDense: true, border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All programs')),
                  for (final p in _programs) DropdownMenuItem<int?>(value: p.programId, child: Text(p.programCode)),
                ],
                onChanged: (v) {
                  setState(() => _programId = v);
                  _load();
                },
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('graduation_csv'),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download CSV'),
              onPressed: rows.isEmpty || _loading ? null : _download,
            ),
            OutlinedButton.icon(
              key: const ValueKey('graduation_print'),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Print'),
              onPressed: rows.isEmpty || _loading ? null : _print,
            ),
            IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            'Students in the final year of their curriculum. "Finishing this term" means everything left is in their study load now.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        if (d != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                key: const ValueKey('grad_all'),
                label: Text('All (${d.rows.length})'),
                selected: _status == null,
                onSelected: (_) => setState(() => _status = null),
              ),
              for (final (key, label, count) in [
                ('Complete', 'Complete', d.complete),
                ('FinishingThisTerm', 'Finishing this term', d.finishingThisTerm),
                ('Lacking', 'Lacking subjects', d.lacking),
              ])
                ChoiceChip(
                  key: ValueKey('grad_$key'),
                  label: Text('$label ($count)'),
                  selected: _status == key,
                  onSelected: (_) => setState(() => _status = _status == key ? null : key),
                ),
            ]),
          ),
        Expanded(child: _body(d, rows)),
      ],
    );
  }

  Widget _body(GraduationCandidates? d, List<GraduationCandidate> rows) {
    if (_loading && d == null) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: const TextStyle(color: AppColors.error)),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }
    if (d == null) return const SizedBox.shrink();
    if (rows.isEmpty) {
      return const Center(
        child: Text('No final-year students to show.', key: ValueKey('graduation_empty'), style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final r = rows[i];
        final (bg, fg) = switch (r.status) {
          'Complete' => (const Color(0xFFDCFCE7), const Color(0xFF166534)),
          'FinishingThisTerm' => (const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
          _ => (const Color(0xFFFEF2F2), const Color(0xFFB91C1C)),
        };
        return Card(
          key: ValueKey('grad_row_${r.userId}'),
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.border)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              shape: const Border(),
              title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(
                [
                  r.studentId?.isNotEmpty == true ? 'ID ${r.studentId}' : 'No ID',
                  r.programCode ?? '',
                  if (r.yearLevel != null) 'Year ${r.yearLevel}',
                  '${_units(r.earnedUnits)} of ${_units(r.totalUnits)} units earned',
                ].join(' · '),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                child: Text(r.statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_details(r)],
            ),
          ),
        );
      },
    );
  }

  static double _sumUnits(List<GraduationSubject> l) => l.fold(0.0, (a, s) => a + s.units);

  static String _semester(int s) => switch (s) {
        1 => '1st Semester',
        2 => '2nd Semester',
        3 => 'Summer',
        _ => 'Semester not set',
      };

  /// What one student still needs: three numbers, then every open subject in one table,
  /// grouped by the year and semester it belongs to in the curriculum.
  Widget _details(GraduationCandidate r) {
    final open = [...r.inProgress, ...r.lacking]
      ..sort((a, b) {
        final y = a.yearLevel.compareTo(b.yearLevel);
        if (y != 0) return y;
        final s = a.semester.compareTo(b.semester);
        return s != 0 ? s : a.subjectCode.compareTo(b.subjectCode);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _stat('Units earned', '${_units(r.earnedUnits)} of ${_units(r.totalUnits)}'),
          _stat('Taking now', '${r.inProgress.length} subject(s) · ${_units(_sumUnits(r.inProgress))} units'),
          _stat('Still needs', '${r.lacking.length} subject(s) · ${_units(_sumUnits(r.lacking))} units',
              alert: r.lacking.isNotEmpty),
        ]),
        const SizedBox(height: 14),
        if (open.isEmpty)
          const Text('Every subject of the curriculum is passed or credited.', style: TextStyle(fontSize: 13))
        else
          _subjectTable(open),
        if (r.curriculumName != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('Curriculum: ${r.curriculumName}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ),
      ],
    );
  }

  Widget _stat(String label, String value, {bool alert = false}) => Container(
        constraints: const BoxConstraints(minWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: alert ? const Color(0xFFFEF2F2) : AppColors.scaffoldBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: alert ? const Color(0xFFFECACA) : AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: alert ? const Color(0xFFB91C1C) : AppColors.textPrimary)),
        ]),
      );

  Widget _subjectTable(List<GraduationSubject> list) {
    const head = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569));
    Widget row(List<Widget> cells, {Color? color, Key? key}) => Container(
          key: key,
          color: color,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            SizedBox(width: 110, child: cells[0]),
            Expanded(child: cells[1]),
            SizedBox(width: 60, child: Align(alignment: Alignment.centerRight, child: cells[2])),
            const SizedBox(width: 24),
            SizedBox(width: 120, child: Align(alignment: Alignment.centerLeft, child: cells[3])),
          ]),
        );
    final children = <Widget>[
      row(const [Text('CODE', style: head), Text('SUBJECT', style: head), Text('UNITS', style: head), Text('STATUS', style: head)],
          color: const Color(0xFFF1F5F9)),
    ];
    (int, int)? group;
    for (final s in list) {
      if (group != (s.yearLevel, s.semester)) {
        group = (s.yearLevel, s.semester);
        children.add(Container(
          width: double.infinity,
          color: AppColors.scaffoldBg,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Text('Year ${s.yearLevel} · ${_semester(s.semester)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
        ));
      }
      children.add(row([
        Text(s.subjectCode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text(s.subjectTitle, style: const TextStyle(fontSize: 13)),
        Text(_units(s.units), style: const TextStyle(fontSize: 13)),
        _statusBadge(s),
      ], key: ValueKey('grad_subject_${s.subjectCode}')));
    }
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (final (i, c) in children.indexed) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.borderSubtle),
          c,
        ],
      ]),
    );
  }

  Widget _statusBadge(GraduationSubject s) {
    final (bg, fg) = switch (s.status) {
      'InProgress' => (const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
      'Failed' => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      'Dropped' || 'Withdrawn' => (const Color(0xFFFFEDD5), const Color(0xFF9A3412)),
      'PartiallyCredited' => (const Color(0xFFFEF9C3), const Color(0xFF854D0E)),
      _ => (AppColors.borderSubtle, AppColors.textSecondary),
    };
    final label = s.statusLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label.isEmpty ? '' : label[0].toUpperCase() + label.substring(1),
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
