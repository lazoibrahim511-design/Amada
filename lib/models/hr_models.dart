/// Resolves tenant companyCode safely with 100% backward compatibility for legacy Amada documents.
String resolveCompanyCode(Map<String, dynamic> map, String docId, {String fallback = 'amada'}) {
  final explicit = map['companyCode']?.toString().trim().toLowerCase();
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }

  final cleanDocId = docId.trim().toLowerCase();
  if (cleanDocId.startsWith('amada_')) {
    return 'amada';
  }
  if (cleanDocId.startsWith('lazo_')) {
    return 'lazo';
  }

  // All legacy Firestore documents created prior to multi-tenancy belong to Amada
  return fallback;
}

class OrgStructure {
  final String id;
  final String name;
  final String location;
  final int capacity;
  final String? parentId;
  final String? supervisorId;
  final double? latitude;
  final double? longitude;
  final double? radius;
  final String companyCode;

  OrgStructure({
    required this.id,
    required this.name,
    required this.location,
    required this.capacity,
    this.parentId,
    this.supervisorId,
    this.latitude,
    this.longitude,
    this.radius,
    this.companyCode = '',
  });

  OrgStructure copyWith({
    String? id,
    String? name,
    String? location,
    int? capacity,
    String? parentId,
    bool overrideParentId = false,
    String? supervisorId,
    bool overrideSupervisorId = false,
    double? latitude,
    bool overrideLatitude = false,
    double? longitude,
    bool overrideLongitude = false,
    double? radius,
    bool overrideRadius = false,
    String? companyCode,
  }) {
    return OrgStructure(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      capacity: capacity ?? this.capacity,
      parentId: overrideParentId ? parentId : (parentId ?? this.parentId),
      supervisorId: overrideSupervisorId ? supervisorId : (supervisorId ?? this.supervisorId),
      latitude: overrideLatitude ? latitude : (latitude ?? this.latitude),
      longitude: overrideLongitude ? longitude : (longitude ?? this.longitude),
      radius: overrideRadius ? radius : (radius ?? this.radius),
      companyCode: companyCode ?? this.companyCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'capacity': capacity,
      'parentId': parentId,
      'supervisorId': supervisorId,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'companyCode': companyCode.trim().toLowerCase(),
    };
  }

  factory OrgStructure.fromMap(Map<String, dynamic> map, String docId) {
    return OrgStructure(
      id: map['id'] ?? docId,
      name: map['name'] ?? '',
      location: map['location'] ?? '',
      capacity: (map['capacity'] as num?)?.toInt() ?? 0,
      parentId: map['parentId'],
      supervisorId: map['supervisorId'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      radius: (map['radius'] as num?)?.toDouble(),
      companyCode: resolveCompanyCode(map, docId),
    );
  }
}

class SalaryHistoryEntry {
  final double basicSalary;
  final double workingHours;
  final String currency; // 'USD' or 'IQD'
  final String startDate; // 'yyyy-MM-dd'
  final String? endDate; // 'yyyy-MM-dd' or null
  final double foodAllowance;
  final double transportationAllowance;
  final double otherAllowance;
  final bool hasInsurance;
  final double insuranceSalary;

  SalaryHistoryEntry({
    required this.basicSalary,
    required this.workingHours,
    required this.currency,
    required this.startDate,
    this.endDate,
    this.foodAllowance = 0.0,
    this.transportationAllowance = 0.0,
    this.otherAllowance = 0.0,
    this.hasInsurance = false,
    this.insuranceSalary = 0.0,
  });

  SalaryHistoryEntry copyWith({
    double? basicSalary,
    double? workingHours,
    String? currency,
    String? startDate,
    String? endDate,
    bool overrideEndDate = false,
    double? foodAllowance,
    double? transportationAllowance,
    double? otherAllowance,
    bool? hasInsurance,
    double? insuranceSalary,
  }) {
    return SalaryHistoryEntry(
      basicSalary: basicSalary ?? this.basicSalary,
      workingHours: workingHours ?? this.workingHours,
      currency: currency ?? this.currency,
      startDate: startDate ?? this.startDate,
      endDate: overrideEndDate ? endDate : (endDate ?? this.endDate),
      foodAllowance: foodAllowance ?? this.foodAllowance,
      transportationAllowance: transportationAllowance ?? this.transportationAllowance,
      otherAllowance: otherAllowance ?? this.otherAllowance,
      hasInsurance: hasInsurance ?? this.hasInsurance,
      insuranceSalary: insuranceSalary ?? this.insuranceSalary,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'basicSalary': basicSalary,
      'workingHours': workingHours,
      'currency': currency,
      'startDate': startDate,
      'endDate': endDate,
      'foodAllowance': foodAllowance,
      'transportationAllowance': transportationAllowance,
      'otherAllowance': otherAllowance,
      'hasInsurance': hasInsurance,
      'insuranceSalary': insuranceSalary,
    };
  }

