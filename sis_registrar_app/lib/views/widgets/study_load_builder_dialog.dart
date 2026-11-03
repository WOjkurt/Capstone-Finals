import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/class_models.dart';
import '../../models/grading_models.dart';
import '../../models/setup_models.dart';
import '../../repositories/class_repository.dart';
import '../../repositories/enrollment_repository.dart';
import '../../theme/app_theme.dart';

class StudyLoadBuilderDialog extends StatefulWidget {
  final UserSearchResultModel student;
  final String initialTermId;
  final String initialTermLabel;
  final bool? isCollegeHead;
  final VoidCallback? onEnrolled;

  const StudyLoadBuilderDialog({
    super.key,
    required this.student,
    required this.initialTermId,
    required this.initialTermLabel,
    this.isCollegeHead,
    this.onEnrolled,
  });

  static Future<bool?> show(
    BuildContext context, {
    required UserSearchResultModel student,
    required String initialTermId,
    required String initialTermLabel,
    bool? isCollegeHead,
    VoidCallback? onEnrolled,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StudyLoadBuilderDialog(
        student: student,
        initialTermId: initialTermId,
        initialTermLabel: initialTermLabel,
        isCollegeHead: isCollegeHead,
        onEnrolled: onEnrolled,
      ),
    );
  }

  @override
  State<StudyLoadBuilderDialog> createState() => _StudyLoadBuilderDialogState();
}

class _StudyLoadBuilderDialogState extends State<StudyLoadBuilderDialog> {
  late String _selectedTermId;
  List<AcademicTermModel> _terms = [];
  bool _isLoadingTerms = false;

  List<ProposedBlockItemModel>? _items;
  bool _isLoadingItems = true;
  String? _loadError;

  // Selected class ID per subject ID
  final Map<String, String> _selectedClassIds = {};

  // Checked subjects in builder
  final Set<String> _checkedSubjectIds = {};

  bool _isSubmitting = false;

  // CHED unit limit for this student and term; null if it could not be loaded.
  UnitLimitModel? _unitLimit;

  bool get _effectiveIsCollegeHead => widget.isCollegeHead ?? false;

  @override
  void initState() {
    super.initState();
    _selectedTermId = widget.initialTermId;
    _fetchTerms();
    _fetchProposedBlock();
  }

