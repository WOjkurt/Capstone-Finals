import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/class_models.dart';
import '../../repositories/class_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';

/// Add, change and delete the meeting times of one class. The server refuses
/// room clashes and teacher clashes and its message is shown as-is.
class ClassScheduleDialog extends StatefulWidget {
  final ClassModel classItem;

  const ClassScheduleDialog({super.key, required this.classItem});

  /// Returns true when anything was saved or deleted.
  static Future<bool?> show(BuildContext context, ClassModel classItem) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ClassScheduleDialog(classItem: classItem),
    );
  }

  static const days = ['M', 'T', 'W', 'TH', 'F', 'S'];

  /// 7:00 AM to 9:00 PM in 30-minute steps, as 24-hour "HH:mm".
  static final List<String> timeOptions = [
    for (var minutes = 7 * 60; minutes <= 21 * 60; minutes += 30)
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}',
  ];

  static String formatTime(String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.parse(parts[0]);
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:${parts[1]} $period';
  }

  @override
  State<ClassScheduleDialog> createState() => _ClassScheduleDialogState();
}

class _ClassScheduleDialogState extends State<ClassScheduleDialog> {
  List<ClassScheduleModel> _schedules = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _changed = false;
  String? _error;

  String? _editingScheduleId;
  final Set<String> _days = {};
  String? _start;
  String? _end;
  final _roomCtrl = TextEditingController();

  ClassRepository get _repo => getIt<ClassRepository>();

  @override
  void initState() {
    super.initState();
    _schedules = widget.classItem.schedules;
    _load();
  }

  @override
  void dispose() {
    _roomCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.getSchedules(widget.classItem.classId);
      if (mounted) setState(() => _schedules = list);
    } catch (e, st) {
      if (mounted) setState(() => _error = getFriendlyErrorMessage(e, st));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static String _hhmm(String time) =>
      time.length >= 5 ? time.substring(0, 5) : time;

  void _edit(ClassScheduleModel s) {
    setState(() {
      _editingScheduleId = s.scheduleId;
      _days
        ..clear()
        ..addAll(s.daysOfWeek
            .split(RegExp(r'[/,\s]+'))
            .map((d) => d.trim().toUpperCase())
            .where(ClassScheduleDialog.days.contains));
      _start = _hhmm(s.startTime);
      _end = _hhmm(s.endTime);
      _roomCtrl.text = s.room;
      _error = null;
    });
  }

  void _resetForm() {
    setState(() {
      _editingScheduleId = null;
      _days.clear();
      _start = null;
      _end = null;
      _roomCtrl.clear();
    });
  }

  String? _validate() {
    if (_days.isEmpty) return 'Pick at least one day.';
    if (_start == null || _end == null) return 'Pick a start and end time.';
    if (_end!.compareTo(_start!) <= 0) return 'End time must be after start time.';
    if (_roomCtrl.text.trim().isEmpty) return 'Enter a room.';
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    // Keep the standard day order, e.g. "M/W/F".
    final days = ClassScheduleDialog.days.where(_days.contains).join('/');
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      if (_editingScheduleId == null) {
        await _repo.createSchedule(
          classId: widget.classItem.classId,
          daysOfWeek: days,
          startTime: _start!,
          endTime: _end!,
          room: _roomCtrl.text.trim(),
        );
      } else {
        await _repo.updateSchedule(
          scheduleId: _editingScheduleId!,
          classId: widget.classItem.classId,
          daysOfWeek: days,
          startTime: _start!,
          endTime: _end!,
          room: _roomCtrl.text.trim(),
        );
      }
      _changed = true;
      _resetForm();
      await _load();
    } catch (e, st) {
      if (mounted) setState(() => _error = getFriendlyErrorMessage(e, st));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete(ClassScheduleModel s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete schedule?'),
        content: Text('Remove ${s.summary} from ${widget.classItem.className}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await _repo.deleteSchedule(s.scheduleId);
      _changed = true;
      if (_editingScheduleId == s.scheduleId) _resetForm();
      await _load();
    } catch (e, st) {
      if (mounted) setState(() => _error = getFriendlyErrorMessage(e, st));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.classItem;
    return AlertDialog(
      title: Text('Schedule · ${c.subjectCode ?? ''} ${c.className}',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isLoading) const LinearProgressIndicator(),
              if (!_isLoading && _schedules.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No schedule yet.',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ..._schedules.map((s) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.summary),
                    selected: s.scheduleId == _editingScheduleId,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: _isSaving ? null : () => _edit(s),
                          child: const Text('Edit'),
                        ),
                        TextButton(
                          onPressed: _isSaving ? null : () => _delete(s),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  )),
              const Divider(height: 24),
              Text(_editingScheduleId == null ? 'Add a meeting time' : 'Edit meeting time',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: ClassScheduleDialog.days
                    .map((d) => FilterChip(
                          key: ValueKey('day_$d'),
                          label: Text(d),
                          selected: _days.contains(d),
                          onSelected: (on) => setState(
                              () => on ? _days.add(d) : _days.remove(d)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _timeDropdown('Start', _start, (v) => setState(() => _start = v))),
                  const SizedBox(width: 12),
                  Expanded(child: _timeDropdown('End', _end, (v) => setState(() => _end = v))),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('room_field'),
                controller: _roomCtrl,
                decoration: const InputDecoration(
                  labelText: 'Room',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_editingScheduleId != null)
                    TextButton(
                      onPressed: _isSaving ? null : _resetForm,
                      child: const Text('Cancel edit'),
                    ),
                  FilledButton(
                    key: const ValueKey('save_schedule_button'),
                    onPressed: _isSaving ? null : _save,
                    child: Text(_editingScheduleId == null ? 'Add' : 'Save changes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_changed),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _timeDropdown(String label, String? value, ValueChanged<String?> onChanged) {
    final options = [...ClassScheduleDialog.timeOptions];
    // Keep a saved time that is off the 30-minute grid selectable.
    if (value != null && !options.contains(value)) {
      options
        ..add(value)
        ..sort();
    }
    return DropdownButtonFormField<String>(
      key: ValueKey('${label.toLowerCase()}_time_${value ?? 'none'}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map((t) => DropdownMenuItem(
                value: t,
                child: Text(ClassScheduleDialog.formatTime(t)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}
