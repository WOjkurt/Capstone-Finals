import 'package:flutter/material.dart';

import '../../injection.dart';
import '../../models/curriculum_models.dart';
import '../../repositories/curriculum_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';

/// The curriculum a student follows, shown in their profile header. Tap to put them on another curriculum
/// of their program (for example a shiftee or a returning student who must follow the new curriculum).
class StudentCurriculumChip extends StatefulWidget {
  final String userId;
  final String studentName;
  final CurriculumRepository? repository;

  /// Called after the curriculum was changed (the evaluation and suggestions depend on it).
  final VoidCallback? onChanged;

  const StudentCurriculumChip({super.key, required this.userId, required this.studentName, this.repository, this.onChanged});

  @override
  State<StudentCurriculumChip> createState() => _StudentCurriculumChipState();
}

class _StudentCurriculumChipState extends State<StudentCurriculumChip> {
  CurriculumRepository? get _repo =>
      widget.repository ?? (getIt.isRegistered<CurriculumRepository>() ? getIt<CurriculumRepository>() : null);
  StudentCurriculumModel? _current;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = _repo;
    if (repo == null) return;
    try {
      final c = await repo.forStudent(widget.userId);
      if (mounted) setState(() => _current = c);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _change() async {
    final repo = _repo;
    final current = _current;
    if (repo == null || current == null) return;
    if (current.programId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Set the student\'s program first.')));
      return;
    }
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangeCurriculumDialog(repo: repo, userId: widget.userId, studentName: widget.studentName, current: current),
    );
    if (changed == true) {
      await _load();
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _current;
    if (_repo == null || (c == null && !_failed)) return const SizedBox.shrink();
    final text = _failed
        ? 'Curriculum unavailable'
        : c!.name == null
            ? 'No curriculum'
            : 'Curriculum: ${c.name}';
    final warn = _failed || c?.name == null;
    return InkWell(
      key: const ValueKey('profile_curriculum'),
      onTap: _failed ? null : _change,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers_outlined, size: 14, color: warn ? const Color(0xFFB45309) : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(text,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: warn ? const Color(0xFFB45309) : const Color(0xFF334155))),
            if (!_failed) ...[
              const SizedBox(width: 5),
              const Icon(Icons.edit_outlined, size: 13, color: AppColors.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChangeCurriculumDialog extends StatefulWidget {
  final CurriculumRepository repo;
  final String userId;
  final String studentName;
  final StudentCurriculumModel current;

  const _ChangeCurriculumDialog({required this.repo, required this.userId, required this.studentName, required this.current});

  @override
  State<_ChangeCurriculumDialog> createState() => _ChangeCurriculumDialogState();
}

class _ChangeCurriculumDialogState extends State<_ChangeCurriculumDialog> {
  List<CurriculumModel>? _options;
  late String? _picked = widget.current.curriculumId;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.repo.list(programId: widget.current.programId).then(
          (list) => mounted ? setState(() => _options = list) : null,
          onError: (Object e) => mounted ? setState(() => _error = e is ApiException ? e.message : e.toString()) : null,
        );
  }

  Future<void> _save() async {
    final picked = _picked;
    if (picked == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repo.setForStudent(widget.userId, picked);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is ApiException ? e.message : e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return AlertDialog(
      title: const Text('Change curriculum'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.studentName} keeps their curriculum until they graduate. Change it only when the student '
              'must follow another one, for example after shifting or returning from a leave.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (options == null && _error == null) const Center(child: CircularProgressIndicator()),
            if (options != null)
              RadioGroup<String>(
                groupValue: _picked,
                onChanged: (v) => setState(() => _picked = v),
                child: Column(
                  children: [
                    for (final c in options)
                      RadioListTile<String>(
                        key: ValueKey('pick_${c.curriculumId}'),
                        value: c.curriculumId,
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.name),
                        subtitle: Text('From SY ${c.effectiveSchoolYear} • ${c.subjectCount} subjects'
                            '${c.curriculumId == widget.current.curriculumId ? ' • current' : ''}'),
                      ),
                  ],
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('save_student_curriculum'),
          onPressed: _saving || _picked == null || _picked == widget.current.curriculumId ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
