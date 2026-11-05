import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../models/record_models.dart';
import '../../repositories/student_record_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/formatters.dart';

/// The student's personal details for their records (Transcript of Records). Starts from the
/// enrollment form; the Registrar fills in what is missing or corrects what is wrong.
class StudentDetailsTab extends StatefulWidget {
  final String userId;

  const StudentDetailsTab({super.key, required this.userId});

  @override
  State<StudentDetailsTab> createState() => _StudentDetailsTabState();
}

/// Field key (as the server names it), label, and hint.
const _fields = [
  ('middleName', 'Middle name', null),
  ('suffix', 'Suffix', 'e.g. Jr., III'),
  ('address', 'Address', 'House/Street, Barangay, City, Province'),
  ('placeOfBirth', 'Place of birth', null),
  ('sex', 'Sex', null),
  ('nationality', 'Nationality', null),
  ('entranceData', 'Entrance data', 'Last school attended before DBTC'),
  ('dateAdmitted', 'Date admitted', 'e.g. 1st Semester, 2024-2025'),
];

class _StudentDetailsTabState extends State<StudentDetailsTab> {
  PersonalDetails? _data;
  String? _error;
  bool _editing = false;
  bool _saving = false;
  DateTime? _dob;
  final Map<String, TextEditingController> _c = {for (final f in _fields) f.$1: TextEditingController()};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _data = null;
      _error = null;
    });
    try {
      final d = await getIt<StudentRecordRepository>().personalDetails(widget.userId);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : e.toString());
    }
  }

  String? _value(PersonalDetails d, String key) => switch (key) {
        'middleName' => d.middleName,
        'suffix' => d.suffix,
        'address' => d.address,
        'placeOfBirth' => d.placeOfBirth,
        'sex' => d.sex,
        'nationality' => d.nationality,
        'entranceData' => d.entranceData,
        'dateAdmitted' => d.dateAdmitted,
        _ => null,
      };

  void _startEditing(PersonalDetails d) {
    for (final f in _fields) {
      _c[f.$1]!.text = _value(d, f.$1) ?? '';
    }
    setState(() {
      _dob = d.dateOfBirth;
      _editing = true;
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final d = await getIt<StudentRecordRepository>().savePersonalDetails(widget.userId, {
        for (final f in _fields) f.$1: _c[f.$1]!.text.trim(),
        'dateOfBirth': _dob == null
            ? null
            : '${_dob!.year.toString().padLeft(4, '0')}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
      });
      if (!mounted) return;
      setState(() {
        _data = d;
        _editing = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Personal details saved.'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString()), backgroundColor: AppColors.error),
      );
    }
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
    final d = _data;
    if (d == null) return const Center(child: CircularProgressIndicator());
    return _editing ? _buildForm(d) : _buildView(d);
  }

  Widget _notice(PersonalDetails d) {
    final missing = d.missingForTranscript;
    final noForm = !d.hasEnrollmentForm;
    if (!noForm && missing.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('details_notice'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.accentAmberLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Text(
        [
          if (noForm) 'This student has no online enrollment form on file.',
          if (missing.isNotEmpty) 'Missing for the transcript: ${missing.join(', ')}.',
        ].join(' '),
        style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
      ),
    );
  }

  Widget _buildView(PersonalDetails d) {
    Widget row(String label, String? value, {bool fromForm = false, String? fallback}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 150, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
              Expanded(
                child: Text(
                  value ?? fallback ?? '—',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: value != null ? FontWeight.w600 : FontWeight.normal,
                    color: value != null ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
              ),
              if (fromForm)
                const Text('from enrollment form', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        );
    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Used on the Transcript of Records.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (d.updatedAt != null)
                    Text('Last edited ${formatDateTime(d.updatedAt!)}${d.updatedBy != null ? ' by ${d.updatedBy}' : ''}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('edit_details_button'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
              onPressed: () => _startEditing(d),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _notice(d),
        row('Name', '${d.lastname.toUpperCase()}, ${[d.firstname, d.middleName, d.suffix].whereType<String>().join(' ')}'),
        for (final f in _fields)
          if (f.$1 == 'dateAdmitted')
            row(f.$2, d.dateAdmitted, fallback: d.firstTermEnrolled != null ? '${d.firstTermEnrolled} (first term enrolled)' : null)
          else ...[
            row(f.$2, _value(d, f.$1), fromForm: d.fromForm.contains(f.$1)),
            if (f.$1 == 'address')
              row('Date of birth', d.dateOfBirth == null ? null : formatDate(d.dateOfBirth!),
                  fromForm: d.fromForm.contains('dateOfBirth')),
          ],
      ],
    );
  }

  Widget _buildForm(PersonalDetails d) {
    Widget field(String key, String label, String? hint) => key == 'sex'
        // A fixed choice keeps statistics and class lists exact (no "Femal" or "m").
        ? Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              key: const ValueKey('details_sex'),
              initialValue: const ['Male', 'Female'].contains(_c['sex']!.text) ? _c['sex']!.text : '',
              decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(_data?.fromForm.contains('sex') == true ? 'Use the enrollment form' : 'Not set'),
                ),
                const DropdownMenuItem(value: 'Male', child: Text('Male')),
                const DropdownMenuItem(value: 'Female', child: Text('Female')),
              ],
              onChanged: (v) => _c['sex']!.text = v ?? '',
            ),
          )
        : Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            key: ValueKey('details_$key'),
            controller: _c[key],
            decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), isDense: true),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Leave a field empty to use the enrollment form\'s value. Date admitted can be left empty to use the first term enrolled.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(onPressed: _saving ? null : () => setState(() => _editing = false), child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey('save_details_button'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView(
            children: [
              for (final f in _fields) ...[
                field(f.$1, f.$2, f.$3),
                if (f.$1 == 'address')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          key: const ValueKey('details_dob'),
                          icon: const Icon(Icons.event, size: 16),
                          label: Text(_dob == null ? 'Date of birth: not set' : 'Date of birth: ${formatDate(_dob!)}'),
                          onPressed: _pickDob,
                        ),
                        if (_dob != null)
                          TextButton(onPressed: () => setState(() => _dob = null), child: const Text('Clear')),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