  factory SalaryHistoryEntry.fromMap(Map<String, dynamic> map) {
    return SalaryHistoryEntry(
      basicSalary: (map['basicSalary'] as num?)?.toDouble() ?? 0.0,
      workingHours: (map['workingHours'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'USD',
      startDate: map['startDate'] ?? '',
      endDate: map['endDate'],
      foodAllowance: (map['foodAllowance'] as num?)?.toDouble() ?? 0.0,
      transportationAllowance: (map['transportationAllowance'] as num?)?.toDouble() ?? 0.0,
      otherAllowance: (map['otherAllowance'] as num?)?.toDouble() ?? 0.0,
      hasInsurance: map['hasInsurance'] as bool? ?? false,
      insuranceSalary: (map['insuranceSalary'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DayShiftConfig {
  final bool isWorkingDay;
  final String startTime;
  final String endTime;
  final String breakStart;
  final String breakEnd;
  final int breakDurationMinutes;
  final bool isOvernight;
  final String crossMidnightCutoff; // "HH:mm" e.g., "03:00"
  final bool isSpecialShift;

  DayShiftConfig({
    required this.isWorkingDay,
    this.startTime = '09:00',
    this.endTime = '17:00',
    this.breakStart = '',
    this.breakEnd = '',
    this.breakDurationMinutes = 0,
    this.isOvernight = false,
    this.crossMidnightCutoff = '',
    this.isSpecialShift = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'isWorkingDay': isWorkingDay,
      'startTime': startTime,
      'endTime': endTime,
      'breakStart': breakStart,
      'breakEnd': breakEnd,
      'breakDurationMinutes': breakDurationMinutes,
      'isOvernight': isOvernight,
      'crossMidnightCutoff': crossMidnightCutoff,
      'isSpecialShift': isSpecialShift,
    };
  }

  factory DayShiftConfig.fromMap(Map<String, dynamic> map) {
    final start = map['startTime'] ?? '09:00';
    final end = map['endTime'] ?? '17:00';
    final autoOvernight = WorkShift.isTimeCrossMidnight(start, end);
    return DayShiftConfig(
      isWorkingDay: map['isWorkingDay'] ?? true,
      startTime: start,
      endTime: end,
      breakStart: map['breakStart'] ?? '',
      breakEnd: map['breakEnd'] ?? '',
      breakDurationMinutes: (map['breakDurationMinutes'] as num?)?.toInt() ?? 0,
      isOvernight: map['isOvernight'] ?? autoOvernight,
      crossMidnightCutoff: map['crossMidnightCutoff'] ?? '',
      isSpecialShift: map['isSpecialShift'] ?? (map['shiftType'] == 'special'),
    );
  }
}

class WorkShift {
  final String id;
  final String name;
  final String startTime; // "HH:mm" e.g., "09:00" (Fallback for non-rotation)
  final String endTime;   // "HH:mm" e.g., "17:00" (Fallback for non-rotation)
  final int forgivenessOfDelay; // in minutes, e.g. 15
  final int earlyExit;          // in minutes, e.g. 10
  final String breakStart; // "HH:mm" e.g., "12:00"
  final String breakEnd;   // "HH:mm" e.g., "14:00"
  final int breakDurationMinutes; // duration in minutes, e.g. 60
  final List<int> workingDays; // list of weekdays, e.g. [1, 2, 3, 4, 5] (Fallback for non-rotation)
  
  final bool isRotation;
  final int rotationDays; // Number of days in the rotation cycle (e.g. 3, 4, 7). Defaults to 7.
  final String rotationStartDate; // Anchor start date 'yyyy-MM-dd' for Day 1 of rotation.
  final Map<int, DayShiftConfig> rotationSchedule; // 1 to rotationDays
  final bool isOvernight;
  final String crossMidnightCutoff; // "HH:mm" e.g., "03:00" (Checkouts up to this cutoff calculate to previous date)
  final bool isSpecialShift; // Special shift: pairs 2nd punch (even on next day) as clock-out and credits to start day
  final String companyCode;

  WorkShift({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.forgivenessOfDelay = 0,
    this.earlyExit = 0,
    this.breakStart = '',
    this.breakEnd = '',
    this.breakDurationMinutes = 0,
    this.workingDays = const [1, 2, 3, 4, 5],
    this.isRotation = false,
    int? rotationDays,
    this.rotationStartDate = '',
    Map<int, DayShiftConfig>? rotationSchedule,
    Map<int, DayShiftConfig>? weeklySchedule,
    this.isOvernight = false,
    this.crossMidnightCutoff = '',
    this.isSpecialShift = false,
    this.companyCode = '',
  })  : rotationDays = rotationDays ?? (rotationSchedule?.length ?? (weeklySchedule?.length ?? 7)),
        rotationSchedule = rotationSchedule ?? weeklySchedule ?? const {};

  // Alias for backward compatibility
  Map<int, DayShiftConfig> get weeklySchedule => rotationSchedule;

  static bool isTimeCrossMidnight(String start, String end) {
    final sParts = start.trim().split(':');
    final eParts = end.trim().split(':');
    if (sParts.length >= 2 && eParts.length >= 2) {
      final sMins = (int.tryParse(sParts[0]) ?? 0) * 60 + (int.tryParse(sParts[1]) ?? 0);
      final eMins = (int.tryParse(eParts[0]) ?? 0) * 60 + (int.tryParse(eParts[1]) ?? 0);
      return eMins <= sMins; // <= catches 24-hour shifts like 08:00 to 08:00 next day
    }
    return false;
  }

  /// Calculates a sensible default cutoff time (1.5h after shift end).
  static String calculateDefaultCutoff(String endStr) {
    final eParts = endStr.trim().split(':');
    if (eParts.length >= 2) {
      final eH = int.tryParse(eParts[0]) ?? 8;
      final eM = int.tryParse(eParts[1]) ?? 0;
      final cutoffMins = eH * 60 + eM + 90;
      final cH = (cutoffMins ~/ 60) % 24;
      final cM = cutoffMins % 60;
      return '${cH.toString().padLeft(2, '0')}:${cM.toString().padLeft(2, '0')}';
    }
    return '03:00';
  }

  /// Calculates which day (1 to rotationDays) of the rotation cycle a given calendar date falls on.
  int getRotationDayForDate(DateTime date) {
    if (!isRotation || rotationDays <= 0) return 1;

    // Backwards compatibility: if rotationDays is 7 and rotationStartDate is empty, use weekday (1=Mon..7=Sun)
    if (rotationDays == 7 && rotationStartDate.isEmpty) {
      return date.weekday;
    }

    DateTime baseDate;
    if (rotationStartDate.isNotEmpty) {
      try {
        baseDate = DateTime.parse(rotationStartDate);
      } catch (_) {
        baseDate = DateTime(2026, 1, 1);
      }
    } else {
      baseDate = DateTime(2026, 1, 1);
    }

    final dateOnly = DateTime(date.year, date.month, date.day);
    final baseOnly = DateTime(baseDate.year, baseDate.month, baseDate.day);
    final diff = dateOnly.difference(baseOnly).inDays;
    final mod = ((diff % rotationDays) + rotationDays) % rotationDays;
    return mod + 1; // 1-indexed (1 .. rotationDays)
  }

  /// Returns the DayShiftConfig for a given date in the rotation schedule.
  DayShiftConfig? getConfigForDate(DateTime date) {
    if (!isRotation) return null;
    final dayNum = getRotationDayForDate(date);
    return rotationSchedule[dayNum] ?? weeklySchedule[dayNum];
  }

  bool isSpecialShiftForDate(DateTime date) {
    if (isSpecialShift) {
      if (!isRotation) return true;
      final config = getConfigForDate(date);
      return config == null || config.isWorkingDay;
    }
    if (isRotation) {
      final config = getConfigForDate(date);
      if (config != null && config.isSpecialShift) return true;
      if (config != null && config.isWorkingDay && isTimeCrossMidnight(config.startTime, config.endTime)) {
        if (config.startTime == config.endTime) return true;
      }
    }
    return false;
  }

  bool isOvernightForDate(DateTime date) {
    if (isRotation) {
      final config = getConfigForDate(date);
      if (config != null) {
        return config.isOvernight || isTimeCrossMidnight(config.startTime, config.endTime);
      }
    }
    return isOvernight || isTimeCrossMidnight(startTime, endTime);
  }

  String getCrossMidnightCutoffForDate(DateTime date) {
    if (isRotation) {
      final config = getConfigForDate(date);
      if (config != null && config.crossMidnightCutoff.isNotEmpty) {
        return config.crossMidnightCutoff;
      }
    }
    if (crossMidnightCutoff.isNotEmpty) {
      return crossMidnightCutoff;
    }
    final endStr = getEndTimeForDate(date);
    return calculateDefaultCutoff(endStr);
  }

  bool isWorkingDay(DateTime date) {
    if (!isRotation) {
      return workingDays.contains(date.weekday);
    }
    final config = getConfigForDate(date);
    return config?.isWorkingDay ?? false;
  }

  String getStartTimeForDate(DateTime date) {
    if (!isRotation) return startTime;
    final config = getConfigForDate(date);
    return config?.startTime ?? '00:00';
  }

  String getEndTimeForDate(DateTime date) {
    if (!isRotation) {
      return endTime;
    }
    final config = getConfigForDate(date);
    return config?.endTime ?? endTime;
  }

  String getBreakStartForDate(DateTime date) {
    if (!isRotation) {
      return breakStart;
    }
    final config = getConfigForDate(date);
    return config?.breakStart ?? breakStart;
  }

  String getBreakEndForDate(DateTime date) {
    if (!isRotation) {
      return breakEnd;
    }
    final config = getConfigForDate(date);
    return config?.breakEnd ?? breakEnd;
  }

  int getBreakDurationForDate(DateTime date) {
    if (!isRotation) {
      return breakDurationMinutes;
    }
    final config = getConfigForDate(date);
    return config?.breakDurationMinutes ?? breakDurationMinutes;
  }

  /// Returns shift duration in minutes for a given date, accurately handling overnight and 24h shifts (e.g. 08:00 to 08:00 = 1440 mins).
  int getShiftDurationMinutesForDate(DateTime date) {
    final sStr = getStartTimeForDate(date);
    final eStr = getEndTimeForDate(date);
    final sParts = sStr.trim().split(':');
    final eParts = eStr.trim().split(':');
    if (sParts.length < 2 || eParts.length < 2) return 480;

    final sMins = (int.tryParse(sParts[0]) ?? 0) * 60 + (int.tryParse(sParts[1]) ?? 0);
    final eMins = (int.tryParse(eParts[0]) ?? 0) * 60 + (int.tryParse(eParts[1]) ?? 0);

    if (eMins < sMins) {
      return (24 * 60) - sMins + eMins;
    } else if (eMins == sMins) {
      return 24 * 60;
    }
    return eMins - sMins;
  }

  WorkShift copyWith({
    String? id,
    String? name,
    String? startTime,
    String? endTime,
    int? forgivenessOfDelay,
    int? earlyExit,
    String? breakStart,
    String? breakEnd,
    int? breakDurationMinutes,
    List<int>? workingDays,
    bool? isRotation,
    int? rotationDays,
    String? rotationStartDate,
    Map<int, DayShiftConfig>? rotationSchedule,
    Map<int, DayShiftConfig>? weeklySchedule,
    bool? isOvernight,
    String? crossMidnightCutoff,
    bool? isSpecialShift,
    String? companyCode,
  }) {
    return WorkShift(
      id: id ?? this.id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      forgivenessOfDelay: forgivenessOfDelay ?? this.forgivenessOfDelay,
      earlyExit: earlyExit ?? this.earlyExit,
      breakStart: breakStart ?? this.breakStart,
      breakEnd: breakEnd ?? this.breakEnd,
      breakDurationMinutes: breakDurationMinutes ?? this.breakDurationMinutes,
      workingDays: workingDays ?? this.workingDays,
      isRotation: isRotation ?? this.isRotation,
      rotationDays: rotationDays ?? this.rotationDays,
      rotationStartDate: rotationStartDate ?? this.rotationStartDate,
      rotationSchedule: rotationSchedule ?? weeklySchedule ?? this.rotationSchedule,
      weeklySchedule: weeklySchedule ?? rotationSchedule ?? this.weeklySchedule,
      isOvernight: isOvernight ?? this.isOvernight,
      crossMidnightCutoff: crossMidnightCutoff ?? this.crossMidnightCutoff,
      isSpecialShift: isSpecialShift ?? this.isSpecialShift,
      companyCode: companyCode ?? this.companyCode,
    );
  }

  Map<String, dynamic> toMap() {
    final scheduleMap = rotationSchedule.map((key, value) => MapEntry(key.toString(), value.toMap()));
    return {
      'id': id,
      'name': name,
      'startTime': startTime,
      'endTime': endTime,
      'forgivenessOfDelay': forgivenessOfDelay,
      'earlyExit': earlyExit,
      'breakStart': breakStart,
      'breakEnd': breakEnd,
      'breakDurationMinutes': breakDurationMinutes,
      'workingDays': workingDays,
      'isRotation': isRotation,
      'rotationDays': rotationDays,
      'rotationStartDate': rotationStartDate,
      'rotationSchedule': scheduleMap,
      'weeklySchedule': scheduleMap,
      'isOvernight': isOvernight,
      'crossMidnightCutoff': crossMidnightCutoff,
      'isSpecialShift': isSpecialShift,
      'companyCode': companyCode.trim().toLowerCase(),
    };
  }

  factory WorkShift.fromMap(Map<String, dynamic> map, String docId) {
    Map<int, DayShiftConfig> parsedSchedule = {};
    if (map['rotationSchedule'] != null) {
      final rsMap = map['rotationSchedule'] as Map<String, dynamic>;
      rsMap.forEach((key, value) {
        parsedSchedule[int.parse(key)] = DayShiftConfig.fromMap(Map<String, dynamic>.from(value));
      });
    } else if (map['weeklySchedule'] != null) {
      final wsMap = map['weeklySchedule'] as Map<String, dynamic>;
      wsMap.forEach((key, value) {
        parsedSchedule[int.parse(key)] = DayShiftConfig.fromMap(Map<String, dynamic>.from(value));
      });
    }

    final start = map['startTime'] ?? '';
    final end = map['endTime'] ?? '';
    final autoOvernight = isTimeCrossMidnight(start, end);
    final rotDays = (map['rotationDays'] as num?)?.toInt() ?? (parsedSchedule.isNotEmpty ? parsedSchedule.length : 7);

    final cCode = resolveCompanyCode(map, docId);

    return WorkShift(
      id: map['id'] ?? docId,
      name: map['name'] ?? '',
      startTime: start,
      endTime: end,
      forgivenessOfDelay: (map['forgivenessOfDelay'] as num?)?.toInt() ?? 0,
      earlyExit: (map['earlyExit'] as num?)?.toInt() ?? 0,
      breakStart: map['breakStart'] ?? '',
      breakEnd: map['breakEnd'] ?? '',
      breakDurationMinutes: (map['breakDurationMinutes'] as num?)?.toInt() ?? 0,
      workingDays: List<int>.from(map['workingDays'] ?? [1, 2, 3, 4, 5]),
      isRotation: map['isRotation'] ?? false,
      rotationDays: rotDays,
      rotationStartDate: map['rotationStartDate'] ?? '',
      rotationSchedule: parsedSchedule,
      weeklySchedule: parsedSchedule,
      isOvernight: map['isOvernight'] ?? autoOvernight,
      crossMidnightCutoff: map['crossMidnightCutoff'] ?? '',
      isSpecialShift: map['isSpecialShift'] ?? (map['shiftType'] == 'special'),
      companyCode: cCode,
    );
  }
}

class EmployeeGroup {
  final String id;
  final String name;
  final String shiftId; // Refers to WorkShift
  
  // Permissions
  final bool canEditCompanyInfo;
  
  // Annual Leave Config
  final String annualLeaveAdditionType; // 'None', 'Monthly', 'Yearly'
  final double annualLeaveAdditionHours;
  
  // Missed Punch Limit
  final int missedPunchLimitPerMonth;
  
  // Annual Leave Request Deadline
  final int annualLeaveRequestDeadlineDays;
  
  // Annual Leave Form Rules
  final int annualLeaveMinNoticeDays;
  final int annualLeaveMaxRequestsPerPeriod;
  final String annualLeavePeriodType; // 'Month' or 'Year'
  
  // Hourly Leave Form Rules
  final int hourlyLeaveMinHours;
  final int hourlyLeaveMinMinutes;
  final int hourlyLeaveMaxHours;
  final int hourlyLeaveMaxMinutes;

  int get totalHourlyLeaveMinMinutes => hourlyLeaveMinHours * 60 + hourlyLeaveMinMinutes;
  int get totalHourlyLeaveMaxMinutes => hourlyLeaveMaxHours * 60 + hourlyLeaveMaxMinutes;
  String get hourlyLeaveMinDurationFormatted =>
      (hourlyLeaveMinHours > 0 || hourlyLeaveMinMinutes > 0)
          ? '${hourlyLeaveMinHours.toString().padLeft(2, '0')}:${hourlyLeaveMinMinutes.toString().padLeft(2, '0')}'
          : '';
  String get hourlyLeaveMaxDurationFormatted =>
      (hourlyLeaveMaxHours > 0 || hourlyLeaveMaxMinutes > 0)
          ? '${hourlyLeaveMaxHours.toString().padLeft(2, '0')}:${hourlyLeaveMaxMinutes.toString().padLeft(2, '0')}'
          : '';
  
  // Specific rules
  final bool overtimeAllowed;
  final int minOvertimeMinutes;
  final int maxOvertimeMinutes;
  final double holidayOvertimeRatio;
  final double weekendOvertimeRatio;
  final bool nightOvertimeAllowed;
  final String nightOvertimeStart;
  final String nightOvertimeEnd;
  final double nightOvertimeRatio;

  // Penalty switches
  final bool delayPenaltiesEnabled;
  final bool earlyExitPenaltiesEnabled;

  // Delay penalty rules
  final int delayTier1Min;
  final int delayTier1Max;
  final double delayTier1Penalty;
  final int delayTier1Forgiveness;
  final int delayTier2Min;
  final int delayTier2Max;
  final double delayTier2Penalty;
  final int delayTier2Forgiveness;
  final int delayTier3Min;
  final double delayTier3Penalty;
  final int delayTier3Forgiveness;

  // Early exit penalty rules
  final int earlyExitTier1Min;
  final int earlyExitTier1Max;
  final double earlyExitTier1Penalty;
  final int earlyExitTier1Forgiveness;
  final int earlyExitTier2Min;
  final int earlyExitTier2Max;
  final double earlyExitTier2Penalty;
  final int earlyExitTier2Forgiveness;
  final int earlyExitTier3Min;
  final double earlyExitTier3Penalty;
  final int earlyExitTier3Forgiveness;

  EmployeeGroup({
    required this.id,
    required this.name,
    required this.shiftId,
    this.annualLeaveAdditionType = 'None',
    this.annualLeaveAdditionHours = 0.0,
    this.missedPunchLimitPerMonth = 3,
    this.annualLeaveRequestDeadlineDays = 0,
    this.annualLeaveMinNoticeDays = 0,
    this.annualLeaveMaxRequestsPerPeriod = 0,
    this.annualLeavePeriodType = 'Month',
    this.hourlyLeaveMinHours = 0,
    this.hourlyLeaveMinMinutes = 0,
    this.hourlyLeaveMaxHours = 0,
    this.hourlyLeaveMaxMinutes = 0,
    this.overtimeAllowed = false,
    this.minOvertimeMinutes = 0,
    this.maxOvertimeMinutes = 0,
    this.holidayOvertimeRatio = 1.5,
    this.weekendOvertimeRatio = 1.5,
    this.nightOvertimeAllowed = false,
    this.nightOvertimeStart = '22:00',
    this.nightOvertimeEnd = '06:00',
    this.nightOvertimeRatio = 1.5,
    this.delayPenaltiesEnabled = true,
    this.earlyExitPenaltiesEnabled = true,
    this.delayTier1Min = 0,
    this.delayTier1Max = 0,
    this.delayTier1Penalty = 0.0,
    this.delayTier1Forgiveness = 0,
    this.delayTier2Min = 0,
    this.delayTier2Max = 0,
    this.delayTier2Penalty = 0.0,
    this.delayTier2Forgiveness = 0,
    this.delayTier3Min = 0,
    this.delayTier3Penalty = 0.0,
    this.delayTier3Forgiveness = 0,
    this.earlyExitTier1Min = 0,
    this.earlyExitTier1Max = 0,
    this.earlyExitTier1Penalty = 0.0,
    this.earlyExitTier1Forgiveness = 0,
    this.earlyExitTier2Min = 0,
    this.earlyExitTier2Max = 0,
    this.earlyExitTier2Penalty = 0.0,
    this.earlyExitTier2Forgiveness = 0,
    this.earlyExitTier3Min = 0,
    this.earlyExitTier3Penalty = 0.0,
    this.earlyExitTier3Forgiveness = 0,
    this.canEditCompanyInfo = false,
    this.companyCode = '',
  });

  final String companyCode;

  EmployeeGroup copyWith({
    String? id,
    String? name,
    String? shiftId,
    bool? canEditCompanyInfo,
    String? annualLeaveAdditionType,
    double? annualLeaveAdditionHours,
    int? missedPunchLimitPerMonth,
    int? annualLeaveRequestDeadlineDays,
    int? annualLeaveMinNoticeDays,
    int? annualLeaveMaxRequestsPerPeriod,
    String? annualLeavePeriodType,
    int? hourlyLeaveMinHours,
    int? hourlyLeaveMinMinutes,
    int? hourlyLeaveMaxHours,
    int? hourlyLeaveMaxMinutes,
    bool? overtimeAllowed,
    int? minOvertimeMinutes,
    int? maxOvertimeMinutes,
    double? holidayOvertimeRatio,
    double? weekendOvertimeRatio,
    bool? nightOvertimeAllowed,
    String? nightOvertimeStart,
    String? nightOvertimeEnd,
    double? nightOvertimeRatio,
    bool? delayPenaltiesEnabled,
    bool? earlyExitPenaltiesEnabled,
    int? delayTier1Min,
    int? delayTier1Max,
    double? delayTier1Penalty,
    int? delayTier1Forgiveness,
    int? delayTier2Min,
    int? delayTier2Max,
    double? delayTier2Penalty,
    int? delayTier2Forgiveness,
    int? delayTier3Min,
    double? delayTier3Penalty,
    int? delayTier3Forgiveness,
    int? earlyExitTier1Min,
    int? earlyExitTier1Max,
    double? earlyExitTier1Penalty,
    int? earlyExitTier1Forgiveness,
    int? earlyExitTier2Min,
    int? earlyExitTier2Max,
    double? earlyExitTier2Penalty,
    int? earlyExitTier2Forgiveness,
    int? earlyExitTier3Min,
    double? earlyExitTier3Penalty,
    int? earlyExitTier3Forgiveness,
    String? companyCode,
  }) {
    return EmployeeGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      shiftId: shiftId ?? this.shiftId,
      canEditCompanyInfo: canEditCompanyInfo ?? this.canEditCompanyInfo,
      annualLeaveAdditionType: annualLeaveAdditionType ?? this.annualLeaveAdditionType,
      annualLeaveAdditionHours: annualLeaveAdditionHours ?? this.annualLeaveAdditionHours,
      missedPunchLimitPerMonth: missedPunchLimitPerMonth ?? this.missedPunchLimitPerMonth,
      annualLeaveRequestDeadlineDays: annualLeaveRequestDeadlineDays ?? this.annualLeaveRequestDeadlineDays,
      annualLeaveMinNoticeDays: annualLeaveMinNoticeDays ?? this.annualLeaveMinNoticeDays,
      annualLeaveMaxRequestsPerPeriod: annualLeaveMaxRequestsPerPeriod ?? this.annualLeaveMaxRequestsPerPeriod,
      annualLeavePeriodType: annualLeavePeriodType ?? this.annualLeavePeriodType,
      hourlyLeaveMinHours: hourlyLeaveMinHours ?? this.hourlyLeaveMinHours,
      hourlyLeaveMinMinutes: hourlyLeaveMinMinutes ?? this.hourlyLeaveMinMinutes,
      hourlyLeaveMaxHours: hourlyLeaveMaxHours ?? this.hourlyLeaveMaxHours,
      hourlyLeaveMaxMinutes: hourlyLeaveMaxMinutes ?? this.hourlyLeaveMaxMinutes,
      overtimeAllowed: overtimeAllowed ?? this.overtimeAllowed,
      minOvertimeMinutes: minOvertimeMinutes ?? this.minOvertimeMinutes,
      maxOvertimeMinutes: maxOvertimeMinutes ?? this.maxOvertimeMinutes,
      holidayOvertimeRatio: holidayOvertimeRatio ?? this.holidayOvertimeRatio,
      weekendOvertimeRatio: weekendOvertimeRatio ?? this.weekendOvertimeRatio,
      nightOvertimeAllowed: nightOvertimeAllowed ?? this.nightOvertimeAllowed,
      nightOvertimeStart: nightOvertimeStart ?? this.nightOvertimeStart,
      nightOvertimeEnd: nightOvertimeEnd ?? this.nightOvertimeEnd,
      nightOvertimeRatio: nightOvertimeRatio ?? this.nightOvertimeRatio,
      delayPenaltiesEnabled: delayPenaltiesEnabled ?? this.delayPenaltiesEnabled,
      earlyExitPenaltiesEnabled: earlyExitPenaltiesEnabled ?? this.earlyExitPenaltiesEnabled,
      delayTier1Min: delayTier1Min ?? this.delayTier1Min,
      delayTier1Max: delayTier1Max ?? this.delayTier1Max,
      delayTier1Penalty: delayTier1Penalty ?? this.delayTier1Penalty,
      delayTier1Forgiveness: delayTier1Forgiveness ?? this.delayTier1Forgiveness,
      delayTier2Min: delayTier2Min ?? this.delayTier2Min,
      delayTier2Max: delayTier2Max ?? this.delayTier2Max,
      delayTier2Penalty: delayTier2Penalty ?? this.delayTier2Penalty,
      delayTier2Forgiveness: delayTier2Forgiveness ?? this.delayTier2Forgiveness,
      delayTier3Min: delayTier3Min ?? this.delayTier3Min,
      delayTier3Penalty: delayTier3Penalty ?? this.delayTier3Penalty,
      delayTier3Forgiveness: delayTier3Forgiveness ?? this.delayTier3Forgiveness,
      earlyExitTier1Min: earlyExitTier1Min ?? this.earlyExitTier1Min,
      earlyExitTier1Max: earlyExitTier1Max ?? this.earlyExitTier1Max,
      earlyExitTier1Penalty: earlyExitTier1Penalty ?? this.earlyExitTier1Penalty,
      earlyExitTier1Forgiveness: earlyExitTier1Forgiveness ?? this.earlyExitTier1Forgiveness,
      earlyExitTier2Min: earlyExitTier2Min ?? this.earlyExitTier2Min,
      earlyExitTier2Max: earlyExitTier2Max ?? this.earlyExitTier2Max,
      earlyExitTier2Penalty: earlyExitTier2Penalty ?? this.earlyExitTier2Penalty,
      earlyExitTier2Forgiveness: earlyExitTier2Forgiveness ?? this.earlyExitTier2Forgiveness,
      earlyExitTier3Min: earlyExitTier3Min ?? this.earlyExitTier3Min,
      earlyExitTier3Penalty: earlyExitTier3Penalty ?? this.earlyExitTier3Penalty,
      earlyExitTier3Forgiveness: earlyExitTier3Forgiveness ?? this.earlyExitTier3Forgiveness,
      companyCode: companyCode ?? this.companyCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'shiftId': shiftId,
      'canEditCompanyInfo': canEditCompanyInfo,
      'annualLeaveAdditionType': annualLeaveAdditionType,
      'annualLeaveAdditionHours': annualLeaveAdditionHours,
      'missedPunchLimitPerMonth': missedPunchLimitPerMonth,
      'annualLeaveRequestDeadlineDays': annualLeaveRequestDeadlineDays,
      'annualLeaveMinNoticeDays': annualLeaveMinNoticeDays,
      'annualLeaveMaxRequestsPerPeriod': annualLeaveMaxRequestsPerPeriod,
      'annualLeavePeriodType': annualLeavePeriodType,
      'hourlyLeaveMinHours': hourlyLeaveMinHours,
      'hourlyLeaveMinMinutes': hourlyLeaveMinMinutes,
      'hourlyLeaveMaxHours': hourlyLeaveMaxHours,
      'hourlyLeaveMaxMinutes': hourlyLeaveMaxMinutes,
      'overtimeAllowed': overtimeAllowed,
      'minOvertimeMinutes': minOvertimeMinutes,
      'maxOvertimeMinutes': maxOvertimeMinutes,
      'holidayOvertimeRatio': holidayOvertimeRatio,
      'weekendOvertimeRatio': weekendOvertimeRatio,
      'nightOvertimeAllowed': nightOvertimeAllowed,
      'nightOvertimeStart': nightOvertimeStart,
      'nightOvertimeEnd': nightOvertimeEnd,
      'nightOvertimeRatio': nightOvertimeRatio,
      'delayPenaltiesEnabled': delayPenaltiesEnabled,
      'earlyExitPenaltiesEnabled': earlyExitPenaltiesEnabled,
      'delayTier1Min': delayTier1Min,
      'delayTier1Max': delayTier1Max,
      'delayTier1Penalty': delayTier1Penalty,
      'delayTier1Forgiveness': delayTier1Forgiveness,
      'delayTier2Min': delayTier2Min,
      'delayTier2Max': delayTier2Max,
      'delayTier2Penalty': delayTier2Penalty,
      'delayTier2Forgiveness': delayTier2Forgiveness,
      'delayTier3Min': delayTier3Min,
      'delayTier3Penalty': delayTier3Penalty,
      'delayTier3Forgiveness': delayTier3Forgiveness,
      'earlyExitTier1Min': earlyExitTier1Min,
      'earlyExitTier1Max': earlyExitTier1Max,
      'earlyExitTier1Penalty': earlyExitTier1Penalty,
      'earlyExitTier1Forgiveness': earlyExitTier1Forgiveness,
      'earlyExitTier2Min': earlyExitTier2Min,
      'earlyExitTier2Max': earlyExitTier2Max,
      'earlyExitTier2Penalty': earlyExitTier2Penalty,
      'earlyExitTier2Forgiveness': earlyExitTier2Forgiveness,
      'earlyExitTier3Min': earlyExitTier3Min,
      'earlyExitTier3Penalty': earlyExitTier3Penalty,
      'earlyExitTier3Forgiveness': earlyExitTier3Forgiveness,
      'companyCode': companyCode.trim().toLowerCase(),
    };
  }

  factory EmployeeGroup.fromMap(Map<String, dynamic> map, String docId) {
    final cCode = resolveCompanyCode(map, docId, fallback: 'amada');

    return EmployeeGroup(
      id: map['id'] ?? docId,
      name: map['name'] ?? '',
      shiftId: map['shiftId'] ?? '',
      canEditCompanyInfo: map['canEditCompanyInfo'] ?? false,
      annualLeaveAdditionType: map['annualLeaveAdditionType'] ?? 'None',
      annualLeaveAdditionHours: (map['annualLeaveAdditionHours'] as num?)?.toDouble() ?? 0.0,
      missedPunchLimitPerMonth: (map['missedPunchLimitPerMonth'] as num?)?.toInt() ?? 3,
      annualLeaveRequestDeadlineDays: (map['annualLeaveRequestDeadlineDays'] as num?)?.toInt() ?? 0,
      annualLeaveMinNoticeDays: (map['annualLeaveMinNoticeDays'] as num?)?.toInt() ?? 0,
      annualLeaveMaxRequestsPerPeriod: (map['annualLeaveMaxRequestsPerPeriod'] as num?)?.toInt() ?? 0,
      annualLeavePeriodType: map['annualLeavePeriodType'] ?? 'Month',
      hourlyLeaveMinHours: (map['hourlyLeaveMinHours'] as num?)?.toInt() ?? 0,
      hourlyLeaveMinMinutes: (map['hourlyLeaveMinMinutes'] as num?)?.toInt() ?? 0,
      hourlyLeaveMaxHours: (map['hourlyLeaveMaxHours'] as num?)?.toInt() ?? 0,
      hourlyLeaveMaxMinutes: (map['hourlyLeaveMaxMinutes'] as num?)?.toInt() ?? 0,
      overtimeAllowed: map['overtimeAllowed'] ?? false,
      minOvertimeMinutes: (map['minOvertimeMinutes'] as num?)?.toInt() ?? 0,
      maxOvertimeMinutes: (map['maxOvertimeMinutes'] as num?)?.toInt() ?? 0,
      holidayOvertimeRatio: (map['holidayOvertimeRatio'] as num?)?.toDouble() ?? 1.5,
      weekendOvertimeRatio: (map['weekendOvertimeRatio'] as num?)?.toDouble() ?? 1.5,
      nightOvertimeAllowed: map['nightOvertimeAllowed'] ?? false,
      nightOvertimeStart: map['nightOvertimeStart'] ?? '22:00',
      nightOvertimeEnd: map['nightOvertimeEnd'] ?? '06:00',
      nightOvertimeRatio: (map['nightOvertimeRatio'] as num?)?.toDouble() ?? 1.5,
      delayPenaltiesEnabled: map['delayPenaltiesEnabled'] ?? true,
      earlyExitPenaltiesEnabled: map['earlyExitPenaltiesEnabled'] ?? true,
      delayTier1Min: (map['delayTier1Min'] as num?)?.toInt() ?? 0,
      delayTier1Max: (map['delayTier1Max'] as num?)?.toInt() ?? 0,
      delayTier1Penalty: (map['delayTier1Penalty'] as num?)?.toDouble() ?? 0.0,
      delayTier1Forgiveness: (map['delayTier1Forgiveness'] as num?)?.toInt() ?? 0,
      delayTier2Min: (map['delayTier2Min'] as num?)?.toInt() ?? 0,
      delayTier2Max: (map['delayTier2Max'] as num?)?.toInt() ?? 0,
      delayTier2Penalty: (map['delayTier2Penalty'] as num?)?.toDouble() ?? 0.0,
      delayTier2Forgiveness: (map['delayTier2Forgiveness'] as num?)?.toInt() ?? 0,
      delayTier3Min: (map['delayTier3Min'] as num?)?.toInt() ?? 0,
      delayTier3Penalty: (map['delayTier3Penalty'] as num?)?.toDouble() ?? 0.0,
      delayTier3Forgiveness: (map['delayTier3Forgiveness'] as num?)?.toInt() ?? 0,
      earlyExitTier1Min: (map['earlyExitTier1Min'] as num?)?.toInt() ?? 0,
      earlyExitTier1Max: (map['earlyExitTier1Max'] as num?)?.toInt() ?? 0,
      earlyExitTier1Penalty: (map['earlyExitTier1Penalty'] as num?)?.toDouble() ?? 0.0,
      earlyExitTier1Forgiveness: (map['earlyExitTier1Forgiveness'] as num?)?.toInt() ?? 0,
      earlyExitTier2Min: (map['earlyExitTier2Min'] as num?)?.toInt() ?? 0,
      earlyExitTier2Max: (map['earlyExitTier2Max'] as num?)?.toInt() ?? 0,
      earlyExitTier2Penalty: (map['earlyExitTier2Penalty'] as num?)?.toDouble() ?? 0.0,
      earlyExitTier2Forgiveness: (map['earlyExitTier2Forgiveness'] as num?)?.toInt() ?? 0,
      earlyExitTier3Min: (map['earlyExitTier3Min'] as num?)?.toInt() ?? 0,
      earlyExitTier3Penalty: (map['earlyExitTier3Penalty'] as num?)?.toDouble() ?? 0.0,
      earlyExitTier3Forgiveness: (map['earlyExitTier3Forgiveness'] as num?)?.toInt() ?? 0,
      companyCode: cCode,
    );
  }

  /// Calculates how many minutes between [start] and [end] fall within the night overtime window
  int calculateNightMinutes(DateTime start, DateTime end) {
    if (!nightOvertimeAllowed) return 0;
    return calculateNightOverlapMinutes(
      start,
      end,
      nightOvertimeStart,
      nightOvertimeEnd,
    );
  }

  /// Calculates total overtime minutes weighted by applicable multipliers (holiday, weekend, normal, and night overtime)
  int calculateOvertimeMinutes({
    required int dayExtraMinutes,
    required int nightExtraMinutes,
    required bool isWeekend,
    required bool isHoliday,
  }) {
    if (!overtimeAllowed || dayExtraMinutes <= 0) return 0;
    if (dayExtraMinutes < minOvertimeMinutes) return 0;

    final baseOt = maxOvertimeMinutes > 0
        ? dayExtraMinutes.clamp(0, maxOvertimeMinutes)
        : dayExtraMinutes;
    final double standardRatio;
    if (isHoliday) {
      standardRatio = holidayOvertimeRatio;
    } else if (isWeekend) {
      standardRatio = weekendOvertimeRatio;
    } else {
      standardRatio = 1.0;
    }

    if (nightOvertimeAllowed && nightExtraMinutes > 0) {
      final effNight = nightExtraMinutes.clamp(0, dayExtraMinutes);
      final nightOtPart = (baseOt * (effNight / dayExtraMinutes)).round();
      final dayOtPart = baseOt - nightOtPart;
      return (dayOtPart * standardRatio).toInt() +
          (nightOtPart * nightOvertimeRatio).toInt();
    } else {
      return (baseOt * standardRatio).toInt();
    }
  }
}

/// Helper function to calculate how many minutes of [start]..[end] overlap with the window [nightStartStr]..[nightEndStr]
int calculateNightOverlapMinutes(
  DateTime start,
  DateTime end,
  String nightStartStr,
  String nightEndStr,
) {
  if (!end.isAfter(start)) return 0;

  final startParts = nightStartStr.trim().split(':');
  final endParts = nightEndStr.trim().split(':');
  if (startParts.length != 2 || endParts.length != 2) return 0;

  final sHour = int.tryParse(startParts[0]) ?? 22;
  final sMin = int.tryParse(startParts[1]) ?? 0;
  final eHour = int.tryParse(endParts[0]) ?? 6;
  final eMin = int.tryParse(endParts[1]) ?? 0;

  final startMins = sHour * 60 + sMin;
  final endMins = eHour * 60 + eMin;
  if (startMins == endMins) return 0;

  final totalDurationMins = end.difference(start).inMinutes;
  if (totalDurationMins <= 0) return 0;

  int nightMinutes = 0;
  final int currentMinuteOfDay = start.hour * 60 + start.minute;
  for (int i = 0; i < totalDurationMins; i++) {
    final mod = (currentMinuteOfDay + i) % 1440;
    final bool isNight;
    if (startMins > endMins) {
      isNight = mod >= startMins || mod < endMins;
    } else {
      isNight = mod >= startMins && mod < endMins;
    }
    if (isNight) {
      nightMinutes++;
    }
  }
  return nightMinutes;
}

/// Parses an hourly leave duration string into total minutes.
/// Supported formats:
/// - "2 Hours", "2 hrs", "2h", "1 Hour 30 Mins", "1 hr 30 min", "1h 30m"
/// - "90 Mins", "45 min", "45m"
/// - "From 15:00 to 16:00 for 1 hour", "15:00 - 16:00", "15:00 to 16:30"
/// - "1.5 Hours", "2.5"
/// - "02:30", "2:30" (HH:mm)
/// - "120" (number)
int parseHourlyLeaveDurationMinutes(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 0;

  // 1. Check for time range format: e.g. "From 15:00 to 16:00 for 1 hour", "15:00 - 16:30", "15:00 to 16:00"
  final rangeMatch = RegExp(r'(\d{1,2}:\d{2})\s*(?:to|-)\s*(\d{1,2}:\d{2})', caseSensitive: false).firstMatch(trimmed);
  if (rangeMatch != null) {
    try {
      final fParts = rangeMatch.group(1)!.split(':');
      final tParts = rangeMatch.group(2)!.split(':');
      final fMins = int.parse(fParts[0]) * 60 + int.parse(fParts[1]);
      final tMins = int.parse(tParts[0]) * 60 + int.parse(tParts[1]);
      var diff = tMins - fMins;
      if (diff < 0) diff += 24 * 60;
      if (diff > 0) return diff;
    } catch (_) {}
  }

  // 2. Check HH:mm format e.g. "02:30" or "2:30" or "01:30"
  final timeMatch = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(trimmed);
  if (timeMatch != null) {
    final h = int.tryParse(timeMatch.group(1)!) ?? 0;
    final m = int.tryParse(timeMatch.group(2)!) ?? 0;
    return h * 60 + m;
  }

  // 3. Check compound e.g. "2 Hours 30 Mins" or "2 hrs 30 m" or "2h 30m"
  final hourMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|h)\b', caseSensitive: false).firstMatch(trimmed);
  final minMatch = RegExp(r'(\d+)\s*(?:minutes?|mins?|m)\b', caseSensitive: false).firstMatch(trimmed);

  if (hourMatch != null || minMatch != null) {
    int total = 0;
    if (hourMatch != null) {
      final hoursVal = double.tryParse(hourMatch.group(1)!) ?? 0.0;
      total += (hoursVal * 60).round();
    }
    if (minMatch != null) {
      final minsVal = int.tryParse(minMatch.group(1)!) ?? 0;
      total += minsVal;
    }
    return total;
  }

  // 4. Decimal number with or without unit: e.g. "1.5" or "2"
  final numVal = double.tryParse(trimmed);
  if (numVal != null) {
    if (numVal > 12 && numVal == numVal.roundToDouble()) {
      return numVal.round();
    } else {
      return (numVal * 60).round();
    }
  }

  // Fallback: extract digits
  final fallbackMatches = RegExp(r'\d+').allMatches(trimmed).map((m) => int.parse(m.group(0)!)).toList();
  if (fallbackMatches.length >= 2) {
    return fallbackMatches[0] * 60 + fallbackMatches[1];
  } else if (fallbackMatches.length == 1) {
    final val = fallbackMatches[0];
    return val <= 12 ? val * 60 : val;
  }

  return 0;
}

/// Parses duration string for Overtime Approval request into minutes.
/// Supports "From 08:25 to 09:00 (0.6 Hours)", "From 08:25 to 09:00",
/// "2.5 Hours", "35 Mins", "35", etc.
int parseOvertimeApprovalDurationMinutes(String raw) {
  return parseHourlyLeaveDurationMinutes(raw);
}

class HourlyLeaveTimeRange {
  final int startMinutes;
  final int endMinutes;
  final int durationMinutes;

  const HourlyLeaveTimeRange({
    required this.startMinutes,
    required this.endMinutes,
    required this.durationMinutes,
  });
}

HourlyLeaveTimeRange? parseHourlyLeaveTimeRange(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final rangeMatch = RegExp(r'(\d{1,2}:\d{2})\s*(?:to|-)\s*(\d{1,2}:\d{2})', caseSensitive: false).firstMatch(trimmed);
  if (rangeMatch != null) {
    try {
      final fParts = rangeMatch.group(1)!.split(':');
      final tParts = rangeMatch.group(2)!.split(':');
      final fMins = int.parse(fParts[0]) * 60 + int.parse(fParts[1]);
      final tMins = int.parse(tParts[0]) * 60 + int.parse(tParts[1]);
      var diff = tMins - fMins;
      if (diff < 0) diff += 24 * 60;
      return HourlyLeaveTimeRange(
        startMinutes: fMins,
        endMinutes: tMins,
        durationMinutes: diff,
      );
    } catch (_) {}
  }
  return null;
}

/// Formats minutes into "01:30" time string
String formatMinutesToTimeString(int totalMins) {
  if (totalMins < 0) totalMins = 0;
  final h = totalMins ~/ 60;
  final m = totalMins % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Formats total minutes into readable hours and minutes string (e.g. "2h", "1h 30m", "45m")
String formatMinutesToHoursAndMinutes(int totalMins) {
  if (totalMins <= 0) return '0 min';
  final h = totalMins ~/ 60;
  final m = totalMins % 60;
  if (h > 0 && m > 0) {
    return '${h}h ${m}m';
  } else if (h > 0) {
    return '${h}h';
  } else {
    return '${m}m';
  }
}

/// Formats From and To times into e.g. "From 15:00 to 16:00 for 1 hour"
String formatHourlyLeaveDurationString(String fromTime, String toTime) {
  final fParts = fromTime.split(':');
  final tParts = toTime.split(':');
  if (fParts.length < 2 || tParts.length < 2) {
    return 'From $fromTime to $toTime';
  }
  final fMins = (int.tryParse(fParts[0]) ?? 0) * 60 + (int.tryParse(fParts[1]) ?? 0);
  final tMins = (int.tryParse(tParts[0]) ?? 0) * 60 + (int.tryParse(tParts[1]) ?? 0);
  var diff = tMins - fMins;
  if (diff < 0) diff += 24 * 60;

  if (diff == 0) {
    return 'From $fromTime to $toTime for 0 min';
  }

  final h = diff ~/ 60;
  final m = diff % 60;
  String durText;
  if (h > 0 && m > 0) {
    final hStr = h == 1 ? '1 hour' : '$h hours';
    final mStr = m == 1 ? '1 min' : '$m mins';
    durText = '$hStr $mStr';
  } else if (h > 0) {
    durText = h == 1 ? '1 hour' : '$h hours';
  } else {
    durText = m == 1 ? '1 min' : '$m mins';
  }

  return 'From $fromTime to $toTime for $durText';
}

class PositionHistoryEntry {
  final String position;
  final String startDate;
  final String endDate;

  PositionHistoryEntry({
    required this.position,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'position': position,
      'startDate': startDate,
      'endDate': endDate,
    };
  }

  factory PositionHistoryEntry.fromMap(Map<String, dynamic> map) {
    return PositionHistoryEntry(
      position: map['position'] ?? '',
      startDate: map['startDate'] ?? '',
      endDate: map['endDate'] ?? '',
    );
  }
}

class GroupHistoryEntry {
  final String groupId;
  final String startDate;
  final String endDate;

  GroupHistoryEntry({
    required this.groupId,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'startDate': startDate,
      'endDate': endDate,
    };
  }

  factory GroupHistoryEntry.fromMap(Map<String, dynamic> map) {
    return GroupHistoryEntry(
      groupId: map['groupId'] ?? '',
      startDate: map['startDate'] ?? '',
      endDate: map['endDate'] ?? '',
    );
  }
}

class CompanyEmployee {
  final String id;
  final String name;
  final String email;
  final String position;
  final String? groupId; // Refers to EmployeeGroup (null if none)
  final String? structureId; // Refers to OrgStructure directly
  final String role; // 'employee', 'supervisor', 'hr'
  final String phoneNumber;
  final String startDate;
  final String? endDate;
  final bool disabled;
  final String positionStartDate;
  final List<PositionHistoryEntry> positionHistory;
  final String groupStartDate;
  final List<GroupHistoryEntry> groupHistory;
  final String? avatarUrl;
  
  final double annualLeaveBalance;
  
  final double basicSalary;
  final double workingHours;
  final String salaryCurrency;
  final List<SalaryHistoryEntry> salaryHistory;
  final double foodAllowance;
  final double transportationAllowance;
  final double otherAllowance;
  final bool hasInsurance;
  final double insuranceSalary;
  
  final List<double>? faceEmbedding;
  final String themePreference; // 'dark' or 'light'
  final String languagePreference; // 'en', 'ku', 'ar'
  final String? fcmToken;
  final String? password;

  // General Info
  final String? dateOfBirth;
  final String? gender;
  final String? maritalStatus;
  final String? emergencyContact; // Close personal relationships
  final String? emergencyPhone;   // Close personal phone no
  final String? bloodGroup;
  final String? nationality;
  final String? address;

  // Documents Info
  final String? nationalCardNo;
  final String? passportNo;
  final String? passportExpiryDate;
  final String? residenceCardNo;
  final String? residenceCardExpiryDate;
  final String? nationalCardAttachment;
  final String? passportAttachment;
  final String? residenceCardAttachment;
  final String companyCode;

  CompanyEmployee({
    required this.id,
    required this.name,
    required this.email,
    required this.position,
    this.groupId,
    this.structureId,
    this.role = 'employee',
    this.phoneNumber = '',
    this.startDate = '',
    this.endDate,
    this.disabled = false,
    this.positionStartDate = '',
    this.positionHistory = const [],
    this.groupStartDate = '',
    this.groupHistory = const [],
    this.avatarUrl,
    this.annualLeaveBalance = 0.0,
    this.basicSalary = 0.0,
    this.workingHours = 0.0,
    this.salaryCurrency = 'USD',
    this.salaryHistory = const [],
    this.foodAllowance = 0.0,
    this.transportationAllowance = 0.0,
    this.otherAllowance = 0.0,
    this.hasInsurance = false,
    this.insuranceSalary = 0.0,
    this.faceEmbedding,
    this.themePreference = 'light',
    this.languagePreference = 'en',
    this.fcmToken,
    this.password,
    this.dateOfBirth,
    this.gender,
    this.maritalStatus,
    this.emergencyContact,
    this.emergencyPhone,
    this.bloodGroup,
    this.nationality,
    this.address,
    this.nationalCardNo,
    this.passportNo,
    this.passportExpiryDate,
    this.residenceCardNo,
    this.residenceCardExpiryDate,
    this.nationalCardAttachment,
    this.passportAttachment,
    this.residenceCardAttachment,
    this.companyCode = '',
  });

  CompanyEmployee copyWith({
    String? id,
    String? name,
    String? email,
    String? position,
    String? groupId,
    bool overrideGroupId = false,
    String? structureId,
    bool overrideStructureId = false,
    String? role,
    String? phoneNumber,
    String? startDate,
    String? endDate,
    bool overrideEndDate = false,
    bool? disabled,
    String? positionStartDate,
    List<PositionHistoryEntry>? positionHistory,
    String? groupStartDate,
    List<GroupHistoryEntry>? groupHistory,
    String? avatarUrl,
    bool overrideAvatarUrl = false,
    double? annualLeaveBalance,
    double? basicSalary,
    double? workingHours,
    String? salaryCurrency,
    List<SalaryHistoryEntry>? salaryHistory,
    double? foodAllowance,
    double? transportationAllowance,
    double? otherAllowance,
    bool? hasInsurance,
    double? insuranceSalary,
    List<double>? faceEmbedding,
    bool overrideFaceEmbedding = false,
    String? themePreference,
    String? languagePreference,
    String? fcmToken,
    bool overrideFcmToken = false,
    String? password,
    bool overridePassword = false,
    String? dateOfBirth,
    String? gender,
    String? maritalStatus,
    String? emergencyContact,
    String? emergencyPhone,
    String? bloodGroup,
    String? nationality,
    String? address,
    String? nationalCardNo,
    String? passportNo,
    String? passportExpiryDate,
    String? residenceCardNo,
    String? residenceCardExpiryDate,
    String? nationalCardAttachment,
    bool overrideNationalCardAttachment = false,
    String? passportAttachment,
    bool overridePassportAttachment = false,
    String? residenceCardAttachment,
    bool overrideResidenceCardAttachment = false,
    String? companyCode,
  }) {
    return CompanyEmployee(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      position: position ?? this.position,
      groupId: overrideGroupId ? groupId : (groupId ?? this.groupId),
      structureId: overrideStructureId ? structureId : (structureId ?? this.structureId),
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      startDate: startDate ?? this.startDate,
      endDate: overrideEndDate ? endDate : (endDate ?? this.endDate),
      disabled: disabled ?? this.disabled,
      positionStartDate: positionStartDate ?? this.positionStartDate,
      positionHistory: positionHistory ?? this.positionHistory,
      groupStartDate: groupStartDate ?? this.groupStartDate,
      groupHistory: groupHistory ?? this.groupHistory,
      avatarUrl: overrideAvatarUrl ? avatarUrl : (avatarUrl ?? this.avatarUrl),
      annualLeaveBalance: annualLeaveBalance ?? this.annualLeaveBalance,
      basicSalary: basicSalary ?? this.basicSalary,
      workingHours: workingHours ?? this.workingHours,
      salaryCurrency: salaryCurrency ?? this.salaryCurrency,
      salaryHistory: salaryHistory ?? this.salaryHistory,
      foodAllowance: foodAllowance ?? this.foodAllowance,
      transportationAllowance: transportationAllowance ?? this.transportationAllowance,
      otherAllowance: otherAllowance ?? this.otherAllowance,
      hasInsurance: hasInsurance ?? this.hasInsurance,
      insuranceSalary: insuranceSalary ?? this.insuranceSalary,
      faceEmbedding: overrideFaceEmbedding ? faceEmbedding : (faceEmbedding ?? this.faceEmbedding),
      themePreference: themePreference ?? this.themePreference,
      languagePreference: languagePreference ?? this.languagePreference,
      fcmToken: overrideFcmToken ? fcmToken : (fcmToken ?? this.fcmToken),
      password: overridePassword ? password : (password ?? this.password),
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      nationality: nationality ?? this.nationality,
      address: address ?? this.address,
      nationalCardNo: nationalCardNo ?? this.nationalCardNo,
      passportNo: passportNo ?? this.passportNo,
      passportExpiryDate: passportExpiryDate ?? this.passportExpiryDate,
      residenceCardNo: residenceCardNo ?? this.residenceCardNo,
      residenceCardExpiryDate: residenceCardExpiryDate ?? this.residenceCardExpiryDate,
      nationalCardAttachment: overrideNationalCardAttachment
          ? nationalCardAttachment
          : (nationalCardAttachment ?? this.nationalCardAttachment),
      passportAttachment: overridePassportAttachment
          ? passportAttachment
          : (passportAttachment ?? this.passportAttachment),
      residenceCardAttachment: overrideResidenceCardAttachment
          ? residenceCardAttachment
          : (residenceCardAttachment ?? this.residenceCardAttachment),
      companyCode: companyCode ?? this.companyCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'position': position,
      'groupId': groupId,
      'structureId': structureId,
      'role': role,
      'phoneNumber': phoneNumber,
      'startDate': startDate,
      'endDate': endDate,
      'disabled': disabled,
      'positionStartDate': positionStartDate,
      'positionHistory': positionHistory.map((e) => e.toMap()).toList(),
      'groupStartDate': groupStartDate,
      'groupHistory': groupHistory.map((e) => e.toMap()).toList(),
      'avatarUrl': avatarUrl,
      'annualLeaveBalance': annualLeaveBalance,
      'basicSalary': basicSalary,
      'workingHours': workingHours,
      'salaryCurrency': salaryCurrency,
      'salaryHistory': salaryHistory.map((e) => e.toMap()).toList(),
      'foodAllowance': foodAllowance,
      'transportationAllowance': transportationAllowance,
      'otherAllowance': otherAllowance,
      'hasInsurance': hasInsurance,
      'insuranceSalary': insuranceSalary,
      'faceEmbedding': faceEmbedding,
      'themePreference': themePreference,
      'languagePreference': languagePreference,
      'fcmToken': fcmToken,
      'password': password,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'maritalStatus': maritalStatus,
      'emergencyContact': emergencyContact,
      'emergencyPhone': emergencyPhone,
      'bloodGroup': bloodGroup,
      'nationality': nationality,
      'address': address,
      'nationalCardNo': nationalCardNo,
      'passportNo': passportNo,
      'passportExpiryDate': passportExpiryDate,
      'residenceCardNo': residenceCardNo,
      'residenceCardExpiryDate': residenceCardExpiryDate,
      'nationalCardAttachment': nationalCardAttachment,
      'passportAttachment': passportAttachment,
      'residenceCardAttachment': residenceCardAttachment,
      'companyCode': companyCode.trim().toLowerCase(),
    };
  }

  factory CompanyEmployee.fromMap(Map<String, dynamic> map, String docId) {
    var historyList = map['positionHistory'] as List?;
    List<PositionHistoryEntry> history = historyList != null
        ? historyList
            .map((e) => PositionHistoryEntry.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : [];

    var groupHistoryList = map['groupHistory'] as List?;
    List<GroupHistoryEntry> gHistory = groupHistoryList != null
        ? groupHistoryList
            .map((e) => GroupHistoryEntry.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : [];

    String cCode = (map['companyCode'] ?? '').toString().trim().toLowerCase();
    final cleanDocId = docId.toLowerCase().trim();
    if (cCode.isEmpty) {
      final emailStr = (map['email'] ?? '').toString().toLowerCase();
      if (emailStr.endsWith('@lazo.com') || cleanDocId.startsWith('lazo_') || cleanDocId.startsWith('_lazo_')) {
        cCode = 'lazo';
      } else if (emailStr.endsWith('@amada.com') || cleanDocId.startsWith('amada_') || cleanDocId.startsWith('_amada_')) {
        cCode = 'amada';
      } else if (emailStr.contains('@') && !emailStr.endsWith('@company.com')) {
        final domainPart = emailStr.split('@').last.split('.').first;
        const personalDomains = {
          'gmail',
          'yahoo',
          'hotmail',
          'outlook',
          'icloud',
          'mail',
          'live',
          'aol',
          'proton',
          'protonmail',
        };
        if (domainPart.isNotEmpty && !personalDomains.contains(domainPart)) {
          cCode = domainPart;
        }
      } else if (cleanDocId.contains('_')) {
        final prefix = cleanDocId.startsWith('_') ? cleanDocId.substring(1).split('_').first : cleanDocId.split('_').first;
        if (prefix.isNotEmpty && prefix != 'admin' && prefix != 'emp' && prefix != 'employee') {
          cCode = prefix;
        }
      }
      if (cCode.isEmpty) {
        cCode = resolveCompanyCode(map, docId, fallback: 'amada');
      }
    }

    final resolvedId = (map['id'] != null && map['id'].toString().trim().isNotEmpty)
        ? map['id'].toString().trim()
        : (docId.startsWith('_') ? docId.substring(1) : docId);

    return CompanyEmployee(
      id: resolvedId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      position: map['position'] ?? '',
      groupId: map['groupId'],
      structureId: map['structureId'],
      role: map['role'] ?? 'employee',
      phoneNumber: map['phoneNumber'] ?? '',
      startDate: map['startDate'] ?? '',
      endDate: map['endDate'],
      disabled: map['disabled'] ?? false,
      positionStartDate: map['positionStartDate'] ?? '',
      positionHistory: history,
      groupStartDate: map['groupStartDate'] ?? '',
      groupHistory: gHistory,
      avatarUrl: map['avatarUrl'],
      annualLeaveBalance: (map['annualLeaveBalance'] as num?)?.toDouble() ?? 0.0,
      basicSalary: (map['basicSalary'] as num?)?.toDouble() ?? 0.0,
      workingHours: (map['workingHours'] as num?)?.toDouble() ?? 0.0,
      salaryCurrency: map['salaryCurrency'] ?? 'USD',
      salaryHistory: (map['salaryHistory'] as List?)
              ?.map((e) => SalaryHistoryEntry.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      foodAllowance: (map['foodAllowance'] as num?)?.toDouble() ?? 0.0,
      transportationAllowance: (map['transportationAllowance'] as num?)?.toDouble() ?? 0.0,
      otherAllowance: (map['otherAllowance'] as num?)?.toDouble() ?? 0.0,
      hasInsurance: map['hasInsurance'] as bool? ?? false,
      insuranceSalary: (map['insuranceSalary'] as num?)?.toDouble() ?? 0.0,
      faceEmbedding: map['faceEmbedding'] != null 
          ? List<double>.from((map['faceEmbedding'] as List).map((e) => (e as num).toDouble()))
          : null,
      themePreference: map['themePreference'] ?? 'light',
      languagePreference: map['languagePreference'] ?? 'en',
      fcmToken: map['fcmToken'],
      password: map['password'],
      dateOfBirth: map['dateOfBirth'],
      gender: map['gender'],
      maritalStatus: map['maritalStatus'],
      emergencyContact: map['emergencyContact'],
      emergencyPhone: map['emergencyPhone'],
      bloodGroup: map['bloodGroup'],
      nationality: map['nationality'],
      address: map['address'],
      nationalCardNo: map['nationalCardNo'],
      passportNo: map['passportNo'],
      passportExpiryDate: map['passportExpiryDate'],
      residenceCardNo: map['residenceCardNo'],
      residenceCardExpiryDate: map['residenceCardExpiryDate'],
      nationalCardAttachment: map['nationalCardAttachment'],
      passportAttachment: map['passportAttachment'],
      residenceCardAttachment: map['residenceCardAttachment'],
      companyCode: cCode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompanyEmployee &&
          runtimeType == other.runtimeType &&
          id.trim().toLowerCase() == other.id.trim().toLowerCase();

  @override
  int get hashCode => id.trim().toLowerCase().hashCode;
}

class Holiday {
  final String id;
  final String name;
  final String fromDate; // yyyy-MM-dd
  final String toDate;   // yyyy-MM-dd
  final List<String> groupIds;
  final String companyCode;

  Holiday({
    required this.id,
    required this.name,
    required this.fromDate,
    required this.toDate,
    this.groupIds = const [],
    this.companyCode = '',
  });

  Holiday copyWith({
    String? id,
    String? name,
    String? fromDate,
    String? toDate,
    List<String>? groupIds,
    String? companyCode,
  }) {
    return Holiday(
      id: id ?? this.id,
      name: name ?? this.name,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      groupIds: groupIds ?? this.groupIds,
      companyCode: companyCode ?? this.companyCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'fromDate': fromDate,
      'toDate': toDate,
      'groupIds': groupIds,
      'companyCode': companyCode.trim().toLowerCase(),
    };
  }

  factory Holiday.fromMap(Map<String, dynamic> map, String docId) {
    return Holiday(
      id: map['id'] ?? docId,
      name: map['name'] ?? '',
      fromDate: map['fromDate'] ?? '',
      toDate: map['toDate'] ?? '',
      groupIds: List<String>.from(map['groupIds'] ?? []),
      companyCode: resolveCompanyCode(map, docId, fallback: 'amada'),
    );
  }
}

class WorkLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius;
  final List<String> groupIds;
  final String companyCode;
  final String? wifiBssid;
  final String? wifiSsid;
  final bool requireWifi;

  WorkLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.groupIds = const [],
    this.companyCode = '',
    this.wifiBssid,
    this.wifiSsid,
    this.requireWifi = false,
  });

  WorkLocation copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? radius,
    List<String>? groupIds,
    String? companyCode,
    String? wifiBssid,
    bool overrideWifiBssid = false,
    String? wifiSsid,
    bool overrideWifiSsid = false,
    bool? requireWifi,
  }) {
    return WorkLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      groupIds: groupIds ?? this.groupIds,
      companyCode: companyCode ?? this.companyCode,
      wifiBssid: overrideWifiBssid ? wifiBssid : (wifiBssid ?? this.wifiBssid),
      wifiSsid: overrideWifiSsid ? wifiSsid : (wifiSsid ?? this.wifiSsid),
      requireWifi: requireWifi ?? this.requireWifi,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'groupIds': groupIds,
      'companyCode': companyCode.trim().toLowerCase(),
      'wifiBssid': wifiBssid,
      'wifiSsid': wifiSsid,
      'requireWifi': requireWifi,
    };
  }

  factory WorkLocation.fromMap(Map<String, dynamic> map, String docId) {
    final cCode = resolveCompanyCode(map, docId, fallback: 'amada');

    return WorkLocation(
      id: map['id'] ?? docId,
      name: map['name'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      radius: (map['radius'] as num?)?.toDouble() ?? 0.0,
      groupIds: List<String>.from(map['groupIds'] ?? []),
      companyCode: cCode,
      wifiBssid: map['wifiBssid'] as String?,
      wifiSsid: map['wifiSsid'] as String?,
      requireWifi: map['requireWifi'] == true,
    );
  }
}

class CompanyProfile {
  final String name;
  final String address;
  final String? email;
  final String? phone;
  final String? logoBase64;
  final String? geminiApiKey;

  CompanyProfile({
    required this.name,
    required this.address,
    this.email,
    this.phone,
    this.logoBase64,
    this.geminiApiKey,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'email': email,
      'phone': phone,
      'logoBase64': logoBase64,
      'geminiApiKey': geminiApiKey,
    };
  }

  factory CompanyProfile.fromMap(Map<String, dynamic> map) {
    return CompanyProfile(
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      email: map['email'],
      phone: map['phone'],
      logoBase64: map['logoBase64'],
      geminiApiKey: map['geminiApiKey'],
    );
  }

  CompanyProfile copyWith({
    String? name,
    String? address,
    String? email,
    String? phone,
    String? logoBase64,
    String? geminiApiKey,
  }) {
    return CompanyProfile(
      name: name ?? this.name,
      address: address ?? this.address,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      logoBase64: logoBase64 ?? this.logoBase64,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
    );
  }
}

class PayrollAdjustment {
  final String id;
  final String employeeId;
  final String type; // 'addition' or 'deduction'
  final String category; // 'Bonus', 'Commission', 'Loan Repayment', 'Fine', etc.
  final double amount;
  final String currency; // 'USD' or 'IQD'
  final String date; // 'yyyy-MM-dd'
  final String month; // 'yyyy-MM'
  final String reason;
  final String? createdBy;
  final DateTime createdAt;

  PayrollAdjustment({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.category,
    required this.amount,
    required this.currency,
    required this.date,
    required this.month,
    this.reason = '',
    this.createdBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  PayrollAdjustment copyWith({
    String? id,
    String? employeeId,
    String? type,
    String? category,
    double? amount,
    String? currency,
    String? date,
    String? month,
    String? reason,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return PayrollAdjustment(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      type: type ?? this.type,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      month: month ?? this.month,
      reason: reason ?? this.reason,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'type': type,
      'category': category,
      'amount': amount,
      'currency': currency,
      'date': date,
      'month': month,
      'reason': reason,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PayrollAdjustment.fromMap(Map<String, dynamic> map, String docId) {
    final dStr = map['date'] ?? '';
    final mStr = map['month'] ?? (dStr.length >= 7 ? dStr.substring(0, 7) : '');
    return PayrollAdjustment(
      id: map['id'] ?? docId,
      employeeId: map['employeeId'] ?? '',
      type: map['type'] ?? 'addition',
      category: map['category'] ?? 'Bonus',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'USD',
      date: dStr,
      month: mStr,
      reason: map['reason'] ?? '',
      createdBy: map['createdBy'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class PayrollReportSnapshot {
  final String employeeId;
  final String employeeName;
  final String position;
  final String? structureId;
  final double basicSalary;
  final double salaryCalcByDay;
  final double workingHours;
  final int daysWorked;
  final double incrementalSalary;
  final double decrementalSalary;
  final double overtimeHours;
  final double overtimeValue;
  final double attendanceDeficitHours;
  final double attendanceDeficit;
  final double unpaidLeaveHours;
  final double unpaidLeaveDeduction;
  final double monthlyPenalties;
  final double foodAllowance;
  final double transportationAllowance;
  final double otherAllowance;
  final double monthlyAdditions;
  final double monthlyDeductions;
  final bool hasInsurance;
  final double insuranceSalary;
  final double insuranceEmployee;
  final double insuranceCompany;
  final double netEarnings;
  final String currency;

  PayrollReportSnapshot({
    required this.employeeId,
    required this.employeeName,
    required this.position,
    this.structureId,
    required this.basicSalary,
    required this.salaryCalcByDay,
    required this.workingHours,
    required this.daysWorked,
    required this.incrementalSalary,
    required this.decrementalSalary,
    required this.overtimeHours,
    required this.overtimeValue,
    required this.attendanceDeficitHours,
    required this.attendanceDeficit,
    this.unpaidLeaveHours = 0.0,
    this.unpaidLeaveDeduction = 0.0,
    required this.monthlyPenalties,
    required this.foodAllowance,
    required this.transportationAllowance,
    required this.otherAllowance,
    required this.monthlyAdditions,
    required this.monthlyDeductions,
    required this.hasInsurance,
    required this.insuranceSalary,
    required this.insuranceEmployee,
    required this.insuranceCompany,
    required this.netEarnings,
    required this.currency,
  });

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'position': position,
      'structureId': structureId,
      'basicSalary': basicSalary,
      'salaryCalcByDay': salaryCalcByDay,
      'workingHours': workingHours,
      'daysWorked': daysWorked,
      'incrementalSalary': incrementalSalary,
      'decrementalSalary': decrementalSalary,
      'overtimeHours': overtimeHours,
      'overtimeValue': overtimeValue,
      'attendanceDeficitHours': attendanceDeficitHours,
      'attendanceDeficit': attendanceDeficit,
      'unpaidLeaveHours': unpaidLeaveHours,
      'unpaidLeaveDeduction': unpaidLeaveDeduction,
      'monthlyPenalties': monthlyPenalties,
      'foodAllowance': foodAllowance,
      'transportationAllowance': transportationAllowance,
      'otherAllowance': otherAllowance,
      'monthlyAdditions': monthlyAdditions,
      'monthlyDeductions': monthlyDeductions,
      'hasInsurance': hasInsurance,
      'insuranceSalary': insuranceSalary,
      'insuranceEmployee': insuranceEmployee,
      'insuranceCompany': insuranceCompany,
      'netEarnings': netEarnings,
      'currency': currency,
    };
  }

  factory PayrollReportSnapshot.fromMap(Map<String, dynamic> map) {
    return PayrollReportSnapshot(
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      position: map['position'] ?? '',
      structureId: map['structureId'],
      basicSalary: (map['basicSalary'] as num?)?.toDouble() ?? 0.0,
      salaryCalcByDay: (map['salaryCalcByDay'] as num?)?.toDouble() ?? 0.0,
      workingHours: (map['workingHours'] as num?)?.toDouble() ?? 0.0,
      daysWorked: (map['daysWorked'] as num?)?.toInt() ?? 0,
      incrementalSalary: (map['incrementalSalary'] as num?)?.toDouble() ?? 0.0,
      decrementalSalary: (map['decrementalSalary'] as num?)?.toDouble() ?? 0.0,
      overtimeHours: (map['overtimeHours'] as num?)?.toDouble() ?? 0.0,
      overtimeValue: (map['overtimeValue'] as num?)?.toDouble() ?? 0.0,
      attendanceDeficitHours: (map['attendanceDeficitHours'] as num?)?.toDouble() ?? 0.0,
      attendanceDeficit: (map['attendanceDeficit'] as num?)?.toDouble() ?? 0.0,
      unpaidLeaveHours: (map['unpaidLeaveHours'] as num?)?.toDouble() ?? 0.0,
      unpaidLeaveDeduction: (map['unpaidLeaveDeduction'] as num?)?.toDouble() ?? 0.0,
      monthlyPenalties: (map['monthlyPenalties'] as num?)?.toDouble() ?? 0.0,
      foodAllowance: (map['foodAllowance'] as num?)?.toDouble() ?? 0.0,
      transportationAllowance: (map['transportationAllowance'] as num?)?.toDouble() ?? 0.0,
      otherAllowance: (map['otherAllowance'] as num?)?.toDouble() ?? 0.0,
      monthlyAdditions: (map['monthlyAdditions'] as num?)?.toDouble() ?? 0.0,
      monthlyDeductions: (map['monthlyDeductions'] as num?)?.toDouble() ?? 0.0,
      hasInsurance: map['hasInsurance'] == true,
      insuranceSalary: (map['insuranceSalary'] as num?)?.toDouble() ?? 0.0,
      insuranceEmployee: (map['insuranceEmployee'] as num?)?.toDouble() ?? 0.0,
      insuranceCompany: (map['insuranceCompany'] as num?)?.toDouble() ?? 0.0,
      netEarnings: (map['netEarnings'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'USD',
    );
  }
}

class PayrollMonthClosure {
  final String id; // e.g. "amada_2026-10" or "2026-10"
  final String yearMonth; // "2026-10"
  final String companyCode; // e.g. "amada", "lazo"
  final bool isClosed;
  final DateTime closedAt;
  final String closedBy;
  final String? closedByEmail;
  final DateTime? reopenedAt;
  final String? reopenedBy;
  final String? reopenReason;
  final double totalPayout;
  final int totalEmployees;
  final String currency;
  final Map<String, PayrollReportSnapshot> snapshots;

  PayrollMonthClosure({
    required this.id,
    required this.yearMonth,
    this.companyCode = '',
    required this.isClosed,
    required this.closedAt,
    required this.closedBy,
    this.closedByEmail,
    this.reopenedAt,
    this.reopenedBy,
    this.reopenReason,
    required this.totalPayout,
    required this.totalEmployees,
    required this.currency,
    this.snapshots = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'yearMonth': yearMonth,
      'companyCode': companyCode.trim().toLowerCase(),
      'isClosed': isClosed,
      'closedAt': closedAt.toIso8601String(),
      'closedBy': closedBy,
      'closedByEmail': closedByEmail,
      'reopenedAt': reopenedAt?.toIso8601String(),
      'reopenedBy': reopenedBy,
      'reopenReason': reopenReason,
      'totalPayout': totalPayout,
      'totalEmployees': totalEmployees,
      'currency': currency,
      'snapshots': snapshots.map((k, v) => MapEntry(k, v.toMap())),
    };
  }

  factory PayrollMonthClosure.fromMap(Map<String, dynamic> map, String docId) {
    final rawSnapshots = map['snapshots'] as Map<String, dynamic>? ?? {};
    final snapshots = <String, PayrollReportSnapshot>{};
    rawSnapshots.forEach((k, v) {
      if (v is Map<String, dynamic>) {
        snapshots[k] = PayrollReportSnapshot.fromMap(v);
      }
    });

    final String cCode = resolveCompanyCode(map, docId, fallback: 'amada');
    final String ym = (map['yearMonth'] ??
            (docId.contains('_') && !docId.startsWith('closure_')
                ? docId.split('_').last
                : docId.replaceAll('closure_', '')))
        .toString();

    return PayrollMonthClosure(
      id: map['id'] ?? docId,
      yearMonth: ym,
      companyCode: cCode,
      isClosed: map['isClosed'] ?? true,
      closedAt: map['closedAt'] != null
          ? DateTime.tryParse(map['closedAt']) ?? DateTime.now()
          : DateTime.now(),
      closedBy: map['closedBy'] ?? 'HR Manager',
      closedByEmail: map['closedByEmail'],
      reopenedAt: map['reopenedAt'] != null
          ? DateTime.tryParse(map['reopenedAt'])
          : null,
      reopenedBy: map['reopenedBy'],
      reopenReason: map['reopenReason'],
      totalPayout: (map['totalPayout'] as num?)?.toDouble() ?? 0.0,
      totalEmployees: (map['totalEmployees'] as num?)?.toInt() ?? 0,
      currency: map['currency'] ?? 'USD',
      snapshots: snapshots,
    );
  }

  PayrollMonthClosure copyWith({
    String? id,
    String? yearMonth,
    String? companyCode,
    bool? isClosed,
    DateTime? closedAt,
    String? closedBy,
    String? closedByEmail,
    DateTime? reopenedAt,
    String? reopenedBy,
    String? reopenReason,
    double? totalPayout,
    int? totalEmployees,
    String? currency,
    Map<String, PayrollReportSnapshot>? snapshots,
  }) {
    return PayrollMonthClosure(
      id: id ?? this.id,
      yearMonth: yearMonth ?? this.yearMonth,
      companyCode: companyCode ?? this.companyCode,
      isClosed: isClosed ?? this.isClosed,
      closedAt: closedAt ?? this.closedAt,
      closedBy: closedBy ?? this.closedBy,
      closedByEmail: closedByEmail ?? this.closedByEmail,
      reopenedAt: reopenedAt ?? this.reopenedAt,
      reopenedBy: reopenedBy ?? this.reopenedBy,
      reopenReason: reopenReason ?? this.reopenReason,
      totalPayout: totalPayout ?? this.totalPayout,
      totalEmployees: totalEmployees ?? this.totalEmployees,
      currency: currency ?? this.currency,
      snapshots: snapshots ?? this.snapshots,
    );
  }
}

class PeriodicDailyAudit {
  final DateTime date;
  final String dateStr;
  final String dayName;
  final String shiftName;
  final String shiftTime;
  final bool isWorkingDay;
  final bool isHoliday;
  final String holidayName;
  final bool hasRecord;
  final String checkIn;
  final String checkOut;
  final int delayMinutes;
  final int earlyExitMinutes;
  final int actualMinutes;
  final int scheduledMinutes;
  final int overtimeMinutes;
  final String status;
  final List<dynamic> requests;

  PeriodicDailyAudit({
    required this.date,
    required this.dateStr,
    required this.dayName,
    required this.shiftName,
    required this.shiftTime,
    required this.isWorkingDay,
    this.isHoliday = false,
    this.holidayName = '',
    required this.hasRecord,
    required this.checkIn,
    required this.checkOut,
    required this.delayMinutes,
    required this.earlyExitMinutes,
    required this.actualMinutes,
    required this.scheduledMinutes,
    this.overtimeMinutes = 0,
    required this.status,
    this.requests = const [],
  });
}

class PeriodicReportRow {
  final CompanyEmployee employee;
  final String structureName;
  final String groupName;
  final String shiftName;
  final double requiredHours;
  final double actualWorkedHours;
  final double deficitHours;
  final int delayMinutes;
  final int delayCount;
  final int earlyExitMinutes;
  final int earlyExitCount;
  final double penaltyDeductions;
  final int penaltyDays;
  final double totalOvertimeHours;
  final double dayOvertimeHours;
  final double nightOvertimeHours;
  final int dailyLeaveDays;
  final double hourlyLeaveHours;
  final double remainingAnnualHours;
  final double remainingAnnualDays;
  final int absentDays;
  final int presentDays;
  final List<PeriodicDailyAudit> dailyAuditLogs;

  PeriodicReportRow({
    required this.employee,
    required this.structureName,
    required this.groupName,
    required this.shiftName,
    required this.requiredHours,
    required this.actualWorkedHours,
    required this.deficitHours,
    required this.delayMinutes,
    required this.delayCount,
    required this.earlyExitMinutes,
    required this.earlyExitCount,
    required this.penaltyDeductions,
    required this.penaltyDays,
    required this.totalOvertimeHours,
    required this.dayOvertimeHours,
    required this.nightOvertimeHours,
    required this.dailyLeaveDays,
    required this.hourlyLeaveHours,
    required this.remainingAnnualHours,
    required this.remainingAnnualDays,
    required this.absentDays,
    required this.presentDays,
    this.dailyAuditLogs = const [],
  });
}


