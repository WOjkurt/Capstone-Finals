class StudentProfileModel {
  final String userDetailId;
  final String userId;
  final String firstname;
  final String lastname;
  final String? lrn;
  final int? programId;
  final String? programCode;
  final String? programName;
  final int? studentType;
  final int? studentStatus;
  final int? yearLevel;
  final bool isRegular;

  const StudentProfileModel({
    required this.userDetailId,
    required this.userId,
    required this.firstname,
    required this.lastname,
    this.lrn,
    this.programId,
    this.programCode,
    this.programName,
    this.studentType,
    this.studentStatus,
    this.yearLevel,
    this.isRegular = true,
  });

  factory StudentProfileModel.fromJson(Map<String, dynamic> json) {
    return StudentProfileModel(
      userDetailId: json['userDetailID'] as String? ?? json['userDetailId'] as String? ?? '',
      userId: json['userID'] as String? ?? json['userId'] as String? ?? '',
      firstname: json['firstname'] as String? ?? json['firstName'] as String? ?? '',
      lastname: json['lastname'] as String? ?? json['lastName'] as String? ?? '',
      lrn: json['lrn'] as String? ?? json['LRN'] as String?,
      programId: (json['programID'] as num?)?.toInt() ?? (json['programId'] as num?)?.toInt(),
      programCode: json['programCode'] as String?,
      programName: json['programName'] as String?,
      studentType: (json['studentType'] as num?)?.toInt(),
      studentStatus: (json['studentStatus'] as num?)?.toInt(),
      yearLevel: (json['yearLevel'] as num?)?.toInt(),
      isRegular: json['isRegular'] as bool? ?? true,
    );
  }

  String get fullName => '$firstname $lastname'.trim();

  String get initials {
    final f = firstname.isNotEmpty ? firstname[0].toUpperCase() : '';
    final l = lastname.isNotEmpty ? lastname[0].toUpperCase() : '';
    final res = '$f$l';
    return res.isEmpty ? 'S' : res;
  }

  String get studentTypeLabel {
    switch (studentType) {
      case 1:
        return 'New Student';
      case 2:
        return 'Old / Continuing';
      case 3:
        return 'Transferee';
      default:
        return 'Regular Student';
    }
  }

  String get studentStatusLabel {
    switch (studentStatus) {
      case 1:
        return 'Enrolled';
      case 2:
        return 'Graduated';
      case 3:
        return 'Dropped';
      default:
        return 'Active';
    }
  }

  String get regularStatusLabel => isRegular ? 'Regular' : 'Irregular';

  String get yearLevelLabel {
    if (yearLevel == null || yearLevel! <= 0) return '1st Year';
    switch (yearLevel) {
      case 1:
        return '1st Year';
      case 2:
        return '2nd Year';
      case 3:
        return '3rd Year';
      case 4:
        return '4th Year';
      default:
        return 'Year $yearLevel';
    }
  }

  String get programDisplay {
    if (programCode != null && programCode!.isNotEmpty) {
      return programCode!;
    }
    if (programName != null && programName!.isNotEmpty) {
      return programName!;
    }
    if (programId != null) {
      return 'Program #$programId';
    }
    return 'General Curriculum';
  }
}
