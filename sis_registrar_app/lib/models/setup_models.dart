class AcademicProgramModel {
  final int programId;
  final String programCode;
  final String programName;

  const AcademicProgramModel({
    required this.programId,
    required this.programCode,
    required this.programName,
  });

  factory AcademicProgramModel.fromJson(Map<String, dynamic> json) {
    return AcademicProgramModel(
      programId: (json['programID'] as num?)?.toInt() ?? (json['programId'] as num?)?.toInt() ?? 0,
      programCode: json['programCode'] as String? ?? '',
      programName: json['programName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'programCode': programCode,
        'programName': programName,
      };
}

class AcademicTermModel {
  final String termId;
  final String schoolYear;
  final int semester;
  final bool isActive;

  const AcademicTermModel({
    required this.termId,
    required this.schoolYear,
    required this.semester,
    this.isActive = false,
  });

  factory AcademicTermModel.fromJson(Map<String, dynamic> json) {
    return AcademicTermModel(
      termId: json['termID'] as String? ?? json['termId'] as String? ?? '',
      schoolYear: json['schoolYear'] as String? ?? '',
      semester: (json['semester'] as num?)?.toInt() ?? 1,
      isActive: json['isActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'schoolYear': schoolYear,
        'semester': semester,
      };

  String get label {
    final semLabel =
        semester == 1 ? '1st Sem' : semester == 2 ? '2nd Sem' : 'Summer';
    return '$schoolYear — $semLabel';
  }
}

class PrerequisiteModel {
  final String prerequisiteId;
  final String subjectId;
  final String prerequisiteSubjectId;
  final String? prerequisiteSubjectCode;
  final String? prerequisiteSubjectTitle;

  /// 0 = Prerequisite, 1 = Corequisite. Defaults to 0 when the server omits the field.
  final int requisiteType;

  const PrerequisiteModel({
    required this.prerequisiteId,
    required this.subjectId,
    required this.prerequisiteSubjectId,
    this.prerequisiteSubjectCode,
    this.prerequisiteSubjectTitle,
    this.requisiteType = 0,
  });

  factory PrerequisiteModel.fromJson(Map<String, dynamic> json) {
    return PrerequisiteModel(
      prerequisiteId: json['prerequisiteID'] as String? ?? json['prerequisiteId'] as String? ?? '',
      subjectId: json['subjectID'] as String? ?? json['subjectId'] as String? ?? '',
      prerequisiteSubjectId:
          json['prerequisiteSubjectID'] as String? ?? json['prerequisiteSubjectId'] as String? ?? '',
      prerequisiteSubjectCode:
          json['prerequisiteSubjectCode'] as String?,
      prerequisiteSubjectTitle:
          json['prerequisiteSubjectTitle'] as String?,
      requisiteType: (json['requisiteType'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isCorequisite => requisiteType == 1;
}

class SubjectModel {
  final String subjectId;
  final String subjectCode;
  final String subjectTitle;
  final double lecUnits;
  final double labUnits;
  final double lecHours;
  final double labHours;
  final int programId;
  final String? programCode;
  final int yearLevel;
  final int defaultSemester;
  final List<PrerequisiteModel> prerequisites;

  const SubjectModel({
    required this.subjectId,
    required this.subjectCode,
    required this.subjectTitle,
    required this.lecUnits,
    required this.labUnits,
    required this.lecHours,
    required this.labHours,
    required this.programId,
    this.programCode,
    required this.yearLevel,
    required this.defaultSemester,
    this.prerequisites = const [],
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      subjectId: json['subjectID'] as String? ?? json['subjectId'] as String? ?? '',
      subjectCode: json['subjectCode'] as String? ?? '',
      subjectTitle: json['subjectTitle'] as String? ?? '',
      lecUnits: (json['lecUnits'] as num?)?.toDouble() ?? 0,
      labUnits: (json['labUnits'] as num?)?.toDouble() ?? 0,
      lecHours: (json['lecHours'] as num?)?.toDouble() ?? 0,
      labHours: (json['labHours'] as num?)?.toDouble() ?? 0,
      programId: (json['programID'] as num?)?.toInt() ?? (json['programId'] as num?)?.toInt() ?? 0,
      programCode: json['programCode'] as String?,
      yearLevel: (json['yearLevel'] as num?)?.toInt() ?? 1,
      defaultSemester: (json['defaultSemester'] as num?)?.toInt() ?? 1,
      prerequisites: (json['prerequisites'] as List<dynamic>?)
              ?.map((e) =>
                  PrerequisiteModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
