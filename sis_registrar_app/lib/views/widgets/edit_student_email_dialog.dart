import 'package:flutter/material.dart';

import '../../injection.dart';
import '../../repositories/records_import_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';

/// Sets the school email of a student imported from Excel who hasn't signed in yet. Their first sign-in with this
/// email makes the account theirs. Returns the saved email ('' when cleared), or null when cancelled.
class EditStudentEmailDialog extends StatefulWidget {
  final String userId;
  final String studentName;
  final String? current;
  final Future<String> Function(String userId, String email)? save;

  const EditStudentEmailDialog({super.key, required this.userId, required this.studentName, this.current, this.save});

  static Future<String?> show(BuildContext context, {required String userId, required String studentName, String? current}) =>
      showDialog<String>(
          context: context, builder: (_) => EditStudentEmailDialog(userId: userId, studentName: studentName, current: current));

  @override
  State<EditStudentEmailDialog> createState() => _EditStudentEmailDialogState();
}

class _EditStudentEmailDialogState extends State<EditStudentEmailDialog> {
  late final _ctrl = TextEditingController(text: widget.current ?? '');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _ctrl.text.trim().toLowerCase();
    if (email.isNotEmpty && !RegExp(r'^[^@\s]+@dbtc-cebu\.edu\.ph$').hasMatch(email)) {
      return setState(() => _error = 'Enter a school email that ends with @dbtc-cebu.edu.ph.');
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final save = widget.save ?? getIt<RecordsImportRepository>().setSchoolEmail;
      final saved = await save(widget.userId, email);
      if (mounted) Navigator.of(context).pop(saved);
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
      title: const Text('School email'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'This student was imported and hasn\'t signed in yet. When they first sign in with this email, '
              'the account and its records become theirs.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('student_email_field'),
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'School email',
                hintText: 'firstname.lastname@dbtc-cebu.edu.ph',
                errorText: _error,
                errorMaxLines: 3,
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
          key: const ValueKey('save_student_email'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
