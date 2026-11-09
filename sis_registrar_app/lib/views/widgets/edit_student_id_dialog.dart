import 'package:flutter/material.dart';

import '../../injection.dart';
import '../../repositories/grading_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';

/// Same rule as the API: digits only (spaces and dashes are removed), 4 to 15 digits, empty clears it.
String? studentIdProblem(String raw) {
  final clean = raw.replaceAll(RegExp(r'[\s-]'), '');
  if (clean.isEmpty) return null;
  if (!RegExp(r'^\d+$').hasMatch(clean)) return 'Use digits only, e.g. 25060208.';
  if (clean.length < 4 || clean.length > 15) return 'A student ID has 4 to 15 digits.';
  return null;
}

/// Sets or clears a student's DBTC student ID. Returns the saved number through [onSaved].
class EditStudentIdDialog extends StatefulWidget {
  final String userId;
  final String studentName;
  final String? current;
  final Future<String?> Function(String userId, String? number)? save;

  const EditStudentIdDialog({super.key, required this.userId, required this.studentName, this.current, this.save});

  /// Returns the new number ('' when cleared), or null when cancelled.
  static Future<String?> show(BuildContext context,
          {required String userId, required String studentName, String? current}) =>
      showDialog<String>(
        context: context,
        builder: (_) => EditStudentIdDialog(userId: userId, studentName: studentName, current: current),
      );

  @override
  State<EditStudentIdDialog> createState() => _EditStudentIdDialogState();
}

class _EditStudentIdDialogState extends State<EditStudentIdDialog> {
  late final _ctrl = TextEditingController(text: widget.current ?? '');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = studentIdProblem(_ctrl.text);
    if (problem != null) return setState(() => _error = problem);
    final clean = _ctrl.text.replaceAll(RegExp(r'[\s-]'), '');
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final save = widget.save ?? getIt<UserSearchRepository>().updateStudentId;
      final saved = await save(widget.userId, clean.isEmpty ? null : clean);
      if (mounted) Navigator.of(context).pop(saved ?? '');
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
    return AlertDialog(
      title: const Text('Student ID'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('student_id_field'),
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Student ID',
                hintText: 'e.g. 25060208',
                helperText: 'Leave empty if the school has not assigned one yet.',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _saving ? null : _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('save_student_id'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
