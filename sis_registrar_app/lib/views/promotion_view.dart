import 'package:flutter/material.dart';
import '../injection.dart';
import '../models/grading_models.dart';
import '../models/setup_models.dart';
import '../repositories/enrollment_repository.dart';
import '../repositories/grading_repository.dart';
import '../theme/app_theme.dart';
import '../utils/error_handler.dart';
import 'widgets/page_header.dart';

/// End-of-year promotion: the system suggests each student's next year level
/// (75% of the year's units and 75% of its major units passed), and the Registrar
/// ticks which suggestions to apply. Nothing changes until "Apply" is confirmed.
class PromotionView extends StatefulWidget {
  /// Set when opened from the Students page; shows a back arrow.
  final VoidCallback? onBack;

  const PromotionView({super.key, this.onBack});

  @override
  State<PromotionView> createState() => _PromotionViewState();
}

class _PromotionViewState extends State<PromotionView> {
  List<AcademicProgramModel> _programs = [];
  int? _programId;
  int? _yearLevel; // null = all years

  List<StudentPromotionModel>? _rows;
  final Set<String> _selected = {};
  bool _loading = false;
  bool _applying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPrograms();
  }

  String _message(Object e) => e is ApiException ? e.message : e.toString();

  Future<void> _loadPrograms() async {
    try {
      final programs = await getIt<AcademicSetupRepository>().getPrograms();
      if (mounted) setState(() => _programs = programs);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  /// Rows that would change if applied.
  bool _canApply(StudentPromotionModel r) =>
      r.suggestion.suggestedYearLevel != r.suggestion.currentYearLevel;

  Future<void> _loadRows() async {
    if (_programId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await getIt<PromotionRepository>()
          .getSuggestions(programId: _programId!, yearLevel: _yearLevel);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _selected
          ..clear()
          // Pre-tick students who move up and have all their grades in.
          ..addAll(rows
              .where((r) => _canApply(r) && r.suggestion.ungradedSubjects == 0)
              .map((r) => r.userId));
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _message(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _apply() async {
    final rows = _rows ?? [];
    final changes = {
      for (final r in rows)
        if (_selected.contains(r.userId) && _canApply(r))
          r.userId: r.suggestion.suggestedYearLevel,
    };
    if (changes.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply year levels?'),
        content: Text(
            '${changes.length} student(s) will move to their suggested year level. '
            'You can still change any student later from their Study Load window.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('confirm_apply_promotion'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _applying = true);
    try {
      final updated = await getIt<PromotionRepository>().applyYearLevels(changes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Updated $updated student(s).'),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
        ));
      }
      await _loadRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not apply: ${_message(e)}'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final selectedCount =
        rows?.where((r) => _selected.contains(r.userId) && _canApply(r)).length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'End-of-Year Promotion',
            subtitle:
                'Suggested next year level for every student: 75% of the year\'s units and 75% of its major units passed. '
                'Tick the ones to apply; nothing changes until you confirm.',
            onBack: widget.onBack,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int>(
                    key: const ValueKey('promotion_program_dropdown'),
                    initialValue: _programId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Program', isDense: true, border: OutlineInputBorder()),
                    items: [
                      for (final p in _programs)
                        DropdownMenuItem(value: p.programId, child: Text(p.programCode)),
                    ],
                    onChanged: (v) {
                      setState(() => _programId = v);
                      _loadRows();
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<int?>(
                    key: const ValueKey('promotion_year_dropdown'),
                    initialValue: _yearLevel,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Year level', isDense: true, border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All years')),
                      for (var y = 1; y <= 5; y++)
                        DropdownMenuItem<int?>(value: y, child: Text('Year $y')),
                    ],
                    onChanged: (v) {
                      setState(() => _yearLevel = v);
                      _loadRows();
                    },
                  ),
                ),
                FilledButton.icon(
                  key: const ValueKey('apply_promotion_button'),
                  icon: _applying
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.trending_up_rounded, size: 18),
                  label: Text('Apply to $selectedCount student(s)'),
                  onPressed: (selectedCount == 0 || _applying) ? null : _apply,
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(rows)),
        ],
      ),
    );
  }

  Widget _buildBody(List<StudentPromotionModel>? rows) {
    if (_error != null) {
      return Center(
          child: Text(_error!, style: const TextStyle(color: AppColors.error)));
    }
    if (_programId == null) {
      return const Center(
          child: Text('Choose a program to see suggestions.',
              style: TextStyle(color: AppColors.textSecondary)));
    }
    if (_loading || rows == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (rows.isEmpty) {
      return const Center(
          child: Text('No active students found.',
              style: TextStyle(color: AppColors.textSecondary)));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) => _buildRow(rows[i]),
    );
  }

  Widget _buildRow(StudentPromotionModel r) {
    final s = r.suggestion;
    final canApply = _canApply(r);
    final String verdict;
    final Color color;
    if (s.movesUp) {
      verdict = 'Year ${s.currentYearLevel} → Year ${s.suggestedYearLevel}';
      color = AppColors.accentGreenDark;
    } else if (s.isFinalYear) {
      verdict = 'Stay in Year ${s.currentYearLevel} (final year)';
      color = AppColors.textSecondary;
    } else {
      verdict = 'Stay in Year ${s.currentYearLevel}';
      color = const Color(0xFFB45309);
    }
    final percent = s.totalUnits > 0 ? (s.passedUnits / s.totalUnits * 100).floor() : 0;

    return Container(
      key: ValueKey('promotion_row_${r.userId}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Checkbox(
            key: ValueKey('promotion_check_${r.userId}'),
            value: canApply && _selected.contains(r.userId),
            onChanged: canApply
                ? (v) => setState(() =>
                    v == true ? _selected.add(r.userId) : _selected.remove(r.userId))
                : null,
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(r.lrn?.isNotEmpty == true ? 'LRN ${r.lrn}' : 'No LRN',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(verdict,
                style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Passed ${s.passedUnits.toStringAsFixed(0)} of ${s.totalUnits.toStringAsFixed(0)} units ($percent%)',
                  style: const TextStyle(fontSize: 12),
                ),
                if (s.failedSubjectCodes.isNotEmpty)
                  Text('Failed: ${s.failedSubjectCodes.join(', ')}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B))),
                if (s.ungradedSubjects > 0)
                  Text('${s.ungradedSubjects} subject(s) without a final grade',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFB45309))),
              ],
            ),
          ),
          Tooltip(
            message: s.reason,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
