import 'package:flutter/material.dart';

import '../../injection.dart';
import '../../models/records_import_models.dart';
import '../../repositories/records_import_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/file_pick.dart';

/// Students → Import credited subjects: credits many subjects at once from the registrar's list
/// (transferees, shiftees, cross-enrollment). Every row is checked first; nothing is saved until Import.
class CreditsImportDialog extends StatefulWidget {
  final RecordsImportRepository? repository;

  const CreditsImportDialog({super.key, this.repository});

  /// Returns true when something was imported.
  static Future<bool?> show(BuildContext context) =>
      showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => const CreditsImportDialog());

  @override
  State<CreditsImportDialog> createState() => _CreditsImportDialogState();
}

class _CreditsImportDialogState extends State<CreditsImportDialog> {
  late final RecordsImportRepository _repo = widget.repository ?? getIt<RecordsImportRepository>();
  PickedFile? _file;
  CreditsImportResult? _preview;
  bool _busy = false;
  String? _error;

  Future<CreditsImportResult?> _run({required bool dryRun}) async {
    final file = _file;
    if (file == null) return null;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      return await _repo.importCredits(fileName: file.name, bytes: file.bytes, dryRun: dryRun);
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
      content: Text('Credited ${result.credits} subject(s) for ${result.students} student(s).'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    final canImport = !_busy && p != null && p.credits > 0;
    return AlertDialog(
      title: const Text('Import credited subjects'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'One row per credited subject. Columns: Student ID, DBTC Subject Code, School, and optionally '
                'Their Subject Code, Grade, School Year, Units Credited (blank = full units), Type '
                '(Transfer or Cross-enrollment) and DBTC Term (for cross-enrollment, e.g. "1st Sem 2024-2025"). '
                'Subjects already credited are skipped, so importing again never makes duplicates.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Row(children: [
                OutlinedButton.icon(
                  key: const ValueKey('choose_credits_file'),
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
                  child: Text(_error!, key: const ValueKey('credits_import_error'), style: const TextStyle(color: AppColors.error)),
                ),
              if (p != null && !_busy) _summary(p),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('run_credits_import'),
          onPressed: canImport ? _import : null,
          child: const Text('Import'),
        ),
      ],
    );
  }

  Widget _summary(CreditsImportResult p) {
    Widget line(String text, {Color? color, bool bold = false}) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: bold ? FontWeight.w700 : null)),
        );
    String units(double u) => u == u.roundToDouble() ? u.toStringAsFixed(0) : u.toString();
    return Container(
      key: const ValueKey('credits_import_summary'),
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
          Text(p.credits > 0 ? 'Ready to import:' : 'Nothing new to import.', style: const TextStyle(fontWeight: FontWeight.w700)),
          line('${p.credits} subject(s) to credit for ${p.students} student(s)'),
          if (p.alreadyCredited > 0) line('${p.alreadyCredited} subject(s) are already credited and will be skipped'),
          if (p.rows.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                child: Table(
                  columnWidths: const {0: FlexColumnWidth(2.4), 1: FlexColumnWidth(1.4), 2: FlexColumnWidth(0.9), 3: FlexColumnWidth(2.2)},
                  children: [
                    for (final r in p.rows)
                      TableRow(children: [
                        _cell('${r.studentName} (${r.studentId})'),
                        _cell(r.subjectCode, bold: true),
                        _cell('${units(r.creditedUnits)}/${units(r.units)} u${r.grade != null ? ' • ${r.grade}' : ''}',
                            color: r.isPartial ? AppColors.warning : null),
                        _cell(r.kind == 2 ? 'Cross-enrolled at ${r.sourceSchool}' : r.sourceSchool),
                      ]),
                  ],
                ),
              ),
            ),
            if (p.rows.length < p.credits) line('…and ${p.credits - p.rows.length} more.', color: AppColors.textSecondary),
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

  Widget _cell(String text, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w600 : null, color: color)),
      );
}
