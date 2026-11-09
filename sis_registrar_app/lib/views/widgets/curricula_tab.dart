import 'package:flutter/material.dart';

import '../../injection.dart';
import '../../models/curriculum_models.dart';
import '../../models/setup_models.dart';
import '../../repositories/curriculum_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/file_pick.dart';
import 'status_badge.dart';

String _message(Object e) => e is ApiException ? e.message : e.toString();

/// Setup → Curricula: the curriculum versions of each program. New students get the newest curriculum in
/// effect when they start; students already enrolled keep theirs until they graduate.
class CurriculaTab extends StatefulWidget {
  final List<AcademicProgramModel> programs;
  final CurriculumRepository? repository;

  /// Called after subjects were imported, so the Subjects tab can reload.
  final VoidCallback? onSubjectsChanged;

  const CurriculaTab({super.key, required this.programs, this.repository, this.onSubjectsChanged});

  @override
  State<CurriculaTab> createState() => _CurriculaTabState();
}

class _CurriculaTabState extends State<CurriculaTab> {
  late final CurriculumRepository _repo = widget.repository ?? getIt<CurriculumRepository>();
  List<CurriculumModel>? _items;
  String? _error;
  int? _programFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _repo.list();
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  Future<void> _edit([CurriculumModel? existing]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CurriculumDialog(repo: _repo, programs: widget.programs, existing: existing, programId: _programFilter),
    );
    if (saved == true) {
      await _load();
      if (mounted) _snack(existing == null ? 'Curriculum added.' : 'Curriculum saved.');
    }
  }

  Future<void> _delete(CurriculumModel c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete curriculum?'),
        content: Text('${c.programCode ?? ''} ${c.name} will be removed. This only works when it has no subjects and no students.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('confirm_delete_curriculum'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.delete(c.curriculumId);
      await _load();
      if (mounted) _snack('Curriculum deleted.');
    } catch (e) {
      if (mounted) _snack(_message(e), error: true);
    }
  }

  Future<void> _import(CurriculumModel c) async {
    final imported = await showDialog<bool>(
      context: context,
      builder: (_) => CurriculumImportDialog(repo: _repo, curriculum: c),
    );
    if (imported == true) {
      await _load();
      widget.onSubjectsChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final shown = items?.where((c) => _programFilter == null || c.programId == _programFilter).toList() ?? const [];
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              const Text('Curricula', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<int?>(
                      key: const ValueKey('curricula_program_filter'),
                      initialValue: _programFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Program', border: OutlineInputBorder(), isDense: true),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('All programs')),
                        for (final p in widget.programs) DropdownMenuItem<int?>(value: p.programId, child: Text(p.programCode)),
                      ],
                      onChanged: (v) => setState(() => _programFilter = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    key: const ValueKey('add_curriculum_button'),
                    onPressed: widget.programs.isEmpty ? null : () => _edit(),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add curriculum'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'New students get the newest curriculum in effect when they start. Students already enrolled keep '
            'theirs until they graduate. You can change one student\'s curriculum on their profile.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: items == null
                  ? Center(
                      child: _error != null
                          ? Text(_error!, style: const TextStyle(color: AppColors.error))
                          : const CircularProgressIndicator(),
                    )
                  : shown.isEmpty
                      ? const Center(
                          child: Text('No curricula yet. Add one to start.', style: TextStyle(color: AppColors.textSecondary)))
                      : LayoutBuilder(
                          builder: (context, box) => SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: box.maxWidth),
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                  columnSpacing: 20,
                                  columns: const [
                                    DataColumn(label: Text('Program', style: TextStyle(fontWeight: FontWeight.w700))),
                                    DataColumn(label: Text('Curriculum', style: TextStyle(fontWeight: FontWeight.w700))),
                                    DataColumn(label: Text('Takes effect', style: TextStyle(fontWeight: FontWeight.w700))),
                                    DataColumn(numeric: true, label: Text('Subjects', style: TextStyle(fontWeight: FontWeight.w700))),
                                    DataColumn(numeric: true, label: Text('Students', style: TextStyle(fontWeight: FontWeight.w700))),
                                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
                                  ],
                                  rows: [
                                    for (final c in shown)
                                      DataRow(
                                        key: ValueKey('curriculum_${c.curriculumId}'),
                                        cells: [
                                          DataCell(Text(c.programCode ?? '${c.programId}',
                                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary))),
                                          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                            Text(c.name),
                                            if (c.isNewest) ...[
                                              const SizedBox(width: 6),
                                              StatusBadge.success(label: 'New students'),
                                            ],
                                          ])),
                                          DataCell(Text('SY ${c.effectiveSchoolYear}')),
                                          DataCell(Text('${c.subjectCount}')),
                                          DataCell(Text('${c.studentCount}')),
                                          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                            IconButton(
                                              key: ValueKey('import_${c.curriculumId}'),
                                              tooltip: 'Import subjects (CSV)',
                                              icon: const Icon(Icons.upload_file_outlined, size: 18, color: AppColors.primary),
                                              onPressed: () => _import(c),
                                            ),
                                            IconButton(
                                              key: ValueKey('edit_${c.curriculumId}'),
                                              tooltip: 'Edit',
                                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryHover),
                                              onPressed: () => _edit(c),
                                            ),
                                            IconButton(
                                              key: ValueKey('delete_${c.curriculumId}'),
                                              tooltip: c.subjectCount > 0 || c.studentCount > 0
                                                  ? 'Only empty curricula can be deleted'
                                                  : 'Delete',
                                              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                                              onPressed: c.subjectCount > 0 || c.studentCount > 0 ? null : () => _delete(c),
                                            ),
                                          ])),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Add or edit a curriculum: program, name and the school year it takes effect.
