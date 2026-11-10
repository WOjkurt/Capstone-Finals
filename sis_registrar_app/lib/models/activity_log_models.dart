/// Labels for the server's activity codes, in the order shown in the filter.
const Map<String, String> kActivityActionLabels = {
  'LOADS_SAVED': 'Study load saved',
  'SIGN_IN_BLOCKED': 'Sign-in blocked',
  'ACCESS_DENIED': 'Access refused',
  'FORCED_ENROLLMENT': 'Forced enrollment',
  'LOADS_FINALIZED': 'Loads finalized',
  'LOAD_STATUS_CHANGED': 'Load status changed',
  'OVERLOAD_APPROVED': 'Overload approved',
  'YEAR_LEVEL_CHANGED': 'Year level changed',
  'CREDIT_ADDED': 'Credit added',
  'CREDIT_REMOVED': 'Credit removed',
  'CREDITS_IMPORTED': 'Credits imported',
  'FORMS_IMPORTED': 'Enrollment forms imported',
  'CURRICULUM_CHANGED': 'Curriculum changed',
  'STUDENT_ID_CHANGED': 'Student ID changed',
  'RECORDS_IMPORTED': 'Records imported',
  'SCHOOL_EMAIL_SET': 'School email set',
  'GRADE_CORRECTION_APPROVED': 'Grade correction approved',
  'GRADE_CORRECTION_REJECTED': 'Grade correction rejected',
  'TEACHER_ASSIGNED': 'Teacher assigned',
  'CLEARANCE_CHANGED': 'Clearance changed',
  'PERSONAL_DETAILS_UPDATED': 'Personal details updated',
  'STANDING_CHANGED': 'Regular/irregular changed',
  'PROGRAM_SHIFTED': 'Program shifted',
  'SETTINGS_CHANGED': 'Settings changed',
  'HOLD_ADDED': 'Enrollment hold added',
  'HOLD_REMOVED': 'Enrollment hold removed',
  'REENROLLMENT_SUBMITTED': 'Enrolled online',
};

const Map<int, String> _roleNames = {
  1: 'Admin',
  2: 'Registrar',
  3: 'Teacher',
  4: 'Program Head',
  5: 'Student',
  6: 'College Head',
};

class ActivityLogEntry {
  final String id;
  final DateTime occurredAt; // local time
  final String actorName;
  final int? actorRole;
  final String action;
  final String? studentUserId;
  final String? studentName;
  final String? termLabel;
  final String summary;

  const ActivityLogEntry({
    required this.id,
    required this.occurredAt,
    required this.actorName,
    this.actorRole,
    required this.action,
    this.studentUserId,
    this.studentName,
    this.termLabel,
    required this.summary,
  });

  String get actionLabel => kActivityActionLabels[action] ?? action;
  String get actorRoleName => _roleNames[actorRole] ?? '';

  factory ActivityLogEntry.fromJson(Map<String, dynamic> j) {
    // The API sends UTC; older servers may omit the trailing Z.
    var raw = j['occurredAt'] as String? ?? '';
    if (raw.isNotEmpty && !raw.endsWith('Z') && !raw.contains('+')) raw = '${raw}Z';
    return ActivityLogEntry(
      id: j['id']?.toString() ?? '',
      occurredAt: (DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)).toLocal(),
      actorName: j['actorName'] as String? ?? '',
      actorRole: (j['actorRole'] as num?)?.toInt(),
      action: j['action'] as String? ?? '',
      studentUserId: j['studentUserId']?.toString(),
      studentName: j['studentName'] as String?,
      termLabel: j['termLabel'] as String?,
      summary: j['summary'] as String? ?? '',
    );
  }
}

class ActivityLogPage {
  final List<ActivityLogEntry> items;
  final int page;
  final int pageSize;
  final int totalCount;

  const ActivityLogPage({required this.items, required this.page, required this.pageSize, required this.totalCount});

  int get pageCount => totalCount == 0 ? 1 : ((totalCount + pageSize - 1) ~/ pageSize);

  factory ActivityLogPage.fromJson(Map<String, dynamic> j) => ActivityLogPage(
        items: (j['items'] as List? ?? []).map((e) => ActivityLogEntry.fromJson(e as Map<String, dynamic>)).toList(),
        page: (j['page'] as num?)?.toInt() ?? 1,
        pageSize: (j['pageSize'] as num?)?.toInt() ?? 50,
        totalCount: (j['totalCount'] as num?)?.toInt() ?? 0,
      );
}
