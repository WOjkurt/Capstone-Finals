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

  Future<void> _print() async {
    try {
      final bytes = await buildReportPdf(
        title: 'Candidates for Graduation',
        subtitle: _status == null ? 'All final-year students' : _visible.first.statusLabel,
        headers: _headers,
        rows: _tableRows,
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
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.inProgress.isEmpty && r.lacking.isEmpty)
                  const Text('Every subject of the curriculum is passed or credited.', style: TextStyle(fontSize: 13)),
                if (r.inProgress.isNotEmpty) _subjects('Taking now', r.inProgress),
                if (r.lacking.isNotEmpty) _subjects('Still needs', r.lacking),
                if (r.curriculumName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Curriculum: ${r.curriculumName}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _subjects(String title, List<GraduationSubject> list) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textSecondary)),
          for (final s in list)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '${s.subjectCode}  ${s.subjectTitle} · ${_units(s.units)} u · Year ${s.yearLevel}${s.status == 'InProgress' ? '' : ' · ${s.statusLabel}'}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ]),
      );
}
