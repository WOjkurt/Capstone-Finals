import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/school_models.dart';
import '../../repositories/accredited_school_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';

/// Setup → Accredited schools: the schools DBTC accepts credits from. The Credits tab picks from
/// this list so each school is spelled the same way everywhere (Transferee list, TOR).
class AccreditedSchoolsTab extends StatefulWidget {
  const AccreditedSchoolsTab({super.key});

  @override
  State<AccreditedSchoolsTab> createState() => _AccreditedSchoolsTabState();
}

class _AccreditedSchoolsTabState extends State<AccreditedSchoolsTab> {
  List<AccreditedSchool>? _schools;
  List<UnlistedSchool> _unlisted = [];
  String? _error;
  String _filter = '';

  AccreditedSchoolRepository get _repo => getIt<AccreditedSchoolRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _message(Object e) => e is ApiException ? e.message : e.toString();

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final schools = await _repo.getAll();
      // Suggestions only; the list still shows if they fail to load.
      var unlisted = <UnlistedSchool>[];
      try {
        unlisted = await _repo.getUnlisted();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _schools = schools;
          _unlisted = unlisted;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (!mounted) return;
      _toast(done);
      await _load();
    } catch (e) {
      if (mounted) _toast(_message(e), error: true);
    }
  }

  Future<void> _edit([AccreditedSchool? school]) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _SchoolDialog(school: school),
    );
    if (result == null) return;
    final (name, address) = result;
    await _run(
      () => school == null
          ? _repo.create(name, address: address)
          : _repo.update(school.schoolId, name, address: address),
      school == null ? 'Added $name.' : 'Saved $name.',
    );
  }

  Future<void> _delete(AccreditedSchool school) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${school.name}?'),
        content: Text(school.creditCount == 0
            ? 'It will no longer be offered when recording credits.'
            : 'It will no longer be offered when recording credits. The ${school.creditCount} credit(s) '
                'already recorded keep this school name.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('confirm_remove_school'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) await _run(() => _repo.delete(school.schoolId), 'Removed ${school.name}.');
  }

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
    final schools = _schools;
    if (schools == null) return const Center(child: CircularProgressIndicator());
    final q = _filter.trim().toLowerCase();
    final shown = q.isEmpty ? schools : schools.where((s) => s.name.toLowerCase().contains(q)).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Schools DBTC accepts credits from. When recording a credit, pick the school from this list so '
                'it is spelled the same way on every record.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              key: const ValueKey('add_school_button'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add school'),
              onPressed: () => _edit(),
            ),
          ],
        ),
        if (_unlisted.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            key: const ValueKey('unlisted_schools'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentAmberLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Schools on existing credits that are not on the list yet:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF92400E))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final u in _unlisted)
                      ActionChip(
                        key: ValueKey('add_unlisted_${u.name}'),
                        avatar: const Icon(Icons.add, size: 16),
                        label: Text('${u.name} (${u.creditCount})'),
                        onPressed: () => _run(() => _repo.create(u.name), 'Added ${u.name}.'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (schools.length > 8)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              key: const ValueKey('school_filter'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Find a school',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: shown.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(schools.isEmpty ? 'No schools yet. Click "Add school" to start the list.' : 'No school matches.',
                      textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                )
              : Column(
                  children: [
                    for (final (i, s) in shown.indexed) ...[
                      if (i > 0) const Divider(height: 1, color: AppColors.border),
                      ListTile(
                        key: ValueKey('school_row_${s.name}'),
                        leading: const Icon(Icons.account_balance_outlined, color: AppColors.primary),
                        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text([
                          if (s.address != null) s.address!,
                          s.creditCount == 0 ? 'No credits yet' : '${s.creditCount} credit(s)',
                        ].join(' · ')),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(s)),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
                            onPressed: () => _delete(s),
                          ),
                        ]),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// Add or edit one school. Returns (name, address).
class _SchoolDialog extends StatefulWidget {
  final AccreditedSchool? school;

  const _SchoolDialog({this.school});

  @override
  State<_SchoolDialog> createState() => _SchoolDialogState();
}

class _SchoolDialogState extends State<_SchoolDialog> {
  late final _name = TextEditingController(text: widget.school?.name);
  late final _address = TextEditingController(text: widget.school?.address);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter the school\'s name.');
      return;
    }
    Navigator.pop(context, (_name.text.trim(), _address.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final renaming = widget.school != null && widget.school!.creditCount > 0;
    return AlertDialog(
      title: Text(widget.school == null ? 'Add school' : 'Edit school'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('school_name_field'),
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: 'School name *', errorText: _error, border: const OutlineInputBorder()),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('school_address_field'),
              controller: _address,
              decoration: const InputDecoration(labelText: 'Address (optional)', border: OutlineInputBorder()),
            ),
            if (renaming) ...[
              const SizedBox(height: 10),
              Text('Changing the name also updates the ${widget.school!.creditCount} credit(s) that use it.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const ValueKey('save_school_button'), onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
