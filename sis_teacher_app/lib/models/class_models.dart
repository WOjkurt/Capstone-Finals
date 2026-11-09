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
  final int? yearLevel;

  /// Minor (GE, theology…) classes are staffed and scheduled by the College Head.
  final bool isMinor;
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
    this.yearLevel,
    this.isMinor = false,
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
      yearLevel: (json['yearLevel'] as num?)?.toInt(),
      isMinor: json['isMinor'] as bool? ?? false,
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
  });

  factory ClassRosterItemModel.fromJson(Map<String, dynamic> json) {
    return ClassRosterItemModel(
      studyLoadId: json['studyLoadId'] as String? ?? json['studyLoadID'] as String? ?? '',
      studentUserId: json['studentUserId'] as String? ?? json['studentUserID'] as String?,
      studentName: json['studentName'] as String?,
      subjectCode: json['subjectCode'] as String? ?? '',
      subjectTitle: json['subjectTitle'] as String? ?? '',
      className: json['className'] as String? ?? '',
      teacherName: json['teacherName'] as String?,
      loadStatus: json['loadStatus'] as String? ?? '',
      termLabel: json['termLabel'] as String? ?? '',
    );
  }

  String get displayName =>
      (studentName != null && studentName!.trim().isNotEmpty)
          ? studentName!.trim()
          : 'Unknown Student';

  int get loadStatusInt {
    switch (loadStatus.trim().toLowerCase()) {
      case 'dropped':
        return 2;
      case 'withdrawn':
        return 3;
      case 'pending':
        return 4;
      case 'enrolled':
      default:
        return 1;
    }
  }

  bool get isEnrolled => loadStatusInt == 1;
  bool get isDropped => loadStatusInt == 2;
  bool get isWithdrawn => loadStatusInt == 3;
  bool get isPending => loadStatusInt == 4;
}
