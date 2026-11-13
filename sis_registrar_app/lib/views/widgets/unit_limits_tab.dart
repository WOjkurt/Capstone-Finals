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

  Widget _field(String key, TextEditingController c, String label) => TextField(
        key: ValueKey(key),
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: 'units', border: const OutlineInputBorder(), isDense: true),
      );

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: const TextStyle(color: AppColors.error)),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }
    final saved = _saved;
    if (saved == null) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Summer unit limits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(
                  'The most units a student can take in a summer term without an overload approval. '
                  'Regular semesters follow each program\'s curriculum load.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                _field('summer_limit_field', _summer, 'Regular students'),
                const SizedBox(height: 12),
                _field('graduating_limit_field', _graduating, 'Graduating students'),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        saved.updatedAt == null
                            ? 'Using the starting values.'
                            : 'Last changed ${formatDateTime(saved.updatedAt!)}${saved.updatedBy != null ? ' by ${saved.updatedBy}' : ''}',
                        key: const ValueKey('unit_limits_status'),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    FilledButton(
                      key: const ValueKey('save_unit_limits_button'),
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: const DeansListRulesSection()),
        ),
      ],
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

  Widget _field(String key, TextEditingController c, String label) => TextField(
        key: ValueKey(key),
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      );

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Row(children: [
        Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error))),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ]);
    }
    final saved = _saved;
    if (saved == null) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Dean\'s list rules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text(
          'A student makes the Dean\'s list when they carried at least their regular study load, their GWA over every '
          'subject (NSTP and PE included) is this or better, and no subject grade is below the lowest allowed grade. '
          'A failed, dropped or withdrawn subject leaves them out.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        _field('deans_rule_gwa', _gwa, 'GWA at most (e.g. 1.7)'),
        const SizedBox(height: 12),
        _field('deans_rule_worst', _worst, 'Lowest allowed grade (e.g. 2.3)'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                saved.updatedAt == null
                    ? 'Using DBTC\'s rules (GWA 1.7, no grade below 2.3).'
                    : 'Last changed ${formatDateTime(saved.updatedAt!)}${saved.updatedBy != null ? ' by ${saved.updatedBy}' : ''}',
                key: const ValueKey('deans_rules_status'),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            FilledButton(
              key: const ValueKey('save_deans_rules_button'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ],
    );
  }
}
