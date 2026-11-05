import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Asks for a reason before a change to a student's load (drop, withdraw, re-enroll, add after enrollment).
/// Returns the trimmed reason, '' when an optional reason is left empty, or null when cancelled.
class ReasonDialog extends StatefulWidget {
  final String title;
  final String message;
  final String label;
  final String? hint;
  final String confirmLabel;
  final Color confirmColor;
  final bool required;

  const ReasonDialog({
    super.key,
    required this.title,
    required this.message,
    this.label = 'Reason',
    this.hint,
    required this.confirmLabel,
    this.confirmColor = AppColors.primary,
    this.required = true,
  });

  static Future<String?> ask(
    BuildContext context, {
    required String title,
    required String message,
    String label = 'Reason',
    String? hint,
    required String confirmLabel,
    Color confirmColor = AppColors.primary,
    bool required = true,
  }) =>
      showDialog<String>(
        context: context,
        builder: (_) => ReasonDialog(
          title: title,
          message: message,
          label: label,
          hint: hint,
          confirmLabel: confirmLabel,
          confirmColor: confirmColor,
          required: required,
        ),
      );

  @override
  State<ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<ReasonDialog> {
  // Owned by this widget so it outlives the dialog's closing animation.
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final text = _controller.text.trim();
    if (widget.required && text.isEmpty) {
      setState(() => _error = 'A reason is required.');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message, style: const TextStyle(fontSize: 14, height: 1.4)),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('change_reason_field'),
              controller: _controller,
              autofocus: true,
              maxLines: 2,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: widget.required ? '${widget.label} *' : '${widget.label} (optional)',
                hintText: widget.hint,
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
            const Text('Recorded with your name and printed on the Adding/Dropping form.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('confirm_change_button'),
          style: FilledButton.styleFrom(backgroundColor: widget.confirmColor),
          onPressed: _confirm,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
