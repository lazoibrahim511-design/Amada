class CompanyLicense {
  final String companyId;
  final String companyCode;
  final String companyName;
  final bool isActive;
  final String planName;
  final int maxActiveUsers;
  final DateTime subscriptionStartDate;
  final DateTime subscriptionExpiresAt;
  final int gracePeriodDays;
  final String? ownerEmail;
  final String? ownerPhone;
  final String? address;
  final String? logoBase64;
  final String? notes;

  CompanyLicense({
    required this.companyId,
    required this.companyCode,
    required this.companyName,
    this.isActive = true,
    this.planName = 'Standard',
    this.maxActiveUsers = 50,
    required this.subscriptionStartDate,
    required this.subscriptionExpiresAt,
    this.gracePeriodDays = 7,
    this.ownerEmail,
    this.ownerPhone,
    this.address,
    this.logoBase64,
    this.notes,
  });

  bool get isExpired => DateTime.now().isAfter(subscriptionExpiresAt);

  bool get isInGracePeriod =>
      isExpired &&
      DateTime.now().isBefore(
        subscriptionExpiresAt.add(Duration(days: gracePeriodDays)),
      );

  /// Hard-locked when explicitly deactivated or when expired past grace period
  bool get isHardLocked => !isActive || (isExpired && !isInGracePeriod);

  int get daysRemaining {
    final diff = subscriptionExpiresAt.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'companyCode': companyCode.trim().toLowerCase(),
      'companyName': companyName,
      'isActive': isActive,
      'planName': planName,
      'maxActiveUsers': maxActiveUsers,
      'subscriptionStartDate': subscriptionStartDate.toIso8601String(),
      'subscriptionExpiresAt': subscriptionExpiresAt.toIso8601String(),
      'gracePeriodDays': gracePeriodDays,
      'ownerEmail': ownerEmail,
      'ownerPhone': ownerPhone,
      'address': address,
      'logoBase64': logoBase64,
      'notes': notes,
    };
  }

  factory CompanyLicense.fromMap(Map<String, dynamic> map, [String? docId]) {
    final cId = (map['companyId'] ?? docId ?? 'default').toString();
    final code = (map['companyCode'] ?? cId).toString().trim().toLowerCase();
    return CompanyLicense(
      companyId: cId,
      companyCode: code.isEmpty ? cId : code,
      companyName: (map['companyName'] ?? 'Company').toString(),
      isActive: map['isActive'] == null ? true : map['isActive'] as bool,
      planName: (map['planName'] ?? 'Standard').toString(),
      maxActiveUsers: map['maxActiveUsers'] is int
          ? map['maxActiveUsers'] as int
          : int.tryParse(map['maxActiveUsers']?.toString() ?? '50') ?? 50,
      subscriptionStartDate: map['subscriptionStartDate'] != null
          ? DateTime.tryParse(map['subscriptionStartDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      subscriptionExpiresAt: map['subscriptionExpiresAt'] != null
          ? DateTime.tryParse(map['subscriptionExpiresAt'].toString()) ??
              DateTime.now().add(const Duration(days: 365))
          : DateTime.now().add(const Duration(days: 365)),
      gracePeriodDays: map['gracePeriodDays'] is int
          ? map['gracePeriodDays'] as int
          : int.tryParse(map['gracePeriodDays']?.toString() ?? '7') ?? 7,
      ownerEmail: map['ownerEmail']?.toString(),
      ownerPhone: map['ownerPhone']?.toString(),
      address: map['address']?.toString(),
      logoBase64: map['logoBase64']?.toString(),
      notes: map['notes']?.toString(),
    );
  }

  CompanyLicense copyWith({
    String? companyId,
    String? companyCode,
    String? companyName,
    bool? isActive,
    String? planName,
    int? maxActiveUsers,
    DateTime? subscriptionStartDate,
    DateTime? subscriptionExpiresAt,
    int? gracePeriodDays,
    String? ownerEmail,
    String? ownerPhone,
    String? address,
    String? logoBase64,
    bool overrideLogo = false,
    String? notes,
  }) {
    return CompanyLicense(
      companyId: companyId ?? this.companyId,
      companyCode: companyCode ?? this.companyCode,
      companyName: companyName ?? this.companyName,
      isActive: isActive ?? this.isActive,
      planName: planName ?? this.planName,
      maxActiveUsers: maxActiveUsers ?? this.maxActiveUsers,
      subscriptionStartDate: subscriptionStartDate ?? this.subscriptionStartDate,
      subscriptionExpiresAt: subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      address: address ?? this.address,
      logoBase64: overrideLogo ? logoBase64 : (logoBase64 ?? this.logoBase64),
      notes: notes ?? this.notes,
    );
  }

  /// Default fallback license for demo or seed company mode
  static CompanyLicense defaultLicense({
    String code = 'amada',
    String name = 'Amada Trading',
    int maxUsers = 50,
  }) {
    return CompanyLicense(
      companyId: code,
      companyCode: code,
      companyName: name,
      isActive: true,
      planName: 'Enterprise',
      maxActiveUsers: maxUsers,
      subscriptionStartDate: DateTime.now().subtract(const Duration(days: 30)),
      subscriptionExpiresAt: DateTime.now().add(const Duration(days: 365)),
      gracePeriodDays: 7,
    );
  }
}
