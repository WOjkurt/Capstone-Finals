/// One curriculum version of a program, e.g. the CHED curriculum from SY 2026-2027.
class CurriculumModel {
  final String curriculumId;
  final int programId;
  final String? programCode;
  final String name;
  final int effectiveFromYear;
  final String effectiveSchoolYear;
  final int subjectCount;
  final int studentCount;

  /// New students get the newest curriculum of their program.
  final bool isNewest;

  const CurriculumModel({
    required this.curriculumId,
    required this.programId,
    this.programCode,
    required this.name,
    required this.effectiveFromYear,
    required this.effectiveSchoolYear,
    this.subjectCount = 0,
    this.studentCount = 0,
    this.isNewest = false,
  });

  /// "2026 curriculum (from SY 2026-2027)"
  String get label => '$name (from SY $effectiveSchoolYear)';

  factory CurriculumModel.fromJson(Map<String, dynamic> j) => CurriculumModel(
        curriculumId: j['curriculumID'] as String? ?? j['curriculumId'] as String? ?? '',
        programId: (j['programID'] as num?)?.toInt() ?? (j['programId'] as num?)?.toInt() ?? 0,
        programCode: j['programCode'] as String?,
        name: j['name'] as String? ?? '',
        effectiveFromYear: (j['effectiveFromYear'] as num?)?.toInt() ?? 0,
        effectiveSchoolYear: j['effectiveSchoolYear'] as String? ?? '',
        subjectCount: (j['subjectCount'] as num?)?.toInt() ?? 0,
        studentCount: (j['studentCount'] as num?)?.toInt() ?? 0,
        isNewest: j['isNewest'] as bool? ?? false,
      );
}

/// The curriculum a student follows; [curriculumId] is null for old records without one.
class StudentCurriculumModel {
  final int? programId;
  final String? curriculumId;
  final String? name;
  final String? effectiveSchoolYear;

  const StudentCurriculumModel({this.programId, this.curriculumId, this.name, this.effectiveSchoolYear});

  factory StudentCurriculumModel.fromJson(Map<String, dynamic> j) => StudentCurriculumModel(
        programId: (j['programID'] as num?)?.toInt() ?? (j['programId'] as num?)?.toInt(),
        curriculumId: j['curriculumID'] as String? ?? j['curriculumId'] as String?,
        name: j['name'] as String?,
        effectiveSchoolYear: j['effectiveSchoolYear'] as String?,
      );
}

class CurriculumImportFinding {
  final int row;
  final String code;
  final String message;
  const CurriculumImportFinding(this.row, this.code, this.message);

  factory CurriculumImportFinding.fromJson(Map<String, dynamic> j) => CurriculumImportFinding(
      (j['row'] as num?)?.toInt() ?? 0, j['code'] as String? ?? '', j['message'] as String? ?? '');
}

/// What a curriculum CSV import would do (dry run) or did.
class CurriculumImportResult {
  final bool dryRun;
  final String program;
  final int create;
  final int update;
  final int unchanged;
  final int prerequisitesToAdd;
  final int corequisitesToAdd;
  final List<CurriculumImportFinding> warnings;
  final List<CurriculumImportFinding> errors;

  const CurriculumImportResult({
    required this.dryRun,
    required this.program,
    this.create = 0,
    this.update = 0,
    this.unchanged = 0,
    this.prerequisitesToAdd = 0,
    this.corequisitesToAdd = 0,
    this.warnings = const [],
    this.errors = const [],
  });

  factory CurriculumImportResult.fromJson(Map<String, dynamic> j) {
    final s = j['subjects'] as Map<String, dynamic>? ?? const {};
    final r = j['requisites'] as Map<String, dynamic>? ?? const {};
    List<CurriculumImportFinding> list(String key) => [
          for (final f in j[key] as List? ?? const []) CurriculumImportFinding.fromJson(f as Map<String, dynamic>)
        ];
    int n(Map<String, dynamic> m, String k) => (m[k] as num?)?.toInt() ?? 0;
    return CurriculumImportResult(
      dryRun: j['dryRun'] as bool? ?? true,
      program: j['program'] as String? ?? '',
      create: n(s, 'create'),
      update: n(s, 'update'),
      unchanged: n(s, 'unchanged'),
      prerequisitesToAdd: n(r, 'prerequisitesToAdd'),
      corequisitesToAdd: n(r, 'corequisitesToAdd'),
      warnings: list('warnings'),
      errors: list('errors'),
    );
  }
}
