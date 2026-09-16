class GradeClearanceModel {
  final String clearanceId;
  final String userId;
  final String termId;
  final String? termLabel;
  final bool isCleared;
  final String? clearedByUserId;
  final String? clearedByUserName;
  final DateTime? clearedAt;

  const GradeClearanceModel({
    required this.clearanceId,
    required this.userId,
    required this.termId,
    this.termLabel,
    required this.isCleared,
    this.clearedByUserId,
    this.clearedByUserName,
    this.clearedAt,
  });

  factory GradeClearanceModel.fromJson(Map<String, dynamic> json) {
    return GradeClearanceModel(
      clearanceId: json['clearanceID'] as String? ?? json['clearanceId'] as String? ?? '',
      userId: json['userID'] as String? ?? json['userId'] as String? ?? '',
      termId: json['termID'] as String? ?? json['termId'] as String? ?? '',
      termLabel: json['termLabel'] as String?,
      isCleared: json['isCleared'] as bool? ?? false,
      clearedByUserId: json['clearedByUserID'] as String? ?? json['clearedByUserId'] as String?,
      clearedByUserName: json['clearedByUserName'] as String?,
      clearedAt: json['clearedAt'] != null
          ? DateTime.tryParse(json['clearedAt'] as String)
          : null,
    );
  }
}

class GradeCorrectionModel {
  final String correctionId;
  final String gradeId;
  final int correctionPeriod;
  final String correctionPeriodLabel;
  final double oldGrade;
  final double newGrade;
  final String reason;
  final String requestedByUserId;
  final String? requesterName;
  final String? reviewedByUserId;
  final String? reviewerName;
  final int correctionStatus;
  final String correctionStatusLabel;
  final DateTime dateRequested;
  final DateTime? dateReviewed;
  final String? subjectCode;
  final String? subjectTitle;
  final String? studentName;

  const GradeCorrectionModel({
    required this.correctionId,
    required this.gradeId,
    required this.correctionPeriod,
    required this.correctionPeriodLabel,
    required this.oldGrade,
    required this.newGrade,
    required this.reason,
    required this.requestedByUserId,
    this.requesterName,
    this.reviewedByUserId,
    this.reviewerName,
    required this.correctionStatus,
    required this.correctionStatusLabel,
    required this.dateRequested,
    this.dateReviewed,
    this.subjectCode,
    this.subjectTitle,
    this.studentName,
  });

  factory GradeCorrectionModel.fromJson(Map<String, dynamic> json) {
    return GradeCorrectionModel(
      correctionId: json['correctionId'] as String? ?? json['correctionID'] as String? ?? '',
      gradeId: json['gradeId'] as String? ?? json['gradeID'] as String? ?? '',
      correctionPeriod: (json['correctionPeriod'] as num?)?.toInt() ?? 0,
      correctionPeriodLabel:
          json['correctionPeriodLabel'] as String? ?? '',
      oldGrade: (json['oldGrade'] as num?)?.toDouble() ?? 0,
      newGrade: (json['newGrade'] as num?)?.toDouble() ?? 0,
      reason: json['reason'] as String? ?? '',
      requestedByUserId: json['requestedByUserID'] as String? ?? json['requestedByUserId'] as String? ?? '',
      requesterName: json['requesterName'] as String?,
      reviewedByUserId: json['reviewedByUserID'] as String? ?? json['reviewedByUserId'] as String?,
      reviewerName: json['reviewerName'] as String?,
      correctionStatus: (json['correctionStatus'] as num?)?.toInt() ?? 0,
      correctionStatusLabel:
          json['correctionStatusLabel'] as String? ?? '',
      dateRequested:
          DateTime.tryParse(json['dateRequested'] as String? ?? '') ??
              DateTime.now(),
      dateReviewed: json['dateReviewed'] != null
          ? DateTime.tryParse(json['dateReviewed'] as String)
          : null,
      subjectCode: json['subjectCode'] as String?,
      subjectTitle: json['subjectTitle'] as String?,
      studentName: json['studentName'] as String?,
    );
  }
}

class UserSearchResultModel {
  final String userId;
  final String firstname;
  final String lastname;
  final String email;
  final int? programId;
  final String? programCode;
  final int? yearLevel;
  final int? studentStatus;
  final int role;
  final String? roleName;

  const UserSearchResultModel({
    required this.userId,
    required this.firstname,
    required this.lastname,
    required this.email,
    this.programId,
    this.programCode,
    this.yearLevel,
    this.studentStatus,
    required this.role,
    this.roleName,
  });

  factory UserSearchResultModel.fromJson(Map<String, dynamic> json) {
    return UserSearchResultModel(
      userId: json['userID'] as String? ?? json['userId'] as String? ?? '',
      firstname: json['firstname'] as String? ?? json['firstName'] as String? ?? '',
      lastname: json['lastname'] as String? ?? json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      programId: (json['programID'] as num?)?.toInt() ?? (json['programId'] as num?)?.toInt(),
      programCode: json['programCode'] as String?,
      yearLevel: (json['yearLevel'] as num?)?.toInt(),
      studentStatus: (json['studentStatus'] as num?)?.toInt(),
      role: (json['role'] as num?)?.toInt() ?? 5,
      roleName: json['roleName'] as String?,
    );
  }

