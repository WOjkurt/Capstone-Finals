class EnrollmentFormModel {
  final String firstName;
  final String middleName;
  final String lastName;
  final String suffix;
  final String dateOfBirth;
  final String placeOfBirth;
  final String sex;
  final String civilStatus;
  final String nationality;
  final String mobileNumber;
  final String barangay;
  final String cityMunicipality;
  final String province;
  final String zipCode;
  final String lastSchoolAttended;
  final String schoolAddress;
  final int shsStrand;
  final String yearGraduated;
  final String previousCollege;
  final String previousCourse;
  final int yearLevel;
  final String? previousStudentID;

  const EnrollmentFormModel({
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.suffix,
    required this.dateOfBirth,
    required this.placeOfBirth,
    required this.sex,
    required this.civilStatus,
    required this.nationality,
    required this.mobileNumber,
    required this.barangay,
    required this.cityMunicipality,
    required this.province,
    required this.zipCode,
    required this.lastSchoolAttended,
    required this.schoolAddress,
    required this.shsStrand,
    required this.yearGraduated,
    required this.previousCollege,
    required this.previousCourse,
    required this.yearLevel,
    this.previousStudentID,
  });

  factory EnrollmentFormModel.fromJson(Map<String, dynamic> json) {
    return EnrollmentFormModel(
      firstName: json['firstName'] as String? ?? '',
      middleName: json['middleName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      suffix: json['suffix'] as String? ?? '',
      dateOfBirth: json['dateOfBirth'] as String? ?? '',
      placeOfBirth: json['placeOfBirth'] as String? ?? '',
      sex: json['sex'] as String? ?? '',
      civilStatus: json['civilStatus'] as String? ?? '',
      nationality: json['nationality'] as String? ?? '',
      mobileNumber: json['mobileNumber'] as String? ?? '',
      barangay: json['barangay'] as String? ?? '',
      cityMunicipality: json['cityMunicipality'] as String? ??
          json['cityOfMunicipality'] as String? ??
          '',
      province: json['province'] as String? ?? '',
      zipCode: json['zipCode'] as String? ?? '',
      lastSchoolAttended: json['lastSchoolAttended'] as String? ?? '',
      schoolAddress: json['schoolAddress'] as String? ?? '',
      shsStrand: json['shsStrand'] is int
          ? json['shsStrand'] as int
          : (int.tryParse(json['shsStrand']?.toString() ?? '') ?? 0),
      yearGraduated: json['yearGraduated'] as String? ?? '',
      previousCollege: json['previousCollege'] as String? ?? '',
      previousCourse: json['previousCourse'] as String? ?? '',
      yearLevel: (json['yearLevel'] is num && (json['yearLevel'] as num) > 0)
          ? (json['yearLevel'] as num).toInt()
          : 1,
      previousStudentID: json['previousStudentID'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'suffix': suffix,
        'dateOfBirth': dateOfBirth,
        'placeOfBirth': placeOfBirth,
        'sex': sex,
        'civilStatus': civilStatus,
        'nationality': nationality,
        'mobileNumber': mobileNumber,
        'barangay': barangay,
        'cityMunicipality': cityMunicipality,
        'province': province,
        'zipCode': zipCode,
        'lastSchoolAttended': lastSchoolAttended,
        'schoolAddress': schoolAddress,
        'shsStrand': shsStrand,
        'yearGraduated': yearGraduated,
        'previousCollege': previousCollege,
        'previousCourse': previousCourse,
        'yearLevel': yearLevel,
        if (previousStudentID != null) 'previousStudentID': previousStudentID,
      };

  String get fullName =>
      '${firstName.isNotEmpty ? firstName : ''} ${middleName.isNotEmpty ? middleName : ''} $lastName'
          .replaceAll(RegExp(r'  +'), ' ')
          .trim();
}

class ContactModel {
  final String firstName;
  final String lastName;
  final int relationType;
  final String occupation;
  final String contactNo;

  const ContactModel({
    required this.firstName,
    required this.lastName,
    required this.relationType,
    required this.occupation,
    required this.contactNo,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      relationType: json['relationType'] is int
          ? json['relationType'] as int
          : (int.tryParse(json['relationType']?.toString() ?? '') ?? 1),
      occupation: json['occupation'] as String? ?? '',
      contactNo: json['contactNo'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'relationType': relationType,
        'occupation': occupation,
        'contactNo': contactNo,
      };
}

class EnrollmentResponseDataModel {
  final EnrollmentFormModel? form;
  final List<ContactModel> contacts;
  final String? intendedProgramCode;

  const EnrollmentResponseDataModel({
    this.form,
    this.contacts = const [],
    this.intendedProgramCode,
  });

  factory EnrollmentResponseDataModel.fromJson(Map<String, dynamic> json) {
    EnrollmentFormModel? form;
    String? intendedProgramCode;
    if (json['form'] != null && json['form'] is Map<String, dynamic>) {
      final formJson = json['form'] as Map<String, dynamic>;
      form = EnrollmentFormModel.fromJson(formJson);
      intendedProgramCode = formJson['intendedProgramCode'] as String?;
    }
    List<ContactModel> contacts = [];
    if (json['contacts'] != null && json['contacts'] is List) {
      contacts = (json['contacts'] as List<dynamic>)
          .map((e) => ContactModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return EnrollmentResponseDataModel(
      form: form,
      contacts: contacts,
      intendedProgramCode: intendedProgramCode ?? json['intendedProgramCode'] as String?,
    );
  }
}

class EnrollmentResponseModel {
  final String responseId;
  final DateTime timestamp;
  final String emailAddress;
  final bool isProcessed;
  final EnrollmentResponseDataModel? data;

  const EnrollmentResponseModel({
    required this.responseId,
    required this.timestamp,
    required this.emailAddress,
    required this.isProcessed,
    this.data,
  });

  factory EnrollmentResponseModel.fromJson(Map<String, dynamic> json) {
    return EnrollmentResponseModel(
      responseId: json['responseID'] as String? ?? json['responseId'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      emailAddress: json['emailAddress'] as String? ?? '',
      isProcessed: json['isProcessed'] as bool? ?? false,
      data: json['data'] != null && json['data'] is Map<String, dynamic>
          ? EnrollmentResponseDataModel.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class EnrollmentApplicationModel {
  final String applicationId;
  final String responseId;
  final int programId;
  final String termId;
  final int status;
  final String? reviewedByUserId;
  final String? studentUserId;
  final DateTime createdAt;
  final String? createdByUserId;
  final EnrollmentFormModel? form;
  final List<ContactModel> contacts;

  const EnrollmentApplicationModel({
    required this.applicationId,
    required this.responseId,
    required this.programId,
    required this.termId,
    required this.status,
    this.reviewedByUserId,
    this.studentUserId,
    required this.createdAt,
    this.createdByUserId,
    this.form,
    this.contacts = const [],
  });

  factory EnrollmentApplicationModel.fromJson(Map<String, dynamic> json) {
    return EnrollmentApplicationModel(
      applicationId: json['applicationID'] as String? ?? json['applicationId'] as String? ?? '',
      responseId: json['responseID'] as String? ?? json['responseId'] as String? ?? '',
      programId: (json['programID'] as num?)?.toInt() ?? (json['programId'] as num?)?.toInt() ?? 0,
      termId: json['termID'] as String? ?? json['termId'] as String? ?? '',
      status: (json['status'] as num?)?.toInt() ?? 1,
      reviewedByUserId: json['reviewedByUserID'] as String? ?? json['reviewedByUserId'] as String?,
      studentUserId: json['studentUserID'] as String? ?? json['studentUserId'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      createdByUserId: json['createdByUserID'] as String? ?? json['createdByUserId'] as String?,
      form: json['form'] != null
          ? EnrollmentFormModel.fromJson(
              json['form'] as Map<String, dynamic>)
          : null,
      contacts: (json['contacts'] as List<dynamic>?)
              ?.map((e) =>
                  ContactModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  String get statusLabel {
    switch (status) {
      case 1:
        return 'Pending';
      case 2:
        return 'Approved';
      case 3:
        return 'Rejected';
      case 4:
        return 'Active';
      default:
        return 'Unknown';
    }
  }
}
