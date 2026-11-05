import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/record_models.dart';
import '../../models/setup_models.dart';
import '../../repositories/enrollment_repository.dart';
import '../../repositories/student_record_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';

/// Moves a student to another program. Returns the result, or null when cancelled.
class ShiftProgramDialog extends StatefulWidget {
  final String userId;
  final String studentName;
  final int? currentProgramId;
  final String? currentProgramCode;

  const ShiftProgramDialog({
    super.key,
    required this.userId,
    required this.studentName,
    this.currentProgramId,
    this.currentProgramCode,
  });

  static Future<ShiftResult?> show(
    BuildContext context, {
    required String userId,
    required String studentName,
    int? currentProgramId,
    String? currentProgramCode,
  }) =>
      showDialog<ShiftResult>(
        context: context,
        builder: (_) => ShiftProgramDialog(
          userId: userId,
          studentName: studentName,
          currentProgramId: currentProgramId,
          currentProgramCode: currentProgramCode,
        ),
      );

  @override
  State<ShiftProgramDialog> createState() => _ShiftProgramDialogState();
}

class _ShiftProgramDialogState extends State<ShiftProgramDialog> {
  final _reason = TextEditingController();
  List<AcademicProgramModel>? _programs;
  int? _programId;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String _message(Object e) => e is ApiException ? e.message : e.toString();

  Future<void> _load() async {
    try {
      final programs = await getIt<AcademicSetupRepository>().getPrograms();
      if (mounted) setState(() => _programs = programs.where((p) => p.programId != widget.currentProgramId).toList());
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  Future<void> _save() async {
    if (_programId == null) {
      setState(() => _error = 'Choose the new program.');
      return;
    }
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Give a reason for the shift.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await getIt<StudentRecordRepository>().shiftProgram(widget.userId, _programId!, _reason.text.trim());
      if (mounted) Navigator.of(context).pop(result);
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
    final programs = _programs;
    return AlertDialog(
      title: Text('Shift ${widget.studentName}'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Current program: ${widget.currentProgramCode ?? 'None'}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (programs == null && _error == null)
              const LinearProgressIndicator()
            else
              DropdownButtonFormField<int>(
                key: const ValueKey('shift_program_dropdown'),
                initialValue: _programId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'New program *', isDense: true, border: OutlineInputBorder()),
                items: [
                  for (final p in programs ?? const <AcademicProgramModel>[])
                    DropdownMenuItem(
                      value: p.programId,
                      child: Text('${p.programCode} — ${p.programName}', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _programId = v),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('shift_reason_field'),
              controller: _reason,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Reason *',
                hintText: 'e.g. Student request, approved by the College Head',
                border: OutlineInputBorder(),
              ),
            ),
            const Text(
              'Subjects and grades already on record stay on the transcript. Afterwards, enter the credits for the new '
              'program on the Credits tab, and check the year level.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('confirm_shift_button'),
          onPressed: _saving ? null : _save,
          child: const Text('Shift program'),
        ),
      ],
    );
  }
}
