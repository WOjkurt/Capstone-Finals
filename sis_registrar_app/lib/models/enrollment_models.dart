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
  final String? houseStreet;
  final String barangay;
  final String cityMunicipality;
  final String province;
  final String zipCode;
  final String lastSchoolAttended;
  final String schoolAddress;
  final String? programTrackStrand;
  final String yearGraduated;
  final String previousCollege;
  final String previousCourse;
  final int yearLevel;
  final String? previousStudentID;

  // Personal / Demographic
  final String? gender;
  final int? age;
  final String? bloodType;
  final String? religion;
  final String? facebookName;

  // Secondary / Provincial Address
  final String? provHouseStreet;
  final String? provBarangay;
  final String? provCityMunicipality;
  final String? provProvince;
  final String? provZipCode;

  // Enrollment Metadata
  final int? studentType;
  final String? lrn;
  final String? academicYear;
  final String? incomingCourse;

  // Family Background
  final String? birthOrder;
  final int? numberOfSiblings;
  final String? familyStatus;

  // Medical / Multi-Select
  final List<String>? presentMedicalConditions;
  final List<String>? pastMedicalHistory;
  final List<String>? immunizationHistory;

  // Family Health History (free text)
  final String? familyMedicalConditionsNotes;
  final String? ongoingMedications;
  final String? developmentalConditions;
  final String? otherMedicalDiagnosis;

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
    this.houseStreet,
    required this.barangay,
    required this.cityMunicipality,
    required this.province,
    required this.zipCode,
    required this.lastSchoolAttended,
    required this.schoolAddress,
    this.programTrackStrand,
    required this.yearGraduated,
    required this.previousCollege,
    required this.previousCourse,
    required this.yearLevel,
    this.previousStudentID,
    this.gender,
    this.age,
    this.bloodType,
    this.religion,
    this.facebookName,
    this.provHouseStreet,
    this.provBarangay,
    this.provCityMunicipality,
    this.provProvince,
    this.provZipCode,
    this.studentType,
    this.lrn,
    this.academicYear,
    this.incomingCourse,
    this.birthOrder,
    this.numberOfSiblings,
    this.familyStatus,
    this.presentMedicalConditions,
    this.pastMedicalHistory,
    this.immunizationHistory,
    this.familyMedicalConditionsNotes,
    this.ongoingMedications,
    this.developmentalConditions,
    this.otherMedicalDiagnosis,
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
      houseStreet: json['houseStreet'] as String?,
      barangay: json['barangay'] as String? ?? '',
      cityMunicipality: json['cityMunicipality'] as String? ??
          json['cityOfMunicipality'] as String? ??
          '',
      province: json['province'] as String? ?? '',
      zipCode: json['zipCode'] as String? ?? '',
      lastSchoolAttended: json['lastSchoolAttended'] as String? ?? '',
      schoolAddress: json['schoolAddress'] as String? ?? '',
      programTrackStrand: json['programTrackStrand'] as String? ??
          json['shsStrand']?.toString(),
      yearGraduated: json['yearGraduated'] as String? ?? '',
      previousCollege: json['previousCollege'] as String? ?? '',
      previousCourse: json['previousCourse'] as String? ?? '',
      yearLevel: (json['yearLevel'] is num && (json['yearLevel'] as num) > 0)
          ? (json['yearLevel'] as num).toInt()
          : 1,
      previousStudentID: json['previousStudentID'] as String?,
      gender: json['gender'] as String?,
      age: json['age'] is num
          ? (json['age'] as num).toInt()
          : int.tryParse(json['age']?.toString() ?? ''),
      bloodType: json['bloodType'] as String?,
      religion: json['religion'] as String?,
      facebookName: json['facebookName'] as String?,
      provHouseStreet: json['provHouseStreet'] as String?,
      provBarangay: json['provBarangay'] as String?,
      provCityMunicipality: json['provCityMunicipality'] as String?,
      provProvince: json['provProvince'] as String?,
      provZipCode: json['provZipCode'] as String?,
      studentType: json['studentType'] is num
          ? (json['studentType'] as num).toInt()
          : int.tryParse(json['studentType']?.toString() ?? ''),
      lrn: json['lrn'] as String?,
      academicYear: json['academicYear'] as String?,
      incomingCourse: json['incomingCourse'] as String?,
      birthOrder: json['birthOrder'] as String?,
      numberOfSiblings: json['numberOfSiblings'] is num
          ? (json['numberOfSiblings'] as num).toInt()
          : int.tryParse(json['numberOfSiblings']?.toString() ?? ''),
      familyStatus: json['familyStatus'] as String?,
      presentMedicalConditions: (json['presentMedicalConditions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (json['familyMedicalConditionsSelected'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
      pastMedicalHistory: (json['pastMedicalHistory'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      immunizationHistory: (json['immunizationHistory'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      familyMedicalConditionsNotes:
          json['familyMedicalConditionsNotes'] as String?,
      ongoingMedications: json['ongoingMedications'] as String?,
      developmentalConditions: json['developmentalConditions'] as String?,
      otherMedicalDiagnosis: json['otherMedicalDiagnosis'] as String?,
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
        if (houseStreet != null) 'houseStreet': houseStreet,
        'barangay': barangay,
        'cityMunicipality': cityMunicipality,
        'province': province,
        'zipCode': zipCode,
        'lastSchoolAttended': lastSchoolAttended,
        'schoolAddress': schoolAddress,
        if (programTrackStrand != null) 'programTrackStrand': programTrackStrand,
        'yearGraduated': yearGraduated,
        'previousCollege': previousCollege,
        'previousCourse': previousCourse,
        'yearLevel': yearLevel,
        if (previousStudentID != null) 'previousStudentID': previousStudentID,
        if (gender != null) 'gender': gender,
        if (age != null) 'age': age,
        if (bloodType != null) 'bloodType': bloodType,
        if (religion != null) 'religion': religion,
        if (facebookName != null) 'facebookName': facebookName,
        if (provHouseStreet != null) 'provHouseStreet': provHouseStreet,
        if (provBarangay != null) 'provBarangay': provBarangay,
        if (provCityMunicipality != null)
          'provCityMunicipality': provCityMunicipality,
        if (provProvince != null) 'provProvince': provProvince,
        if (provZipCode != null) 'provZipCode': provZipCode,
        if (studentType != null) 'studentType': studentType,
        if (lrn != null) 'lrn': lrn,
        if (academicYear != null) 'academicYear': academicYear,
        if (incomingCourse != null) 'incomingCourse': incomingCourse,
        if (birthOrder != null) 'birthOrder': birthOrder,
        if (numberOfSiblings != null) 'numberOfSiblings': numberOfSiblings,
        if (familyStatus != null) 'familyStatus': familyStatus,
        if (presentMedicalConditions != null)
          'presentMedicalConditions': presentMedicalConditions,
        if (pastMedicalHistory != null)
          'pastMedicalHistory': pastMedicalHistory,
        if (immunizationHistory != null)
          'immunizationHistory': immunizationHistory,
        if (familyMedicalConditionsNotes != null)
          'familyMedicalConditionsNotes': familyMedicalConditionsNotes,
        if (ongoingMedications != null)
          'ongoingMedications': ongoingMedications,
        if (developmentalConditions != null)
          'developmentalConditions': developmentalConditions,
        if (otherMedicalDiagnosis != null)
          'otherMedicalDiagnosis': otherMedicalDiagnosis,
      };

  String get fullName =>
      '${firstName.isNotEmpty ? firstName : ''} ${middleName.isNotEmpty ? middleName : ''} $lastName'
          .replaceAll(RegExp(r'  +'), ' ')
          .trim();

  String get strandName =>
      (programTrackStrand != null && programTrackStrand!.isNotEmpty)
          ? programTrackStrand!
          : '—';
}

class ContactModel {
  final String firstName;
  final String lastName;
  final int relationType;
  final String occupation;
  final String contactNo;
  final String? email;
  final String? dateOfBirth;
  final String? workplace;
  final String? facebookAccount;
  final bool? livingWithGuardian;
  final String? guardianRelationshipDescription;

  const ContactModel({
    required this.firstName,
    required this.lastName,
    required this.relationType,
    required this.occupation,
    required this.contactNo,
    this.email,
    this.dateOfBirth,
    this.workplace,
    this.facebookAccount,
    this.livingWithGuardian,
    this.guardianRelationshipDescription,
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
      email: json['email'] as String?,
      dateOfBirth: json['dateOfBirth'] as String?,
      workplace: json['workplace'] as String?,
      facebookAccount: json['facebookAccount'] as String?,
      livingWithGuardian: json['livingWithGuardian'] as bool?,
      guardianRelationshipDescription:
          json['guardianRelationshipDescription'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'relationType': relationType,
        'occupation': occupation,
        'contactNo': contactNo,
        if (email != null) 'email': email,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
        if (workplace != null) 'workplace': workplace,
        if (facebookAccount != null) 'facebookAccount': facebookAccount,
        if (livingWithGuardian != null)
          'livingWithGuardian': livingWithGuardian,
        if (guardianRelationshipDescription != null)
          'guardianRelationshipDescription': guardianRelationshipDescription,
      };

  String get relationName {
    switch (relationType) {
      case 1:
        return 'Father';
      case 2:
        return 'Mother';
      case 3:
        return 'Guardian';
      case 4:
        return 'Sibling';
      case 5:
        return 'Spouse';
      case 6:
        return 'Other';
      default:
        return relationType > 0 ? 'Relation #$relationType' : '—';
    }
  }
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
  final String? schoolEmail;
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
    this.schoolEmail,
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
      schoolEmail: json['schoolEmail'] as String?,
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
