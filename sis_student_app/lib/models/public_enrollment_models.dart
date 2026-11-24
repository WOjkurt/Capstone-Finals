// Applying to DBTC without an account. Nothing here belongs to a person: the status is the same
// answer for every visitor, and the receipt is the only record the applicant is given, because
// no confirmation email is sent.

class PublicProgram {
  final int programId;
  final String programCode;
  final String programName;

  const PublicProgram({required this.programId, required this.programCode, required this.programName});

  factory PublicProgram.fromJson(Map<String, dynamic> json) => PublicProgram(
        programId: (json['programId'] as num?)?.toInt() ?? 0,
        programCode: json['programCode']?.toString() ?? '',
        programName: json['programName']?.toString() ?? '',
      );

  String get label => programCode.isEmpty ? programName : '$programCode — $programName';
}

class PublicEnrollmentStatus {
  final bool isOpen;
  final String? termLabel;
  final DateTime? closesOn;
  final List<PublicProgram> programs;

  const PublicEnrollmentStatus({
    required this.isOpen,
    this.termLabel,
    this.closesOn,
    this.programs = const [],
  });

  factory PublicEnrollmentStatus.fromJson(Map<String, dynamic> json) => PublicEnrollmentStatus(
        isOpen: json['isOpen'] == true,
        termLabel: json['termLabel']?.toString(),
        closesOn: DateTime.tryParse(json['closesOn']?.toString() ?? ''),
        programs: [
          for (final p in (json['programs'] as List<dynamic>? ?? []))
            PublicProgram.fromJson(p as Map<String, dynamic>)
        ],
      );
}

/// What the applicant is shown after sending the form. The reference is the only thing they can
/// quote back to the Registrar, so it is short enough to write down.
class PublicEnrollmentReceipt {
  final String responseId;
  final String reference;
  final String termLabel;
  final DateTime? submittedAt;

  const PublicEnrollmentReceipt({
    required this.responseId,
    required this.reference,
    required this.termLabel,
    this.submittedAt,
  });

  factory PublicEnrollmentReceipt.fromJson(Map<String, dynamic> json) => PublicEnrollmentReceipt(
        responseId: json['responseId']?.toString() ?? '',
        reference: json['reference']?.toString() ?? '',
        termLabel: json['termLabel']?.toString() ?? '',
        submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? ''),
      );
}

/// New student (1) or transferring in from another school (3). An old student enrols from inside
/// the portal instead, so 2 is deliberately not offered here.
class ApplicantKinds {
  static const newStudent = 1;
  static const transferee = 3;
}
