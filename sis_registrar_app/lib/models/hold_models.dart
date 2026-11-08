/// Something that stops a student from enrolling online until the Registrar removes it.
class EnrollmentHold {
  final String holdId;
  final String reason;
  final String reasonLabel;
  final String? note;
  final DateTime? addedAt;
  final String? addedByName;
  final DateTime? removedAt;
  final String? removedByName;
  final String? removalNote;
  final bool isOpen;

  const EnrollmentHold({
    required this.holdId,
    required this.reason,
    required this.reasonLabel,
    this.note,
    this.addedAt,
    this.addedByName,
    this.removedAt,
    this.removedByName,
    this.removalNote,
    required this.isOpen,
  });

  factory EnrollmentHold.fromJson(Map<String, dynamic> j) => EnrollmentHold(
        holdId: j['holdId'] as String? ?? '',
        reason: j['reason'] as String? ?? '',
        reasonLabel: j['reasonLabel'] as String? ?? '',
        note: j['note'] as String?,
        addedAt: DateTime.tryParse(j['addedAt'] as String? ?? ''),
        addedByName: j['addedByName'] as String?,
        removedAt: DateTime.tryParse(j['removedAt'] as String? ?? ''),
        removedByName: j['removedByName'] as String?,
        removalNote: j['removalNote'] as String?,
        isOpen: j['isOpen'] as bool? ?? false,
      );
}

class EnrollmentHoldReasons {
  static const unpaidBalance = 'UnpaidBalance';
  static const other = 'Other';
}
