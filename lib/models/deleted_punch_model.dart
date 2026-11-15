class DeletedPunch {
  final String id;
  final String employeeId;
  final String? employeeName;
  final String? companyCode;
  final DateTime punchTime;
  final String punchType; // 'checkIn', 'checkOut', 'raw', or 'session'
  final String? reason;
  final DateTime deletedAt;
  final String? deletedBy;

  DeletedPunch({
    required this.id,
    required this.employeeId,
    this.employeeName,
    this.companyCode,
    required this.punchTime,
    this.punchType = 'raw',
    this.reason,
    DateTime? deletedAt,
    this.deletedBy,
  }) : deletedAt = deletedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'companyCode': companyCode,
      'punchTime': punchTime.toIso8601String(),
      'punchType': punchType,
      'reason': reason,
      'deletedAt': deletedAt.toIso8601String(),
      'deletedBy': deletedBy,
    };
  }

  factory DeletedPunch.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val == null) return fallback;
      if (val is DateTime) return val;
      try {
        return (val as dynamic).toDate();
      } catch (_) {}
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      final s = val.toString().trim();
      return DateTime.tryParse(s) ?? fallback;
    }

    return DeletedPunch(
      id: docId ?? map['id']?.toString() ?? '',
      employeeId: map['employeeId']?.toString() ?? '',
      employeeName: map['employeeName']?.toString(),
      companyCode: map['companyCode']?.toString(),
      punchTime: parseDate(map['punchTime'], DateTime.now()),
      punchType: map['punchType']?.toString() ?? 'raw',
      reason: map['reason']?.toString(),
      deletedAt: parseDate(map['deletedAt'], DateTime.now()),
      deletedBy: map['deletedBy']?.toString(),
    );
  }
}
