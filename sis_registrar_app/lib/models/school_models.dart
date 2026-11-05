/// A school DBTC accepts credits from.
class AccreditedSchool {
  final String schoolId;
  final String name;
  final String? address;

  /// How many credited subjects name this school.
  final int creditCount;

  const AccreditedSchool({required this.schoolId, required this.name, this.address, this.creditCount = 0});

  factory AccreditedSchool.fromJson(Map<String, dynamic> j) => AccreditedSchool(
        schoolId: j['schoolId']?.toString() ?? '',
        name: j['name'] as String? ?? '',
        address: j['address'] as String?,
        creditCount: (j['creditCount'] as num?)?.toInt() ?? 0,
      );
}

/// A school name typed on credits that is not on the accredited list yet.
class UnlistedSchool {
  final String name;
  final int creditCount;

  const UnlistedSchool({required this.name, this.creditCount = 0});

  factory UnlistedSchool.fromJson(Map<String, dynamic> j) =>
      UnlistedSchool(name: j['name'] as String? ?? '', creditCount: (j['creditCount'] as num?)?.toInt() ?? 0);
}
