import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/report_models.dart';
import '../../repositories/report_repository.dart';
import '../../repositories/student_record_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';

/// Enrolled students of a term with no sex on record. One click per student saves Male or Female
/// to their Details, so they count in the statistics and class lists.
class MissingSexDialog extends StatefulWidget {
  final String termId;
  final String termLabel;

  const MissingSexDialog({super.key, required this.termId, required this.termLabel});

  /// Returns true when at least one student was updated.
  static Future<bool?> show(BuildContext context, {required String termId, required String termLabel}) =>
      showDialog<bool>(context: context, builder: (_) => MissingSexDialog(termId: termId, termLabel: termLabel));

  @override
  State<MissingSexDialog> createState() => _MissingSexDialogState();
}

class _MissingSexDialogState extends State<MissingSexDialog> {
  List<MissingSexRow>? _rows;
  String? _error;
  final Map<String, String> _saved = {};
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await getIt<ReportRepository>().studentsMissingSex(widget.termId);
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : e.toString());
    }
  }

  Future<void> _set(MissingSexRow r, String sex) async {
    setState(() => _saving.add(r.userId));
    try {
      await getIt<StudentRecordRepository>().setSex(r.userId, sex);
      if (mounted) setState(() => _saved[r.userId] = sex);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save ${r.studentName}: ${e is ApiException ? e.message : e}'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(r.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final left = rows == null ? 0 : rows.where((r) => !_saved.containsKey(r.userId)).length;
    return AlertDialog(
      title: Text('Fill in missing sex — ${widget.termLabel}'),
      content: SizedBox(
        width: 600,
        height: 440,
        child: _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
            : rows == null
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                    ? const Center(child: Text('Every enrolled student has a sex on record.'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            left == 0 ? 'All done.' : '$left student(s) left. Each choice is saved right away to the student\'s Details.',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.separated(
                              itemCount: rows.length,
                              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                              itemBuilder: (_, i) {
                                final r = rows[i];
                                final saved = _saved[r.userId];
                                final busy = _saving.contains(r.userId);
                                return ListTile(
                                  key: ValueKey('missing_sex_${r.userId}'),
                                  dense: true,
                                  title: Text(r.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text([
                                    if (r.programCode != null) r.programCode!,
                                    if (r.yearLevel != null) 'Year ${r.yearLevel}',
                                    if (r.lrn != null) 'LRN ${r.lrn}',
                                  ].join(' · ')),
                                  trailing: SegmentedButton<String>(
                                    key: ValueKey('sex_choice_${r.userId}'),
                                    emptySelectionAllowed: true,
                                    showSelectedIcon: false,
                                    segments: const [
                                      ButtonSegment(value: 'Male', label: Text('Male')),
                                      ButtonSegment(value: 'Female', label: Text('Female')),
                                    ],
                                    selected: {if (saved != null) saved},
                                    onSelectionChanged: busy ? null : (v) => v.isEmpty ? null : _set(r, v.first),
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
          key: const ValueKey('missing_sex_done'),
          onPressed: () => Navigator.of(context).pop(_saved.isNotEmpty),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
