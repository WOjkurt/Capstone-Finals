/// A row the Excel import skipped, with the reason.
class RecordsImportProblem {
  final String file;
  final String sheet;
  final int row;
  final String message;
  const RecordsImportProblem({this.file = '', this.sheet = '', this.row = 0, required this.message});

  factory RecordsImportProblem.fromJson(Map<String, dynamic> j) => RecordsImportProblem(
        file: j['file'] as String? ?? '',
        sheet: j['sheet'] as String? ?? '',
        row: (j['row'] as num?)?.toInt() ?? 0,
        message: j['message'] as String? ?? '',
      );

  /// "Grades › 2ND SEM_2025-2026, row 877: …"
  String get label {
    final where = [if (file.isNotEmpty) file, if (sheet.isNotEmpty) sheet].join(' › ');
    final at = [if (where.isNotEmpty) where, if (row > 0) 'row $row'].join(', ');
    return at.isEmpty ? message : '$at: $message';
  }
}

/// What importing old students and grades from Excel would do (dry run) or did.
class RecordsImportResult {
  final bool dryRun;
  final List<String> schoolYearsFound;
  final List<String> schoolYearsImported;
  final int newStudents;
  final int existingStudents;

  /// Only students already in the system got grades (older school years); [studentsNotInSystem] were left out.
  final bool onlyExistingStudents;
  final int studentsNotInSystem;
  final Map<String, int> studentsPerProgram;
  final Map<String, int> studentsPerCurriculum;
  final int gradesPassed;
  final int gradesFailed;
  final int dropped;
  final int noGradeYet;
  final int alreadyImported;
  final List<String> termsCreated;
  final bool gradesReleased;
  final List<RecordsImportProblem> problems;
  final int totalProblems;
  final List<String> notes;

  const RecordsImportResult({
    this.dryRun = true,
    this.schoolYearsFound = const [],
    this.schoolYearsImported = const [],
    this.newStudents = 0,
    this.existingStudents = 0,
    this.onlyExistingStudents = false,
    this.studentsNotInSystem = 0,
    this.studentsPerProgram = const {},
    this.studentsPerCurriculum = const {},
    this.gradesPassed = 0,
    this.gradesFailed = 0,
    this.dropped = 0,
    this.noGradeYet = 0,
    this.alreadyImported = 0,
    this.termsCreated = const [],
    this.gradesReleased = true,
    this.problems = const [],
    this.totalProblems = 0,
    this.notes = const [],
  });

  int get gradeRows => gradesPassed + gradesFailed + dropped + noGradeYet;
  bool get hasWork => newStudents > 0 || gradeRows > 0;

  factory RecordsImportResult.fromJson(Map<String, dynamic> j) {
    List<String> strings(String k) => [for (final v in j[k] as List? ?? const []) '$v'];
    Map<String, int> counts(String k) =>
        {for (final e in (j[k] as Map<String, dynamic>? ?? const {}).entries) e.key: (e.value as num).toInt()};
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return RecordsImportResult(
      dryRun: j['dryRun'] as bool? ?? true,
      schoolYearsFound: strings('schoolYearsFound'),
      schoolYearsImported: strings('schoolYearsImported'),
      newStudents: n('newStudents'),
      existingStudents: n('existingStudents'),
      onlyExistingStudents: j['onlyExistingStudents'] as bool? ?? false,
      studentsNotInSystem: n('studentsNotInSystem'),
      studentsPerProgram: counts('studentsPerProgram'),
      studentsPerCurriculum: counts('studentsPerCurriculum'),
      gradesPassed: n('gradesPassed'),
      gradesFailed: n('gradesFailed'),
      dropped: n('dropped'),
      noGradeYet: n('noGradeYet'),
      alreadyImported: n('alreadyImported'),
      termsCreated: strings('termsCreated'),
      gradesReleased: j['gradesReleased'] as bool? ?? true,
      problems: [for (final p in j['problems'] as List? ?? const []) RecordsImportProblem.fromJson(p as Map<String, dynamic>)],
      totalProblems: n('totalProblems'),
      notes: strings('notes'),
    );
  }
}

/// One subject the credits import will credit (or credited).
class CreditsImportRow {
  final String studentId;
  final String studentName;
  final String subjectCode;
  final String subjectTitle;
  final double creditedUnits;
  final double units;
  final String sourceSchool;
  final String? grade;

  /// 1 = before DBTC (transferee/shiftee), 2 = cross-enrolled.
  final int kind;

