import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/public_enrollment_models.dart';
import '../repositories/public_enrollment_repository.dart';
import '../theme/app_theme.dart';
import '../utils/error_handler.dart';
import 'widgets/enrollment_fields.dart';

final _day = DateFormat('MMM d, yyyy');

/// Applying to DBTC with no account — what the Google Form used to be.
///
/// Reached from the sign-in page, because the people who need it cannot sign in: they have no
/// account yet, and will not have one until the Registrar processes what they send here.
/// Submitting creates no account and grants nothing. It adds an unprocessed response to the
/// Registrar's queue, which is exactly where a Google Forms submission landed.
///
/// There is no confirmation email, so the reference shown at the end is the applicant's only
/// record of having applied. It is said plainly on that screen rather than left to be assumed.
class ApplyView extends StatefulWidget {
  final PublicEnrollmentRepository repository;
  final VoidCallback onBackToSignIn;

  const ApplyView({super.key, required this.repository, required this.onBackToSignIn});

  @override
  State<ApplyView> createState() => _ApplyViewState();
}

class _ApplyViewState extends State<ApplyView> {
  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();

  PublicEnrollmentStatus? _status;
  PublicEnrollmentReceipt? _receipt;
  String? _loadError;
  bool _loading = true;
  bool _sending = false;

  int _kind = ApplicantKinds.newStudent;
  String _email = '';
  String? _course;

  final Map<String, dynamic> _form = {};
  final Map<int, Map<String, dynamic>> _contacts = {
    for (final type in enrollmentRelations.keys) type: <String, dynamic>{}
  };

  /// Schooling before DBTC. A transferee is also asked where they are coming from.
  static const _schooling = [
    EnrollmentField('lastSchoolAttended', 'Last school attended', required: true, wide: true),
    EnrollmentField('schoolAddress', 'School address', wide: true),
    EnrollmentField('programTrackStrand', 'Track / strand'),
    EnrollmentField('yearGraduated', 'Year of last school attended', required: true, date: true),
  ];

