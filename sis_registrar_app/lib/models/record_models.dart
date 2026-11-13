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

/// What a program shift changed, and what the Registrar should look at next.
class ShiftResult {
  final int programId;
  final String programCode;
  final int inProgressSubjects;
  final int pendingSubjects;

  const ShiftResult({required this.programId, required this.programCode, this.inProgressSubjects = 0, this.pendingSubjects = 0});

  factory ShiftResult.fromJson(Map<String, dynamic> j) => ShiftResult(
        programId: (j['programId'] as num?)?.toInt() ?? 0,
        programCode: j['programCode'] as String? ?? '',
        inProgressSubjects: (j['inProgressSubjects'] as num?)?.toInt() ?? 0,
        pendingSubjects: (j['pendingSubjects'] as num?)?.toInt() ?? 0,
      );
}

/// A subject passed or being taken in a previous program, which may be credited to the current one.
class PreviousProgramSubject {
  final String subjectCode;
  final String subjectTitle;
  final String programCode;
  final double units;

  /// Passed or InProgress.
  final String status;
  final double? finalGrade;
  final String schoolYear;
  final String termLabel;
  final String? suggestedSubjectId;
  final String? suggestedSubjectCode;
  final double? suggestedUnits;
  final bool alreadyCredited;

  const PreviousProgramSubject({
    required this.subjectCode,
    required this.subjectTitle,
    this.programCode = '',
    this.units = 0,
    this.status = 'Passed',
    this.finalGrade,
    this.schoolYear = '',
    this.termLabel = '',
    this.suggestedSubjectId,
    this.suggestedSubjectCode,
    this.suggestedUnits,
    this.alreadyCredited = false,
  });

  factory PreviousProgramSubject.fromJson(Map<String, dynamic> j) => PreviousProgramSubject(
        subjectCode: j['subjectCode'] as String? ?? '',
        subjectTitle: j['subjectTitle'] as String? ?? '',
        programCode: j['programCode'] as String? ?? '',
        units: (j['units'] as num?)?.toDouble() ?? 0,
        status: j['status'] as String? ?? 'Passed',
        finalGrade: (j['finalGrade'] as num?)?.toDouble(),
        schoolYear: j['schoolYear'] as String? ?? '',
        termLabel: j['termLabel'] as String? ?? '',
        suggestedSubjectId: j['suggestedSubjectId']?.toString(),
        suggestedSubjectCode: j['suggestedSubjectCode'] as String?,
        suggestedUnits: (j['suggestedUnits'] as num?)?.toDouble(),
        alreadyCredited: j['alreadyCredited'] as bool? ?? false,
      );
}

/// One count on the Records check page, e.g. "No school email (can't sign in)": 12.
class RecordsCheckCount {
  final String key;
  final String label;
  final int count;
  const RecordsCheckCount({required this.key, required this.label, required this.count});
  factory RecordsCheckCount.fromJson(Map<String, dynamic> j) =>
      RecordsCheckCount(key: j['key'] as String? ?? '', label: j['label'] as String? ?? '', count: (j['count'] as num?)?.toInt() ?? 0);
}

/// A student with something still missing. [json] has the keys of a student search result, to open them.
class RecordsCheckRow {
  final Map<String, dynamic> json;
  final List<String> issues;
  final List<String> missing;
  const RecordsCheckRow({required this.json, this.issues = const [], this.missing = const []});

  String get userId => json['userId'] as String? ?? '';
  String get name => '${json['lastname'] ?? ''}, ${json['firstname'] ?? ''}';
  String? get studentId => json['studentId'] as String?;
  String? get programCode => json['programCode'] as String?;
  int? get yearLevel => (json['yearLevel'] as num?)?.toInt();

  factory RecordsCheckRow.fromJson(Map<String, dynamic> j) => RecordsCheckRow(
        json: j,
        issues: [for (final i in j['issues'] as List? ?? const []) i as String],
        missing: [for (final m in j['missing'] as List? ?? const []) m as String],
      );
}

