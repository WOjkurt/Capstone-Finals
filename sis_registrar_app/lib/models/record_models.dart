import 'grading_models.dart';

/// One curriculum subject on a student's evaluation checklist.
class EvaluationSubject {
  final String subjectId;
  final String subjectCode;
  final String subjectTitle;
  final double units;
  final double lecHours;
  final double labHours;
  final String? prerequisites;
  final String? corequisites;
  final int yearLevel;
  final int semester;
  final bool isMinor;

  /// Passed, Credited, CrossEnrolled, PartiallyCredited, InProgress, Failed, Dropped or NotTaken.
  final String status;
  final double? finalGrade;
  final String? termLabel;
  final String? creditedFrom;
  final String? creditedGrade;

  const EvaluationSubject({
    required this.subjectId,
    required this.subjectCode,
    required this.subjectTitle,
    required this.units,
    this.lecHours = 0,
    this.labHours = 0,
    this.prerequisites,
    this.corequisites,
    required this.yearLevel,
    required this.semester,
    required this.isMinor,
    required this.status,
    this.finalGrade,
    this.termLabel,
    this.creditedFrom,
    this.creditedGrade,
    this.creditedUnits,
  });

  final double? creditedUnits;

  bool get isDone => status == 'Passed' || status == 'Credited' || status == 'CrossEnrolled';

  factory EvaluationSubject.fromJson(Map<String, dynamic> json) => EvaluationSubject(
        subjectId: json['subjectId']?.toString() ?? '',
        subjectCode: json['subjectCode'] as String? ?? '',
        subjectTitle: json['subjectTitle'] as String? ?? '',
        units: (json['units'] as num?)?.toDouble() ?? 0,
        lecHours: (json['lecHours'] as num?)?.toDouble() ?? 0,
        labHours: (json['labHours'] as num?)?.toDouble() ?? 0,
        prerequisites: json['prerequisites'] as String?,
        corequisites: json['corequisites'] as String?,
        yearLevel: json['yearLevel'] as int? ?? 0,
        semester: json['semester'] as int? ?? 0,
        isMinor: json['isMinor'] as bool? ?? false,
        status: json['status'] as String? ?? 'NotTaken',
        finalGrade: (json['finalGrade'] as num?)?.toDouble(),
        termLabel: json['termLabel'] as String?,
        creditedFrom: json['creditedFrom'] as String?,
        creditedGrade: json['creditedGrade'] as String?,
        creditedUnits: (json['creditedUnits'] as num?)?.toDouble(),
      );
}

/// A student's progress through their program's curriculum.
class StudentEvaluation {
  final String fullName;
  final String? lrn;
  final String programCode;
  final String programName;
  final int? yearLevel;
  final double totalUnits;
  final double earnedUnits;
  final double inProgressUnits;
  final double remainingUnits;
  final List<EvaluationSubject> subjects;

  const StudentEvaluation({
    this.fullName = '',
    this.lrn,
    required this.programCode,
    required this.programName,
    this.yearLevel,
    required this.totalUnits,
    required this.earnedUnits,
    required this.inProgressUnits,
    required this.remainingUnits,
    required this.subjects,
  });

