import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/activity_log_models.dart';
import '../../repositories/activity_log_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/formatters.dart';


/// Filterable, paged list of activity log entries. With [studentId] it shows one student's history.
class ActivityLogBrowser extends StatefulWidget {
  final String? studentId;
  final int pageSize;

  const ActivityLogBrowser({super.key, this.studentId, this.pageSize = 50});

  @override
  State<ActivityLogBrowser> createState() => _ActivityLogBrowserState();
}

class _ActivityLogBrowserState extends State<ActivityLogBrowser> {
  String? _action;
  DateTime? _from;
  DateTime? _to;
  int _page = 1;
  ActivityLogPage? _data;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await getIt<ActivityLogRepository>().search(
        from: _from,
        to: _to,
        action: _action,
        studentId: widget.studentId,
        page: _page,
        pageSize: widget.pageSize,
      );
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : e.toString();
          _loading = false;
        });
      }
    }
  }

  void _refilter(VoidCallback change) {
    setState(() {
      change();
      _page = 1;
    });
    _load();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) _refilter(() => isFrom ? _from = picked : _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String?>(
                key: const ValueKey('activity_action_dropdown'),
                initialValue: _action,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Action', isDense: true, border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('All actions')),
                  for (final e in kActivityActionLabels.entries)
                    DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => _refilter(() => _action = v),
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('activity_from_button'),
              icon: const Icon(Icons.event, size: 16),
              label: Text(_from == null ? 'From: any' : 'From: ${formatDate(_from!)}'),
              onPressed: () => _pickDate(isFrom: true),
            ),
            OutlinedButton.icon(
              key: const ValueKey('activity_to_button'),
              icon: const Icon(Icons.event, size: 16),
              label: Text(_to == null ? 'To: any' : 'To: ${formatDate(_to!)}'),
              onPressed: () => _pickDate(isFrom: false),
            ),
            if (_action != null || _from != null || _to != null)
              TextButton(
                key: const ValueKey('activity_clear_filters'),
                onPressed: () => _refilter(() {
                  _action = null;
                  _from = null;
                  _to = null;
                }),
                child: const Text('Clear filters'),
              ),
            IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildList(data)),
        if (data != null && data.totalCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('${data.totalCount} entr${data.totalCount == 1 ? 'y' : 'ies'} · page ${data.page} of ${data.pageCount}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                IconButton(
                  key: const ValueKey('activity_prev_page'),
                  icon: const Icon(Icons.chevron_left),
                  onPressed: (_loading || _page <= 1)
                      ? null
                      : () {
                          setState(() => _page--);
                          _load();
                        },
                ),
                IconButton(
                  key: const ValueKey('activity_next_page'),
                  icon: const Icon(Icons.chevron_right),
                  onPressed: (_loading || _page >= data.pageCount)
                      ? null
                      : () {
                          setState(() => _page++);
                          _load();
                        },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildList(ActivityLogPage? data) {
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)));
    }
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (data.items.isEmpty) {
      return const Center(
          child: Text('No activity recorded yet.', style: TextStyle(color: AppColors.textSecondary)));
    }
    return ListView.separated(
      itemCount: data.items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) {
        final e = data.items[i];
        final who = e.actorRoleName.isEmpty ? e.actorName : '${e.actorName} (${e.actorRoleName})';
        final about = [
          if (widget.studentId == null && e.studentName != null) e.studentName!,
          if (e.termLabel != null) e.termLabel!,
        ].join(' · ');
        return Container(
          key: ValueKey('activity_entry_${e.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(formatDateTime(e.occurredAt),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.actionLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(e.summary, style: const TextStyle(fontSize: 13)),
                    Text(
                      about.isEmpty ? 'By $who' : 'By $who · $about',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One student's history, opened from their Study Load window.
class StudentHistoryDialog extends StatelessWidget {
  final String studentId;
  final String studentName;

  const StudentHistoryDialog({super.key, required this.studentId, required this.studentName});

  static Future<void> show(BuildContext context, {required String studentId, required String studentName}) =>
      showDialog<void>(
        context: context,
        builder: (_) => StudentHistoryDialog(studentId: studentId, studentName: studentName),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 820,
        height: 620,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('History — $studentName',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                ),
                IconButton(icon: const Icon(Icons.close), tooltip: 'Close', onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(child: ActivityLogBrowser(studentId: studentId, pageSize: 25)),
          ],
        ),
      ),
    );
  }
}
