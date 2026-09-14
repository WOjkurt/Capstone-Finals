class StaffModel {
  final String userId;
  final String firebaseUid;
  final String email;
  final int role;
  final String roleName;
  final String firstname;
  final String lastname;
  final int? employeeId;
  final String? positionId;
  final String? positionName;
  final int? programId;
  final String? programCode;
  final bool isRegular;
  final bool isActive;
  final DateTime createdAt;
  final String? passwordResetLink;
  final String? firebaseSyncWarning;

  StaffModel({
    required this.userId,
    required this.firebaseUid,
    required this.email,
    required this.role,
    required this.roleName,
    required this.firstname,
    required this.lastname,
    this.employeeId,
    this.positionId,
    this.positionName,
    this.programId,
    this.programCode,
    required this.isRegular,
    required this.isActive,
    required this.createdAt,
    this.passwordResetLink,
    this.firebaseSyncWarning,
  });

  String get fullName => '$firstname $lastname'.trim();

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      userId: (json['userID'] ?? json['userId'] ?? '').toString(),
      firebaseUid: (json['firebaseUID'] ?? json['firebaseUid'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: json['role'] as int? ?? 0,
      roleName: (json['roleName'] ?? '').toString(),
      firstname: (json['firstname'] ?? '').toString(),
      lastname: (json['lastname'] ?? '').toString(),
      employeeId: json['employeeID'] as int? ?? json['employeeId'] as int?,
      positionId: json['positionID'] as String? ?? json['positionId'] as String?,
      positionName: json['positionName'] as String?,
      programId: json['programID'] as int? ?? json['programId'] as int?,
      programCode: json['programCode'] as String?,
      isRegular: json['isRegular'] as bool? ?? true,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      passwordResetLink: json['passwordResetLink'] as String?,
      firebaseSyncWarning: json['firebaseSyncWarning'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userID': userId,
      'firebaseUID': firebaseUid,
      'email': email,
      'role': role,
      'roleName': roleName,
      'firstname': firstname,
      'lastname': lastname,
      if (employeeId != null) 'employeeID': employeeId,
      if (positionId != null) 'positionID': positionId,
      if (positionName != null) 'positionName': positionName,
      if (programId != null) 'programID': programId,
      if (programCode != null) 'programCode': programCode,
      'isRegular': isRegular,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      if (passwordResetLink != null) 'passwordResetLink': passwordResetLink,
      if (firebaseSyncWarning != null) 'firebaseSyncWarning': firebaseSyncWarning,
    };
  }
}

class CreateStaffRequest {
  final String email;
  final String firstname;
  final String lastname;
  final int role;
  final int? employeeId;
  final int? programId;
  final bool isRegular;

  CreateStaffRequest({
    required this.email,
    required this.firstname,
    required this.lastname,
    required this.role,
    this.employeeId,
    this.programId,
    this.isRegular = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email.trim(),
      'firstname': firstname.trim(),
      'lastname': lastname.trim(),
      'role': role,
      if (employeeId != null) 'employeeID': employeeId,
      if (programId != null) 'programID': programId,
      'isRegular': isRegular,
    };
  }
}