  factory StudentEvaluation.fromJson(Map<String, dynamic> json) => StudentEvaluation(
        fullName: json['fullName'] as String? ?? '',
        lrn: json['lrn'] as String?,
        programCode: json['programCode'] as String? ?? '',
        programName: json['programName'] as String? ?? '',
        yearLevel: json['yearLevel'] as int?,
        totalUnits: (json['totalUnits'] as num?)?.toDouble() ?? 0,
        earnedUnits: (json['earnedUnits'] as num?)?.toDouble() ?? 0,
        inProgressUnits: (json['inProgressUnits'] as num?)?.toDouble() ?? 0,
        remainingUnits: (json['remainingUnits'] as num?)?.toDouble() ?? 0,
        subjects: ((json['subjects'] as List?) ?? [])
            .map((e) => EvaluationSubject.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// NSTP and PE (PATHFIT) subjects, which are left out of the GWA as most schools do.
final _notInGwa = RegExp(r'^(NSTP|PATHFIT|PE)(\s|\d|$)', caseSensitive: false);

bool countsInGwa(String? subjectCode) => !_notInGwa.hasMatch((subjectCode ?? '').trim());

/// General weighted average: final grades weighted by units. Only enrolled subjects with a
/// final grade count (failed grades included); NSTP, PE and credits from other schools do not.
double? computeGwa(Iterable<StudentGradeModel> grades) {
  var units = 0.0;
  var sum = 0.0;
  for (final g in grades) {
    if (g.loadStatus != null && g.loadStatus != 1) continue;
    if (!countsInGwa(g.subjectCode)) continue;
    final u = g.units;
    final f = g.finalGrade;
    if (u == null || u <= 0 || f == null) continue;
    units += u;
    sum += u * f;
  }
  return units == 0 ? null : sum / units;
}

/// One line of the Transcript of Records.
class TranscriptRow {
  final String subjectCode;
  final String subjectTitle;

  /// "1.75", "5.00", "DO" (dropped officially), "W" (withdrawn), or empty when not graded yet.
  final String finalGrade;
  final double units;

  const TranscriptRow({required this.subjectCode, required this.subjectTitle, required this.finalGrade, required this.units});

  factory TranscriptRow.fromJson(Map<String, dynamic> json) => TranscriptRow(
        subjectCode: json['subjectCode'] as String? ?? '',
        subjectTitle: json['subjectTitle'] as String? ?? '',
        finalGrade: json['final'] as String? ?? '',
        units: (json['units'] as num?)?.toDouble() ?? 0,
      );
}

/// A titled block of transcript lines: one term ("1st Semester, 2025-2026") or one other school's credits.
class TranscriptSection {
  final String heading;
  final List<TranscriptRow> rows;

  const TranscriptSection({required this.heading, required this.rows});

  static List<TranscriptRow> _rows(Object? json) =>
      ((json as List?) ?? []).map((e) => TranscriptRow.fromJson(e as Map<String, dynamic>)).toList();
}

class Transcript {
  final String fullName;
  final String? lrn;
  final String programCode;
  final String programName;
  final String? address;
  final DateTime? dateOfBirth;
  final String? placeOfBirth;
  final String? sex;
  final String? nationality;
  final String? dateAdmitted;
  final String? entranceData;
  final List<TranscriptSection> terms;

  /// Subjects credited from other schools, one section per school.
  final List<TranscriptSection> credits;

  const Transcript({
    required this.fullName,
    this.lrn,
    required this.programCode,
    required this.programName,
    this.address,
    this.dateOfBirth,
    this.placeOfBirth,
    this.sex,
    this.nationality,
    this.dateAdmitted,
    this.entranceData,
    this.terms = const [],
    this.credits = const [],
  });

  factory Transcript.fromJson(Map<String, dynamic> json) => Transcript(
        fullName: json['fullName'] as String? ?? '',
        lrn: json['lrn'] as String?,
        programCode: json['programCode'] as String? ?? '',
        programName: json['programName'] as String? ?? '',
        address: json['address'] as String?,
        dateOfBirth: DateTime.tryParse(json['dateOfBirth'] as String? ?? ''),
        placeOfBirth: json['placeOfBirth'] as String?,
        sex: json['sex'] as String?,
        nationality: json['nationality'] as String?,
        dateAdmitted: json['dateAdmitted'] as String?,
        entranceData: json['entranceData'] as String?,
        terms: [
          for (final t in (json['terms'] as List?) ?? [])
            TranscriptSection(heading: (t as Map<String, dynamic>)['heading'] as String? ?? '', rows: TranscriptSection._rows(t['rows'])),
        ],
        credits: [
          for (final c in (json['credits'] as List?) ?? [])
            TranscriptSection(
                heading: 'Credited from ${(c as Map<String, dynamic>)['sourceSchool'] ?? 'another school'}',
                rows: TranscriptSection._rows(c['rows'])),
        ],
      );
}

/// A student's personal details for their records. Each value is the Registrar's saved one or, when
/// that is empty, the enrollment form's; [fromForm] names the fields that came from the form.
class PersonalDetails {
  final String firstname;
  final String lastname;
  final String? middleName;
  final String? suffix;
  final String? address;
  final DateTime? dateOfBirth;
  final String? placeOfBirth;
  final String? sex;
  final String? nationality;
  final String? entranceData;
  final String? dateAdmitted;

  /// Used on the transcript when [dateAdmitted] is empty.
  final String? firstTermEnrolled;
  final bool hasEnrollmentForm;
  final Set<String> fromForm;
  final String? updatedBy;
  final DateTime? updatedAt;

  const PersonalDetails({
    this.firstname = '',
    this.lastname = '',
    this.middleName,
    this.suffix,
    this.address,
    this.dateOfBirth,
    this.placeOfBirth,
    this.sex,
    this.nationality,
    this.entranceData,
    this.dateAdmitted,
    this.firstTermEnrolled,
    this.hasEnrollmentForm = false,
    this.fromForm = const {},
    this.updatedBy,
    this.updatedAt,
  });

  /// Lines the transcript needs that are still empty.
  List<String> get missingForTranscript => [
        if (address == null) 'Address',
        if (dateOfBirth == null) 'Date of birth',
        if (placeOfBirth == null) 'Place of birth',
        if (sex == null) 'Sex',
        if (nationality == null) 'Nationality',
        if (entranceData == null) 'Entrance data',
      ];

  factory PersonalDetails.fromJson(Map<String, dynamic> json) => PersonalDetails(
        firstname: json['firstname'] as String? ?? '',
        lastname: json['lastname'] as String? ?? '',
        middleName: json['middleName'] as String?,
        suffix: json['suffix'] as String?,
        address: json['address'] as String?,
        dateOfBirth: DateTime.tryParse(json['dateOfBirth'] as String? ?? ''),
        placeOfBirth: json['placeOfBirth'] as String?,
        sex: json['sex'] as String?,
        nationality: json['nationality'] as String?,
        entranceData: json['entranceData'] as String?,
        dateAdmitted: json['dateAdmitted'] as String?,
        firstTermEnrolled: json['firstTermEnrolled'] as String?,
        hasEnrollmentForm: json['hasEnrollmentForm'] as bool? ?? false,
        fromForm: {for (final f in (json['fromForm'] as List?) ?? []) f.toString()},
        updatedBy: json['updatedBy'] as String?,
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toLocal(),
      );
}

/// Regular or irregular, and progress back to regular (6 units of back major subjects passed).
class Standing {
  final bool isRegular;
  final DateTime? irregularSince;
  final double backMajorUnitsPassed;
  final double unitsToRegular;
  final List<String> countedSubjects;
  final List<String> unresolvedSubjects;

  /// "MarkRegular", "MarkIrregular", or null when the status fits.
  final String? suggestion;

  const Standing({
    required this.isRegular,
    this.irregularSince,
    this.backMajorUnitsPassed = 0,
    this.unitsToRegular = 6,
    this.countedSubjects = const [],
    this.unresolvedSubjects = const [],
    this.suggestion,
  });

  factory Standing.fromJson(Map<String, dynamic> j) => Standing(
        isRegular: j['isRegular'] as bool? ?? true,
        irregularSince: DateTime.tryParse(j['irregularSince'] as String? ?? '')?.toLocal(),
        backMajorUnitsPassed: (j['backMajorUnitsPassed'] as num?)?.toDouble() ?? 0,
        unitsToRegular: (j['unitsToRegular'] as num?)?.toDouble() ?? 6,
        countedSubjects: [for (final c in (j['countedSubjects'] as List?) ?? []) c.toString()],
        unresolvedSubjects: [for (final c in (j['unresolvedSubjects'] as List?) ?? []) c.toString()],
        suggestion: j['suggestion'] as String?,
      );
}

/// An irregular student and their progress back to regular.
class IrregularStudent {
  final String userId;
  final String studentName;
  final String? lrn;
  final String? programCode;
  final int? yearLevel;
  final DateTime? irregularSince;
  final double backMajorUnitsPassed;
  final bool readyToBeRegular;

  const IrregularStudent({
    required this.userId,
    required this.studentName,
    this.lrn,
    this.programCode,
    this.yearLevel,
    this.irregularSince,
    this.backMajorUnitsPassed = 0,
    this.readyToBeRegular = false,
  });

  factory IrregularStudent.fromJson(Map<String, dynamic> j) => IrregularStudent(
        userId: j['userId']?.toString() ?? '',
        studentName: j['studentName'] as String? ?? '',
        lrn: j['lrn'] as String?,
        programCode: j['programCode'] as String?,
        yearLevel: (j['yearLevel'] as num?)?.toInt(),
        irregularSince: DateTime.tryParse(j['irregularSince'] as String? ?? '')?.toLocal(),
        backMajorUnitsPassed: (j['backMajorUnitsPassed'] as num?)?.toDouble() ?? 0,
        readyToBeRegular: j['readyToBeRegular'] as bool? ?? false,
      );
}
