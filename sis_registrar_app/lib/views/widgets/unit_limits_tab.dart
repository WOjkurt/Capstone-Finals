import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../repositories/school_settings_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/formatters.dart';

/// Setup → Limits & Rules: the summer unit limits and the Dean's list rules, which the Registrar can change at any time.
class UnitLimitsTab extends StatefulWidget {
  const UnitLimitsTab({super.key});

  @override
  State<UnitLimitsTab> createState() => _UnitLimitsTabState();
}

class _UnitLimitsTabState extends State<UnitLimitsTab> {
  final _summer = TextEditingController();
  final _graduating = TextEditingController();
  UnitLimitSettings? _saved;
  String? _error;
  bool _saving = false;

  static String _units(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _summer.dispose();
    _graduating.dispose();
    super.dispose();
  }

  String _message(Object e) => e is ApiException ? e.message : e.toString();

  void _show(UnitLimitSettings s) {
    _summer.text = _units(s.summerMaxUnits);
    _graduating.text = _units(s.graduatingSummerMaxUnits);
    _saved = s;
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final s = await getIt<SchoolSettingsRepository>().getUnitLimits();
      if (mounted) setState(() => _show(s));
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? AppColors.error : AppColors.success));
  }

  Future<void> _save() async {
    final summer = double.tryParse(_summer.text.trim());
    final graduating = double.tryParse(_graduating.text.trim());
    if (summer == null || graduating == null) {
      _toast('Enter both limits as numbers.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final s = await getIt<SchoolSettingsRepository>().saveUnitLimits(summer: summer, graduating: graduating);
      if (!mounted) return;
      setState(() => _show(s));
      _toast('Unit limits saved. They apply to new study loads from now on.');
    } catch (e) {
      if (mounted) _toast(_message(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String key, TextEditingController c, String label, String helper) => TextField(
    key: ValueKey(key),
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      suffixText: 'units',
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final saved = _saved;
    if (saved == null) return const Center(child: CircularProgressIndicator());
    final changed =
        _summer.text.trim() != _units(saved.summerMaxUnits) || _graduating.text.trim() != _units(saved.graduatingSummerMaxUnits);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsCard(
                  icon: Icons.wb_sunny_outlined,
                  title: 'Summer unit limits',
                  description:
                      'The most units a student can take in a summer term without an overload approval. '
                      'Regular semesters follow each program\'s curriculum load. Failed subjects retaken in summer are extra.',
                  fields: [
                    _field('summer_limit_field', _summer, 'Regular students', 'CHED default: 9'),
                    _field('graduating_limit_field', _graduating, 'Graduating students', 'CHED default: 12'),
                  ],
                  status: saved.updatedAt == null
                      ? 'Using the starting values.'
                      : 'Last changed ${formatDateTime(saved.updatedAt!)}${saved.updatedBy != null ? ' by ${saved.updatedBy}' : ''}',
                  statusKey: const ValueKey('unit_limits_status'),
                  saveKey: const ValueKey('save_unit_limits_button'),
                  saving: _saving,
                  changed: changed,
                  onSave: _save,
                  onUndo: () => setState(() => _show(saved)),
                ),
                const SizedBox(height: 24),
                const DeansListRulesSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A settings section as a card: header with icon, title and description; the fields side by side;
/// a footer with when it was last changed and the Save button (on only after something changed).
class SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<Widget> fields;
  final String status;
  final Key statusKey;
  final Key saveKey;
  final bool saving;
  final bool changed;
  final VoidCallback onSave;
  final VoidCallback onUndo;

  const SettingsCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.fields,
    required this.status,
    required this.statusKey,
    required this.saveKey,
    required this.saving,
    required this.changed,
    required this.onSave,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(description, style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, c) => c.maxWidth < 480
                  ? Column(
                      children: [
                        for (final (i, f) in fields.indexed) ...[if (i > 0) const SizedBox(height: 16), f],
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (i, f) in fields.indexed) ...[if (i > 0) const SizedBox(width: 16), Expanded(child: f)],
                      ],
                    ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.scaffoldBg,
              border: Border(top: BorderSide(color: AppColors.border)),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    status,
                    key: statusKey,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                if (changed && !saving) ...[TextButton(onPressed: onUndo, child: const Text('Undo changes')), const SizedBox(width: 8)],
                FilledButton(key: saveKey, onPressed: saving || !changed ? null : onSave, child: Text(saving ? 'Saving…' : 'Save changes')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Dean's list rules. Units are always the student's regular study load, so only the grades are set here.
class DeansListRulesSection extends StatefulWidget {
  const DeansListRulesSection({super.key});

  @override
  State<DeansListRulesSection> createState() => _DeansListRulesSectionState();
}

class _DeansListRulesSectionState extends State<DeansListRulesSection> {
  final _gwa = TextEditingController();
  final _worst = TextEditingController();
  DeansListRules? _saved;
  String? _error;
  bool _saving = false;

  static String _grade(double v) {
    final two = v.toStringAsFixed(2);
    return two.endsWith('0') ? v.toStringAsFixed(1) : two;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _gwa.dispose();
    _worst.dispose();
    super.dispose();
  }

  void _show(DeansListRules r) {
    _gwa.text = _grade(r.maxGwa);
    _worst.text = _grade(r.worstGrade);
    _saved = r;
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await getIt<SchoolSettingsRepository>().getDeansListRules();
      if (mounted) setState(() => _show(r));
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : e.toString());
    }
  }

  Future<void> _save() async {
    final gwa = double.tryParse(_gwa.text.trim());
    final worst = double.tryParse(_worst.text.trim());
    final messenger = ScaffoldMessenger.of(context);
    void toast(String text, {bool error = false}) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? AppColors.error : AppColors.success));
    if (gwa == null || worst == null) {
      toast('Enter both grades as numbers, e.g. 1.7 and 2.3.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final r = await getIt<SchoolSettingsRepository>().saveDeansListRules(maxGwa: gwa, worstGrade: worst);
      if (!mounted) return;
      setState(() => _show(r));
      toast('Dean\'s list rules saved.');
    } catch (e) {
      if (mounted) toast(e is ApiException ? e.message : e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String key, TextEditingController c, String label, String helper) => TextField(
    key: ValueKey(key),
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(labelText: label, helperText: helper, border: const OutlineInputBorder(), isDense: true),
  );

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Row(
        children: [
          Expanded(
            child: Text(_error!, style: const TextStyle(color: AppColors.error)),
          ),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }
    final saved = _saved;
    if (saved == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final changed = _gwa.text.trim() != _grade(saved.maxGwa) || _worst.text.trim() != _grade(saved.worstGrade);
    return SettingsCard(
      icon: Icons.workspace_premium_outlined,
      title: 'Dean\'s list rules',
      description:
          'A student makes the Dean\'s list when they carry at least their regular study load, their GWA over '
          'every subject (NSTP and PE included) meets the limit, and no grade is below the lowest allowed grade. '
          'A failed, dropped or withdrawn subject leaves them out.',
      fields: [
        _field('deans_rule_gwa', _gwa, 'GWA at most', 'DBTC rule: 1.7'),
        _field('deans_rule_worst', _worst, 'Lowest allowed grade', 'DBTC rule: 2.3'),
      ],
      status: saved.updatedAt == null
          ? 'Using DBTC\'s rules (GWA 1.7, no grade below 2.3).'
          : 'Last changed ${formatDateTime(saved.updatedAt!)}${saved.updatedBy != null ? ' by ${saved.updatedBy}' : ''}',
      statusKey: const ValueKey('deans_rules_status'),
      saveKey: const ValueKey('save_deans_rules_button'),
      saving: _saving,
      changed: changed,
      onSave: _save,
      onUndo: () => setState(() => _show(saved)),
    );
  }
}
