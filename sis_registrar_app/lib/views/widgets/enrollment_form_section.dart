import 'package:flutter/material.dart';

import '../../injection.dart';
import '../../models/enrollment_models.dart';
import '../../repositories/student_record_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import '../../utils/formatters.dart';

/// Students → Details: the student's latest enrollment form (Google Form, online re-enrollment or an import),
/// read-only. Collapsed at first because it holds family and medical information.
class EnrollmentFormSection extends StatefulWidget {
  final String userId;

  /// For tests; the app uses the registered repository.
  final Future<EnrollmentApplicationModel?> Function(String userId)? load;

  const EnrollmentFormSection({super.key, required this.userId, this.load});

  @override
  State<EnrollmentFormSection> createState() => _EnrollmentFormSectionState();
}

class _EnrollmentFormSectionState extends State<EnrollmentFormSection> {
  late Future<EnrollmentApplicationModel?> _future = _fetch();

  Future<EnrollmentApplicationModel?> _fetch() =>
      (widget.load ?? getIt<StudentRecordRepository>().enrollmentForm)(widget.userId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EnrollmentApplicationModel?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          final e = snap.error;
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(children: [
              Expanded(
                child: Text('Could not load the enrollment form: ${e is ApiException ? e.message : e}',
                    style: const TextStyle(fontSize: 12, color: AppColors.error)),
              ),
              TextButton(onPressed: () => setState(() => _future = _fetch()), child: const Text('Retry')),
            ]),
          );
        }
        final app = snap.data;
        final form = app?.form;
        if (app == null || form == null) return const SizedBox.shrink();
        return Container(
          key: const ValueKey('enrollment_form_section'),
          margin: const EdgeInsets.only(top: 20),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const ValueKey('enrollment_form_tile'),
              shape: const Border(),
              title: const Text('Enrollment form', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              subtitle: Text(
                'Submitted ${formatDate(app.createdAt)} · read-only. Change transcript details with Edit above.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: _sections(form, app.contacts),
            ),
          ),
        );
      },
    );
  }

  static String? _text(String? v) => v == null || v.trim().isEmpty ? null : v.trim();

  /// Dates come as "2004-01-01"; the server's empty date is year 1.
  static String? _date(String? v) {
    final d = DateTime.tryParse(v ?? '');
    return d == null || d.year < 1900 ? null : formatDate(d);
  }

  static String? _year(String? v) {
    final d = DateTime.tryParse(v ?? '');
    return d == null || d.year < 1900 ? null : '${d.year}';
  }

  static String? _join(List<String?> parts) {
    final kept = parts.map(_text).whereType<String>().toList();
    return kept.isEmpty ? null : kept.join(', ');
  }

  static String? _list(List<String>? items) => items == null || items.isEmpty ? null : items.join(', ');

  static String? _studentType(int? t) => switch (t) { 1 => 'New', 2 => 'Old', 3 => 'Transferee', _ => null };

  List<Widget> _sections(EnrollmentFormModel f, List<ContactModel> contacts) {
    final order = {1: 0, 2: 1, 3: 2};
    final people = [...contacts]..sort((a, b) => (order[a.relationType] ?? 9).compareTo(order[b.relationType] ?? 9));
    return [
      _title('Personal'),
      _row('Student type', _studentType(f.studentType)),
      _row('LRN', _text(f.lrn)),
      _row('Civil status', _text(f.civilStatus)),
      _row('Religion', _text(f.religion)),
      _row('Blood type', _text(f.bloodType)),
      _title('Contact'),
      _row('Mobile number', _text(f.mobileNumber)),
      _row('Facebook', _text(f.facebookName)),
      _row('Home address', _join([f.houseStreet, f.barangay, f.cityMunicipality, f.province, f.zipCode])),
      _row('Provincial address', _join([f.provHouseStreet, f.provBarangay, f.provCityMunicipality, f.provProvince, f.provZipCode])),
      _title('Education'),
      _row('Last school attended', _text(f.lastSchoolAttended)),
      _row('School address', _text(f.schoolAddress)),
      _row('Year graduated', _year(f.yearGraduated)),
      _row('Track / strand', _text(f.programTrackStrand)),
      _row('Previous college', _text(f.previousCollege)),
      _row('Previous course', _text(f.previousCourse)),
      _title('Family'),
      if (people.isEmpty) _row('Parents / guardian', null),
      for (final c in people)
        _row(
          c.relationType == 3 && _text(c.guardianRelationshipDescription) != null
              ? 'Guardian (${c.guardianRelationshipDescription!.trim()})'
              : c.relationName,
          [
            '${c.firstName} ${c.lastName}'.trim(),
            if (_text(c.contactNo) != null) c.contactNo.trim(),
            if (_text(c.email) != null) c.email!.trim(),
            if (_text(c.occupation) != null) c.occupation.trim(),
            if (_text(c.workplace) != null) c.workplace!.trim(),
            if (_date(c.dateOfBirth) != null) 'born ${_date(c.dateOfBirth)}',
            if (c.relationType == 3 && c.livingWithGuardian == true) 'student lives with guardian',
          ].join(' · '),
        ),
      _row('Birth order', _text(f.birthOrder)),
      _row('Number of siblings', f.numberOfSiblings?.toString()),
      _row('Family status', _text(f.familyStatus)),
      _title('Health'),
      _row('Present conditions', _list(f.presentMedicalConditions)),
      _row('Past medical history', _list(f.pastMedicalHistory)),
      _row('Immunization', _list(f.immunizationHistory)),
      _row('Family medical notes', _text(f.familyMedicalConditionsNotes)),
      _row('Ongoing medications', _text(f.ongoingMedications)),
      _row('Developmental / psychological', _text(f.developmentalConditions)),
      _row('Other diagnosis', _text(f.otherMedicalDiagnosis)),
    ];
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 2),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textSecondary)),
      );

  Widget _row(String label, String? value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 190, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
            Expanded(
              child: Text(
                value ?? '—',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: value != null ? FontWeight.w600 : FontWeight.normal,
                  color: value != null ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      );
}
