import '../utils/numbers.dart';


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

/// A student on irregular standing and how far they are from returning to
/// regular. DBTC's rule is 6 units of back major subjects passed.
class IrregularStudentModel {
  final String userId;
  final String studentName;
  final String? lrn;
  final String? programCode;
  final int? yearLevel;
  final DateTime? irregularSince;
  final double backMajorUnitsPassed;
  final bool readyToBeRegular;

  const IrregularStudentModel({
    required this.userId,
    required this.studentName,
    this.lrn,
    this.programCode,
    this.yearLevel,
    this.irregularSince,
    required this.backMajorUnitsPassed,
    required this.readyToBeRegular,
  });

  /// The units the Registrar's rule asks for before a student is regular again.
  static const double unitsToRegular = 6;

  String get progressLabel {
    final passed = backMajorUnitsPassed;
    final text =
        unitsText(passed);
    return '$text/${unitsToRegular.toStringAsFixed(0)} units';
  }

  factory IrregularStudentModel.fromJson(Map<String, dynamic> json) {
    final since = json['irregularSince'] as String?;
    return IrregularStudentModel(
      userId: json['userId'] as String? ?? json['userID'] as String? ?? '',
      studentName: json['studentName'] as String? ?? 'Unknown Student',
      lrn: json['lrn'] as String? ?? json['LRN'] as String?,
      programCode: json['programCode'] as String?,
      yearLevel: (json['yearLevel'] as num?)?.toInt(),
      irregularSince: since == null ? null : DateTime.tryParse(since),
      backMajorUnitsPassed:
          (json['backMajorUnitsPassed'] as num?)?.toDouble() ?? 0.0,
      readyToBeRegular: json['readyToBeRegular'] as bool? ?? false,
    );
  }
}
