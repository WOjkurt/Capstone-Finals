import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth_bloc.dart';
import '../blocs/grades_bloc.dart';
import '../injection.dart';
import '../models/class_models.dart';
import '../models/grading_models.dart';
import '../repositories/class_repository.dart';
import '../repositories/grading_repository.dart';
import '../theme/app_theme.dart';
import 'widgets/page_header.dart';
import 'widgets/status_badge.dart';

class GradesView extends StatefulWidget {
  final AuthenticatedState auth;
  final String? initialClassId;

  const GradesView({
    super.key,
    required this.auth,
    this.initialClassId,
  });

  @override
  State<GradesView> createState() => _GradesViewState();
}

class _GradesViewState extends State<GradesView> {
  List<ClassModel> _classes = [];
  bool _isLoadingClasses = true;
  String? _classesError;
  ClassModel? _selectedClass;

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    setState(() {
      _isLoadingClasses = true;
      _classesError = null;
    });

    try {
      final list = await getIt<ClassRepository>().getMyClasses(
        teacherUserId: widget.auth.userId,
      );

      if (!mounted) return;

      setState(() {
        _classes = list;
        _isLoadingClasses = false;

        if (_classes.isNotEmpty) {
          if (widget.initialClassId != null) {
            _selectedClass = _classes.firstWhere(
              (c) => c.classId == widget.initialClassId,
              orElse: () => _classes.first,
            );
          } else {
            _selectedClass = _classes.first;
          }
          _loadSelectedClassGrades();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _classesError = e.toString();
        _isLoadingClasses = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant GradesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialClassId != null &&
        widget.initialClassId != oldWidget.initialClassId &&
        _classes.isNotEmpty) {
      final match = _classes.where((c) => c.classId == widget.initialClassId);
      if (match.isNotEmpty && match.first.classId != _selectedClass?.classId) {
        setState(() {
          _selectedClass = match.first;
        });
        _loadSelectedClassGrades();
      }
    }
  }

  void _loadSelectedClassGrades() {
    if (_selectedClass != null) {
      context.read<GradesBloc>().add(LoadClassGradesSheetEvent(_selectedClass!));
    }
  }

  void _onClassChanged(ClassModel? newClass) {
    if (newClass != null && newClass.classId != _selectedClass?.classId) {
      setState(() {
        _selectedClass = newClass;
      });
      _loadSelectedClassGrades();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Grades',
          subtitle: 'Input, calculate, and submit student midterm and final grades.',
          onRefresh: _fetchClasses,
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isLoadingClasses && _classes.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ClassModel>(
                      value: _selectedClass,
                      hint: const Text('Select a class...', style: TextStyle(fontSize: 13)),
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                      borderRadius: BorderRadius.circular(8),
                      items: _classes.map((c) {
                        return DropdownMenuItem<ClassModel>(
                          value: c,
                          child: Text(
                            '${c.subjectCode ?? ''} — ${c.className} (${c.termLabel})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: _onClassChanged,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
                          ],
          ),
        ),
        Expanded(
          child: _buildBody(),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoadingClasses) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading your assigned classes...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_classesError != null) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF87171)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 36),
              const SizedBox(height: 12),
              const Text(
                'Failed to load classes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF991B1B)),
              ),
              const SizedBox(height: 6),
              Text(
                _classesError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchClasses,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_classes.isEmpty) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.grade_outlined, color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Classes Assigned',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'You must have active class assignments before submitting student grades.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return BlocConsumer<GradesBloc, GradesState>(
      listener: (context, state) {
        if (state is GradesSheetLoaded) {
          if (state.actionSuccessMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.actionSuccessMessage!),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.read<GradesBloc>().add(ClearGradeSheetFeedbackEvent());
          }

          if (state.actionErrorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.actionErrorMessage!),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.read<GradesBloc>().add(ClearGradeSheetFeedbackEvent());
          }

          if (state.lastBatchResult != null) {
            _showBatchResultDialog(context, state.lastBatchResult!, state.roster);
            context.read<GradesBloc>().add(ClearGradeSheetFeedbackEvent());
          }
        }
      },
      builder: (context, state) {
        if (state is GradesSheetLoading) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Loading class roster and grade records...',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          );
        }

        if (state is GradesSheetError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 36),
                const SizedBox(height: 12),
                Text(
                  'Error: ${state.message}',
                  style: const TextStyle(color: Color(0xFF991B1B), fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadSelectedClassGrades,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (state is GradesSheetLoaded) {
          return _GradeSheetTable(
            classItem: state.classItem,
            roster: state.roster,
            grades: state.grades,
            savingRowStudyLoadId: state.savingRowStudyLoadId,
            isSubmittingBatch: state.isSubmittingBatch,
            auth: widget.auth,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  /// Opens the "Request Correction" dialog for a locked grade field.
  /// [grade]         — the existing GradeModel for this student row.
  /// [correctionPeriod] — 1 for Midterms, 2 for Finals.
  static Future<void> showRequestCorrectionDialog(
    BuildContext context, {
    required GradeModel grade,
    required int correctionPeriod,
  }) async {
    final periodLabel = correctionPeriod == 1 ? 'Midterm' : 'Final';
    final currentGrade = correctionPeriod == 1
        ? grade.midtermGrade!
        : grade.finalGrade!;

    final newGradeController = TextEditingController();
    final reasonController = TextEditingController();
    String? newGradeError;
    String? reasonError;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            titlePadding:
                const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding:
                const EdgeInsets.fromLTRB(24, 16, 24, 0),
            actionsPadding:
                const EdgeInsets.fromLTRB(16, 8, 16, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFF92400E),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Request Grade Correction',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        '$periodLabel Grade${grade.studentName != null ? " — ${grade.studentName}" : ""}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      'The registrar will review this request. The grade will not change until they approve it.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Current (read-only) grade
                  _DialogField(
                    label: 'Current $periodLabel Grade (Read-Only)',
                    child: Container(
                      height: 42,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded,
                              size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Text(
                            currentGrade.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // New grade input
                  _DialogField(
                    label: 'New $periodLabel Grade *',
                    child: TextField(
                      controller: newGradeController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'e.g. 1.75',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: Colors.white,
                        errorText: newGradeError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: newGradeError != null
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: newGradeError != null
                                ? const Color(0xFFEF4444)
                                : AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                      onChanged: (_) {
                        setDialogState(() => newGradeError = null);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Reason text field
                  _DialogField(
                    label: 'Reason / Justification *',
                    child: TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText:
                            'Briefly explain why the correction is needed…',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.all(12),
                        filled: true,
                        fillColor: Colors.white,
                        errorText: reasonError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: reasonError != null
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: reasonError != null
                                ? const Color(0xFFEF4444)
                                : AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      style:
                          const TextStyle(fontSize: 13, height: 1.5),
                      onChanged: (_) {
                        setDialogState(() => reasonError = null);
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        // Validate
                        String? ngErr;
                        String? rErr;

                        final newGradeText =
                            newGradeController.text.trim();
                        if (newGradeText.isEmpty) {
                          ngErr = 'Required';
                        } else {
                          final parsed = double.tryParse(newGradeText);
                          if (parsed == null ||
                              !isValidGradeValue(parsed)) {
                            ngErr = kGradeScaleMessage;
                          } else if ((parsed - currentGrade).abs() <
                              0.001) {
                            ngErr =
                                'New grade must differ from current grade';
                          }
                        }

                        if (reasonController.text.trim().isEmpty) {
                          rErr = 'Required';
                        }

                        if (ngErr != null || rErr != null) {
                          setDialogState(() {
                            newGradeError = ngErr;
                            reasonError = rErr;
                          });
                          return;
                        }

                        setDialogState(() => isSubmitting = true);

                        try {
                          await getIt<GradeCorrectionRepository>()
                              .requestCorrection(
                            gradeId: grade.gradeId,
                            correctionPeriod: correctionPeriod,
                            oldGrade: currentGrade,
                            newGrade: double.parse(newGradeText),
                            reason: reasonController.text.trim(),
                          );

                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Correction request submitted for '
                                  '${grade.studentName ?? 'student'} — $periodLabel grade.',
                                ),
                                backgroundColor:
                                    AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Failed to submit request: ${e.toString()}'),
                                backgroundColor:
                                    AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Request',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBatchResultDialog(
      BuildContext context, GradeBatchResultModel result,
      [List<ClassRosterItemModel> roster = const []]) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              result.failed.isEmpty ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              color: result.failed.isEmpty ? const Color(0xFF16A34A) : const Color(0xFFD97706),
              size: 26,
            ),
            const SizedBox(width: 10),
            const Text('Batch Submission Results', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Container(
          width: 520,
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: result.failed.isEmpty ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: result.failed.isEmpty ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${result.succeeded.length} Saved Successfully',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                    ),
                    const Spacer(),
                    if (result.failed.isNotEmpty)
                      Text(
                        '${result.failed.length} Failed',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                      ),
                  ],
                ),
              ),
              if (result.failed.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Failed Entries:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: result.failed.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (ctx, i) {
                      final f = result.failed[i];
                      final student = roster
                          .where((r) => r.studyLoadId == f.studyLoadId)
                          .firstOrNull;
                      final studentHeader = student != null
                          ? student.displayName
                          : 'Student (ID: ${f.studyLoadId})';

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              studentHeader,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF991B1B)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              f.reason,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF7F1D1D)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _GradeSheetTable extends StatefulWidget {
  final ClassModel classItem;
  final List<ClassRosterItemModel> roster;
  final Map<String, GradeModel> grades;
  final String? savingRowStudyLoadId;
  final bool isSubmittingBatch;
  final AuthenticatedState auth;

  const _GradeSheetTable({
    required this.classItem,
    required this.roster,
    required this.grades,
    this.savingRowStudyLoadId,
    required this.isSubmittingBatch,
    required this.auth,
  });

  @override
  State<_GradeSheetTable> createState() => _GradeSheetTableState();
}

class _GradeSheetTableState extends State<_GradeSheetTable> {
  final Map<String, TextEditingController> _midtermControllers = {};
  final Map<String, TextEditingController> _finalControllers = {};
  final Map<String, String?> _midtermErrors = {};
  final Map<String, String?> _finalErrors = {};
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant _GradeSheetTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roster != widget.roster || oldWidget.grades != widget.grades) {
      _initControllers();
    }
  }

  void _initControllers() {
    for (final r in widget.roster.where((r) => r.isEnrolled)) {
      final g = widget.grades[r.studyLoadId];
      final midtermVal = g?.midtermGrade?.toStringAsFixed(2) ?? '';
      final finalVal = g?.finalGrade?.toStringAsFixed(2) ?? '';

      _midtermControllers.putIfAbsent(r.studyLoadId, () => TextEditingController(text: midtermVal));
      if (_midtermControllers[r.studyLoadId]!.text.isEmpty && midtermVal.isNotEmpty) {
        _midtermControllers[r.studyLoadId]!.text = midtermVal;
      }

      _finalControllers.putIfAbsent(r.studyLoadId, () => TextEditingController(text: finalVal));
      if (_finalControllers[r.studyLoadId]!.text.isEmpty && finalVal.isNotEmpty) {
        _finalControllers[r.studyLoadId]!.text = finalVal;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _midtermControllers.values) {
      c.dispose();
    }
    for (final c in _finalControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _validateField(String studyLoadId, bool isMidterm, String val) {
    setState(() {
      final err = validateGradeString(val);
      if (isMidterm) {
        _midtermErrors[studyLoadId] = err;
      } else {
        _finalErrors[studyLoadId] = err;
      }
    });
  }

  bool _hasRowChanges(String studyLoadId) {
    final g = widget.grades[studyLoadId];
    final isMidtermLocked = g?.midtermGrade != null;
    final isFinalLocked = g?.finalGrade != null;

    final midtermText = _midtermControllers[studyLoadId]?.text.trim() ?? '';
    final finalText = _finalControllers[studyLoadId]?.text.trim() ?? '';

    final hasNewMidterm = !isMidtermLocked && midtermText.isNotEmpty && _midtermErrors[studyLoadId] == null;
    final hasNewFinal = !isFinalLocked && finalText.isNotEmpty && _finalErrors[studyLoadId] == null;

    return hasNewMidterm || hasNewFinal;
  }

  int _countBatchReadyRows() {
    int count = 0;
    for (final r in widget.roster.where((r) => r.isEnrolled)) {
      if (_hasRowChanges(r.studyLoadId)) {
        count++;
      }
    }
    return count;
  }

  void _saveSingleRow(ClassRosterItemModel r) {
    final g = widget.grades[r.studyLoadId];
    final isMidtermLocked = g?.midtermGrade != null;
    final isFinalLocked = g?.finalGrade != null;

    final midtermText = _midtermControllers[r.studyLoadId]?.text.trim() ?? '';
    final finalText = _finalControllers[r.studyLoadId]?.text.trim() ?? '';

    final midtermVal = !isMidtermLocked && midtermText.isNotEmpty ? double.tryParse(midtermText) : null;
    final finalVal = !isFinalLocked && finalText.isNotEmpty ? double.tryParse(finalText) : null;

    if (midtermVal == null && finalVal == null) {
      return;
    }

    context.read<GradesBloc>().add(
          SubmitSingleGradeRowEvent(
            studyLoadId: r.studyLoadId,
            midtermGrade: midtermVal,
            finalGrade: finalVal,
            studentName: r.displayName,
          ),
        );
  }

  void _submitBatchAll() {
    final batchItems = <SubmitGradeBatchItemModel>[];

    for (final r in widget.roster.where((r) => r.isEnrolled)) {
      if (_hasRowChanges(r.studyLoadId)) {
        final g = widget.grades[r.studyLoadId];
        final isMidtermLocked = g?.midtermGrade != null;
        final isFinalLocked = g?.finalGrade != null;

        final midtermText = _midtermControllers[r.studyLoadId]?.text.trim() ?? '';
        final finalText = _finalControllers[r.studyLoadId]?.text.trim() ?? '';

        final midtermVal = !isMidtermLocked && midtermText.isNotEmpty ? double.tryParse(midtermText) : null;
        final finalVal = !isFinalLocked && finalText.isNotEmpty ? double.tryParse(finalText) : null;

        if (midtermVal != null || finalVal != null) {
          batchItems.add(SubmitGradeBatchItemModel(
            studyLoadId: r.studyLoadId,
            midtermGrade: midtermVal,
            finalGrade: finalVal,
          ));
        }
      }
    }

    if (batchItems.isEmpty) return;

    context.read<GradesBloc>().add(
          SubmitBatchGradesEvent(
            SubmitGradeBatchModel(
              classId: widget.classItem.classId,
              grades: batchItems,
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.classItem;
    final batchCount = _countBatchReadyRows();

    final filteredRoster = widget.roster.where((r) {
      if (!r.isEnrolled) return false;
      if (_searchFilter.isEmpty) return true;
      return r.displayName.toLowerCase().contains(_searchFilter);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Class Banner & Batch Actions Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              c.subjectCode ?? 'No Code',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            c.className,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            c.termLabel,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.subjectTitle ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Batch Submit Button
                ElevatedButton.icon(
                  onPressed: (!widget.isSubmittingBatch && batchCount > 0) ? _submitBatchAll : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: widget.isSubmittingBatch
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.playlist_add_check_rounded, size: 18),
                  label: Text(
                    batchCount > 0 ? 'Submit All ($batchCount)' : 'Submit All',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search Input & Scale Guide Banner
          Row(
            children: [
              SizedBox(
                width: 280,
                height: 38,
                child: TextField(
                  onChanged: (val) => setState(() => _searchFilter = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search student by name...',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    'Grading scale: 1.0 to 3.0 (Passed) · 3.1 to 5.0 (Failed), in steps of 0.1 (1.25, 1.75 … also allowed). Submitted fields become permanently locked.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Grade Sheet Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text('STUDENT NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
                        ),
                        SizedBox(
                          width: 140,
                          child: Text('MIDTERM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
                        ),
                        SizedBox(width: 16),
                        SizedBox(
                          width: 140,
                          child: Text('FINAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
                        ),
                        SizedBox(width: 16),
                        SizedBox(
                          width: 120,
                          child: Text('REMARKS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
                        ),
                        SizedBox(
                          width: 160,
                          child: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                  ),

                  // Table Rows
                  Expanded(
                    child: filteredRoster.isEmpty
                        ? const Center(
                            child: Text('No students match your filter.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          )
                        : ListView.separated(
                            itemCount: filteredRoster.length,
                            separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, index) {
                              final item = filteredRoster[index];
                              final g = widget.grades[item.studyLoadId];
                              final isMidtermLocked = g?.midtermGrade != null;
                              final isFinalLocked = g?.finalGrade != null;
                              final isSavingThisRow = widget.savingRowStudyLoadId == item.studyLoadId;
                              final hasChanges = _hasRowChanges(item.studyLoadId);

                              // Calculate dynamic remarks preview
                              final finalText = _finalControllers[item.studyLoadId]?.text.trim() ?? '';
                              final enteredFinal = double.tryParse(finalText);
                              final effectiveFinal = g?.finalGrade ?? enteredFinal;

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                color: index % 2 == 1 ? const Color(0xFFFAFAFA) : Colors.white,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 44,
                                      child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        item.displayName,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                      ),
                                    ),
                                    // Midterm Input
                                    SizedBox(
                                      width: 140,
                                      child: _buildGradeInputField(
                                        controller: _midtermControllers[item.studyLoadId]!,
                                        isLocked: isMidtermLocked,
                                        errorText: _midtermErrors[item.studyLoadId],
                                        onChanged: (val) => _validateField(item.studyLoadId, true, val),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Final Input
                                    SizedBox(
                                      width: 140,
                                      child: _buildGradeInputField(
                                        controller: _finalControllers[item.studyLoadId]!,
                                        isLocked: isFinalLocked,
                                        errorText: _finalErrors[item.studyLoadId],
                                        onChanged: (val) => _validateField(item.studyLoadId, false, val),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Remarks Badge
                                    SizedBox(
                                      width: 120,
                                      child: _buildRemarksBadge(effectiveFinal, g?.remarksLabel),
                                    ),
                                    // Action column: Save button + Correction icon buttons
                                    SizedBox(
                                      width: 160,
                                      child: isSavingThisRow
                                          ? const Center(
                                              child: SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Save button (only active when there are un-submitted changes)
                                                OutlinedButton(
                                                  onPressed: (hasChanges && !widget.isSubmittingBatch) ? () => _saveSingleRow(item) : null,
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: AppColors.primary,
                                                    side: BorderSide(
                                                      color: hasChanges ? AppColors.primary : const Color(0xFFCBD5E1),
                                                    ),
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                  ),
                                                  child: const Text('Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                ),
                                                // Correction icon buttons (one per locked period)
                                                if (isMidtermLocked && g != null) ...[  
                                                  const SizedBox(width: 4),
                                                  Tooltip(
                                                    message: 'Request Midterm Correction',
                                                    child: InkWell(
                                                      borderRadius: BorderRadius.circular(6),
                                                      onTap: () => _GradesViewState.showRequestCorrectionDialog(
                                                        context,
                                                        grade: g,
                                                        correctionPeriod: 1,
                                                      ),
                                                      child: Container(
                                                        padding: const EdgeInsets.all(6),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFFEF3C7),
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(color: const Color(0xFFFDE68A)),
                                                        ),
                                                        child: const Icon(
                                                          Icons.edit_note_rounded,
                                                          size: 14,
                                                          color: Color(0xFF92400E),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                if (isFinalLocked && g != null) ...[  
                                                  const SizedBox(width: 4),
                                                  Tooltip(
                                                    message: 'Request Final Correction',
                                                    child: InkWell(
                                                      borderRadius: BorderRadius.circular(6),
                                                      onTap: () => _GradesViewState.showRequestCorrectionDialog(
                                                        context,
                                                        grade: g,
                                                        correctionPeriod: 2,
                                                      ),
                                                      child: Container(
                                                        padding: const EdgeInsets.all(6),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFFEF3C7),
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(color: const Color(0xFFFDE68A)),
                                                        ),
                                                        child: const Icon(
                                                          Icons.edit_note_rounded,
                                                          size: 14,
                                                          color: Color(0xFF92400E),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeInputField({
    required TextEditingController controller,
    required bool isLocked,
    required String? errorText,
    required ValueChanged<String> onChanged,
  }) {
    if (isLocked) {
      return Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              controller.text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 38,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'e.g. 1.75',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: errorText != null ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: errorText != null ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: errorText != null ? const Color(0xFFEF4444) : AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 2),
          Text(
            errorText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }

  Widget _buildRemarksBadge(double? finalGrade, String? serverLabel) {
    if (finalGrade == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('—', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
      );
    }

    if (finalGrade <= 3.00) {
      return StatusBadge.success(label: serverLabel ?? 'Passed');
    } else {
      return StatusBadge.danger(label: serverLabel ?? 'Failed');
    }
  }
}

/// Small labelled form field used in the correction request dialog.
class _DialogField extends StatelessWidget {
  final String label;
  final Widget child;

  const _DialogField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
