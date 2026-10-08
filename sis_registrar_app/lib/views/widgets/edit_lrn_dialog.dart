import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../repositories/enrollment_repository.dart';
import '../../repositories/grading_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';

class EditLrnDialog extends StatefulWidget {
  final String title;
  final String targetName;
  final String? initialLrn;
  final Future<void> Function(String? cleanLrn) onSave;
  final ValueChanged<String?>? onSaved;
  final VoidCallback? onUpdated;

  const EditLrnDialog({
    super.key,
    required this.title,
    required this.targetName,
    this.initialLrn,
    required this.onSave,
    this.onSaved,
    this.onUpdated,
  });

  static Future<bool?> showForStudent(
    BuildContext context, {
    required String userId,
    required String studentName,
    String? currentLrn,
    ValueChanged<String?>? onSaved,
    VoidCallback? onUpdated,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => EditLrnDialog(
        title: 'Edit Student Profile LRN',
        targetName: studentName,
        initialLrn: currentLrn,
        onSave: (cleanLrn) async {
          final repo = getIt<UserSearchRepository>();
          await repo.updateStudentLrn(userId, cleanLrn);
        },
        onSaved: onSaved,
        onUpdated: onUpdated,
      ),
    );
  }

  static Future<bool?> showForApplication(
    BuildContext context, {
    required String applicationId,
    required String applicantName,
    String? currentLrn,
    ValueChanged<String?>? onSaved,
    VoidCallback? onUpdated,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => EditLrnDialog(
        title: 'Edit Application Form LRN',
        targetName: applicantName,
        initialLrn: currentLrn,
        onSave: (cleanLrn) async {
          final repo = getIt<EnrollmentRepository>();
          await repo.updateApplicationLrn(applicationId, cleanLrn);
        },
        onSaved: onSaved,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<EditLrnDialog> createState() => _EditLrnDialogState();
}

class _EditLrnDialogState extends State<EditLrnDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialLrn ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validateLrn(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Empty means clear LRN
    }
    final stripped = value.replaceAll(RegExp(r'[\s\-]'), '');
    if (!RegExp(r'^\d+$').hasMatch(stripped)) {
      return 'LRN must contain digits only. Spaces and dashes are ignored.';
    }
    if (stripped.length != 12) {
      return 'LRN must be exactly 12 digits (currently ${stripped.length} digits).';
    }
    return null;
  }

  Future<void> _handleSave() async {
    setState(() => _serverError = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final raw = _controller.text.trim();
    final clean = raw.isEmpty ? null : raw.replaceAll(RegExp(r'[\s\-]'), '');

    setState(() => _isSaving = true);

    try {
      await widget.onSave(clean);
      if (mounted) {
        widget.onSaved?.call(clean);
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(clean == null
                ? 'LRN cleared successfully.'
                : 'LRN updated successfully ($clean).'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        String message = e.toString();
        if (e is ApiException) {
          message = e.message;
        } else if (message.startsWith('Exception: ')) {
          message = message.substring('Exception: '.length);
        }
        setState(() {
          _isSaving = false;
          _serverError = message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.badge_outlined,
              color: Color(0xFFD97706),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  widget.targetName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Learner Reference Number (LRN)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g. 123456789012',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _controller.clear()),
                        )
                      : null,
                  helperText:
                      'Exactly 12 digits (numbers only). Spaces and dashes are ignored. Leave blank to remove.',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: _validateLrn,
                onChanged: (_) => setState(() {}),
              ),
              if (_serverError != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _serverError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save LRN'),
        ),
      ],
    );
  }
}
