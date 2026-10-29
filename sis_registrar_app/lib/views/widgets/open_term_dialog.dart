import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/class_models.dart';
import '../../models/setup_models.dart';
import '../../repositories/class_repository.dart';
import '../../theme/app_theme.dart';

class OpenTermDialog extends StatefulWidget {
  final List<AcademicTermModel> terms;
  final List<AcademicProgramModel> programs;
  final String? initialTermId;
  final ValueChanged<OpenTermResultModel>? onComplete;

  const OpenTermDialog({
    super.key,
    required this.terms,
    required this.programs,
    this.initialTermId,
    this.onComplete,
  });

  static Future<OpenTermResultModel?> show(
    BuildContext context, {
    required List<AcademicTermModel> terms,
    required List<AcademicProgramModel> programs,
    String? initialTermId,
    ValueChanged<OpenTermResultModel>? onComplete,
  }) {
    return showDialog<OpenTermResultModel>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => OpenTermDialog(
        terms: terms,
        programs: programs,
        initialTermId: initialTermId,
        onComplete: onComplete,
      ),
    );
  }

  @override
  State<OpenTermDialog> createState() => _OpenTermDialogState();
}

class _OpenTermDialogState extends State<OpenTermDialog> {
  String? _selectedTermId;
  int? _selectedProgramId;
  int? _selectedYearLevel; // null = All
  final TextEditingController _sectionsCtrl = TextEditingController(text: '1');

  bool _isPreviewLoading = false;
  bool _isConfirmLoading = false;
  String? _errorMessage;
  OpenTermResultModel? _previewResult;

  @override
  void initState() {
    super.initState();
    // Initialize Term
    if (widget.terms.isNotEmpty) {
      if (widget.initialTermId != null &&
          widget.terms.any((t) => t.termId == widget.initialTermId)) {
        _selectedTermId = widget.initialTermId;
      } else {
        final active = widget.terms.firstWhere(
          (t) => t.isActive,
          orElse: () => widget.terms.first,
        );
        _selectedTermId = active.termId;
      }
    }

    // Initialize Program
    if (widget.programs.isNotEmpty) {
      _selectedProgramId = widget.programs.first.programId;
    }
  }

  @override
  void dispose() {
    _sectionsCtrl.dispose();
    super.dispose();
  }

  void _clearPreview() {
    if (_previewResult != null) {
      setState(() {
        _previewResult = null;
        _errorMessage = null;
      });
    }
  }

  Future<void> _runPreview() async {
    if (_selectedTermId == null || _selectedProgramId == null) {
      setState(() => _errorMessage = 'Please select a term and program.');
      return;
    }

    final sections = int.tryParse(_sectionsCtrl.text.trim()) ?? 1;

    if (sections < 1 || sections > 6) {
      setState(() => _errorMessage = 'Sections must be between 1 and 6.');
      return;
    }

    setState(() {
      _isPreviewLoading = true;
      _errorMessage = null;
      _previewResult = null;
    });

    try {
      final repo = getIt<ClassRepository>();
      final result = await repo.openTerm(
        programId: _selectedProgramId!,
        termId: _selectedTermId!,
        yearLevel: _selectedYearLevel,
        sections: sections,
        dryRun: true,
      );

      if (mounted) {
        setState(() {
          _previewResult = result;
          _isPreviewLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('ApiException: ', '');
          _isPreviewLoading = false;
        });
      }
    }
  }