class RecordsCheck {
  final int activeStudents;
  final List<RecordsCheckCount> counts;
  final List<RecordsCheckRow> rows;
  const RecordsCheck({this.activeStudents = 0, this.counts = const [], this.rows = const []});
  factory RecordsCheck.fromJson(Map<String, dynamic> j) => RecordsCheck(
        activeStudents: (j['activeStudents'] as num?)?.toInt() ?? 0,
        counts: [for (final c in j['counts'] as List? ?? const []) RecordsCheckCount.fromJson(c as Map<String, dynamic>)],
        rows: [for (final r in j['rows'] as List? ?? const []) RecordsCheckRow.fromJson(r as Map<String, dynamic>)],
      );
}

class GraduationSubject {
  final String subjectCode;
  final String subjectTitle;
  final double units;
  final int yearLevel;
  final int semester;

  /// InProgress, NotTaken, Failed, Dropped, Withdrawn or PartiallyCredited.
  final String status;

  const GraduationSubject({required this.subjectCode, this.subjectTitle = '', this.units = 0, this.yearLevel = 0, this.semester = 0, this.status = ''});

  factory GraduationSubject.fromJson(Map<String, dynamic> j) => GraduationSubject(
        subjectCode: j['subjectCode'] as String? ?? '',
        subjectTitle: j['subjectTitle'] as String? ?? '',
        units: (j['units'] as num?)?.toDouble() ?? 0,
        yearLevel: (j['yearLevel'] as num?)?.toInt() ?? 0,
        semester: (j['semester'] as num?)?.toInt() ?? 0,
        status: j['status'] as String? ?? '',
      );

  String get statusLabel => switch (status) {
        'InProgress' => 'taking now',
        'NotTaken' => 'not taken',
        'Failed' => 'failed',
        'Dropped' => 'dropped',
        'Withdrawn' => 'withdrawn',
        'PartiallyCredited' => 'partly credited',
        _ => status,
      };
}

class GraduationCandidate {
  final Map<String, dynamic> json;
  final String status; // Complete, FinishingThisTerm, Lacking
  final double totalUnits;
  final double earnedUnits;
  final List<GraduationSubject> inProgress;
  final List<GraduationSubject> lacking;

  const GraduationCandidate({
    required this.json,
    required this.status,
    this.totalUnits = 0,
    this.earnedUnits = 0,
    this.inProgress = const [],
    this.lacking = const [],
  });

  String get userId => json['userId'] as String? ?? '';
  String get name => '${json['lastname'] ?? ''}, ${json['firstname'] ?? ''}';
  String? get studentId => json['studentId'] as String?;
  String? get programCode => json['programCode'] as String?;
  int? get yearLevel => (json['yearLevel'] as num?)?.toInt();
  String? get curriculumName => json['curriculumName'] as String?;

  String get statusLabel => switch (status) {
        'Complete' => 'Complete',
        'FinishingThisTerm' => 'Finishing this term',
        _ => 'Lacking subjects',
      };

  factory GraduationCandidate.fromJson(Map<String, dynamic> j) => GraduationCandidate(
        json: j,
        status: j['status'] as String? ?? '',
        totalUnits: (j['totalUnits'] as num?)?.toDouble() ?? 0,
        earnedUnits: (j['earnedUnits'] as num?)?.toDouble() ?? 0,
        inProgress: [for (final x in j['inProgress'] as List? ?? const []) GraduationSubject.fromJson(x as Map<String, dynamic>)],
        lacking: [for (final x in j['lackingSubjects'] as List? ?? const []) GraduationSubject.fromJson(x as Map<String, dynamic>)],
      );
}

class GraduationCandidates {
  final int complete;
  final int finishingThisTerm;
  final int lacking;
  final List<GraduationCandidate> rows;

  const GraduationCandidates({this.complete = 0, this.finishingThisTerm = 0, this.lacking = 0, this.rows = const []});

  factory GraduationCandidates.fromJson(Map<String, dynamic> j) => GraduationCandidates(
        complete: (j['complete'] as num?)?.toInt() ?? 0,
        finishingThisTerm: (j['finishingThisTerm'] as num?)?.toInt() ?? 0,
        lacking: (j['lacking'] as num?)?.toInt() ?? 0,
        rows: [for (final r in j['rows'] as List? ?? const []) GraduationCandidate.fromJson(r as Map<String, dynamic>)],
      );
}
