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
