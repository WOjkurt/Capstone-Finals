import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../injection.dart';
import '../models/reenrollment_models.dart';
import '../repositories/reenrollment_repository.dart';
import '../theme/app_theme.dart';
import '../utils/error_handler.dart';
import '../utils/phone_zip.dart';
import 'widgets/page_header.dart';

final _day = DateFormat('MMM d, yyyy');

/// One field of the form: its key in the API's form, its label, and how to check it.
class _Field {
  final String key;
  final String label;
  final bool required;
  final String? Function(String?)? check;
  final List<String>? choices;
  final bool wide;
  final bool number;

  const _Field(this.key, this.label,
      {this.required = false, this.check, this.choices, this.wide = false, this.number = false});
}

const _personal = [
  _Field('lastName', 'Last name'),
  _Field('firstName', 'First name'),
  _Field('middleName', 'Middle name'),
  _Field('suffix', 'Suffix'),
  _Field('dateOfBirth', 'Date of birth'),
  _Field('placeOfBirth', 'Place of birth'),
  _Field('sex', 'Sex'),
  _Field('lrn', 'LRN'),
  _Field('civilStatus', 'Civil status', required: true, choices: ['Single', 'Married', 'Widowed', 'Separated']),
  _Field('nationality', 'Nationality', required: true),
  _Field('religion', 'Religion'),
  _Field('gender', 'Gender identity'),
  _Field('bloodType', 'Blood type'),
  _Field('facebookName', 'Facebook name'),
];

const _address = [
  _Field('mobileNumber', 'Mobile number', required: true, check: mobileError),
  _Field('houseStreet', 'House no. / street', wide: true),
  _Field('barangay', 'Barangay', required: true),
  _Field('cityMunicipality', 'City / municipality', required: true),
  _Field('province', 'Province', required: true),
  _Field('zipCode', 'ZIP code', required: true, check: zipError),
  _Field('provHouseStreet', 'Provincial house no. / street', wide: true),
  _Field('provBarangay', 'Provincial barangay'),
  _Field('provCityMunicipality', 'Provincial city / municipality'),
  _Field('provProvince', 'Provincial province'),
  _Field('provZipCode', 'Provincial ZIP code', check: zipError),
];

const _family = [
  _Field('birthOrder', 'Birth order'),
  _Field('numberOfSiblings', 'Number of siblings', number: true),
  _Field('familyStatus', 'Family status'),
];

const _health = [
  _Field('ongoingMedications', 'Medicines you take now', wide: true),
  _Field('developmentalConditions', 'Developmental conditions', wide: true),
  _Field('otherMedicalDiagnosis', 'Other medical diagnosis', wide: true),
  _Field('familyMedicalConditionsNotes', 'Family medical history notes', wide: true),
];

const _contactFields = [
  _Field('lastName', 'Last name', required: true),
  _Field('firstName', 'First name', required: true),
  _Field('contactNo', 'Contact number', required: true, check: phoneError),
  _Field('occupation', 'Occupation'),
  _Field('email', 'Email'),
  _Field('workplace', 'Workplace'),
];

const _relations = {1: 'Father', 2: 'Mother', 3: 'Guardian'};

/// Old students enroll for the next term here, with last time's information already filled in.
class EnrollmentView extends StatefulWidget {
  final ReenrollmentRepository? repository;

  const EnrollmentView({super.key, this.repository});

  @override
  State<EnrollmentView> createState() => _EnrollmentViewState();
}

class _EnrollmentViewState extends State<EnrollmentView> {
  late final ReenrollmentRepository _repo = widget.repository ?? getIt<ReenrollmentRepository>();
  final _formKey = GlobalKey<FormState>();

  ReenrollmentStatus? _status;
  String? _error;
  bool _editing = false;
  bool _sending = false;
  bool _confirmed = false;
  int? _yearLevel;
  int _step = 0;

  /// Shown in the bottom bar when Next finds a mistake (a pop-up message would cover the buttons).
  String? _stepError;
  bool _showProvincial = false;
  final Set<int> _openContacts = {};
  Map<String, dynamic> _form = {};
  Map<String, dynamic> _original = {};
  Map<int, Map<String, dynamic>> _contacts = {};
  Map<int, Map<String, dynamic>> _originalContacts = {};

  static const _steps = ['Personal information', 'Contact and address', 'Parents and guardian', 'Family and health', 'Review and send'];
  static const _reviewStep = 4;

