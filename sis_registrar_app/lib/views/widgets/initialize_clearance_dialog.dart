import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/grading_models.dart';
import '../../models/setup_models.dart';
import '../../repositories/enrollment_repository.dart';
import '../../theme/app_theme.dart';

class InitializeClearanceDialog extends StatefulWidget {
  final UserSearchResultModel student;
  final List<String> existingTermIds;
  final void Function(String termId, bool isCleared) onConfirmed;

  const InitializeClearanceDialog({
    super.key,
    required this.student,
    required this.existingTermIds,
    required this.onConfirmed,
  });

  static Future<void> show(
    BuildContext context, {
    required UserSearchResultModel student,
    required List<String> existingTermIds,
    required void Function(String termId, bool isCleared) onConfirmed,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => InitializeClearanceDialog(
        student: student,
        existingTermIds: existingTermIds,
        onConfirmed: onConfirmed,
      ),
    );
  }

  @override
  State<InitializeClearanceDialog> createState() =>
      _InitializeClearanceDialogState();
}

class _InitializeClearanceDialogState extends State<InitializeClearanceDialog> {
  List<AcademicTermModel>? _availableTerms;
  bool _isLoadingTerms = true;
  String? _selectedTermId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTerms();
  }

  Future<void> _fetchTerms() async {
    setState(() {
      _isLoadingTerms = true;
      _error = null;
    });

    try {
      final repo = getIt<AcademicSetupRepository>();
      final allTerms = await repo.getTerms();
      final filtered = allTerms
          .where((t) => !widget.existingTermIds.contains(t.termId))
          .toList();

      if (mounted) {
        setState(() {
          _availableTerms = filtered;
          _isLoadingTerms = false;
          if (filtered.isNotEmpty) {
            _selectedTermId = filtered.first.termId;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoadingTerms = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_moderator_outlined,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Initialize Clearance Record',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.student.fullName.isNotEmpty
                              ? widget.student.fullName
                              : widget.student.email,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              if (_isLoadingTerms)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Failed to load academic terms: $_error',
                    style: const TextStyle(color: Color(0xFFDC2626)),
                  ),
                )
              else if (_availableTerms == null || _availableTerms!.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF64748B), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'All available academic terms already have a clearance record initialized for this student.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                const Text(
                  'Select Academic Term',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTermId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  items: _availableTerms!.map((term) {
                    return DropdownMenuItem<String>(
                      value: term.termId,
                      child: Text(
                        term.label,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedTermId = val;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined,
                          color: Color(0xFFD97706), size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'The new clearance record will default to Hold (Uncleared) status. You can toggle it to Cleared once academic and financial requirements are verified.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Initialize Clearance',
                          overflow: TextOverflow.ellipsis),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: (_availableTerms == null ||
                              _availableTerms!.isEmpty ||
                              _selectedTermId == null)
                          ? null
                          : () {
                              final termId = _selectedTermId!;
                              Navigator.of(context).pop();
                              widget.onConfirmed(termId, false);
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
