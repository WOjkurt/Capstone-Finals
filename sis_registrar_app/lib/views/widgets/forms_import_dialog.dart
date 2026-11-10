import 'package:flutter/material.dart';

import '../../injection.dart';
import '../../models/records_import_models.dart';
import '../../repositories/records_import_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/file_pick.dart';

/// Students → Import → Enrollment forms: saves the Google Form's answers as the enrollment forms of students
/// already in the system, so their Details tab and online re-enrollment are filled in.
class FormsImportDialog extends StatefulWidget {
  final RecordsImportRepository? repository;

  const FormsImportDialog({super.key, this.repository});

  static Future<bool?> show(BuildContext context) =>
      showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => const FormsImportDialog());

  @override
  State<FormsImportDialog> createState() => _FormsImportDialogState();
}

class _FormsImportDialogState extends State<FormsImportDialog> {
  late final RecordsImportRepository _repo = widget.repository ?? getIt<RecordsImportRepository>();
  PickedFile? _file;
  FormsImportResult? _preview;
  bool _busy = false;
  String? _error;

  Future<FormsImportResult?> _run({required bool dryRun}) async {
    final file = _file;
    if (file == null) return null;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      return await _repo.importEnrollmentForms(fileName: file.name, bytes: file.bytes, dryRun: dryRun);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : e.toString());
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
    try {
      final file = await pickFile(accept: '.xlsx');
      if (file == null) return;
      setState(() {
        _file = file;
        _preview = null;
      });
      final result = await _run(dryRun: true);
      if (mounted) setState(() => _preview = result);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _import() async {
    final result = await _run(dryRun: false);
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(true);
    messenger.showSnackBar(SnackBar(
      backgroundColor: AppColors.success,
      content: Text('Saved the enrollment form of ${result.forms} student(s).'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    final canImport = !_busy && p != null && p.forms > 0;
    return AlertDialog(
      title: const Text('Import enrollment forms (Google Form)'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'In Google Sheets, open the form\'s responses and use File → Download → Microsoft Excel (.xlsx). '
                'Each answer is saved as the enrollment form of the student it belongs to (matched by school email, '
                'otherwise by first and last name). Students not in the system are left out; new applicants are '
                'still reviewed in Form responses.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Row(children: [
                OutlinedButton.icon(
                  key: const ValueKey('choose_forms_file'),
                  onPressed: _busy ? null : _choose,
                  icon: const Icon(Icons.table_view_outlined, size: 18),
                  label: Text(_file == null ? 'Choose file' : 'Change'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_file?.name ?? 'Form responses (.xlsx)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: _file != null ? FontWeight.w600 : FontWeight.normal,
                          color: _file != null ? AppColors.textPrimary : AppColors.textSecondary)),
                ),
              ]),
              if (_busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, key: const ValueKey('forms_import_error'), style: const TextStyle(color: AppColors.error)),
                ),
              if (p != null && !_busy) _summary(p),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('run_forms_import'),
          onPressed: canImport ? _import : null,
          child: const Text('Import'),
        ),
      ],
    );
  }

  Widget _summary(FormsImportResult p) {
    Widget line(String text, {Color? color, bool bold = false}) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: bold ? FontWeight.w700 : null)),
        );
    return Container(
      key: const ValueKey('forms_import_summary'),
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
          Text(p.forms > 0 ? 'Ready to import:' : 'Nothing new to import.', style: const TextStyle(fontWeight: FontWeight.w700)),
          line('${p.forms} student(s) get their enrollment form'),
          if (p.alreadyImported > 0) line('${p.alreadyImported} answer(s) were imported before and will be skipped'),
          if (p.olderAnswersSkipped > 0)
            line('${p.olderAnswersSkipped} older answer(s) skipped: only each student\'s newest answer is kept',
                color: AppColors.textSecondary),
          for (final r in p.rows.take(50))
            line('• ${r.studentName}${r.studentId.isNotEmpty ? ' (${r.studentId})' : ''} — matched by ${r.matchedBy}'
                '${r.contacts > 0 ? ', ${r.contacts} parent/guardian' : ''}'),
          if (p.rows.length > 50) line('…and ${p.rows.length - 50} more.', color: AppColors.textSecondary),
          if (p.totalProblems > 0) ...[
            const SizedBox(height: 8),
            line('${p.totalProblems} answer(s) left out:', color: AppColors.error, bold: true),
            for (final problem in p.problems.take(20)) line('• ${problem.label}', color: AppColors.error),
            if (p.totalProblems > 20) line('…and more.', color: AppColors.error),
          ],
        ],
      ),
    );
  }
}