class _CurriculumDialog extends StatefulWidget {
  final CurriculumRepository repo;
  final List<AcademicProgramModel> programs;
  final CurriculumModel? existing;
  final int? programId;

  const _CurriculumDialog({required this.repo, required this.programs, this.existing, this.programId});

  @override
  State<_CurriculumDialog> createState() => _CurriculumDialogState();
}

class _CurriculumDialogState extends State<_CurriculumDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late int? _programId = widget.existing?.programId ?? widget.programId ?? widget.programs.firstOrNull?.programId;
  late int _year = widget.existing?.effectiveFromYear ?? DateTime.now().year;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<int> get _years {
    final last = DateTime.now().year + 3;
    final years = [for (var y = last; y >= 2000; y--) y];
    if (!years.contains(_year)) years.add(_year);
    return years;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _error = 'Give the curriculum a name.');
    if (_programId == null) return setState(() => _error = 'Choose a program.');
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final existing = widget.existing;
      if (existing == null) {
        await widget.repo.create(programId: _programId!, name: name, effectiveFromYear: _year);
      } else {
        await widget.repo.update(existing.curriculumId, name: name, effectiveFromYear: _year);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _message(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? 'Edit curriculum' : 'Add curriculum'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              key: const ValueKey('curriculum_program_field'),
              initialValue: _programId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Program', border: OutlineInputBorder()),
              items: [
                for (final p in widget.programs)
                  DropdownMenuItem(value: p.programId, child: Text('${p.programCode} – ${p.programName}', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: editing ? null : (v) => setState(() => _programId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('curriculum_name_field'),
              controller: _name,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. CHED 2026 curriculum',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              key: const ValueKey('curriculum_year_field'),
              initialValue: _year,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Takes effect in school year', border: OutlineInputBorder()),
              items: [for (final y in _years) DropdownMenuItem(value: y, child: Text('$y-${y + 1}'))],
              onChanged: (v) => setState(() => _year = v ?? _year),
            ),
            const SizedBox(height: 8),
            Text(
              'Students who start in SY $_year-${_year + 1} or later get this curriculum, unless a newer one takes effect.',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, key: const ValueKey('curriculum_dialog_error'), style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('save_curriculum_button'),
          onPressed: _saving ? null : _save,
          child: Text(editing ? 'Save' : 'Add curriculum'),
        ),
      ],
    );
  }
}

/// Choose a curriculum CSV, see what it would change (nothing is saved yet), then import it.
class CurriculumImportDialog extends StatefulWidget {
  final CurriculumRepository repo;
  final CurriculumModel curriculum;

  const CurriculumImportDialog({super.key, required this.repo, required this.curriculum});

  @override
  State<CurriculumImportDialog> createState() => _CurriculumImportDialogState();
}

class _CurriculumImportDialogState extends State<CurriculumImportDialog> {
  PickedFile? _file;
  CurriculumImportResult? _preview;
  bool _updateExisting = false;
  bool _busy = false;
  String? _error;

  Future<void> _choose() async {
    try {
      final file = await pickFile(accept: '.csv');
      if (file == null) return;
      setState(() => _file = file);
      await _check();
    } catch (e) {
      setState(() => _error = _message(e));
    }
  }

  Future<CurriculumImportResult?> _run({required bool dryRun}) async {
    final file = _file;
    if (file == null) return null;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      return await widget.repo.importCsv(
        curriculumId: widget.curriculum.curriculumId,
        fileName: file.name,
        bytes: file.bytes,
        dryRun: dryRun,
        updateExisting: _updateExisting,
      );
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    final result = await _run(dryRun: true);
    if (mounted) setState(() => _preview = result);
  }

  Future<void> _import() async {
    final result = await _run(dryRun: false);
    if (result == null || !mounted) return;
    if (result.errors.isNotEmpty) return setState(() => _preview = result);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(true);
    messenger.showSnackBar(SnackBar(
      backgroundColor: AppColors.success,
      content: Text('Imported into ${widget.curriculum.name}: ${result.create} new, '
          '${_updateExisting ? '${result.update} updated, ' : ''}${result.unchanged} unchanged.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    final canImport = p != null && p.errors.isEmpty && !_busy && (p.create > 0 || p.prerequisitesToAdd > 0 ||
        p.corequisitesToAdd > 0 || (_updateExisting && p.update > 0));
    return AlertDialog(
      title: Text('Import subjects into ${widget.curriculum.programCode ?? ''} ${widget.curriculum.name}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose the curriculum CSV. You will see what changes before anything is saved.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(children: [
                OutlinedButton.icon(
                  key: const ValueKey('choose_csv_button'),
                  onPressed: _busy ? null : _choose,
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: Text(_file == null ? 'Choose CSV file' : 'Choose another file'),
                ),
                const SizedBox(width: 12),
                if (_file != null) Expanded(child: Text(_file!.name, overflow: TextOverflow.ellipsis)),
              ]),
              CheckboxListTile(
                key: const ValueKey('update_existing_checkbox'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _updateExisting,
                title: const Text('Also update subjects that are already in this curriculum'),
                onChanged: _busy
                    ? null
                    : (v) {
                        setState(() => _updateExisting = v ?? false);
                        if (_file != null) _check();
                      },
              ),
              if (_busy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
              if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.error)),
              if (p != null && !_busy) _summary(p),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('run_import_button'),
          onPressed: canImport ? _import : null,
          child: const Text('Import'),
        ),
      ],
    );
  }

  Widget _summary(CurriculumImportResult p) {
    Widget line(String text, {Color? color}) =>
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(text, style: TextStyle(fontSize: 13, color: color)));
    return Column(
      key: const ValueKey('import_summary'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(p.errors.isEmpty ? 'Ready to import:' : 'Fix these first, then choose the file again:',
            style: TextStyle(fontWeight: FontWeight.w700, color: p.errors.isEmpty ? AppColors.textPrimary : AppColors.error)),
        if (p.errors.isEmpty) ...[
          line('${p.create} new subject(s)'),
          line(_updateExisting
              ? '${p.update} subject(s) updated'
              : '${p.update} subject(s) differ from the file and will be left as they are'),
          line('${p.unchanged} subject(s) already the same'),
          line('${p.prerequisitesToAdd} prerequisite(s) and ${p.corequisitesToAdd} corequisite(s) to add'),
        ],
        for (final e in p.errors.take(30))
          line('${e.row > 0 ? 'Row ${e.row}: ' : ''}${e.message}', color: AppColors.error),
        if (p.errors.length > 30) line('…and ${p.errors.length - 30} more.', color: AppColors.error),
        if (p.warnings.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Notes', style: TextStyle(fontWeight: FontWeight.w700)),
          for (final w in p.warnings.take(10)) line('${w.row > 0 ? 'Row ${w.row}: ' : ''}${w.message}', color: AppColors.textSecondary),
          if (p.warnings.length > 10) line('…and ${p.warnings.length - 10} more.', color: AppColors.textSecondary),
        ],
      ],
    );
  }
}
