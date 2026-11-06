import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../repositories/school_settings_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/formatters.dart';

/// Setup → Unit Limits: the summer limits, which the Registrar can change at any time.
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
      ],
    );
  }
}
