import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../utils/phone_zip.dart';

/// The enrollment form's fields, shared by the two places it is filled in: an old student
/// enrolling again from inside the portal, and someone applying from the public page with no
/// account at all. Both send the same jsonb to the same Registrar queue, so both ask for the
/// same things, by the same names, checked the same way.
///
/// Who may change what is the difference between them, and that is the caller's to say: the
/// re-enrollment form locks what only the Registrar may edit, while an applicant filling this
/// in for the first time locks nothing.

final _day = DateFormat('MMM d, yyyy');

/// One field of the form: its key in the API's form, its label, and how to check it.
class EnrollmentField {
  final String key;
  final String label;
  final bool required;
  final String? Function(String?)? check;
  final List<String>? choices;
  final bool wide;
  final bool number;

  /// Picked from a calendar rather than typed. The Google Form used a date picker for these, and
  /// the Registrar's own form takes a real date, so free text would reach them unusable.
  final bool date;

  const EnrollmentField(this.key, this.label,
      {this.required = false, this.check, this.choices, this.wide = false, this.number = false,
      this.date = false});
}

const enrollmentPersonalFields = [
  EnrollmentField('lastName', 'Last name'),
  EnrollmentField('firstName', 'First name'),
  EnrollmentField('middleName', 'Middle name'),
  EnrollmentField('suffix', 'Suffix'),
  EnrollmentField('dateOfBirth', 'Date of birth', required: true, date: true),
  EnrollmentField('placeOfBirth', 'Place of birth'),
  EnrollmentField('sex', 'Sex'),
  EnrollmentField('lrn', 'LRN'),
  EnrollmentField('civilStatus', 'Civil status', required: true, choices: ['Single', 'Married', 'Widowed', 'Separated']),
  EnrollmentField('nationality', 'Nationality', required: true),
  EnrollmentField('religion', 'Religion'),
  EnrollmentField('gender', 'Gender identity'),
  EnrollmentField('bloodType', 'Blood type'),
  EnrollmentField('facebookName', 'Facebook name'),
];

const enrollmentAddressFields = [
  EnrollmentField('mobileNumber', 'Mobile number', required: true, check: mobileError),
  EnrollmentField('houseStreet', 'House no. / street', wide: true),
  EnrollmentField('barangay', 'Barangay', required: true),
  EnrollmentField('cityMunicipality', 'City / municipality', required: true),
  EnrollmentField('province', 'Province', required: true),
  EnrollmentField('zipCode', 'ZIP code', required: true, check: zipError),
  EnrollmentField('provHouseStreet', 'Provincial house no. / street', wide: true),
  EnrollmentField('provBarangay', 'Provincial barangay'),
  EnrollmentField('provCityMunicipality', 'Provincial city / municipality'),
  EnrollmentField('provProvince', 'Provincial province'),
  EnrollmentField('provZipCode', 'Provincial ZIP code', check: zipError),
];

const enrollmentFamilyFields = [
  EnrollmentField('birthOrder', 'Birth order'),
  EnrollmentField('numberOfSiblings', 'Number of siblings', number: true),
  EnrollmentField('familyStatus', 'Family status'),
];

const enrollmentHealthFields = [
  EnrollmentField('ongoingMedications', 'Medicines you take now', wide: true),
  EnrollmentField('developmentalConditions', 'Developmental conditions', wide: true),
  EnrollmentField('otherMedicalDiagnosis', 'Other medical diagnosis', wide: true),
  EnrollmentField('familyMedicalConditionsNotes', 'Family medical history notes', wide: true),
];

const enrollmentContactFields = [
  EnrollmentField('lastName', 'Last name', required: true),
  EnrollmentField('firstName', 'First name', required: true),
  EnrollmentField('contactNo', 'Contact number', required: true, check: phoneError),
  EnrollmentField('occupation', 'Occupation'),
  EnrollmentField('email', 'Email'),
  EnrollmentField('workplace', 'Workplace'),
];

const enrollmentRelations = {1: 'Father', 2: 'Mother', 3: 'Guardian'};

