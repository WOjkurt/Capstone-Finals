import 'package:flutter/material.dart';

import '../injection.dart';
import '../models/grading_models.dart';
import '../models/record_models.dart';
import '../models/setup_models.dart';
import '../repositories/enrollment_repository.dart';
import '../repositories/student_record_repository.dart';
import '../theme/app_theme.dart';
import '../utils/error_handler.dart';
import 'widgets/page_header.dart';

/// Students → Records check: every active student who still needs something before their records are complete
/// (school email, Student ID, program, year level, curriculum, transcript details). Clicking a student opens them.
class RecordsCheckView extends StatefulWidget {
  final VoidCallback? onBack;

  /// Called with the student to open on the Students page.
  final void Function(UserSearchResultModel student)? onOpen;

  /// For tests; the app uses the registered repositories.
  final Future<RecordsCheck> Function(int? programId)? load;
  final Future<List<AcademicProgramModel>> Function()? loadPrograms;

  const RecordsCheckView({super.key, this.onBack, this.onOpen, this.load, this.loadPrograms});

  @override
  State<RecordsCheckView> createState() => _RecordsCheckViewState();
}

class _RecordsCheckViewState extends State<RecordsCheckView> {
  List<AcademicProgramModel> _programs = [];
  int? _programId;
  String? _issue; // null = every issue
  final _search = TextEditingController();
  RecordsCheck? _data;
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await (widget.load ?? ((id) => getIt<StudentRecordRepository>().recordsCheck(programId: id)))(_programId);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const _short = {
    'no-email': 'No school email',
    'no-student-id': 'No Student ID',
    'no-program': 'No program',
    'no-year-level': 'No year level',
    'no-curriculum': 'No curriculum',
    'transcript': 'Transcript details',
    'not-signed-in': 'Not signed in yet',
  };

  /// Problems the registrar has to fix (red); "not signed in yet" only waits for the student (grey).
  static bool _needsFix(String issue) => issue != 'not-signed-in';

  List<RecordsCheckRow> get _visible {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final r in _data?.rows ?? const <RecordsCheckRow>[])
        if ((_issue == null || r.issues.contains(_issue)) &&
            (q.isEmpty || r.name.toLowerCase().contains(q) || (r.studentId ?? '').contains(q)))
          r
    ];
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final rows = _visible;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Records check',
            subtitle: 'Students who still need something before their records are complete. Click a student to open them.',
            onBack: widget.onBack,
            onRefresh: _load,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<int?>(
                  key: const ValueKey('check_program_dropdown'),
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
              SizedBox(
                width: 260,
                child: TextField(
                  key: const ValueKey('check_search'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      labelText: 'Name or Student ID', isDense: true, border: OutlineInputBorder(), prefixIcon: Icon(Icons.search, size: 18)),
                ),
              ),
              if (d != null)
                Text('${d.rows.length} of ${d.activeStudents} active student(s) need something',
                    key: const ValueKey('check_total'), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ]),
          ),
          if (d != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(
                  key: const ValueKey('issue_all'),
                  label: Text('All (${d.rows.length})'),
                  selected: _issue == null,
                  onSelected: (_) => setState(() => _issue = null),
                ),
                for (final c in d.counts)
                  if (c.count > 0)
                    ChoiceChip(
                      key: ValueKey('issue_${c.key}'),
                      label: Text('${c.label} (${c.count})'),
                      selected: _issue == c.key,
                      onSelected: (_) => setState(() => _issue = _issue == c.key ? null : c.key),
                    ),
              ]),
            ),
          Expanded(child: _body(d, rows)),
        ],
      ),
    );
  }

  Widget _body(RecordsCheck? d, List<RecordsCheckRow> rows) {
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
    if (d.rows.isEmpty) {
      return const Center(
        child: Text('Every active student\'s record is complete.', key: ValueKey('check_all_done'),
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    if (rows.isEmpty) {
      return const Center(child: Text('No student matches.', style: TextStyle(color: AppColors.textSecondary)));
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (context, i) {
          final r = rows[i];
          return ListTile(
            key: ValueKey('check_row_${r.userId}'),
            onTap: widget.onOpen == null ? null : () => widget.onOpen!(UserSearchResultModel.fromJson(r.json)),
            title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              [
                r.studentId?.isNotEmpty == true ? 'ID ${r.studentId}' : 'No ID',
                r.programCode ?? 'No program',
                if (r.yearLevel != null) 'Year ${r.yearLevel}',
              ].join(' · '),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            trailing: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final issue in r.issues)
                    Tooltip(
                      message: issue == 'transcript' ? 'Missing: ${r.missing.join(', ')}' : '',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _needsFix(issue) ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          issue == 'transcript' ? 'Transcript: ${r.missing.join(', ')}' : _short[issue] ?? issue,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _needsFix(issue) ? const Color(0xFFB91C1C) : AppColors.textSecondary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