  const CreditsImportRow({
    required this.studentId,
    required this.studentName,
    required this.subjectCode,
    this.subjectTitle = '',
    required this.creditedUnits,
    required this.units,
    required this.sourceSchool,
    this.grade,
    this.kind = 1,
  });

  factory CreditsImportRow.fromJson(Map<String, dynamic> j) => CreditsImportRow(
        studentId: j['studentId'] as String? ?? '',
        studentName: j['studentName'] as String? ?? '',
        subjectCode: j['subjectCode'] as String? ?? '',
        subjectTitle: j['subjectTitle'] as String? ?? '',
        creditedUnits: (j['creditedUnits'] as num?)?.toDouble() ?? 0,
        units: (j['units'] as num?)?.toDouble() ?? 0,
        sourceSchool: j['sourceSchool'] as String? ?? '',
        grade: j['grade'] as String?,
        kind: (j['kind'] as num?)?.toInt() ?? 1,
      );

  bool get isPartial => creditedUnits < units;
}

/// What importing a list of credited subjects would do (dry run) or did.
class CreditsImportResult {
  final bool dryRun;
  final int credits;
  final int students;
  final int alreadyCredited;
  final List<CreditsImportRow> rows;
  final List<RecordsImportProblem> problems;
  final int totalProblems;

  const CreditsImportResult({
    this.dryRun = true,
    this.credits = 0,
    this.students = 0,
    this.alreadyCredited = 0,
    this.rows = const [],
    this.problems = const [],
    this.totalProblems = 0,
  });

  factory CreditsImportResult.fromJson(Map<String, dynamic> j) => CreditsImportResult(
        dryRun: j['dryRun'] as bool? ?? true,
        credits: (j['credits'] as num?)?.toInt() ?? 0,
        students: (j['students'] as num?)?.toInt() ?? 0,
        alreadyCredited: (j['alreadyCredited'] as num?)?.toInt() ?? 0,
        rows: [for (final r in (j['rows'] as List? ?? const [])) CreditsImportRow.fromJson(r as Map<String, dynamic>)],
        problems: [
          for (final p in (j['problems'] as List? ?? const [])) RecordsImportProblem.fromJson(p as Map<String, dynamic>)
        ],
        totalProblems: (j['totalProblems'] as num?)?.toInt() ?? 0,
      );
}

/// One student whose enrollment form will be (or was) saved from the Google Form's answers.
class FormsImportRow {
  final int row;
  final String studentId;
  final String studentName;

  /// "school email" or "name".
  final String matchedBy;
  final int contacts;

  const FormsImportRow({this.row = 0, this.studentId = '', required this.studentName, this.matchedBy = '', this.contacts = 0});

  factory FormsImportRow.fromJson(Map<String, dynamic> j) => FormsImportRow(
        row: (j['row'] as num?)?.toInt() ?? 0,
        studentId: j['studentId'] as String? ?? '',
        studentName: j['studentName'] as String? ?? '',
        matchedBy: j['matchedBy'] as String? ?? '',
        contacts: (j['contacts'] as num?)?.toInt() ?? 0,
      );
}

/// What importing the Google Form's responses spreadsheet would do (dry run) or did.
class FormsImportResult {
  final bool dryRun;
  final int forms;
  final int alreadyImported;
  final int olderAnswersSkipped;
  final int notInSystem;
  final List<FormsImportRow> rows;
  final List<RecordsImportProblem> problems;
  final int totalProblems;

  const FormsImportResult({
    this.dryRun = true,
    this.forms = 0,
    this.alreadyImported = 0,
    this.olderAnswersSkipped = 0,
    this.notInSystem = 0,
    this.rows = const [],
    this.problems = const [],
    this.totalProblems = 0,
  });

  factory FormsImportResult.fromJson(Map<String, dynamic> j) => FormsImportResult(
        dryRun: j['dryRun'] as bool? ?? true,
        forms: (j['forms'] as num?)?.toInt() ?? 0,
        alreadyImported: (j['alreadyImported'] as num?)?.toInt() ?? 0,
        olderAnswersSkipped: (j['olderAnswersSkipped'] as num?)?.toInt() ?? 0,
        notInSystem: (j['notInSystem'] as num?)?.toInt() ?? 0,
        rows: [for (final r in (j['rows'] as List? ?? const [])) FormsImportRow.fromJson(r as Map<String, dynamic>)],
        problems: [
          for (final p in (j['problems'] as List? ?? const [])) RecordsImportProblem.fromJson(p as Map<String, dynamic>)
        ],
        totalProblems: (j['totalProblems'] as num?)?.toInt() ?? 0,
      );
}
