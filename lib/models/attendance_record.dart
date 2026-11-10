class AttendanceRecord {
  final DateTime checkIn;
  final DateTime? checkOut;
  final String? employeeId;
  final String? companyCode;

  AttendanceRecord({
    required DateTime checkIn,
    DateTime? checkOut,
    this.employeeId,
    this.companyCode,
  }) : checkIn = DateTime(checkIn.year, checkIn.month, checkIn.day, checkIn.hour, checkIn.minute),
       checkOut = checkOut != null ? DateTime(checkOut.year, checkOut.month, checkOut.day, checkOut.hour, checkOut.minute) : null;

  bool get isCompleted => checkOut != null;

  Duration get duration {
    final tIn = DateTime(checkIn.year, checkIn.month, checkIn.day, checkIn.hour, checkIn.minute);
    if (checkOut == null) {
      final now = DateTime.now();
      final isSameDay = now.year == checkIn.year && now.month == checkIn.month && now.day == checkIn.day;
      if (!isSameDay || now.difference(tIn).inHours.abs() >= 24) {
        return Duration.zero;
      }
      final tNow = DateTime(now.year, now.month, now.day, now.hour, now.minute);
      return tNow.difference(tIn);
    }
    final tOut = DateTime(checkOut!.year, checkOut!.month, checkOut!.day, checkOut!.hour, checkOut!.minute);
    return tOut.difference(tIn);
  }

  String get durationString {
    final dur = duration;
    final hours = dur.inHours;
    final minutes = dur.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  AttendanceRecord copyWith({
    DateTime? checkIn,
    DateTime? checkOut,
    String? employeeId,
    String? companyCode,
  }) {
    return AttendanceRecord(
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      employeeId: employeeId ?? this.employeeId,
      companyCode: companyCode ?? this.companyCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'checkIn': checkIn.toIso8601String(),
      'checkOut': checkOut?.toIso8601String(),
      'employeeId': employeeId,
      'companyCode': companyCode,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map, [String? employeeId, String? companyCode]) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val == null) return fallback;
      if (val is DateTime) return val;
      try {
        // Handle Cloud Firestore Timestamp
        return (val as dynamic).toDate();
      } catch (_) {}
      if (val is int) {
        return DateTime.fromMillisecondsSinceEpoch(val);
      }
      final s = val.toString().trim();
      if (s.isEmpty) return fallback;
      return DateTime.tryParse(s) ?? fallback;
    }

    DateTime? parseDateNullable(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      try {
        return (val as dynamic).toDate();
      } catch (_) {}
      if (val is int) {
        return DateTime.fromMillisecondsSinceEpoch(val);
      }
      final s = val.toString().trim();
      if (s.isEmpty || s == 'null') return null;
      return DateTime.tryParse(s);
    }

    final parsedIn = parseDate(map['checkIn'], DateTime.now());
    final parsedOut = parseDateNullable(map['checkOut']);

    final empId = (map['employeeId'] != null && map['employeeId'].toString().isNotEmpty)
        ? map['employeeId'].toString()
        : employeeId;
    final compCode = (map['companyCode'] != null && map['companyCode'].toString().isNotEmpty)
        ? map['companyCode'].toString()
        : companyCode;
    return AttendanceRecord(
      checkIn: parsedIn,
      checkOut: parsedOut,
      employeeId: empId,
      companyCode: compCode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttendanceRecord &&
        other.checkIn == checkIn &&
        other.checkOut == checkOut &&
        other.employeeId == employeeId &&
        other.companyCode == companyCode;
  }

  @override
  int get hashCode => Object.hash(checkIn, checkOut, employeeId, companyCode);
}