/// The Google Form asked different things of each contact, and the Excel importer still reads it
/// that way: a parent is asked for a birthday, a workplace and a Messenger account, while a
/// guardian is asked instead how they are related and whether the student lives with them.
/// Keeping that split means an imported row and one typed in here hold the same shape.
List<EnrollmentField> enrollmentContactFieldsFor(int relation) => [
      const EnrollmentField('lastName', 'Last name'),
      const EnrollmentField('firstName', 'First name'),
      const EnrollmentField('contactNo', 'Mobile number', check: phoneError),
      const EnrollmentField('occupation', 'Occupation'),
      const EnrollmentField('email', 'Email'),
      if (relation != 3) ...[
        const EnrollmentField('dateOfBirth', 'Date of birth', date: true),
        const EnrollmentField('workplace', 'Workplace or company'),
        const EnrollmentField('facebookAccount', 'Facebook Messenger account'),
      ],
      if (relation == 3) const EnrollmentField('guardianRelationshipDescription', 'How they are related to you'),
    ];

/// Guardian only, and a plain yes or no rather than a blank that could mean either.
const guardianLivesWithKey = 'livingWithGuardian';

// The three checkbox lists the Google Form asked a new applicant for, stored as arrays of
// strings. The Registrar's own screen offers exactly these choices when processing a response,
// so an applicant who ticks a box here produces the same value the Registrar would have.
const presentConditionChoices = [
  'Allergies',
  'Birth Deficiencies',
  'Eye-Vision Problems',
  'Hearing Problems',
  'Lung Problems',
  'Physically Challenged',
  'Other',
];

const pastHistoryChoices = [
  'Fractures',
  'Heart Problems',
  'Kidney Problems',
  'Other',
];

const immunizationChoices = [
  'BCG',
  'COVID-19',
  'Diphtheria',
  'Hepatitis A',
  'Hepatitis B',
  'HiB',
  'Influenza A annual',
  'Influenza A not annual',
  'IPV or OPV',
  'MMR',
  'Pertussis',
  'Pneumococcal',
  'Tetanus',
  'Varicella',
];

/// Tick as many as apply, or none. Sends a list of the chosen labels, or null when nothing is
/// chosen, so an untouched list is absent from the form rather than an empty array.
class EnrollmentChecklist extends StatelessWidget {
  final String label;
  final List<String> choices;
  final List<String> chosen;
  final String keyPrefix;
  final void Function(List<String>? chosen) onChanged;

  const EnrollmentChecklist({
    super.key,
    required this.label,
    required this.choices,
    required this.chosen,
    required this.keyPrefix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final choice in choices)
                FilterChip(
                  key: ValueKey('$keyPrefix:$choice'),
                  label: Text(choice),
                  selected: chosen.contains(choice),
                  onSelected: (on) {
                    final next = [...chosen];
                    on ? next.add(choice) : next.remove(choice);
                    onChanged(next.isEmpty ? null : next);
                  },
                ),
            ],
          ),
        ],
      );
}

/// What the applicant typed, as the API will receive it.
String fieldText(Object? v) => v == null ? '' : '$v'.trim();

/// The one rule for whether an answer will do, wherever the form is filled in.
String? fieldProblem(EnrollmentField f, Object? raw) {
  final t = fieldText(raw);
  if (f.required && t.isEmpty) return '${f.label} is required';
  if (f.number && t.isNotEmpty && int.tryParse(t) == null) return 'Numbers only';
  return f.check?.call(t);
}

String _shown(Map<String, dynamic> data, EnrollmentField f) {
  final value = fieldText(data[f.key]);
  if (f.key == 'dateOfBirth' && DateTime.tryParse(value) != null) return _day.format(DateTime.parse(value));
  return value.isEmpty ? '—' : value;
}

