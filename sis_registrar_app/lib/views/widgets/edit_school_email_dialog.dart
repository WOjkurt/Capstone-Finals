import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../repositories/enrollment_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';

/// Dialog for the Registrar to set, edit, or clear a student's school email on an application.
/// Mirrors [EditLrnDialog] and [EditYearLevelDialog] in structure and error handling.
class EditSchoolEmailDialog extends StatefulWidget {
  final String applicationId;
  final String applicantName;
  final String? currentSchoolEmail;
  final ValueChanged<String?>? onSaved;
  final VoidCallback? onUpdated;

  const EditSchoolEmailDialog({
    super.key,
    required this.applicationId,
    required this.applicantName,
    this.currentSchoolEmail,
    this.onSaved,
    this.onUpdated,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String applicationId,
    required String applicantName,
    String? currentSchoolEmail,
    ValueChanged<String?>? onSaved,
    VoidCallback? onUpdated,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => EditSchoolEmailDialog(
        applicationId: applicationId,
        applicantName: applicantName,
        currentSchoolEmail: currentSchoolEmail,
        onSaved: onSaved,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<EditSchoolEmailDialog> createState() => _EditSchoolEmailDialogState();
}

class _EditSchoolEmailDialogState extends State<EditSchoolEmailDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentSchoolEmail ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validateSchoolEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Empty means clear school email
    }
    final trimmed = value.trim();
    if (trimmed.contains(' ')) {
      return 'Email address cannot contain spaces.';
    }

    final atIndex = trimmed.indexOf('@');
    final lastAtIndex = trimmed.lastIndexOf('@');
    if (atIndex <= 0 || atIndex != lastAtIndex || atIndex == trimmed.length - 1) {
      return 'Please enter a valid email address.';
    }

    final domain = trimmed.substring(atIndex + 1);
    if (domain.toLowerCase() != 'dbtc-cebu.edu.ph') {
      return 'School email domain must be exactly @dbtc-cebu.edu.ph';
    }

    return null;
  }

  Future<void> _handleSave() async {
    setState(() => _serverError = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final raw = _controller.text.trim();
    final clean = raw.isEmpty ? null : raw.toLowerCase();

    setState(() => _isSaving = true);

    try {
      final repo = getIt<EnrollmentRepository>();
      await repo.updateApplicationSchoolEmail(widget.applicationId, clean);
      if (mounted) {
        widget.onSaved?.call(clean);
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(clean == null
                ? 'School email cleared successfully.'
                : 'School email updated successfully ($clean).'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _serverError = e is ApiException
              ? e.message
              : 'Failed to update school email: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCurrent = widget.currentSchoolEmail != null &&
        widget.currentSchoolEmail!.trim().isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.alternate_email,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Application School Email',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.applicantName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  ),
                ],
              ),
            ),

            // Form Body
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Server Error Banner
                    if (_serverError != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _serverError!,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const Text(
                      'School Email Address (@dbtc-cebu.edu.ph)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _controller,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isSaving,
                      decoration: InputDecoration(
                        hintText: 'e.g. jdelacruz@dbtc-cebu.edu.ph',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        helperText: 'Leave blank to clear the school email.',
                        helperStyle: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                        prefixIcon: const Icon(Icons.email_outlined, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _controller.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      validator: _validateSchoolEmail,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(hasCurrent && _controller.text.trim().isEmpty
                            ? 'Clear Email'
                            : 'Save Email'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
