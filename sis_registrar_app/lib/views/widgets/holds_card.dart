import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/hold_models.dart';
import '../../repositories/hold_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/formatters.dart';
import 'reason_dialog.dart';

/// Holds that stop the student from enrolling online (for example an unpaid balance), with Add and Remove.
class HoldsCard extends StatefulWidget {
  final String userId;
  final HoldRepository? repository;

  const HoldsCard({super.key, required this.userId, this.repository});

  @override
  State<HoldsCard> createState() => _HoldsCardState();
}

class _HoldsCardState extends State<HoldsCard> {
  late final HoldRepository _repo = widget.repository ?? getIt<HoldRepository>();
  List<EnrollmentHold>? _holds;
  String? _error;
  bool _busy = false;
  bool _showRemoved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final holds = await _repo.forStudent(widget.userId);
      if (mounted) {
        setState(() {
          _holds = holds;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : e.toString());
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException ? e.message : e.toString()),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final choice = await showDialog<(String, String)>(context: context, builder: (_) => const _AddHoldDialog());
    if (choice == null) return;
    await _run(() => _repo.add(widget.userId, reason: choice.$1, note: choice.$2.isEmpty ? null : choice.$2));
  }

  Future<void> _remove(EnrollmentHold h) async {
    final note = await ReasonDialog.ask(
      context,
      title: 'Remove hold?',
      message: 'The student will be able to enroll online again if they have no other holds.',
      label: 'Note (optional)',
      hint: 'e.g. Paid on Nov 20, OR #12345',
      confirmLabel: 'Remove hold',
      required: false,
    );
    if (note == null) return;
    await _run(() => _repo.remove(h.holdId, note: note.isEmpty ? null : note));
  }

  @override
  Widget build(BuildContext context) {
    final holds = _holds;
    final open = holds?.where((h) => h.isOpen).toList() ?? const [];
    final removed = holds?.where((h) => !h.isOpen).toList() ?? const [];
    return Container(
      key: const ValueKey('holds_card'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: open.isEmpty ? Colors.white : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: open.isEmpty ? AppColors.border : const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(open.isEmpty ? Icons.verified_outlined : Icons.block,
                  size: 18, color: open.isEmpty ? AppColors.accentGreenDark : AppColors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  holds == null
                      ? (_error ?? 'Loading holds…')
                      : open.isEmpty
                          ? 'No holds. This student can enroll online.'
                          : 'On hold: cannot enroll online',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _error != null && holds == null
                          ? AppColors.error
                          : open.isEmpty
                              ? AppColors.textPrimary
                              : AppColors.error),
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('add_hold_button'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add hold'),
                onPressed: _busy || holds == null ? null : _add,
              ),
            ],
          ),
          for (final h in open)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                key: ValueKey('hold_${h.holdId}'),
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.reasonLabel + (h.note != null ? ': ${h.note}' : ''),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                          'Added${h.addedAt != null ? ' ${formatDate(h.addedAt!)}' : ''}'
                          '${h.addedByName != null ? ' by ${h.addedByName}' : ''}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: ValueKey('remove_hold_${h.holdId}'),
                    onPressed: _busy ? null : () => _remove(h),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            ),
          if (removed.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('show_removed_holds'),
                onPressed: () => setState(() => _showRemoved = !_showRemoved),
                child: Text(_showRemoved ? 'Hide removed holds' : 'Show removed holds (${removed.length})'),
              ),
            ),
            if (_showRemoved)
              for (final h in removed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${h.reasonLabel}${h.note != null ? ': ${h.note}' : ''}. Removed'
                    '${h.removedAt != null ? ' ${formatDate(h.removedAt!)}' : ''}'
                    '${h.removedByName != null ? ' by ${h.removedByName}' : ''}'
                    '${h.removalNote != null ? ' (${h.removalNote})' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

/// Returns (reason, note) or null when cancelled.
class _AddHoldDialog extends StatefulWidget {
  const _AddHoldDialog();

  @override
  State<_AddHoldDialog> createState() => _AddHoldDialogState();
}

class _AddHoldDialogState extends State<_AddHoldDialog> {
  final _note = TextEditingController();
  String _reason = EnrollmentHoldReasons.unpaidBalance;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final note = _note.text.trim();
    if (_reason == EnrollmentHoldReasons.other && note.isEmpty) {
      setState(() => _error = 'Write what the hold is for.');
      return;
    }
    Navigator.of(context).pop((_reason, note));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add enrollment hold'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The student cannot enroll online until the hold is removed.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: const ValueKey('hold_reason_field'),
              initialValue: _reason,
              decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: EnrollmentHoldReasons.unpaidBalance, child: Text('Unpaid balance')),
                DropdownMenuItem(value: EnrollmentHoldReasons.other, child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _reason = v ?? _reason),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('hold_note_field'),
              controller: _note,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: _reason == EnrollmentHoldReasons.other ? 'What is it for?' : 'Note (optional)',
                hintText: _reason == EnrollmentHoldReasons.other ? 'e.g. Missing Form 137' : 'e.g. Balance of P2,500',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(key: const ValueKey('save_hold_button'), onPressed: _save, child: const Text('Add hold')),
      ],
    );
  }
}
