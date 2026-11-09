import '../utils/formatters.dart';

class ClassScheduleModel {
  final String scheduleId;
  final String classId;
  final String daysOfWeek;
  final String startTime;
  final String endTime;
  final String room;

  const ClassScheduleModel({
    required this.scheduleId,
    required this.classId,
    required this.daysOfWeek,
    required this.startTime,
    required this.endTime,
    required this.room,
  });

  factory ClassScheduleModel.fromJson(Map<String, dynamic> json) {
    return ClassScheduleModel(
      scheduleId: json['scheduleID'] as String? ?? json['scheduleId'] as String? ?? '',
      classId: json['classID'] as String? ?? json['classId'] as String? ?? '',
      daysOfWeek: json['daysOfWeek'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      room: json['room'] as String? ?? '',
    );
  }

  String get formattedTime => _formatTimeRange(startTime, endTime);

  String get summary {
    final t = formattedTime;
    final r = room.trim().isNotEmpty ? ' · $room' : '';
    return t.isNotEmpty ? '$daysOfWeek $t$r' : '$daysOfWeek$r';
  }

  static String _formatTime(String time) {
    if (time.isEmpty) return '';
    final parts = time.split(':');
    if (parts.length < 2) return time;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return time;
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  static String _formatTimeRange(String start, String end) {
    final s = _formatTime(start);
    final e = _formatTime(end);
    if (s.isEmpty && e.isEmpty) return '';
    if (s.isEmpty) return e;
    if (e.isEmpty) return s;
    return '$s – $e';
  }
}

class ClassModel {
  final String classId;
  final String subjectId;
  final String? subjectCode;
  final String? subjectTitle;
  final String? userId;
  final String? teacherName;
  final String termId;
  final String? termSchoolYear;
  final int? termSemester;
  final String className;

  /// The subject's curriculum; [showCurriculum] is true when its program has several curricula.
  final String? curriculumName;
  final bool showCurriculum;
  final DateTime? createdAt;
  final String? createdByUserId;
  final int enrolledCount;
  final bool isMinor;
  final int? programId;
  final List<ClassScheduleModel> schedules;

  const ClassModel({
    required this.classId,
    required this.subjectId,
    this.subjectCode,
    this.subjectTitle,
    this.userId,
    this.teacherName,
    required this.termId,
    this.termSchoolYear,
    this.termSemester,
    required this.className,
    this.curriculumName,
    this.showCurriculum = false,
    this.createdAt,
    this.createdByUserId,
    this.enrolledCount = 0,
    this.isMinor = false,
    this.programId,
    this.schedules = const [],
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      classId: json['classID'] as String? ?? json['classId'] as String? ?? '',
      subjectId: json['subjectID'] as String? ?? json['subjectId'] as String? ?? '',
      subjectCode: json['subjectCode'] as String?,
      subjectTitle: json['subjectTitle'] as String?,
      userId: json['userID'] as String? ?? json['userId'] as String?,
      teacherName: json['teacherName'] as String?,
      termId: json['termID'] as String? ?? json['termId'] as String? ?? '',
      termSchoolYear: json['termSchoolYear'] as String?,
      termSemester: (json['termSemester'] as num?)?.toInt(),
      className: json['className'] as String? ?? '',
      curriculumName: json['curriculumName'] as String?,
      showCurriculum: json['showCurriculum'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      createdByUserId: json['createdByUserID'] as String? ?? json['createdByUserId'] as String?,
      enrolledCount: (json['enrolledCount'] as num?)?.toInt() ?? 0,
      isMinor: json['isMinor'] as bool? ?? false,
      programId: (json['programID'] as num?)?.toInt() ?? (json['programId'] as num?)?.toInt(),
      schedules: (json['schedules'] as List<dynamic>?)
              ?.map((e) => ClassScheduleModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// The subject title, followed by the curriculum when the program has more than one (e.g. "Machining · CHED 2026").
  String titleWithCurriculum([String fallback = '']) {
    final title = subjectTitle ?? fallback;
    return showCurriculum && curriculumName != null ? '$title · $curriculumName' : title;
  }

  String get termLabel {
    if (termSchoolYear == null || termSchoolYear!.isEmpty) return 'N/A';
    return formatTermLabel(termSchoolYear!, termSemester);
  }

  String get scheduleSummary {
    if (schedules.isEmpty) return 'No schedule assigned';
    return schedules.map((s) => s.summary).join(' | ');
  }
}

class ClassRosterItemModel {
  final String studyLoadId;
  final String? studentUserId;
  final String? studentName;
  final String subjectCode;
  final String subjectTitle;
  final String className;
  final String? teacherName;
  final String loadStatus;
  final String termLabel;
  final String? lrn;
  final bool? hasLrn;
  final bool isForced;
  final String? forcedReason;
  final String? forcedByUserId;
  final double units;
  final List<ClassScheduleModel> schedules;

  const ClassRosterItemModel({
    required this.studyLoadId,
    this.studentUserId,
    this.studentName,
    required this.subjectCode,
    required this.subjectTitle,
    required this.className,
    this.teacherName,
    required this.loadStatus,
    required this.termLabel,
    this.lrn,
    this.hasLrn,
    this.isForced = false,
    this.forcedReason,
    this.forcedByUserId,
    this.units = 0,
    this.schedules = const [],
  });

  factory ClassRosterItemModel.fromJson(Map<String, dynamic> json) {
    final rawLrn = json['lrn'] as String? ?? json['LRN'] as String?;
    final rawHasLrn = json['hasLrn'] as bool? ?? json['HasLrn'] as bool?;

    return ClassRosterItemModel(
      studyLoadId: json['studyLoadId'] as String? ?? json['studyLoadID'] as String? ?? '',
      studentUserId: json['studentUserId'] as String? ?? json['studentUserID'] as String?,
      studentName: json['studentName'] as String?,
      subjectCode: json['subjectCode'] as String? ?? '',
      subjectTitle: json['subjectTitle'] as String? ?? '',
      className: json['className'] as String? ?? '',
      teacherName: json['teacherName'] as String?,
      loadStatus: json['loadStatus']?.toString() ?? '',
      termLabel: json['termLabel'] as String? ?? '',
      lrn: rawLrn,
      hasLrn: rawHasLrn ?? (rawLrn != null && rawLrn.isNotEmpty),
      isForced: json['isForced'] as bool? ?? false,
      forcedReason: json['forcedReason'] as String?,
      forcedByUserId: json['forcedByUserID'] as String? ?? json['forcedByUserId'] as String?,
      units: (json['units'] as num?)?.toDouble() ?? 0,
      schedules: (json['schedules'] as List?)
              ?.map((e) => ClassScheduleModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  String get displayName =>
      (studentName != null && studentName!.trim().isNotEmpty)
          ? studentName!.trim()
          : 'Unknown Student';

  int get loadStatusInt {
    switch (loadStatus.toLowerCase()) {
      case 'dropped':
        return 2;
      case 'withdrawn':
        return 3;
      case 'pending':
        return 4;
      case 'rejected':
        return 5;
      case 'enrolled':
      default:
        return 1;
    }
  }

  bool get isEnrolled => loadStatusInt == 1;
  bool get isDropped => loadStatusInt == 2;
  bool get isWithdrawn => loadStatusInt == 3;
  bool get isPending => loadStatusInt == 4;
  bool get isRejected => loadStatusInt == 5;
}

class PendingStudyLoadSummaryModel {
  final String userId;
  final String fullName;
  final String? lrn;
  final String? programCode;
  final String? programName;
  final int? yearLevel;
  final int pendingCount;
  final double pendingUnits;

  const PendingStudyLoadSummaryModel({
    required this.userId,
    required this.fullName,
    this.lrn,
    this.programCode,
    this.programName,
    this.yearLevel,
    required this.pendingCount,
    required this.pendingUnits,
  });

  factory PendingStudyLoadSummaryModel.fromJson(Map<String, dynamic> json) {
    return PendingStudyLoadSummaryModel(
      userId: json['userId'] as String? ?? json['studentUserId'] as String? ?? '',
      fullName: json['fullName'] as String? ?? json['studentName'] as String? ?? 'Unknown Student',
      lrn: json['lrn'] as String? ?? json['LRN'] as String?,
      programCode: json['programCode'] as String?,
      programName: json['programName'] as String?,
      yearLevel: (json['yearLevel'] as num?)?.toInt(),
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      pendingUnits: (json['pendingUnits'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OpenTermResultModel {
  final bool dryRun;
  final String termId;
  final int programId;
  final int plannedCount;
  final int createdCount;
  final int skippedExisting;
  final int skippedNoDefaultSemester;
  final Map<int, int> perYear;
  final bool termIsActive;
  final List<String> sampleClassNames;

  OpenTermResultModel({
    required this.dryRun,
    required this.termId,
    required this.programId,
    required this.plannedCount,
    required this.createdCount,
    required this.skippedExisting,
    required this.skippedNoDefaultSemester,
    required this.perYear,
    required this.termIsActive,
    required this.sampleClassNames,
  });

  int get skippedCount => skippedExisting + skippedNoDefaultSemester;

  factory OpenTermResultModel.fromJson(Map<String, dynamic> json) {
    final rawPerYear = json['perYear'] as Map<String, dynamic>? ?? {};
    final perYearMap = <int, int>{};
    for (final entry in rawPerYear.entries) {
      final y = int.tryParse(entry.key);
      if (y != null) {
        perYearMap[y] = (entry.value as num?)?.toInt() ?? 0;
      }
    }

    return OpenTermResultModel(
      dryRun: json['dryRun'] as bool? ?? false,
      termId: json['termId'] as String? ?? '',
      programId: (json['programId'] as num?)?.toInt() ?? 0,
      plannedCount: (json['plannedCount'] as num?)?.toInt() ?? 0,
      createdCount: (json['createdCount'] as num?)?.toInt() ?? 0,
      skippedExisting: (json['skippedExisting'] as num?)?.toInt() ?? 0,
      skippedNoDefaultSemester:
          (json['skippedNoDefaultSemester'] as num?)?.toInt() ?? 0,
      perYear: perYearMap,
      termIsActive: json['termIsActive'] as bool? ?? false,
      sampleClassNames: (json['sampleClassNames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class ClassOptionModel {
  final String classId;
  final String className;
  final String? teacherName;
  final String schedule;

  const ClassOptionModel({
    required this.classId,
    required this.className,
    this.teacherName,
    required this.schedule,
  });

  factory ClassOptionModel.fromJson(Map<String, dynamic> json) {
    return ClassOptionModel(
      classId: json['classId']?.toString() ?? '',
      className: json['className']?.toString() ?? '',
      teacherName: json['teacherName']?.toString(),
      schedule: json['schedule']?.toString() ?? '',
    );
  }
}

class ProposedBlockCorequisiteModel {
  final String subjectId;
  final String subjectCode;
  final bool includedInProposal;

  const ProposedBlockCorequisiteModel({
    required this.subjectId,
    required this.subjectCode,
    required this.includedInProposal,
  });

  factory ProposedBlockCorequisiteModel.fromJson(Map<String, dynamic> json) {
    return ProposedBlockCorequisiteModel(
      subjectId: json['subjectId']?.toString() ?? '',
      subjectCode: json['subjectCode']?.toString() ?? '',
      includedInProposal: json['includedInProposal'] as bool? ?? false,
    );
  }
}

class ProposedBlockItemModel {
  final String subjectId;
  final String subjectCode;
  final String subjectTitle;
  final String? classId;
  final String? className;
  final String matchType; // 'auto' | 'multiple_found' | 'no_class_offered'
  final List<ClassOptionModel> options;
  final String prerequisiteStatus; // 'met' | 'unmet'
  final List<String> prerequisiteMessages;
  final bool alreadyPassed;
  final bool alreadyEnrolledThisTerm;
  final String category; // 'regular' | 'retake' | 'back_subject'
  final int subjectYearLevel;
  final double units;
  final double? lastGrade;
  final String? lastGradeTerm;
  final String standingStatus; // 'not_required' | 'met' | 'unmet'
  final List<ProposedBlockCorequisiteModel> corequisites;

  const ProposedBlockItemModel({
    required this.subjectId,
    required this.subjectCode,
    required this.subjectTitle,
    this.classId,
    this.className,
    required this.matchType,
    this.options = const [],
    this.prerequisiteStatus = 'met',
    this.prerequisiteMessages = const [],
    this.alreadyPassed = false,
    this.alreadyEnrolledThisTerm = false,
    required this.category,
    required this.subjectYearLevel,
    required this.units,
    this.lastGrade,
    this.lastGradeTerm,
    this.standingStatus = 'not_required',
    this.corequisites = const [],
  });

  bool get isRegular => category == 'regular';
  bool get isRetake => category == 'retake';
  bool get isBackSubject => category == 'back_subject';
  bool get isNoClassOffered => matchType == 'no_class_offered';
  bool get isPrereqUnmet => prerequisiteStatus == 'unmet';
  bool get isStandingUnmet => standingStatus == 'unmet';
  bool get isBlocked => isPrereqUnmet || isStandingUnmet;

  factory ProposedBlockItemModel.fromJson(Map<String, dynamic> json) {
    return ProposedBlockItemModel(
      subjectId: json['subjectId']?.toString() ?? '',
      subjectCode: json['subjectCode']?.toString() ?? '',
      subjectTitle: json['subjectTitle']?.toString() ?? '',
      classId: json['classId']?.toString(),
      className: json['className']?.toString(),
      matchType: json['matchType']?.toString() ?? 'auto',
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => ClassOptionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      prerequisiteStatus: json['prerequisiteStatus']?.toString() ?? 'met',
      prerequisiteMessages: (json['prerequisiteMessages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      alreadyPassed: json['alreadyPassed'] as bool? ?? false,
      alreadyEnrolledThisTerm: json['alreadyEnrolledThisTerm'] as bool? ?? false,
      category: json['category']?.toString() ?? 'regular',
      subjectYearLevel: (json['subjectYearLevel'] as num?)?.toInt() ?? 1,
      units: (json['units'] as num?)?.toDouble() ?? 0.0,
      lastGrade: (json['lastGrade'] as num?)?.toDouble(),
      lastGradeTerm: json['lastGradeTerm']?.toString(),
      standingStatus: json['standingStatus']?.toString() ?? 'not_required',
      corequisites: (json['corequisites'] as List<dynamic>?)
              ?.map((e) => ProposedBlockCorequisiteModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class EnrollBatchResponseModel {
  final String classId;
  final bool enrolled;
  final String? studyLoadId;
  final List<String> reasons;

  const EnrollBatchResponseModel({
    required this.classId,
    required this.enrolled,
    this.studyLoadId,
    this.reasons = const [],
  });

  factory EnrollBatchResponseModel.fromJson(Map<String, dynamic> json) {
    return EnrollBatchResponseModel(
      classId: json['classId']?.toString() ?? '',
      enrolled: json['enrolled'] as bool? ?? false,
      studyLoadId: json['studyLoadId']?.toString(),
      reasons: (json['reasons'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class EnrollSingleResponseModel {
  final bool success;
  final String? studyLoadId;
  final List<String> warnings;

  const EnrollSingleResponseModel({
    required this.success,
    this.studyLoadId,
    this.warnings = const [],
  });

  factory EnrollSingleResponseModel.fromJson(Map<String, dynamic> json) {
    return EnrollSingleResponseModel(
      success: json['success'] as bool? ?? false,
      studyLoadId: json['studyLoadId']?.toString(),
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}



/// CHED-style unit limit for a student in a term (a warning only).
class UnitLimitModel {
  final double maxUnits;
  final double currentUnits;
  final bool isGraduating;
  final bool isSummer;
  final String rule;
  final String? overloadReason;
  final String? overloadApprovedBy;

  const UnitLimitModel({
    required this.maxUnits,
    required this.currentUnits,
    this.isGraduating = false,
    this.isSummer = false,
    this.rule = '',
    this.overloadReason,
    this.overloadApprovedBy,
  });

  bool get isOverloaded => currentUnits > maxUnits + 0.001;

  factory UnitLimitModel.fromJson(Map<String, dynamic> json) {
    return UnitLimitModel(
      maxUnits: (json['maxUnits'] as num?)?.toDouble() ?? 0,
      currentUnits: (json['currentUnits'] as num?)?.toDouble() ?? 0,
      isGraduating: json['isGraduating'] as bool? ?? false,
      isSummer: json['isSummer'] as bool? ?? false,
      rule: json['rule'] as String? ?? '',
      overloadReason: json['overloadReason'] as String?,
      overloadApprovedBy: json['overloadApprovedBy'] as String?,
    );
  }
}