/// A block of the form, laid out in one to three columns depending on the width it is given.
class EnrollmentFieldGrid extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<EnrollmentField> fields;

  /// Keys only the Registrar may change; shown as read-only. Empty when nothing is locked.
  final Set<String> locked;

  /// Whether a key differs from what was on record, for the "changed" highlight. Always false
  /// on a first application, where there is nothing to differ from.
  final bool Function(String)? changed;

  /// Keys are prefixed so two grids on one screen cannot collide.
  final String prefix;

  final void Function(String key, Object? value) onChanged;

  const EnrollmentFieldGrid({
    super.key,
    required this.data,
    required this.fields,
    required this.onChanged,
    this.locked = const {},
    this.changed,
    this.prefix = 'f',
  });

  bool _changed(String key) => changed?.call(key) ?? false;

  @override
  Widget build(BuildContext context) {
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
            _LockedCard(data: data, fields: [for (final f in fields) if (locked.contains(f.key)) f]),
            const SizedBox(height: gap),
          ],
          Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final f in shownAsBoxes)
                SizedBox(
                  width: f.wide && columns > 1 ? cell * 2 + gap : cell,
                  child: _field(f, locked.contains(f.key), _changed(f.key)),
                ),
            ],
          ),
        ],
      );
    });
  }

  Widget _field(EnrollmentField f, bool isLocked, bool isChanged) {
    final value = fieldText(data[f.key]);
    if (isLocked) {
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
      helperText: isChanged ? 'changed' : null,
      helperStyle: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w700),
      enabledBorder: isChanged
          ? const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFF59E0B), width: 1.5))
          : null,
      filled: isChanged,
      fillColor: isChanged ? AppColors.accentAmberLight : null,
    );
    String? validate(String? v) => fieldProblem(f, v);

    if (f.date) {
      return _DateField(
        key: ValueKey('$prefix:${f.key}'),
        field: f,
        value: value,
        decoration: decoration,
        onChanged: (picked) => onChanged(f.key, picked),
      );
    }

    if (f.choices != null) {
      final choices = [...f.choices!, if (value.isNotEmpty && !f.choices!.contains(value)) value];
      return DropdownButtonFormField<String>(
        key: ValueKey('$prefix:${f.key}'),
        initialValue: value.isEmpty ? null : value,
        isExpanded: true,
        decoration: decoration,
        items: [for (final c in choices) DropdownMenuItem(value: c, child: Text(c))],
        validator: validate,
        onChanged: (v) => onChanged(f.key, v),
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
      onChanged: (v) {
        final t = v.trim();
        onChanged(f.key, f.number ? (t.isEmpty ? null : int.tryParse(t)) : (t.isEmpty && data[f.key] == null ? null : v));
      },
    );
  }
}

/// Phone view of the locked fields: label and value rows in one grey card.
class _LockedCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<EnrollmentField> fields;

  const _LockedCard({required this.data, required this.fields});

  @override
  Widget build(BuildContext context) => Container(
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
}


/// A date the applicant picks from a calendar. Holds no text of its own, so there is nothing to
/// mistype: it reads yyyy-MM-dd and writes yyyy-MM-dd, which is what the API stores. It is a
/// FormField so that a required date left empty is marked here, beside the question, rather than
/// only coming back from the server as a refusal.
class _DateField extends StatelessWidget {
  final EnrollmentField field;
  final String value;
  final InputDecoration decoration;
  final void Function(String? value) onChanged;

  const _DateField({
    super.key,
    required this.field,
    required this.value,
    required this.decoration,
    required this.onChanged,
  });

  static final _iso = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) => FormField<String>(
        initialValue: value,
        validator: (v) => fieldProblem(field, v),
        builder: (state) {
          final chosen = DateTime.tryParse(state.value ?? '');
          return InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                // A birthday opens around school age; anything else opens at this year.
                initialDate: chosen ??
                    (field.key == 'dateOfBirth' ? DateTime(now.year - 18) : DateTime(now.year)),
                firstDate: DateTime(now.year - 100),
                lastDate: now,
                helpText: field.label,
              );
              if (picked == null) return;
              final iso = _iso.format(picked);
              state.didChange(iso);
              onChanged(iso);
            },
            child: InputDecorator(
              decoration: decoration.copyWith(
                errorText: state.errorText,
                suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
              ),
              child: Text(
                chosen == null ? 'Tap to choose' : _day.format(chosen),
                style: TextStyle(
                  fontSize: 14,
                  color: chosen == null ? AppColors.textMuted : AppColors.textPrimary,
                ),
              ),
            ),
          );
        },
      );
}
