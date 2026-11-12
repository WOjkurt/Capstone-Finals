import 'package:flutter/material.dart';

import '../../injection.dart';
import '../../models/records_import_models.dart';
import '../../repositories/records_import_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/file_pick.dart';

/// Students → Import → School emails: adds the IT department's school emails to imported students who haven't
/// signed in yet, so they can sign in. Every row is checked first; nothing is saved until Import.
class EmailsImportDialog extends StatefulWidget {
  final RecordsImportRepository? repository;

  const EmailsImportDialog({super.key, this.repository});

  static Future<bool?> show(BuildContext context) =>
      showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => const EmailsImportDialog());

  @override
  State<EmailsImportDialog> createState() => _EmailsImportDialogState();
}

class _EmailsImportDialogState extends State<EmailsImportDialog> {
  late final RecordsImportRepository _repo = widget.repository ?? getIt<RecordsImportRepository>();
  PickedFile? _file;
  EmailsImportResult? _preview;
  bool _busy = false;
  String? _error;

  Future<EmailsImportResult?> _run({required bool dryRun}) async {
    final file = _file;
    if (file == null) return null;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      return await _repo.importSchoolEmails(fileName: file.name, bytes: file.bytes, dryRun: dryRun);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : e.toString());
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
    try {
      final file = await pickFile(accept: '.xlsx,.csv');
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
      content: Text('Added the school email of ${result.emails} student(s). They can sign in now.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    final canImport = !_busy && p != null && p.emails > 0;
    return AlertDialog(
      title: const Text('Import school emails'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Use the IT department\'s list as Excel (.xlsx) or CSV. It needs an Email column, and a Student ID '
                'column (best) or the student\'s name (Last Name and First Name, or "LAST, FIRST"). Only students who '
                'haven\'t signed in yet get their email; their first sign-in with it makes the account theirs.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Row(children: [
                OutlinedButton.icon(
                  key: const ValueKey('choose_emails_file'),
                  onPressed: _busy ? null : _choose,
                  icon: const Icon(Icons.table_view_outlined, size: 18),
                  label: Text(_file == null ? 'Choose file' : 'Change'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_file?.name ?? 'Excel (.xlsx) or CSV file',
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
                  child: Text(_error!, key: const ValueKey('emails_import_error'), style: const TextStyle(color: AppColors.error)),
                ),
              if (p != null && !_busy) _summary(p),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('run_emails_import'),
          onPressed: canImport ? _import : null,
          child: const Text('Import'),
        ),
      ],
    );
  }

  Widget _summary(EmailsImportResult p) {
    Widget line(String text, {Color? color, bool bold = false}) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: bold ? FontWeight.w700 : null)),
        );
    return Container(
      key: const ValueKey('emails_import_summary'),
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
          Text(p.emails > 0 ? 'Ready to import:' : 'Nothing new to import.', style: const TextStyle(fontWeight: FontWeight.w700)),
          line('${p.emails} student(s) get their school email'),
          if (p.changed > 0)
            line('${p.changed} of them had a different email set by hand; it will be replaced', color: AppColors.warning),
          if (p.alreadySet > 0) line('${p.alreadySet} student(s) already have this email and are skipped'),
          if (p.rows.isNotEmpty) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final r in p.rows)
                    line('• ${r.studentName}${r.studentId.isNotEmpty ? ' (${r.studentId})' : ''} → ${r.email}'
                        '${r.oldEmail != null ? ' (was ${r.oldEmail})' : ''}'
                        '${r.matchedBy == 'name' ? ' — matched by name' : ''}'),
                ]),
              ),
            ),
            if (p.rows.length < p.emails) line('…and ${p.emails - p.rows.length} more.', color: AppColors.textSecondary),
          ],
          if (p.totalProblems > 0) ...[
            const SizedBox(height: 8),
            line('${p.totalProblems} row(s) will be skipped:', color: AppColors.error, bold: true),
            for (final problem in p.problems.take(20)) line('• ${problem.label}', color: AppColors.error),
            if (p.totalProblems > 20) line('…and more.', color: AppColors.error),
          ],
        ],
      ),
    );
  }
}
