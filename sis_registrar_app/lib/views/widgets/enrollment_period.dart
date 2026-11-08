import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/setup_models.dart';
import '../../theme/app_theme.dart';

final _day = DateFormat('MMM d, yyyy');

/// "Nov 17 – Nov 28, 2026", or "Not set".
String enrollmentPeriodText(AcademicTermModel t) {
  final opens = t.enrollmentOpensOn, closes = t.enrollmentClosesOn;
  if (opens == null || closes == null) return 'Not set';
  final start = opens.year == closes.year ? DateFormat('MMM d').format(opens) : _day.format(opens);
  return '$start – ${_day.format(closes)}';
}

enum EnrollmentPeriodStatus { notSet, upcoming, open, ended }

EnrollmentPeriodStatus enrollmentPeriodStatus(AcademicTermModel t, DateTime today) {
  final opens = t.enrollmentOpensOn, closes = t.enrollmentClosesOn;
  if (opens == null || closes == null) return EnrollmentPeriodStatus.notSet;
  if (t.isEnrollmentOpen) return EnrollmentPeriodStatus.open;
  final day = DateTime(today.year, today.month, today.day);
  return day.isBefore(opens) ? EnrollmentPeriodStatus.upcoming : EnrollmentPeriodStatus.ended;
}

/// The dates and a small status chip, for the Academic Terms table.
class EnrollmentPeriodCell extends StatelessWidget {
  final AcademicTermModel term;
  final DateTime? today;

  const EnrollmentPeriodCell({super.key, required this.term, this.today});

  @override
  Widget build(BuildContext context) {
    final status = enrollmentPeriodStatus(term, today ?? DateTime.now());
    final (label, fg, bg) = switch (status) {
      EnrollmentPeriodStatus.open => ('Open', AppColors.accentGreenDark, const Color(0xFFDCFCE7)),
      EnrollmentPeriodStatus.upcoming => ('Opens soon', const Color(0xFFB45309), const Color(0xFFFEF3C7)),
      EnrollmentPeriodStatus.ended => ('Ended', AppColors.textSecondary, const Color(0xFFF1F5F9)),
      EnrollmentPeriodStatus.notSet => ('', AppColors.textSecondary, Colors.transparent),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(enrollmentPeriodText(term),
            style: TextStyle(
                fontSize: 13,
                color: status == EnrollmentPeriodStatus.notSet ? AppColors.textSecondary : AppColors.textPrimary)),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            key: ValueKey('enrollment_status_${term.termId}'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
          ),
        ],
      ],
    );
  }
}

/// What the Registrar chose in the dialog. Both null means "close online enrollment".
class EnrollmentPeriodChoice {
  final DateTime? opensOn;
  final DateTime? closesOn;
  const EnrollmentPeriodChoice(this.opensOn, this.closesOn);
}

/// Asks for the first and last day old students can enroll online. Returns null when cancelled.
Future<EnrollmentPeriodChoice?> showEnrollmentPeriodDialog(BuildContext context, AcademicTermModel term) =>
    showDialog<EnrollmentPeriodChoice>(context: context, builder: (_) => _EnrollmentPeriodDialog(term: term));

class _EnrollmentPeriodDialog extends StatefulWidget {
  final AcademicTermModel term;
  const _EnrollmentPeriodDialog({required this.term});

  @override
  State<_EnrollmentPeriodDialog> createState() => _EnrollmentPeriodDialogState();
}

class _EnrollmentPeriodDialogState extends State<_EnrollmentPeriodDialog> {
  late DateTime? _opens = widget.term.enrollmentOpensOn;
  late DateTime? _closes = widget.term.enrollmentClosesOn;

  bool get _inOrder => _opens != null && _closes != null && !_closes!.isBefore(_opens!);

  Future<void> _pick({required bool start}) async {
    final now = DateTime.now();
    final current = start ? _opens : _closes;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? (start ? now : (_opens ?? now)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: start ? 'Enrollment starts' : 'Enrollment ends',
    );
    if (picked == null) return;
    setState(() => start ? _opens = picked : _closes = picked);
  }

  Widget _dateButton(String key, String label, DateTime? value, bool start) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              key: ValueKey(key),
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(value == null ? 'Pick a date' : _day.format(value)),
              onPressed: () => _pick(start: start),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final hasDates = widget.term.enrollmentOpensOn != null;
    return AlertDialog(
      title: Text('Online Enrollment · ${widget.term.label}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Old students can enroll for this term in the Student Portal from the start date until the end of the last day.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _dateButton('enrollment_opens_button', 'Starts', _opens, true),
                const SizedBox(width: 12),
                _dateButton('enrollment_closes_button', 'Ends', _closes, false),
              ],
            ),
            if (_opens != null && _closes != null && !_inOrder) ...[
              const SizedBox(height: 10),
              const Text('The end date cannot be before the start date.',
                  style: TextStyle(fontSize: 12, color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        if (hasDates)
          TextButton(
            key: const ValueKey('enrollment_close_now_button'),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(const EnrollmentPeriodChoice(null, null)),
            child: const Text('Close enrollment'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('enrollment_save_button'),
          onPressed: _inOrder ? () => Navigator.of(context).pop(EnrollmentPeriodChoice(_opens, _closes)) : null,
          child: const Text('Save dates'),
        ),
      ],
    );
  }
}
