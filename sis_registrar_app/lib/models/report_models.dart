double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;

class EnrollmentSummaryRow {
  final String programCode;
  final int? yearLevel;
  final int enrolledStudents;
  final int pendingOnlyStudents;

  const EnrollmentSummaryRow({
    required this.programCode,
    this.yearLevel,
    required this.enrolledStudents,
    required this.pendingOnlyStudents,
  });

  factory EnrollmentSummaryRow.fromJson(Map<String, dynamic> j) => EnrollmentSummaryRow(
        programCode: j['programCode'] as String? ?? '',
        yearLevel: (j['yearLevel'] as num?)?.toInt(),
        enrolledStudents: _i(j['enrolledStudents']),
        pendingOnlyStudents: _i(j['pendingOnlyStudents']),
      );
}

class ClassSizeRow {
  final String className;
  final String subjectCode;
  final String subjectTitle;
  final String programCode;
  final String? teacherName;
  final int enrolled;
  final int pending;

  const ClassSizeRow({
    required this.className,
    required this.subjectCode,
    required this.subjectTitle,
    required this.programCode,
    this.teacherName,
    required this.enrolled,
    required this.pending,
  });

  factory ClassSizeRow.fromJson(Map<String, dynamic> j) => ClassSizeRow(
        className: j['className'] as String? ?? '',
        subjectCode: j['subjectCode'] as String? ?? '',
        subjectTitle: j['subjectTitle'] as String? ?? '',
        programCode: j['programCode'] as String? ?? '',
        teacherName: j['teacherName'] as String?,
        enrolled: _i(j['enrolled']),
        pending: _i(j['pending']),
      );
}

class FailedStudentRow {
  final String studentName;
  final String? lrn;
  final String? programCode;
  final int? yearLevel;
  final String subjectCode;
  final String subjectTitle;
  final String className;
  final double? finalGrade;
  final String? teacherName;

  const FailedStudentRow({
    required this.studentName,
    this.lrn,
    this.programCode,
    this.yearLevel,
    required this.subjectCode,
    required this.subjectTitle,
    required this.className,
    this.finalGrade,
    this.teacherName,
  });

  factory FailedStudentRow.fromJson(Map<String, dynamic> j) => FailedStudentRow(
        studentName: j['studentName'] as String? ?? '',
        lrn: j['lrn'] as String?,
        programCode: j['programCode'] as String?,
        yearLevel: (j['yearLevel'] as num?)?.toInt(),
        subjectCode: j['subjectCode'] as String? ?? '',
        subjectTitle: j['subjectTitle'] as String? ?? '',
        className: j['className'] as String? ?? '',
        finalGrade: (j['finalGrade'] as num?)?.toDouble(),
        teacherName: j['teacherName'] as String?,
      );
}

class TeacherLoadRow {
  final String teacherName;
  final bool isUnassigned;
  final int classes;
  final double units;
  final int students;
  final List<String> subjectCodes;

  const TeacherLoadRow({
    required this.teacherName,
    this.isUnassigned = false,
    required this.classes,
    required this.units,
    required this.students,
    this.subjectCodes = const [],
  });

  factory TeacherLoadRow.fromJson(Map<String, dynamic> j) => TeacherLoadRow(
        teacherName: j['teacherName'] as String? ?? '',
        isUnassigned: j['teacherUserId'] == null,
        classes: _i(j['classes']),
        units: _d(j['units']),
        students: _i(j['students']),
        subjectCodes: (j['subjectCodes'] as List?)?.cast<String>() ?? const [],
      );
}

/// A transferee, or any student with credits from another school.
class TransfereeRow {
  final String userId;
  final String studentName;
  final String? lrn;
  final String? programCode;
  final int? yearLevel;
  final List<String> previousSchools;
  final int creditedSubjects;
  final double creditedUnits;
  final List<String> creditedCodes;

  const TransfereeRow({
    required this.userId,
    required this.studentName,
    this.lrn,
    this.programCode,
    this.yearLevel,
    this.previousSchools = const [],
    this.creditedSubjects = 0,
    this.creditedUnits = 0,
    this.creditedCodes = const [],
  });

  factory TransfereeRow.fromJson(Map<String, dynamic> j) => TransfereeRow(
        userId: j['userId']?.toString() ?? '',
        studentName: j['studentName'] as String? ?? '',
        lrn: j['lrn'] as String?,
        programCode: j['programCode'] as String?,
        yearLevel: (j['yearLevel'] as num?)?.toInt(),
        previousSchools: [for (final s in (j['previousSchools'] as List?) ?? []) s.toString()],
        creditedSubjects: (j['creditedSubjects'] as num?)?.toInt() ?? 0,
        creditedUnits: (j['creditedUnits'] as num?)?.toDouble() ?? 0,
        creditedCodes: [for (final s in (j['creditedCodes'] as List?) ?? []) s.toString()],
      );
}

/// Enrolled students of one program in a term, by year level (1st to 4th) and sex.
class EnrollmentStatisticsRow {
  final String programCode;
  final String programName;

  /// Index 0 is 1st year ... index 3 is 4th year.
  final List<int> male;
  final List<int> female;
  final int sexNotRecorded;
  final int yearNotRecorded;

  const EnrollmentStatisticsRow({
    required this.programCode,
    this.programName = '',
    required this.male,
    required this.female,
    this.sexNotRecorded = 0,
    this.yearNotRecorded = 0,
  });

  int get totalMale => male.fold(0, (a, b) => a + b);
  int get totalFemale => female.fold(0, (a, b) => a + b);
  int get total => totalMale + totalFemale;

  static List<int> _four(Object? v) {
    final list = [for (final x in (v as List?) ?? const []) (x as num).toInt()];
    return [for (var i = 0; i < 4; i++) i < list.length ? list[i] : 0];
  }

  factory EnrollmentStatisticsRow.fromJson(Map<String, dynamic> j) => EnrollmentStatisticsRow(
        programCode: j['programCode'] as String? ?? '',
        programName: j['programName'] as String? ?? '',
        male: _four(j['male']),
        female: _four(j['female']),
        sexNotRecorded: _i(j['sexNotRecorded']),
        yearNotRecorded: _i(j['yearNotRecorded']),
      );
}
