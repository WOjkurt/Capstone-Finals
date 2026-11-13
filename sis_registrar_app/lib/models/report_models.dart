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

/// One student on a printed class list.
class ClassListStudent {
  /// "LASTNAME, Firstname".
  final String name;
  final String? lrn;
  final String? programCode;
  final int? yearLevel;

  /// "M", "F", or null when not on record.
  final String? sex;

  const ClassListStudent({required this.name, this.lrn, this.programCode, this.yearLevel, this.sex});

  factory ClassListStudent.fromJson(Map<String, dynamic> j) => ClassListStudent(
        name: j['name'] as String? ?? '',
        lrn: j['lrn'] as String?,
        programCode: j['programCode'] as String?,
        yearLevel: (j['yearLevel'] as num?)?.toInt(),
        sex: j['sex'] as String?,
      );
}

/// A class with its Enrolled students, ready to print.
class ClassList {
  final String classId;
  final String className;
  final String subjectCode;
  final String subjectTitle;
  final double units;
  final String termLabel;
  final String? teacherName;
  final List<String> schedules;
  final List<ClassListStudent> students;

  const ClassList({
    required this.classId,
    required this.className,
    required this.subjectCode,
    required this.subjectTitle,
    this.units = 0,
    this.termLabel = '',
    this.teacherName,
    this.schedules = const [],
    this.students = const [],
  });

  factory ClassList.fromJson(Map<String, dynamic> j) => ClassList(
        classId: j['classId']?.toString() ?? '',
        className: j['className'] as String? ?? '',
        subjectCode: j['subjectCode'] as String? ?? '',
        subjectTitle: j['subjectTitle'] as String? ?? '',
        units: _d(j['units']),
        termLabel: j['termLabel'] as String? ?? '',
        teacherName: j['teacherName'] as String?,
        schedules: [for (final s in (j['schedules'] as List?) ?? []) s.toString()],
        students: [for (final s in (j['students'] as List?) ?? []) ClassListStudent.fromJson(s as Map<String, dynamic>)],
      );
}

/// An enrolled student with no sex on record.
class MissingSexRow {
  final String userId;
  final String studentName;
  final String? lrn;
  final String? programCode;
  final int? yearLevel;

  const MissingSexRow({required this.userId, required this.studentName, this.lrn, this.programCode, this.yearLevel});

  factory MissingSexRow.fromJson(Map<String, dynamic> j) => MissingSexRow(
        userId: j['userId']?.toString() ?? '',
        studentName: j['studentName'] as String? ?? '',
        lrn: j['lrn'] as String?,
        programCode: j['programCode'] as String?,
        yearLevel: (j['yearLevel'] as num?)?.toInt(),
      );
}

class DeansListRow {
  final int rank;
  final String userId;
  final String studentName;
  final String? studentId;
  final String? programCode;
  final int? yearLevel;
  final double units;

  /// The student's regular study load for the term (the units they had to carry).
  final double requiredUnits;
  final double gwa;
  final double lowestGrade;

  const DeansListRow({
    required this.rank,
    required this.userId,
    required this.studentName,
    this.studentId,
    this.programCode,
    this.yearLevel,
    required this.units,
    this.requiredUnits = 0,
    required this.gwa,
    required this.lowestGrade,
  });

  factory DeansListRow.fromJson(Map<String, dynamic> j) => DeansListRow(
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        userId: j['userId'] as String? ?? '',
        studentName: j['studentName'] as String? ?? '',
        studentId: j['studentId'] as String?,
        programCode: j['programCode'] as String?,
        yearLevel: (j['yearLevel'] as num?)?.toInt(),
        units: (j['units'] as num?)?.toDouble() ?? 0,
        requiredUnits: (j['requiredUnits'] as num?)?.toDouble() ?? 0,
        gwa: (j['gwa'] as num?)?.toDouble() ?? 0,
        lowestGrade: (j['lowestGrade'] as num?)?.toDouble() ?? 0,
      );
}

/// The Dean's list of a term with the rules it was made with.
class DeansList {
  final double maxGwa;
  final double worstGrade;
  final double fallbackUnits;
  final int studentsChecked;
  final int studentsWithMissingGrades;
  final List<DeansListRow> rows;

  const DeansList({
    this.maxGwa = 1.7,
    this.worstGrade = 2.3,
    this.fallbackUnits = 15,
    this.studentsChecked = 0,
    this.studentsWithMissingGrades = 0,
    this.rows = const [],
  });

  factory DeansList.fromJson(Map<String, dynamic> j) => DeansList(
        maxGwa: (j['maxGwa'] as num?)?.toDouble() ?? 1.7,
        worstGrade: (j['worstGrade'] as num?)?.toDouble() ?? 2.3,
        fallbackUnits: (j['fallbackUnits'] as num?)?.toDouble() ?? 15,
        studentsChecked: (j['studentsChecked'] as num?)?.toInt() ?? 0,
        studentsWithMissingGrades: (j['studentsWithMissingGrades'] as num?)?.toInt() ?? 0,
        rows: [for (final r in j['rows'] as List? ?? const []) DeansListRow.fromJson(r as Map<String, dynamic>)],
      );

  String get rules => 'GWA ${gradeText(maxGwa)} or better, no grade below ${gradeText(worstGrade)}, '
      'at least their regular study load, no failed, dropped or withdrawn subject';
}

/// 1.7 → "1.7", 1.75 → "1.75", 2 → "2.0".
String gradeText(double v) {
  final two = v.toStringAsFixed(2);
  return two.endsWith('0') ? v.toStringAsFixed(1) : two;
}