  static const _transferring = [
    EnrollmentField('previousCollege', 'Previous college', required: true, wide: true),
    EnrollmentField('previousCourse', 'Previous course', required: true, wide: true),
    // Capital D: the key the rest of the system uses for this is previousStudentID.
    EnrollmentField('previousStudentID', 'Previous student number'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final status = await widget.repository.status();
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _loadError = getFriendlyErrorMessage(e, st);
        _loading = false;
      });
    }
  }

  bool get _isTransferee => _kind == ApplicantKinds.transferee;

  List<EnrollmentField> get _schoolingFields => [..._schooling, if (_isTransferee) ..._transferring];

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ));
  }

  Future<void> _submit() async {
    // Every answer, the course picker included: it carries its own validator, so one pass marks
    // all of them at once rather than sending the applicant back a field at a time.
    if (!(_formKey.currentState?.validate() ?? false)) {
      _snack('Some answers still need fixing. They are marked in red.', error: true);
      return;
    }

    setState(() => _sending = true);
    try {
      final receipt = await widget.repository.submit(
        email: _email.trim(),
        form: {
          ..._form,
          'studentType': _kind,
          'incomingCourse': _course,
        },
        contacts: [
          for (final entry in _contacts.entries)
            if (_hasAnswers(entry.value)) {...entry.value, 'relationType': entry.key}
        ],
      );
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _sending = false;
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _sending = false);
      _snack(getFriendlyErrorMessage(e, st), error: true);
    }
  }

  /// The guardian's "I live with them" box is ignored here: on its own it names nobody, and a box
  /// ticked and then unticked would otherwise make an empty card look filled in.
  static bool _hasAnswers(Map<String, dynamic> contact) => contact.entries
      .any((e) => e.key != guardianLivesWithKey && fieldText(e.value).isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Enroll at DBTC-Cebu', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          key: const ValueKey('apply_back_button'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to sign in',
          onPressed: widget.onBackToSignIn,
        ),
      ),
      body: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: _body(),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return _notice(
        key: 'apply_load_error',
        icon: Icons.wifi_off_rounded,
        color: AppColors.error,
        title: 'Could not check whether enrollment is open',
        body: _loadError!,
        action: TextButton(onPressed: _load, child: const Text('Try again')),
      );
    }
    if (_receipt != null) return _submitted(_receipt!);

    final status = _status!;
    if (!status.isOpen) {
      return _notice(
        key: 'apply_closed',
        icon: Icons.event_busy_rounded,
        color: AppColors.textSecondary,
        title: 'Online enrollment is closed right now',
        body: 'Applications open when the Registrar opens the next enrollment period. '
            'Please check back then, or visit the Registrar\'s Office.',
      );
    }
    return _form_(status);
  }

  // ── After sending ────────────────────────────────────────────────────────

  Widget _submitted(PublicEnrollmentReceipt receipt) => Column(
        key: const ValueKey('apply_submitted'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.accentGreenLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentGreen),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.accentGreenDark),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Your application has been sent',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.accentGreenDark)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('For ${receipt.termLabel}. The Registrar reviews every application by hand, '
                    'and will contact you on the email and mobile number you gave.',
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                const Text('Your reference', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                SelectableText(
                  receipt.reference,
                  key: const ValueKey('apply_reference'),
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 2),
                ),
                const SizedBox(height: 10),
                // Said outright, because an applicant who expects an email will sit waiting for one.
                const Text(
                  'Write this down. We do not send a confirmation email, so this is your only record '
                  'of having applied — quote it if you need to ask about your application.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('apply_done_button'),
              onPressed: widget.onBackToSignIn,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to sign in'),
            ),
          ),
        ],
      );

  // ── The form ─────────────────────────────────────────────────────────────

  Widget _form_(PublicEnrollmentStatus status) => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _openBanner(status),
            const SizedBox(height: 20),
            _section('Which course, and how you are joining', [
              _kindPicker(),
              const SizedBox(height: 12),
              _coursePicker(status.programs),
              // The Google Form asked everyone for an incoming year level. A first-year's answer
              // can only be 1, so only a transferee is asked — and the Registrar decides in the
              // end anyway, once they know which credits are granted.
              if (_isTransferee) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: const ValueKey('apply_year_level_picker'),
                  initialValue: _form['yearLevel'] as int?,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Year level you are entering',
                    helperText: 'Your best idea of it. The Registrar confirms this from your credits.',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1st year')),
                    DropdownMenuItem(value: 2, child: Text('2nd year')),
                    DropdownMenuItem(value: 3, child: Text('3rd year')),
                    DropdownMenuItem(value: 4, child: Text('4th year')),
                  ],
                  onChanged: (v) => _set('yearLevel', v),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('apply_email'),
                decoration: const InputDecoration(
                  labelText: 'Your email address *',
                  helperText: 'The Registrar replies here. Use one you check.',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Email address is required';
                  if (!t.contains('@') || t.startsWith('@') || t.endsWith('@')) {
                    return 'That does not look like an email address';
                  }
                  return null;
                },
                onChanged: (v) => _email = v,
              ),
            ]),
            _section('About you', [
              EnrollmentFieldGrid(
                data: _form,
                fields: enrollmentPersonalFields,
                prefix: 'apply',
                onChanged: _set,
              ),
            ]),
            _section('Where to reach you', [
              EnrollmentFieldGrid(
                data: _form,
                fields: enrollmentAddressFields,
                prefix: 'apply',
                onChanged: _set,
              ),
            ]),
            _section('Schooling before DBTC', [
              EnrollmentFieldGrid(
                data: _form,
                fields: _schoolingFields,
                prefix: 'apply',
                onChanged: _set,
              ),
            ]),
            _section('Parents and guardian', [
              const Text('Give at least one. The Registrar contacts them if they cannot reach you.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              for (final type in enrollmentRelations.keys) _contactCard(type),
            ]),
            _section('Family and health', [
              const Text('All optional, and used by the guidance office rather than for admission.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              EnrollmentFieldGrid(
                data: _form,
                fields: enrollmentFamilyFields,
                prefix: 'apply',
                onChanged: _set,
              ),
              const SizedBox(height: 16),
              // The Google Form asked a new applicant for these three as checkbox lists, and the
              // Registrar's processing screen offers the same choices, so they belong here too.
              _checklist('Conditions you have now', presentConditionChoices, 'presentMedicalConditions'),
              _checklist('Conditions you have had before', pastHistoryChoices, 'pastMedicalHistory'),
              _checklist('Vaccinations you have had', immunizationChoices, 'immunizationHistory'),
              EnrollmentFieldGrid(
                data: _form,
                fields: enrollmentHealthFields,
                prefix: 'apply',
                onChanged: _set,
              ),
            ]),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('apply_submit_button'),
              onPressed: _sending ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(_sending ? 'Sending…' : 'Send my application'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Sending this does not enrol you or create an account. The Registrar reviews it first.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      );

  void _set(String key, Object? value) => setState(() => _form[key] = value);

  Widget _checklist(String label, List<String> choices, String key) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: EnrollmentChecklist(
          label: label,
          choices: choices,
          chosen: [for (final v in (_form[key] as List<dynamic>? ?? [])) '$v'],
          keyPrefix: 'apply_$key',
          onChanged: (chosen) => _set(key, chosen),
        ),
      );

  Widget _openBanner(PublicEnrollmentStatus status) => Container(
        key: const ValueKey('apply_open_banner'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.event_available_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Enrollment is open for ${status.termLabel ?? 'the coming term'}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                  if (status.closesOn != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Applications close on ${_day.format(status.closesOn!)}.',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _kindPicker() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('I am…', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SegmentedButton<int>(
            key: const ValueKey('apply_kind_picker'),
            segments: const [
              ButtonSegment(
                value: ApplicantKinds.newStudent,
                label: Text('New student'),
                icon: Icon(Icons.person_add_alt_rounded, size: 18),
              ),
              ButtonSegment(
                value: ApplicantKinds.transferee,
                label: Text('Transferring in'),
                icon: Icon(Icons.swap_horiz_rounded, size: 18),
              ),
            ],
            selected: {_kind},
            // Answers that belong only to a transferee are dropped on the way back, not just
            // hidden. Left in, they would reach the Registrar as a first-year with a previous
            // college and a year level of 3 -- which reads like somebody with credits to record.
            onSelectionChanged: (s) => setState(() {
              _kind = s.first;
              if (_kind != ApplicantKinds.transferee) {
                for (final field in _transferring) {
                  _form.remove(field.key);
                }
                _form.remove('yearLevel');
              }
            }),
          ),
          const SizedBox(height: 6),
          // An old student has an account and enrols signed in, where their record fills the form.
          const Text('Already studying at DBTC? Sign in instead — your details are already on file.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      );

  Widget _coursePicker(List<PublicProgram> programs) => DropdownButtonFormField<String>(
        key: const ValueKey('apply_course_picker'),
        initialValue: _course,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Course you are applying for *', border: OutlineInputBorder()),
        items: [
          for (final p in programs) DropdownMenuItem(value: p.programCode, child: Text(p.label)),
        ],
        validator: (v) => (v == null || v.isEmpty) ? 'Choose a course' : null,
        onChanged: (v) => setState(() => _course = v),
      );

  Widget _contactCard(int type) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          key: ValueKey('apply_contact_$type'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.borderSubtle,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(enrollmentRelations[type]!,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              // Nothing inside a contact is required on its own: a card left empty is simply not
              // sent, so an applicant with no father to name is not stopped from applying.
              EnrollmentFieldGrid(
                data: _contacts[type]!,
                fields: enrollmentContactFieldsFor(type),
                prefix: 'apply_c$type',
                onChanged: (key, value) => setState(() => _contacts[type]![key] = value),
              ),
              if (type == 3)
                CheckboxListTile(
                  key: const ValueKey('apply_lives_with_guardian'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  value: _contacts[type]![guardianLivesWithKey] == true,
                  title: const Text('I live with this guardian', style: TextStyle(fontSize: 13)),
                  onChanged: (on) => setState(() => _contacts[type]![guardianLivesWithKey] = on == true),
                ),
            ],
          ),
        ),
      );

  Widget _section(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
            ...children,
          ],
        ),
      );

  Widget _notice({
    required String key,
    required IconData icon,
    required Color color,
    required String title,
    required String body,
    Widget? action,
  }) =>
      Container(
        key: ValueKey(key),
        margin: const EdgeInsets.only(top: 40),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            if (action != null) ...[const SizedBox(height: 12), action],
            const SizedBox(height: 8),
            TextButton.icon(
              key: const ValueKey('apply_back_to_sign_in'),
              onPressed: widget.onBackToSignIn,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to sign in'),
            ),
          ],
        ),
      );
}