  Future<void> _runConfirm() async {
    if (_selectedTermId == null || _selectedProgramId == null) return;

    final sections = int.tryParse(_sectionsCtrl.text.trim()) ?? 1;

    setState(() {
      _isConfirmLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = getIt<ClassRepository>();
      final result = await repo.openTerm(
        programId: _selectedProgramId!,
        termId: _selectedTermId!,
        yearLevel: _selectedYearLevel,
        sections: sections,
        dryRun: false,
      );

      if (mounted) {
        setState(() => _isConfirmLoading = false);
        final messenger = ScaffoldMessenger.of(context);
        if (result.createdCount > 0) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Opened ${result.createdCount} classes'),
              backgroundColor: AppColors.accentGreenDark,
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('No new classes were created. They already exist.'),
              backgroundColor: Color(0xFF475569),
            ),
          );
        }
        widget.onComplete?.call(result);
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('ApiException: ', '');
          _isConfirmLoading = false;
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
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Title & Close ───────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_mode_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Open Classes for Term',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Automatically generate scheduled class sections for curriculum subjects.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 28, color: AppColors.border),

              // ── Form Inputs ──────────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Term Dropdown
                      const Text(
                        'Academic Term',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        key: const Key('open_term_dropdown_term'),
                        isExpanded: true,
                        initialValue: _selectedTermId,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: widget.terms.map((t) {
                          return DropdownMenuItem<String>(
                            value: t.termId,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    t.label,
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (t.isActive) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentGreenLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Active',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.accentGreenDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedTermId = val);
                          _clearPreview();
                        },
                      ),
                      const SizedBox(height: 14),

                      // Program Dropdown
                      const Text(
                        'Academic Program',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        key: const Key('open_term_dropdown_program'),
                        isExpanded: true,
                        initialValue: _selectedProgramId,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: widget.programs.map((p) {
                          return DropdownMenuItem<int>(
                            value: p.programId,
                            child: Text(
                              '${p.programCode} – ${p.programName}',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedProgramId = val);
                          _clearPreview();
                        },
                      ),
                      const SizedBox(height: 14),

                      // Year Level Filter & Sections per year
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Year Level',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<int?>(
                                  key: const Key('open_term_dropdown_year_level'),
                                  isExpanded: true,
                                  initialValue: _selectedYearLevel,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: const [
                                    DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('All Year Levels', style: TextStyle(fontSize: 13)),
                                    ),
                                    DropdownMenuItem<int?>(
                                      value: 1,
                                      child: Text('1st Year', style: TextStyle(fontSize: 13)),
                                    ),
                                    DropdownMenuItem<int?>(
                                      value: 2,
                                      child: Text('2nd Year', style: TextStyle(fontSize: 13)),
                                    ),
                                    DropdownMenuItem<int?>(
                                      value: 3,
                                      child: Text('3rd Year', style: TextStyle(fontSize: 13)),
                                    ),
                                    DropdownMenuItem<int?>(
                                      value: 4,
                                      child: Text('4th Year', style: TextStyle(fontSize: 13)),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    setState(() => _selectedYearLevel = val);
                                    _clearPreview();
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sections (A, B…)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  key: const Key('open_term_input_sections'),
                                  controller: _sectionsCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText: '1',
                                  ),
                                  onChanged: (_) => _clearPreview(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Error Banner
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Preview Results Card
                      if (_previewResult != null) ...[
                        // Inactive Term Warning
                        if (!_previewResult!.termIsActive) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              border: Border.all(color: const Color(0xFFFCD34D)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Warning: The selected academic term is not active.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (_previewResult!.plannedCount == 0 && _previewResult!.skippedExisting > 0)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 20, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'All classes for this term are already open (${_previewResult!.skippedExisting} existing). Nothing to create.',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (_previewResult!.plannedCount == 0 && _previewResult!.skippedExisting == 0)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline, size: 20, color: Color(0xFF64748B)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'No subjects match this program, term and year level.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (_previewResult!.skippedNoDefaultSemester > 0) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          '${_previewResult!.skippedNoDefaultSemester} subjects have no default semester set.',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${_previewResult!.plannedCount} classes will be created, ${_previewResult!.skippedExisting} will be skipped (already exist).',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_previewResult!.skippedNoDefaultSemester > 0) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.remove_circle_outline, size: 16, color: Color(0xFF64748B)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${_previewResult!.skippedNoDefaultSemester} curriculum subjects skipped (no default semester assigned).',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (_previewResult!.perYear.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Classes by Year Level:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: _previewResult!.perYear.entries.map((e) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Text(
                                          'Year ${e.key}: ${e.value} classes',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                                if (_previewResult!.sampleClassNames.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Preview of class sections to be created:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: _previewResult!.sampleClassNames.map((name) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFB9D7F2)),
                                        ),
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Action Buttons ───────────────────────────────────────────
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: (_isPreviewLoading || _isConfirmLoading)
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  // Preview Button
                  ElevatedButton.icon(
                    key: const Key('open_term_btn_preview'),
                    onPressed: (_isPreviewLoading || _isConfirmLoading) ? null : _runPreview,
                    icon: _isPreviewLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.remove_red_eye_outlined, size: 16),
                    label: Text(_isPreviewLoading ? 'Previewing...' : 'Preview'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF475569),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  // Confirm & Open Classes Button
                  ElevatedButton.icon(
                    key: const Key('open_term_btn_confirm'),
                    onPressed: (_previewResult == null ||
                            _previewResult!.plannedCount == 0 ||
                            _isConfirmLoading ||
                            _isPreviewLoading)
                        ? null
                        : _runConfirm,
                    icon: _isConfirmLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(_isConfirmLoading ? 'Opening Classes...' : 'Confirm & Open Classes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      disabledBackgroundColor: const Color(0xFFCBD5E1),
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