  String get fullName => '$firstname $lastname'.trim();
}

class GradeModel {
  final String gradeId;
  final String studyLoadId;
  final double? midtermGrade;
  final double? finalGrade;
  final int? remarks;
  final String? remarksLabel;
  final String? submittedByUserID;
  final String? teacherName;
  final DateTime? dateSubmitted;
  final String? studentUserId;
  final String? studentName;
  final String? subjectCode;
  final String? subjectTitle;
  final String? className;

  const GradeModel({
    required this.gradeId,
    required this.studyLoadId,
    this.midtermGrade,
    this.finalGrade,
    this.remarks,
    this.remarksLabel,
    this.submittedByUserID,
    this.teacherName,
    this.dateSubmitted,
    this.studentUserId,
    this.studentName,
    this.subjectCode,
    this.subjectTitle,
    this.className,
  });

  factory GradeModel.fromJson(Map<String, dynamic> json) {
    return GradeModel(
      gradeId: json['gradeId'] as String? ?? json['gradeID'] as String? ?? '',
      studyLoadId: json['studyLoadId'] as String? ?? json['studyLoadID'] as String? ?? '',
      midtermGrade: (json['midtermGrade'] as num?)?.toDouble(),
      finalGrade: (json['finalGrade'] as num?)?.toDouble(),
      remarks: (json['remarks'] as num?)?.toInt(),
      remarksLabel: json['remarksLabel'] as String?,
      submittedByUserID: json['submittedByUserID'] as String? ?? json['submittedByUserId'] as String?,
      teacherName: json['teacherName'] as String?,
      dateSubmitted: json['dateSubmitted'] != null
          ? DateTime.tryParse(json['dateSubmitted'] as String)
          : null,
      studentUserId: json['studentUserId'] as String? ?? json['studentUserID'] as String?,
      studentName: json['studentName'] as String?,
      subjectCode: json['subjectCode'] as String?,
      subjectTitle: json['subjectTitle'] as String?,
      className: json['className'] as String?,
    );
  }

  bool get isMidtermSubmitted => midtermGrade != null;
  bool get isFinalSubmitted => finalGrade != null;
}

class SubmitGradeBatchItemModel {
  final String studyLoadId;
  final double? midtermGrade;
  final double? finalGrade;

  const SubmitGradeBatchItemModel({
    required this.studyLoadId,
    this.midtermGrade,
    this.finalGrade,
  });

  Map<String, dynamic> toJson() => {
        'studyLoadId': studyLoadId,
        'midtermGrade': midtermGrade,
        'finalGrade': finalGrade,
      };
}

class SubmitGradeBatchModel {
  final String classId;
  final List<SubmitGradeBatchItemModel> grades;

  const SubmitGradeBatchModel({
    required this.classId,
    required this.grades,
  });

  Map<String, dynamic> toJson() => {
        'classId': classId,
        'grades': grades.map((g) => g.toJson()).toList(),
      };
}

class GradeBatchFailedItemModel {
  final String studyLoadId;
  final String reason;

  const GradeBatchFailedItemModel({
    required this.studyLoadId,
    required this.reason,
  });

  factory GradeBatchFailedItemModel.fromJson(Map<String, dynamic> json) {
    return GradeBatchFailedItemModel(
      studyLoadId: json['studyLoadId'] as String? ?? json['studyLoadID'] as String? ?? '',
      reason: json['reason'] as String? ?? 'Unknown error',
    );
  }
}

class GradeBatchResultModel {
  final List<GradeModel> succeeded;
  final List<GradeBatchFailedItemModel> failed;

  const GradeBatchResultModel({
    this.succeeded = const [],
    this.failed = const [],
  });

  factory GradeBatchResultModel.fromJson(Map<String, dynamic> json) {
    return GradeBatchResultModel(
      succeeded: (json['succeeded'] as List<dynamic>?)
              ?.map((e) => GradeModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      failed: (json['failed'] as List<dynamic>?)
              ?.map((e) =>
                  GradeBatchFailedItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Allowed values on the DBTC-Cebu collegiate grading scale
const List<double> kValidGradeValues = [
  1.00,
  1.25,
  1.50,
  1.75,
  2.00,
  2.25,
  2.50,
  2.75,
  3.00,
  5.00,
];

bool isValidGradeValue(double value) {
  return kValidGradeValues.any((v) => (v - value).abs() < 0.001);
}

String? validateGradeString(String? text) {
  if (text == null || text.trim().isEmpty) return null; // empty is allowed
  final parsed = double.tryParse(text.trim());
  if (parsed == null || !isValidGradeValue(parsed)) {
    return 'Must be 1.00, 1.25, 1.50, 1.75, 2.00, 2.25, 2.50, 2.75, 3.00, or 5.00';
  }
  return null;
}
