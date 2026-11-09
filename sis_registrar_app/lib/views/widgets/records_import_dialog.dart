import 'package:flutter/material.dart';

import '../../injection.dart';
import '../../models/records_import_models.dart';
import '../../repositories/records_import_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/file_pick.dart';

/// Students → Import from Excel: loads old students and their grades from the registrar's files.
/// Nothing is saved until the preview has been checked and Import is pressed.
class RecordsImportDialog extends StatefulWidget {
  final RecordsImportRepository? repository;

  const RecordsImportDialog({super.key, this.repository});

  /// Returns true when something was imported.
  static Future<bool?> show(BuildContext context) =>
      showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => const RecordsImportDialog());

  @override
  State<RecordsImportDialog> createState() => _RecordsImportDialogState();
}

class _RecordsImportDialogState extends State<RecordsImportDialog> {
  late final RecordsImportRepository _repo = widget.repository ?? getIt<RecordsImportRepository>();
  PickedFile? _grades;
  PickedFile? _students;
  List<String> _yearsFound = const [];
  final Set<String> _years = {};
  bool _release = true;
  RecordsImportResult? _preview;
  bool _busy = false;
  String? _error;

  String _message(Object e) => e is ApiException ? e.message : e.toString();

  Future<RecordsImportResult?> _run({required bool dryRun, List<String>? years}) async {
    final grades = _grades;
    if (grades == null) return null;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      return await _repo.importRecords(
        gradesName: grades.name,
        gradesBytes: grades.bytes,
        studentsName: _students?.name,
        studentsBytes: _students?.bytes,
        schoolYears: years ?? _years.toList(),
        dryRun: dryRun,
        releaseGrades: _release,
      );
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseGrades() async {
    try {
      final file = await pickFile(accept: '.xlsx');
      if (file == null) return;
      setState(() {
        _grades = file;
        _preview = null;
        _years.clear();
        _yearsFound = const [];
      });
      // Read which school years the file has; the newest one is ticked (the registrar imports the previous year).
      final found = await _run(dryRun: true, years: const []);
      if (found == null || !mounted) return;
      setState(() {
        _yearsFound = found.schoolYearsFound;
        if (found.schoolYearsFound.isNotEmpty) _years.add(found.schoolYearsFound.first);
        if (found.schoolYearsFound.isEmpty && found.problems.isNotEmpty) _error = found.problems.first.message;
      });
      if (_years.isNotEmpty) await _check();
    } catch (e) {
      setState(() => _error = _message(e));
    }
  }

  Future<void> _chooseStudents() async {
    try {
      final file = await pickFile(accept: '.xlsx');
      if (file == null) return;
      setState(() => _students = file);
      if (_grades != null && _years.isNotEmpty) await _check();
    } catch (e) {
      setState(() => _error = _message(e));
    }
  }

  Future<void> _check() async {
    final result = await _run(dryRun: true);
    if (mounted) setState(() => _preview = result);
  }

  Future<void> _import() async {
    final result = await _run(dryRun: false);
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(true);
    messenger.showSnackBar(SnackBar(
      backgroundColor: AppColors.success,
      content: Text('Imported SY ${result.schoolYearsImported.join(', ')}: ${result.newStudents} new student(s) and '
          '${result.gradeRows} subject record(s).'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    final canImport = !_busy && p != null && p.hasWork && _years.isNotEmpty;
    return AlertDialog(
      title: const Text('Import students and grades from Excel'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Use the registrar\'s files: the grades file has one sheet per term (for example "1ST SEM_2025-2026"). '
                'Students are matched by Student ID, so importing again never makes duplicates.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              _fileRow(
                key: const ValueKey('choose_grades_file'),
                label: 'Grades file',
                file: _grades,
                onPressed: _chooseGrades,
                required: true,
              ),
              const SizedBox(height: 8),
              _fileRow(
                key: const ValueKey('choose_students_file'),
                label: 'Students file (optional)',
                file: _students,
                onPressed: _chooseStudents,
                hint: 'Gives current year levels and regular/irregular status.',
              ),
              if (_yearsFound.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('School years to import', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  for (final y in _yearsFound)
                    FilterChip(
                      key: ValueKey('year_$y'),
                      label: Text('SY $y'),
                      selected: _years.contains(y),
                      onSelected: _busy
                          ? null
                          : (on) {
                              setState(() => on ? _years.add(y) : _years.remove(y));
                              if (_years.isNotEmpty) {
                                _check();
                              } else {
                                setState(() => _preview = null);
                              }
                            },
                    ),
                ]),
                CheckboxListTile(
                  key: const ValueKey('release_grades_checkbox'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _release,
                  title: const Text('Release these grades to the students'),
                  subtitle: const Text('Released terms count as cleared, so old students can enroll online.',
                      style: TextStyle(fontSize: 12)),
                  onChanged: _busy ? null : (v) => setState(() => _release = v ?? true),
                ),
              ],
              if (_busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, key: const ValueKey('import_error'), style: const TextStyle(color: AppColors.error)),
                ),
              if (p != null && !_busy && _years.isNotEmpty) _summary(p),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('run_records_import'),
          onPressed: canImport ? _import : null,
          child: const Text('Import'),
        ),
      ],
    );
  }

  Widget _fileRow({required Key key, required String label, required PickedFile? file, required VoidCallback onPressed,
      bool required = false, String? hint}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          key: key,
          onPressed: _busy ? null : onPressed,
          icon: const Icon(Icons.table_view_outlined, size: 18),
          label: Text(file == null ? 'Choose $label'.replaceFirst(' (optional)', '') : 'Change'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(file?.name ?? label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: file != null ? FontWeight.w600 : FontWeight.normal,
                      color: file != null ? AppColors.textPrimary : AppColors.textSecondary)),
              if (hint != null && file == null)
                Text(hint, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summary(RecordsImportResult p) {
    Widget line(String text, {Color? color, bool bold = false}) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: bold ? FontWeight.w700 : null)),
        );
    String perGroup(Map<String, int> m) => m.entries.map((e) => '${e.key}: ${e.value}').join(' • ');
    return Container(
      key: const ValueKey('records_import_summary'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.hasWork ? 'Ready to import:' : 'Nothing new to import.', style: const TextStyle(fontWeight: FontWeight.w700)),
          line('${p.newStudents} new student(s)${p.existingStudents > 0 ? ', ${p.existingStudents} already in the system' : ''}'),
          if (p.studentsPerProgram.isNotEmpty) line(perGroup(p.studentsPerProgram), color: AppColors.textSecondary),
          if (p.studentsPerCurriculum.isNotEmpty) line('Curricula: ${perGroup(p.studentsPerCurriculum)}', color: AppColors.textSecondary),
          line('${p.gradesPassed} passed, ${p.gradesFailed} failed, ${p.dropped} dropped, ${p.noGradeYet} without a final grade'),
          if (p.alreadyImported > 0) line('${p.alreadyImported} subject record(s) are already in the system and will be skipped'),
          if (p.termsCreated.isNotEmpty) line('Terms that will be added: ${p.termsCreated.join(', ')}'),
          if (p.totalProblems > 0) ...[
            const SizedBox(height: 8),
            line('${p.totalProblems} row(s) will be skipped:', color: AppColors.error, bold: true),
            for (final problem in p.problems.take(15)) line('• ${problem.label}', color: AppColors.error),
            if (p.problems.length > 15) line('…and more.', color: AppColors.error),
          ],
          if (p.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final n in p.notes) line('Note: $n', color: AppColors.textSecondary),
          ],
        ],
      ),
    );
  }
}
