import '../utils/formatters.dart';

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

  String get label => formatTermLabel(schoolYear, semester);
}