  Future<void> _fetchTerms() async {
    setState(() => _isLoadingTerms = true);
    try {
      final repo = getIt<AcademicSetupRepository>();
      final terms = await repo.getTerms();
      if (mounted) {
        setState(() {
          _terms = terms;
          _isLoadingTerms = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingTerms = false);
      }
    }
  }

  /// The limit is only a warning, so a failure here never blocks the builder.
  Future<void> _fetchUnitLimit() async {
    final termId = _selectedTermId;
    UnitLimitModel? limit;
    try {
      limit = await getIt<ClassRepository>()
          .getUnitLimit(widget.student.userId, termId);
    } catch (_) {
      limit = null;
    }
    if (mounted && termId == _selectedTermId) {
      setState(() => _unitLimit = limit);
    }
  }

  Future<void> _fetchProposedBlock() async {
    setState(() {
      _isLoadingItems = true;
      _loadError = null;
      _unitLimit = null;
    });
    _fetchUnitLimit();

    try {
      final repo = getIt<ClassRepository>();
      final items = await repo.getProposedBlock(
        widget.student.userId,
        _selectedTermId,
      );

      if (mounted) {
        _checkedSubjectIds.clear();
        _selectedClassIds.clear();

        for (final item in items) {
          // Initialize selected classId
          if (item.classId != null && item.classId!.isNotEmpty) {
            _selectedClassIds[item.subjectId] = item.classId!;
          } else if (item.options.isNotEmpty) {
            _selectedClassIds[item.subjectId] = item.options.first.classId;
          }

          // Defaults: Regular rows with met prerequisites/standing and one matching class are pre-checked.
          // Retake and back subjects start unchecked.
          if (item.isRegular &&
              !item.isBlocked &&
              !item.isNoClassOffered &&
              !item.alreadyPassed &&
              !item.alreadyEnrolledThisTerm &&
              _selectedClassIds.containsKey(item.subjectId)) {
            _checkedSubjectIds.add(item.subjectId);
          }
        }

        setState(() {
          _items = items;
          _isLoadingItems = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _isLoadingItems = false;
        });
      }
    }
  }

  Future<void> _onSubjectCheckChanged(
      ProposedBlockItemModel item, bool checked) async {
    if (checked) {
      // Prompt for corequisite pairing if any corequisite is offered/included and not yet checked
      final unselectedCoreqs = item.corequisites
          .where((c) =>
              c.includedInProposal && !_checkedSubjectIds.contains(c.subjectId))
          .toList();

      if (unselectedCoreqs.isNotEmpty) {
        final pairCode = unselectedCoreqs.map((c) => c.subjectCode).join(', ');
        final acceptPair = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.link_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Corequisite Pairing'),
              ],
            ),
            content: Text(
              '${item.subjectCode} has corequisite ($pairCode). Would you like to select the corequisite pair too?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('No, keep only this'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Yes, select pair'),
              ),
            ],
          ),
        );

        if (acceptPair == true) {
          setState(() {
            _checkedSubjectIds.add(item.subjectId);
            for (final c in unselectedCoreqs) {
              final pairItem =
                  _items?.firstWhere((it) => it.subjectId == c.subjectId);
              if (pairItem != null && !pairItem.isNoClassOffered) {
                _checkedSubjectIds.add(c.subjectId);
              }
            }
          });
          return;
        }
      }

      setState(() {
        _checkedSubjectIds.add(item.subjectId);
      });
    } else {
      // Unchecking: Warn if any corequisite pair is currently selected
      final selectedCoreqs = item.corequisites
          .where((c) => _checkedSubjectIds.contains(c.subjectId))
          .toList();

      if (selectedCoreqs.isNotEmpty) {
        final pairCode = selectedCoreqs.map((c) => c.subjectCode).join(', ');
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.accentAmber),
                const SizedBox(width: 8),
                const Text('Corequisite Warning'),
              ],
            ),
            content: Text(
              'Deselecting ${item.subjectCode} while corequisite ($pairCode) is selected may cause validation to fail. Do you wish to continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentAmber),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Unselect Anyway'),
              ),
            ],
          ),
        );

        if (proceed != true) return;
      }

      setState(() {
        _checkedSubjectIds.remove(item.subjectId);
      });
    }
  }

  int get _selectedSubjectCount => _checkedSubjectIds.length;

  double get _selectedUnitsTotal {
    if (_items == null) return 0.0;
    double total = 0.0;
    for (final it in _items!) {
      if (_checkedSubjectIds.contains(it.subjectId)) {
        total += it.units;
      }
    }
    return total;
  }

  /// Units after saving: what is already in the term plus the ticked subjects.
  double get _projectedUnits => (_unitLimit?.currentUnits ?? 0) + _selectedUnitsTotal;

  bool get _isOverUnitLimit =>
      _unitLimit != null && _projectedUnits > _unitLimit!.maxUnits + 0.001;

  /// Asks for the overload reason; returns null when the user goes back.
  Future<String?> _askOverloadReason() {
    final limit = _unitLimit!;
    return showDialog<String>(
      context: context,
      builder: (ctx) => _OverloadReasonDialog(
        message: 'This load would be ${_projectedUnits.toStringAsFixed(1)} units, '
            'above the limit of ${limit.maxUnits.toStringAsFixed(1)} units.\n\n${limit.rule}',
      ),
    );
  }

  List<ProposedBlockItemModel> get _selectedBlockedItems {
    if (_items == null) return [];
    return _items!
        .where((it) => _checkedSubjectIds.contains(it.subjectId) && it.isBlocked)
        .toList();
  }

  Future<void> _submitBatch({required bool asPending}) async {
    if (_checkedSubjectIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one subject.')),
      );
      return;
    }

    if (_selectedBlockedItems.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot batch enroll subjects with unmet prerequisites or standing rules. Please uncheck them or force them individually.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final classIds = <String>[];
    for (final subjId in _checkedSubjectIds) {
      final cid = _selectedClassIds[subjId];
      if (cid != null && cid.isNotEmpty) {
        classIds.add(cid);
      }
    }

    if (classIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid classes chosen for selected subjects.'),
        ),
      );
      return;
    }

    String? overloadReason;
    if (_isOverUnitLimit) {
      overloadReason = await _askOverloadReason();
      if (overloadReason == null || !mounted) return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = getIt<ClassRepository>();
      final results = await repo.enrollBatch(
        userId: widget.student.userId,
        termId: _selectedTermId,
        classIds: classIds,
        asPending: asPending,
        overloadReason: overloadReason,
      );

      final enrolledResults = results.where((r) => r.enrolled).toList();
      final refusedResults = results.where((r) => !r.enrolled).toList();

      if (mounted) {
        setState(() => _isSubmitting = false);

        if (refusedResults.isEmpty) {
          Navigator.of(context).pop(true);
          widget.onEnrolled?.call();

          final modeLabel = asPending ? 'saved as pending' : 'enrolled';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${enrolledResults.length} subjects $modeLabel successfully.',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          return;
        }

        // Partial success / some refused:
        // Succeeded items are unchecked
        for (final r in enrolledResults) {
          final item = _findItemForClassId(r.classId);
          if (item != null) {
            _checkedSubjectIds.remove(item.subjectId);
          }
        }
        // Refused items stay checked so user can fix and retry
        for (final r in refusedResults) {
          final item = _findItemForClassId(r.classId);
          if (item != null) {
            _checkedSubjectIds.add(item.subjectId);
          }
        }

        setState(() {});
        widget.onEnrolled?.call();

        // Show batch results dialog with reasons
        await _showBatchResultsDialog(results, asPending: asPending);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enrollment failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  ProposedBlockItemModel? _findItemForClassId(String classId) {
    if (_items == null) return null;
    for (final it in _items!) {
      if (_selectedClassIds[it.subjectId] == classId) return it;
      if (it.classId == classId) return it;
      if (it.options.any((opt) => opt.classId == classId)) return it;
    }
    return null;
  }

  Future<void> _showBatchResultsDialog(
    List<EnrollBatchResponseModel> results, {
    required bool asPending,
  }) async {
    final enrolledCount = results.where((r) => r.enrolled).length;
    final refusedCount = results.where((r) => !r.enrolled).length;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              refusedCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
              color: refusedCount > 0 ? AppColors.accentAmber : AppColors.success,
              size: 26,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Batch Results',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: refusedCount > 0
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: refusedCount > 0
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '$enrolledCount ${asPending ? "saved as pending" : "enrolled"}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: Color(0xFF6B7280))),
                    const SizedBox(width: 8),
                    Text(
                      '$refusedCount refused',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: refusedCount > 0
                            ? const Color(0xFF991B1B)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Details by Subject:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final r = results[index];
                    final item = _findItemForClassId(r.classId);
                    final subjCode = item?.subjectCode ?? 'Class ${r.classId}';
                    final subjTitle = item?.subjectTitle ?? '';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            r.enrolled ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            size: 18,
                            color: r.enrolled ? AppColors.success : AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$subjCode${subjTitle.isNotEmpty ? ' — $subjTitle' : ''}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (r.enrolled)
                                  Text(
                                    asPending ? 'Saved as Pending' : 'Enrolled',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                else
                                  Text(
                                    r.reasons.isNotEmpty
                                        ? r.reasons.join('; ')
                                        : 'Enrollment refused by academic rules',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
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
        actions: [
          FilledButton(
            key: const ValueKey('dismiss_batch_results_button'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Review and retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _openForceSingleDialog(ProposedBlockItemModel item) async {
    final classId = _selectedClassIds[item.subjectId];
    if (classId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No class section selected to force.')),
      );
      return;
    }

    final reasonCtrl = TextEditingController();
    bool asPending = _effectiveIsCollegeHead;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.bolt, color: AppColors.accentAmber, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Force Enroll: ${item.subjectCode}'),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.subjectTitle} (${item.units} units)',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Blocking Findings:',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF991B1B)),
                      ),
                      const SizedBox(height: 4),
                      if (item.isPrereqUnmet)
                        ...item.prerequisiteMessages.map(
                          (m) => Text('• $m',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF991B1B))),
                        ),
                      if (item.isStandingUnmet)
                        const Text('• Year standing requirement unmet',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF991B1B))),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Force Reason (Required):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const ValueKey('force_reason_field'),
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter reason for override/force enrollment...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(height: 10),
                if (!_effectiveIsCollegeHead)
                  Row(
                    children: [
                      Checkbox(
                        key: const ValueKey('force_as_pending_checkbox'),
                        value: asPending,
                        onChanged: (v) =>
                            setDialogState(() => asPending = v ?? false),
                      ),
                      const Text('Submit as Pending load (recommended)',
                          style: TextStyle(fontSize: 12)),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'College Head forces are submitted as Pending loads for Registrar finalization.',
                      style: TextStyle(fontSize: 11, color: AppColors.primaryDark),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('confirm_force_button'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentAmber),
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Please provide a force reason.')),
                  );
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Confirm Force'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && reasonCtrl.text.trim().isNotEmpty) {
      final effectiveAsPending = _effectiveIsCollegeHead ? true : asPending;
      try {
        final repo = getIt<ClassRepository>();
        final res = await repo.enrollSingle(
          userId: widget.student.userId,
          classId: classId,
          force: true,
          forceReason: reasonCtrl.text.trim(),
          asPending: effectiveAsPending,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully force enrolled in ${item.subjectCode}${effectiveAsPending ? ' (as Pending)' : ''}.',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          // Refresh proposed block
          _fetchProposedBlock();
          widget.onEnrolled?.call();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Force enrollment failed: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 960,
          maxHeight: 780,
          minWidth: 700,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoadingItems
                    ? const Center(child: CircularProgressIndicator())
                    : _loadError != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_loadError!,
                                    style: const TextStyle(
                                        color: AppColors.error)),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: _fetchProposedBlock,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _buildItemsList(),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.architecture_rounded,
              color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Study-Load Builder — ${widget.student.fullName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.student.programCode != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.student.programCode!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Year ${widget.student.yearLevel ?? "?"} • ${widget.student.email}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        // Term selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _terms.any((t) => t.termId == _selectedTermId)
                  ? _selectedTermId
                  : null,
              hint: Text(_selectedTermId.isNotEmpty
                  ? widget.initialTermLabel
                  : 'Select Term'),
              items: _terms.map((t) {
                return DropdownMenuItem<String>(
                  value: t.termId,
                  child: Text(
                    t.label,
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
              onChanged: (newTermId) {
                if (newTermId != null && newTermId != _selectedTermId) {
                  setState(() => _selectedTermId = newTermId);
                  _fetchProposedBlock();
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: AppColors.textSecondary),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildItemsList() {
    if (_items == null || _items!.isEmpty) {
      return const Center(
        child: Text(
          'No proposed subjects found for this student and term.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final regularItems = _items!.where((it) => it.isRegular).toList();
    final retakeItems = _items!.where((it) => it.isRetake).toList();
    final backSubjectItems = _items!.where((it) => it.isBackSubject).toList();

    return ListView(
      children: [
        if (regularItems.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Regular',
            count: regularItems.length,
            color: AppColors.primary,
          ),
          ...regularItems.map((it) => _buildRow(it)),
          const SizedBox(height: 16),
        ],
        if (retakeItems.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Retake candidates',
            count: retakeItems.length,
            color: AppColors.accentAmber,
            subtitle: 'Subjects previously failed and eligible for retake',
          ),
          ...retakeItems.map((it) => _buildRow(it)),
          const SizedBox(height: 16),
        ],
        if (backSubjectItems.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Back subjects',
            count: backSubjectItems.length,
            color: const Color(0xFF6B7280),
            subtitle: 'Earlier-year subjects never taken or withdrawn',
          ),
          ...backSubjectItems.map((it) => _buildRow(it)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required int count,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 10),
            Text(
              '($subtitle)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(ProposedBlockItemModel item) {
    final isChecked = _checkedSubjectIds.contains(item.subjectId);
    final isDisabled = item.isNoClassOffered ||
        item.alreadyPassed ||
        item.alreadyEnrolledThisTerm;

    return Container(
      key: ValueKey('builder_row_${item.subjectCode}'),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isChecked ? AppColors.primaryLight.withValues(alpha: 0.3) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isChecked
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            key: ValueKey('checkbox_${item.subjectCode}'),
            value: isChecked,
            onChanged: isDisabled
                ? null
                : (val) => _onSubjectCheckChanged(item, val ?? false),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.subjectCode,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDisabled
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.subjectTitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.units.toStringAsFixed(1)} units',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Badges & Section selector row
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Retake last grade badge
                    if (item.isRetake && item.lastGrade != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentAmberLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color:
                                  AppColors.accentAmber.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'Last grade: ${item.lastGrade!.toStringAsFixed(1)}${item.lastGradeTerm != null ? ' (${item.lastGradeTerm})' : ''}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    // Prereq unmet badge
                    if (item.isPrereqUnmet)
                      Tooltip(
                        message: item.prerequisiteMessages.join('; '),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 11, color: Color(0xFFDC2626)),
                              const SizedBox(width: 3),
                              Text(
                                item.prerequisiteMessages.isNotEmpty
                                    ? item.prerequisiteMessages.first
                                    : 'Prerequisite unmet',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Standing unmet badge
                    if (item.isStandingUnmet)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Text(
                          'Standing unmet',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    // Corequisites badge
                    if (item.corequisites.isNotEmpty)
                      ...item.corequisites.map(
                        (c) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Coreq: ${c.subjectCode}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    // No class offered badge
                    if (item.isNoClassOffered)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Not offered this term',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    // Already passed badge
                    if (item.alreadyPassed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentGreenLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Already passed',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentGreenDark,
                          ),
                        ),
                      ),
                    // Already enrolled badge
                    if (item.alreadyEnrolledThisTerm)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Enrolled this term',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Section dropdown or single class name
          if (!item.isNoClassOffered) ...[
            if (item.options.length > 1)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: ValueKey('section_dropdown_${item.subjectCode}'),
                    value: _selectedClassIds[item.subjectId],
                    items: item.options.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt.classId,
                        child: Text(
                          opt.className,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                    onChanged: (newClassId) {
                      if (newClassId != null) {
                        setState(() {
                          _selectedClassIds[item.subjectId] = newClassId;
                        });
                      }
                    },
                  ),
                ),
              )
            else if (item.className != null || item.options.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.className ??
                      (item.options.isNotEmpty
                          ? item.options.first.className
                          : ''),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
          ],
          // Individual Force button if blocked and class offered
          if (item.isBlocked && !item.isNoClassOffered) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              key: ValueKey('force_button_${item.subjectCode}'),
              icon: const Icon(Icons.bolt, size: 14, color: AppColors.accentAmber),
              label: const Text('Force', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB45309),
                side: const BorderSide(color: AppColors.accentAmber),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: () => _openForceSingleDialog(item),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final hasBlocked = _selectedBlockedItems.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isOverUnitLimit)
          Container(
            key: const ValueKey('unit_limit_warning'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFB45309), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Over the unit limit: ${_projectedUnits.toStringAsFixed(1)} of '
                    '${_unitLimit!.maxUnits.toStringAsFixed(1)} units. ${_unitLimit!.rule}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        if (hasBlocked)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded,
                    color: Color(0xFFDC2626), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_selectedBlockedItems.length} selected subject(s) have blocking findings (prerequisite/standing unmet). Batch enrollment cannot override blocking findings. Use the Force button on the subject to enroll with a written reason.',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            // Live totals
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        '$_selectedSubjectCount subjects selected',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Total: ${_selectedUnitsTotal.toStringAsFixed(1)} units',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      if (_unitLimit != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          '${_unitLimit!.currentUnits > 0 ? '${_unitLimit!.currentUnits.toStringAsFixed(1)} already in term · ' : ''}'
                          'Limit ${_unitLimit!.maxUnits.toStringAsFixed(1)}',
                          key: const ValueKey('unit_limit_label'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _isOverUnitLimit
                                ? const Color(0xFFB45309)
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                // "Save as pending"
                FilledButton.tonal(
                  key: const ValueKey('save_as_pending_button'),
                  onPressed: (_isSubmitting || hasBlocked)
                      ? null
                      : () => _submitBatch(asPending: true),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save as pending'),
                ),
                const SizedBox(width: 8),
                // "Enroll now" (Hidden for College Head)
                if (!_effectiveIsCollegeHead) ...[
                  FilledButton(
                    key: const ValueKey('enroll_now_button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: (_isSubmitting || hasBlocked)
                        ? null
                        : () => _submitBatch(asPending: false),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Enroll now'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Owns its text controller so it is disposed only after the dialog has closed.
class _OverloadReasonDialog extends StatefulWidget {
  final String message;
  const _OverloadReasonDialog({required this.message});

  @override
  State<_OverloadReasonDialog> createState() => _OverloadReasonDialogState();
}

class _OverloadReasonDialogState extends State<_OverloadReasonDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Approve overload'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.message),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('overload_reason_field'),
                controller: _controller,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'Reason for the overload *',
                  hintText: 'e.g. Irregular student catching up on back subjects',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
              ),
              const Text(
                'Your name and this reason are recorded and shown to the Registrar.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Go back'),
        ),
        FilledButton(
          key: const ValueKey('confirm_over_limit_button'),
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) {
              setState(() => _error = 'A reason is required.');
              return;
            }
            Navigator.of(context).pop(text);
          },
          child: const Text('Approve and save'),
        ),
      ],
    );
  }
}