  // "provBarangay", "provZipCode"... but not "province", which is part of the main address.
  static final _isProvincial = RegExp(r'^prov[A-Z]');
  static final _mainAddress = _address.where((f) => !_isProvincial.hasMatch(f.key)).toList();
  static final _provincial = _address.where((f) => _isProvincial.hasMatch(f.key)).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _status = null;
    });
    try {
      final s = await _repo.status();
      if (!mounted) return;
      setState(() {
        _status = s;
        _editing = false;
        _confirmed = false;
        _step = 0;
        _stepError = null;
        _openContacts.clear();
        _form = Map.of(s.form ?? {});
        _original = Map.of(s.form ?? {});
        _showProvincial = _provincial.any((f) => _text(_form[f.key]).isNotEmpty);
        _contacts = {for (final c in s.contacts) (c['relationType'] as num).toInt(): Map.of(c)};
        _originalContacts = {for (final c in s.contacts) (c['relationType'] as num).toInt(): Map.of(c)};
        _yearLevel = s.yearLevelChoices.contains(s.currentYearLevel)
            ? s.currentYearLevel
            : (s.yearLevelChoices.isEmpty ? null : s.yearLevelChoices.first);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Could not load enrollment. $e');
    }
  }

  /// What is wrong with a value, or null. Used by the fields and to check hidden fields before Next.
  static String? _problem(_Field f, Object? raw) {
    final t = _text(raw);
    if (f.required && t.isEmpty) return '${f.label} is required';
    if (f.number && t.isNotEmpty && int.tryParse(t) == null) return 'Numbers only';
    return f.check?.call(t);
  }

  /// Checks this step only. Fields folded away (provincial address, a parent's card) are opened first
  /// when they have a mistake, so the student sees it.
  Future<void> _next() async {
    if (_step == 1 && _provincial.any((f) => _problem(f, _form[f.key]) != null)) _showProvincial = true;
    if (_step == 2) {
      for (final type in _contacts.keys) {
        if (_contactFields.any((f) => _problem(f, _contacts[type]![f.key]) != null)) _openContacts.add(type);
      }
    }
    setState(() {});
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (!(_formKey.currentState?.validate() ?? true)) {
      setState(() => _stepError = 'Please fix the fields marked in red.');
      return;
    }
    _goTo(_step + 1);
  }

  void _back() => _goTo(_step - 1);

  void _goTo(int step) => setState(() {
        _step = step;
        _stepError = null;
      });

  Future<void> _cancel() async {
    if (_changedItems.isNotEmpty) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Leave without sending?'),
          content: const Text('Your changes will not be saved.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
            TextButton(
              key: const ValueKey('confirm_leave_button'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Leave'),
            ),
          ],
        ),
      );
      if (leave != true) return;
    }
    await _load();
  }

  Future<void> _submit() async {
    final s = _status!;
    setState(() => _sending = true);
    try {
      final message = await _repo.submit(
        termId: s.termId!,
        yearLevel: _yearLevel!,
        form: _form,
        contacts: [for (final type in _contacts.keys.toList()..sort()) _contacts[type]!],
      );
      _snack(message);
      await _load();
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Could not send. $e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  static String _text(Object? v) => v == null ? '' : '$v'.trim();

  bool _changed(String key) => _text(_form[key]) != _text(_original[key]);

  bool _contactChanged(int type, String key) =>
      _text(_contacts[type]?[key]) != _text(_originalContacts[type]?[key]);

  bool _anyContactChange(int type) => _contactFields.any((f) => _contactChanged(type, f.key));

  /// Each change and the step it is on, for the review list.
  List<(String, int)> get _changedItems => [
        for (final f in _personal) if (_changed(f.key)) (f.label, 0),
        for (final f in _address) if (_changed(f.key)) (f.label, 1),
        for (final type in _relations.keys) if (_anyContactChange(type)) (_relations[type]!, 2),
        for (final f in [..._family, ..._health]) if (_changed(f.key)) (f.label, 3),
      ];

  @override
  Widget build(BuildContext context) {
    final s = _status;
    if (_editing && s != null && s.state == ReenrollmentStatus.ready) return _wizard(s);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Enrollment',
              subtitle: 'Enroll for the next term with your information from last time.',
              onRefresh: _load,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: _body(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return _Notice(
        key: const ValueKey('enrollment_error'),
        icon: Icons.error_outline_rounded,
        color: AppColors.error,
        title: 'Could not load enrollment',
        lines: [_error!],
        action: OutlinedButton(onPressed: _load, child: const Text('Try again')),
      );
    }
    final s = _status;
    if (s == null) {
      return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
    }
    switch (s.state) {
      case ReenrollmentStatus.closed:
        return const _Notice(
          key: ValueKey('enrollment_closed'),
          icon: Icons.event_busy_outlined,
          color: AppColors.textSecondary,
          title: 'Online enrollment is not open right now',
          lines: ['When the Registrar opens enrollment for the next term, you can enroll here.'],
        );
      case ReenrollmentStatus.notEligible:
        return _Notice(
          key: const ValueKey('enrollment_not_eligible'),
          icon: Icons.info_outline_rounded,
          color: const Color(0xFFB45309),
          title: 'You can\'t enroll online for ${s.termLabel ?? 'this term'}',
          lines: s.reasons,
        );
      case ReenrollmentStatus.onHold:
        return _Notice(
          key: const ValueKey('enrollment_on_hold'),
          icon: Icons.block_rounded,
          color: AppColors.error,
          title: 'You can\'t enroll yet',
          lines: [
            ...s.reasons,
            if (s.closesOn != null) 'Enrollment for ${s.termLabel} closes on ${_day.format(s.closesOn!)}.',
          ],
        );
      case ReenrollmentStatus.submitted:
        return _submitted(s);
      default:
        return _openBanner(s);
    }
  }

  Widget _openBanner(ReenrollmentStatus s) => Container(
        key: const ValueKey('enrollment_open_banner'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enrollment for ${s.termLabel} is open',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
            const SizedBox(height: 6),
            Text(
              [
                if (s.closesOn != null) 'You can enroll until ${_day.format(s.closesOn!)}.',
                'Your information${s.filledFromTerm != null ? ' from ${s.filledFromTerm}' : ''} is already filled in. '
                    'Check it, change what is different, and send it.',
              ].join(' '),
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('start_enrollment_button'),
              icon: const Icon(Icons.how_to_reg_outlined, size: 18),
              label: Text('Enroll for ${s.termLabel}'),
              onPressed: () => setState(() => _editing = true),
            ),
          ],
        ),
      );

  Widget _submitted(ReenrollmentStatus s) {
    final approved = s.applicationStatus == 'Active' || s.applicationStatus == 'Approved';
    Widget step(String text, {required bool done, bool now = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(done ? Icons.check_circle_rounded : (now ? Icons.timelapse_rounded : Icons.radio_button_unchecked),
                  size: 18,
                  color: done ? AppColors.success : (now ? const Color(0xFFB45309) : AppColors.textMuted)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 13, color: done || now ? AppColors.textPrimary : AppColors.textSecondary)),
              ),
            ],
          ),
        );
    return Container(
      key: const ValueKey('enrollment_submitted'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enrollment for ${s.termLabel}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: approved ? AppColors.accentGreenLight : AppColors.accentAmberLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(approved ? 'Approved by the Registrar' : 'Waiting for the Registrar',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: approved ? AppColors.accentGreenDark : const Color(0xFFB45309))),
          ),
          const SizedBox(height: 12),
          step('Sent${s.submittedAt != null ? ' on ${_day.format(s.submittedAt!.toLocal())}' : ''}', done: true),
          step('The Registrar checks your information', done: approved, now: !approved),
          step('The College Head prepares your study load', done: false, now: approved),
          step('Enrolled: your new classes appear under Schedule', done: false),
        ],
      ),
    );
  }

  // ── The step-by-step form ─────────────────────────────────────────────────

  Widget _wizard(ReenrollmentStatus s) {
    final last = _step == _reviewStep;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Enroll for ${s.termLabel}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      key: const ValueKey('cancel_enrollment_button'),
                      tooltip: 'Cancel',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _sending ? null : _cancel,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Step ${_step + 1} of ${_steps.length} · ${_steps[_step]}',
                    key: const ValueKey('step_title'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / _steps.length,
                    minHeight: 6,
                    backgroundColor: AppColors.borderSubtle,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey('step_scroll_$_step'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Form(key: _formKey, child: _stepBody(s)),
                ),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SafeArea(
              top: false,
              child: LayoutBuilder(builder: (context, box) {
                // On a phone the main button fills the row (easy to reach with a thumb) and Back is an arrow.
                final narrow = box.maxWidth < 480;
                final Widget main = !last
                    ? FilledButton.icon(
                        key: const ValueKey('next_button'),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('Next'),
                        onPressed: _next,
                      )
                    : FilledButton.icon(
                        key: const ValueKey('send_enrollment_button'),
                        icon: _sending
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Send enrollment'),
                        onPressed: _sending || !_confirmed || _yearLevel == null ? null : _submit,
                      );
                final buttons = Row(
                  children: [
                    if (_step > 0)
                      narrow
                          ? IconButton.outlined(
                              key: const ValueKey('back_button'),
                              tooltip: 'Back',
                              icon: const Icon(Icons.arrow_back_rounded),
                              onPressed: _sending ? null : _back,
                            )
                          : OutlinedButton.icon(
                              key: const ValueKey('back_button'),
                              icon: const Icon(Icons.arrow_back_rounded, size: 18),
                              label: const Text('Back'),
                              onPressed: _sending ? null : _back,
                            ),
                    if (narrow) ...[
                      if (_step > 0) const SizedBox(width: 10),
                      Expanded(child: main),
                    ] else ...[
                      const Spacer(),
                      main,
                    ],
                  ],
                );
                if (_stepError == null) return buttons;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        key: const ValueKey('step_error'),
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(_stepError!,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error)),
                          ),
                        ],
                      ),
                    ),
                    buttons,
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBody(ReenrollmentStatus s) => switch (_step) {
        0 => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (s.filledFromTerm != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Filled in from your ${s.filledFromTerm} enrollment. Change only what is different.',
                    key: const ValueKey('filled_in_note'),
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              _fields(_form, _personal, s.lockedFields, _changed),
            ],
          ),
        1 => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fields(_form, _mainAddress, s.lockedFields, _changed),
              const SizedBox(height: 16),
              if (_showProvincial) ...[
                const Text('Provincial address',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                _fields(_form, _provincial, s.lockedFields, _changed),
              ] else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('add_provincial_address'),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add a provincial address'),
                    onPressed: () => setState(() => _showProvincial = true),
                  ),
                ),
            ],
          ),
        2 => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_contacts.isEmpty)
                const Text('No parent or guardian on file. Please tell the Registrar.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              for (final type in _relations.keys)
                if (_contacts.containsKey(type)) _contactCard(type),
            ],
          ),
        3 => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Family', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _fields(_form, _family, s.lockedFields, _changed),
              const SizedBox(height: 20),
              const Text('Health', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Leave empty what does not apply to you.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              _fields(_form, _health, s.lockedFields, _changed),
            ],
          ),
        _ => _review(s),
      };

  Widget _contactCard(int type) {
    final c = _contacts[type]!;
    final open = _openContacts.contains(type);
    final changed = _anyContactChange(type);
    return Container(
      key: ValueKey('contact_card_$type'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: _card.copyWith(
        border: Border.all(color: changed ? const Color(0xFFF59E0B) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_relations[type]! + (changed ? '  ·  changed' : ''),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: changed ? const Color(0xFFB45309) : AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text('${_text(c['firstName'])} ${_text(c['lastName'])}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    if (_text(c['contactNo']).isNotEmpty)
                      Text(_text(c['contactNo']), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              TextButton(
                key: ValueKey('edit_contact_$type'),
                onPressed: () => setState(() => open ? _openContacts.remove(type) : _openContacts.add(type)),
                child: Text(open ? 'Done' : 'Edit'),
              ),
            ],
          ),
          if (open) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _fields(c, _contactFields, const {}, (k) => _contactChanged(type, k), prefix: 'c$type'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _review(ReenrollmentStatus s) {
    final changes = _changedItems;
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
              Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row('Course', s.programName ?? s.programCode ?? '—'),
              row('Term', s.termLabel ?? '—'),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                key: const ValueKey('year_level_field'),
                initialValue: _yearLevel,
                decoration: const InputDecoration(labelText: 'Year level', border: OutlineInputBorder()),
                items: [for (final y in s.yearLevelChoices) DropdownMenuItem(value: y, child: Text('Year $y'))],
                onChanged: (v) => setState(() => _yearLevel = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          key: const ValueKey('changes_card'),
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
          decoration: _card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('What you changed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (changes.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('Nothing. Your information is the same as last time.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ),
              for (final (label, step) in changes)
                InkWell(
                  key: ValueKey('change_$label'),
                  onTap: () => _goTo(step),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFFB45309)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
                        Text(_steps[step], style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          key: const ValueKey('confirm_checkbox'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _confirmed,
          onChanged: (v) => setState(() => _confirmed = v ?? false),
          title: const Text('I checked my information and it is correct.', style: TextStyle(fontSize: 14)),
        ),
      ],
    );
  }

  static final _card = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: AppColors.border),
  );

  /// A responsive grid: one column on phones, two or three on wider screens.
  Widget _fields(Map<String, dynamic> data, List<_Field> fields, Set<String> locked, bool Function(String) changed,
      {String prefix = 'f'}) {
    return LayoutBuilder(builder: (context, box) {
      final columns = box.maxWidth < 520 ? 1 : (box.maxWidth < 760 ? 2 : 3);
      const gap = 12.0;
      final cell = (box.maxWidth - gap * (columns - 1)) / columns;
      // On a phone, fields the student cannot change are one short card instead of a tall box each.
      final compact = columns == 1 && fields.any((f) => locked.contains(f.key));
      final shownAsBoxes = compact ? fields.where((f) => !locked.contains(f.key)) : fields;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact) ...[
            _lockedCard(data, [for (final f in fields) if (locked.contains(f.key)) f]),
            const SizedBox(height: gap),
          ],
          Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final f in shownAsBoxes)
                SizedBox(
                  width: f.wide && columns > 1 ? cell * 2 + gap : cell,
                  child: _field(data, f, locked.contains(f.key), changed(f.key), prefix),
                ),
            ],
          ),
        ],
      );
    });
  }

  String _shown(Map<String, dynamic> data, _Field f) {
    final value = _text(data[f.key]);
    if (f.key == 'dateOfBirth' && DateTime.tryParse(value) != null) return _day.format(DateTime.parse(value));
    return value.isEmpty ? '—' : value;
  }

  /// Phone view of the locked fields: label and value rows in one grey card.
  Widget _lockedCard(Map<String, dynamic> data, List<_Field> fields) => Container(
        key: const ValueKey('locked_card'),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: AppColors.borderSubtle, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textMuted),
                SizedBox(width: 6),
                Expanded(
                  child: Text('Only the Registrar can change these',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final f in fields)
              Padding(
                key: ValueKey('locked:${f.key}'),
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 104,
                      child: Text(f.label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ),
                    Expanded(
                      child: Text(_shown(data, f),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _field(Map<String, dynamic> data, _Field f, bool locked, bool changed, String prefix) {
    final value = _text(data[f.key]);
    if (locked) {
      final shown = f.key == 'dateOfBirth' && DateTime.tryParse(value) != null
          ? _day.format(DateTime.parse(value))
          : (value.isEmpty ? '—' : value);
      return InputDecorator(
        key: ValueKey('$prefix:${f.key}'),
        decoration: InputDecoration(
          labelText: f.label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: AppColors.borderSubtle,
          suffixIcon: const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textMuted),
        ),
        child: Text(shown, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
      );
    }

    final decoration = InputDecoration(
      labelText: f.required ? '${f.label} *' : f.label,
      border: const OutlineInputBorder(),
      errorMaxLines: 2,
      helperText: changed ? 'changed' : null,
      helperStyle: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w700),
      enabledBorder: changed
          ? const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF59E0B), width: 1.5))
          : null,
      filled: changed,
      fillColor: changed ? AppColors.accentAmberLight : null,
    );
    String? validate(String? v) => _problem(f, v);

    if (f.choices != null) {
      final choices = [...f.choices!, if (value.isNotEmpty && !f.choices!.contains(value)) value];
      return DropdownButtonFormField<String>(
        key: ValueKey('$prefix:${f.key}'),
        initialValue: value.isEmpty ? null : value,
        isExpanded: true,
        decoration: decoration,
        items: [for (final c in choices) DropdownMenuItem(value: c, child: Text(c))],
        validator: validate,
        onChanged: (v) => setState(() => data[f.key] = v),
      );
    }
    return TextFormField(
      key: ValueKey('$prefix:${f.key}'),
      initialValue: value,
      decoration: decoration,
      keyboardType: f.number || f.check == mobileError || f.check == zipError || f.check == phoneError
          ? TextInputType.phone
          : TextInputType.text,
      validator: validate,
      onChanged: (v) => setState(() {
        final t = v.trim();
        data[f.key] = f.number ? (t.isEmpty ? null : int.tryParse(t)) : (t.isEmpty && data[f.key] == null ? null : v);
      }),
    );
  }
}

/// A short message card: closed, can't enroll yet, or an error.
class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> lines;
  final Widget? action;

  const _Notice({super.key, required this.icon, required this.color, required this.title, required this.lines, this.action});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  for (final l in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(l, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ),
                  if (action != null) ...[const SizedBox(height: 8), action!],
                ],
              ),
            ),
          ],
        ),
      );
}
