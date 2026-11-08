/// Where the student stands for online enrollment, from GET /api/me/reenrollment.
class ReenrollmentStatus {
  static const closed = 'Closed';
  static const notEligible = 'NotEligible';
  static const onHold = 'OnHold';
  static const ready = 'Ready';
  static const submitted = 'Submitted';

  final String state;
  final List<String> reasons;
  final String? termId;
  final String? termLabel;
  final DateTime? opensOn;
  final DateTime? closesOn;
  final String? programCode;
  final String? programName;
  final int? currentYearLevel;
  final List<int> yearLevelChoices;
  final Set<String> lockedFields;

  /// Last time's form, kept as the API sent it so every field goes back unchanged unless edited.
  final Map<String, dynamic>? form;
  final List<Map<String, dynamic>> contacts;
  final String? filledFromTerm;
  final DateTime? submittedAt;
  final String? applicationStatus;

  const ReenrollmentStatus({
    required this.state,
    this.reasons = const [],
    this.termId,
    this.termLabel,
    this.opensOn,
    this.closesOn,
    this.programCode,
    this.programName,
    this.currentYearLevel,
    this.yearLevelChoices = const [],
    this.lockedFields = const {},
    this.form,
    this.contacts = const [],
    this.filledFromTerm,
    this.submittedAt,
    this.applicationStatus,
  });

  factory ReenrollmentStatus.fromJson(Map<String, dynamic> j) => ReenrollmentStatus(
        state: j['state'] as String? ?? closed,
        reasons: [for (final r in j['reasons'] as List? ?? const []) r as String],
        termId: j['termId'] as String?,
        termLabel: j['termLabel'] as String?,
        opensOn: DateTime.tryParse(j['opensOn'] as String? ?? ''),
        closesOn: DateTime.tryParse(j['closesOn'] as String? ?? ''),
        programCode: j['programCode'] as String?,
        programName: j['programName'] as String?,
        currentYearLevel: (j['currentYearLevel'] as num?)?.toInt(),
        yearLevelChoices: [for (final y in j['yearLevelChoices'] as List? ?? const []) (y as num).toInt()],
        lockedFields: {for (final f in j['lockedFields'] as List? ?? const []) _camel(f as String)},
        form: (j['form'] as Map?)?.cast<String, dynamic>(),
        contacts: [for (final c in j['contacts'] as List? ?? const []) (c as Map).cast<String, dynamic>()],
        filledFromTerm: j['filledFromTerm'] as String?,
        submittedAt: DateTime.tryParse(j['submittedAt'] as String? ?? ''),
        applicationStatus: j['applicationStatus'] as String?,
      );

  /// The API names locked fields like "FirstName" or "LRN"; the form's keys are "firstName" and "lrn"
  /// (the same rule as the API's JSON: the leading capitals become small letters).
  static String _camel(String name) {
    var i = 0;
    while (i < name.length && name[i] != name[i].toLowerCase()) {
      i++;
    }
    if (i == 0) return name;
    // "FirstName": only the first capital; "LRN": all of them; "IDNumber": all but the one starting the next word.
    final keep = i == name.length || i == 1 ? i : i - 1;
    return name.substring(0, keep).toLowerCase() + name.substring(keep);
  }
}
