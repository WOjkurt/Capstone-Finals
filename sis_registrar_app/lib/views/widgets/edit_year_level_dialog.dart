import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../injection.dart';
import '../../repositories/grading_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';

/// Dialog for the Registrar to change a student's year level.
/// Mirrors [EditLrnDialog] in structure and error handling.
class EditYearLevelDialog extends StatefulWidget {
  final String userId;
  final String studentName;
  final int? currentYearLevel;
  final ValueChanged<int>? onSaved;

  const EditYearLevelDialog({
    super.key,
    required this.userId,
    required this.studentName,
    this.currentYearLevel,
    this.onSaved,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String userId,
    required String studentName,
    int? currentYearLevel,
    ValueChanged<int>? onSaved,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => EditYearLevelDialog(
        userId: userId,
        studentName: studentName,
        currentYearLevel: currentYearLevel,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<EditYearLevelDialog> createState() => _EditYearLevelDialogState();
}

class _EditYearLevelDialogState extends State<EditYearLevelDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentYearLevel?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validateYearLevel(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Year level is required.';
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return 'Year level must be a number.';
    }
    if (parsed < 1 || parsed > 5) {
      return 'Year level must be between 1 and 5.';
    }
    return null;
  }

  Future<void> _handleSave() async {
    setState(() => _serverError = null);
    if (!_formKey.currentState!.validate()) return;

    final parsed = int.parse(_controller.text.trim());
    setState(() => _isSaving = true);

    try {
      final repo = getIt<UserSearchRepository>();
      await repo.updateStudentYearLevel(widget.userId, parsed);
      if (mounted) {
        widget.onSaved?.call(parsed);
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Year level updated to Year $parsed.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.school_outlined,
              color: Color(0xFF7C3AED),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Student Year Level',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  widget.studentName,
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
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Year Level (1 – 5)',
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: '1, 2, 3, 4 or 5',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.bar_chart_rounded, size: 20),
                  helperText: 'Valid values: 1 (first year) to 5 (fifth year).',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: _validateYearLevel,
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
              : const Text('Save Year Level'),
        ),
      ],
    );
  }
}
