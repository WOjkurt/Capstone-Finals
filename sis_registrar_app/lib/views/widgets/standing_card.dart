import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/record_models.dart';
import '../../repositories/student_record_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/formatters.dart';

/// Regular or irregular, with progress back to regular: an irregular student becomes regular again
/// after passing 6 units of back major subjects. The Registrar confirms each change.
class StandingCard extends StatefulWidget {
  final String userId;

  const StandingCard({super.key, required this.userId});

  @override
  State<StandingCard> createState() => _StandingCardState();
}

class _StandingCardState extends State<StandingCard> {
  Standing? _standing;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await getIt<StudentRecordRepository>().standing(widget.userId);
      if (mounted) setState(() => _standing = s);
    } catch (_) {
      // The rest of the Evaluation tab still works without it.
    }
  }

  static String _units(double u) => u.toStringAsFixed(u % 1 == 0 ? 0 : 1);

  Future<void> _set(bool regular) async {
    final s = _standing!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(regular ? 'Mark as regular?' : 'Mark as irregular?'),
        content: Text(regular
            ? (s.backMajorUnitsPassed >= s.unitsToRegular
                ? 'The student has passed ${_units(s.backMajorUnitsPassed)} units of back major subjects.'
                : 'The student has passed only ${_units(s.backMajorUnitsPassed)} of the ${_units(s.unitsToRegular)} '
                    'back major units needed. Mark as regular anyway?')
            : 'From now on, back major subjects the student passes count toward becoming regular again '
                '(${_units(s.unitsToRegular)} units).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('confirm_standing_button'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(regular ? 'Mark regular' : 'Mark irregular'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final updated = await getIt<StudentRecordRepository>().setStanding(widget.userId, isRegular: regular);
      if (mounted) setState(() => _standing = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException ? e.message : e.toString()),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _button({required Key key, required String label, required bool emphasised, VoidCallback? onPressed}) =>
      emphasised
          ? FilledButton(key: key, onPressed: onPressed, child: Text(label))
          : TextButton(key: key, onPressed: onPressed, child: Text(label));

  @override
  Widget build(BuildContext context) {
    final s = _standing;
    if (s == null) return const SizedBox.shrink();
    final progress = (s.backMajorUnitsPassed / s.unitsToRegular).clamp(0.0, 1.0);
    final suggestRegular = s.suggestion == 'MarkRegular';
    final suggestIrregular = s.suggestion == 'MarkIrregular';

    return Container(
      key: const ValueKey('standing_card'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: suggestRegular || suggestIrregular ? AppColors.accentAmberLight : AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: suggestRegular || suggestIrregular ? const Color(0xFFFCD34D) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(s.isRegular ? Icons.verified_outlined : Icons.report_gmailerrorred_outlined,
                  size: 18, color: s.isRegular ? AppColors.accentGreenDark : AppColors.warning),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  s.isRegular
                      ? 'Regular student'
                      : 'Irregular${s.irregularSince != null ? ' since ${formatDate(s.irregularSince!)}' : ''}',
                  key: const ValueKey('standing_label'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              _button(
                key: ValueKey(s.isRegular ? 'mark_irregular_button' : 'mark_regular_button'),
                label: s.isRegular ? 'Mark irregular' : 'Mark regular',
                // The suggested change gets the filled button.
                emphasised: s.isRegular ? suggestIrregular : suggestRegular,
                onPressed: _saving ? null : () => _set(!s.isRegular),
              ),
            ],
          ),
          if (!s.isRegular) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.border,
                color: suggestRegular ? AppColors.accentGreen : AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_units(s.backMajorUnitsPassed)} of ${_units(s.unitsToRegular)} back major units passed'
              '${s.countedSubjects.isEmpty ? '' : ' (${s.countedSubjects.join(', ')})'}'
              '${suggestRegular ? ' — ready to be regular again.' : '.'}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (s.unresolvedSubjects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Not yet passed after a fail or drop: ${s.unresolvedSubjects.join(', ')}'
                '${suggestIrregular ? ' — consider marking the student irregular.' : ''}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
