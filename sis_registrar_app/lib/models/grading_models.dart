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
  final String? lrn;
  final bool? hasLrn;

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
    this.lrn,
    this.hasLrn,
  });

  factory UserSearchResultModel.fromJson(Map<String, dynamic> json) {
    String fn = json['firstname'] as String? ?? json['firstName'] as String? ?? '';
    String ln = json['lastname'] as String? ?? json['lastName'] as String? ?? '';
    if (fn.isEmpty && ln.isEmpty && json['fullName'] != null) {
      final parts = (json['fullName'] as String).trim().split(' ');
      if (parts.length > 1) {
        fn = parts.first;
        ln = parts.sublist(1).join(' ');
      } else {
        fn = parts.first;
      }
    }
    final rawLrn = json['lrn'] as String? ?? json['LRN'] as String?;
    final rawHasLrn = json['hasLrn'] as bool? ?? json['HasLrn'] as bool?;

    return UserSearchResultModel(
      userId: json['userID'] as String? ?? json['userId'] as String? ?? '',
      firstname: fn,
      lastname: ln,
      email: json['email'] as String? ?? '',
      programId: (json['programID'] as num?)?.toInt() ?? (json['programId'] as num?)?.toInt(),
      programCode: json['programCode'] as String?,
      yearLevel: (json['yearLevel'] as num?)?.toInt(),
      studentStatus: (json['studentStatus'] as num?)?.toInt(),
      role: (json['role'] as num?)?.toInt() ?? 5,
      roleName: json['roleName'] as String?,
      lrn: rawLrn,
      hasLrn: rawHasLrn ?? (rawLrn != null && rawLrn.isNotEmpty),
    );
  }

  String get fullName => '$firstname $lastname'.trim();

  UserSearchResultModel copyWith({
    String? userId,
    String? firstname,
    String? lastname,
    String? email,
    int? programId,
    String? programCode,
    int? yearLevel,
    int? studentStatus,
    int? role,
    String? roleName,
    String? lrn,
    bool clearLrn = false,
    bool? hasLrn,
  }) {
    return UserSearchResultModel(
      userId: userId ?? this.userId,
      firstname: firstname ?? this.firstname,
      lastname: lastname ?? this.lastname,
      email: email ?? this.email,
      programId: programId ?? this.programId,
      programCode: programCode ?? this.programCode,
      yearLevel: yearLevel ?? this.yearLevel,
      studentStatus: studentStatus ?? this.studentStatus,
      role: role ?? this.role,
      roleName: roleName ?? this.roleName,
      lrn: clearLrn ? null : (lrn ?? this.lrn),
      hasLrn: hasLrn ?? this.hasLrn,
    );
  }
}
