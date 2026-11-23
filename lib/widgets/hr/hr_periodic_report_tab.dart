import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/hr_models.dart';
import '../../models/request_model.dart';
import '../../providers/attendance_provider.dart';
import '../../services/export_service.dart';
import '../glass_container.dart';
import '../compact_date_picker_dialog.dart';

class HrPeriodicReportTab extends StatefulWidget {
  final String searchQuery;

  const HrPeriodicReportTab({
    super.key,
    this.searchQuery = '',
  });

  @override
  State<HrPeriodicReportTab> createState() => _HrPeriodicReportTabState();
}

class _HrPeriodicReportTabState extends State<HrPeriodicReportTab> {
  bool _isMonthMode = true;
  late DateTime _selectedMonth;
  late DateTime _startDate;
  late DateTime _endDate;

  String? _selectedStructureId;
  String? _selectedGroupId;
  late TextEditingController _searchController;
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  bool _isExporting = false;

  String _selectedMetricFilter = 'all'; // 'all', 'overtime', 'deficit', 'delay', 'early_exit', 'absence', 'leave', 'penalties'
  String _filterOperator = '>='; // '>=', '<=', '>', '<', 'any'
  late TextEditingController _thresholdController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month, DateUtils.getDaysInMonth(now.year, now.month));
    _searchController = TextEditingController(text: widget.searchQuery);
    _thresholdController = TextEditingController(text: '01:00');
  }

  @override
  void didUpdateWidget(covariant HrPeriodicReportTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _thresholdController.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _selectedMonth = DateTime(newMonth.year, newMonth.month, 1);
      _startDate = DateTime(newMonth.year, newMonth.month, 1);
      _endDate = DateTime(newMonth.year, newMonth.month, DateUtils.getDaysInMonth(newMonth.year, newMonth.month));
    });
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final sixtyDaysAgo = DateTime.now().subtract(const Duration(days: 60));
    if (_startDate.isBefore(sixtyDaysAgo)) {
      provider.loadHistoricalRecordsForRange(_startDate, _endDate);
    }
  }

  bool _isCountMetric(String metric) {
    return metric == 'absence' || metric == 'leave';
  }

  double _parseThresholdToHours(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return 0.0;
    if (clean.contains(':')) {
      final parts = clean.split(':');
      final h = double.tryParse(parts[0]) ?? 0.0;
      final m = parts.length > 1 ? (double.tryParse(parts[1]) ?? 0.0) : 0.0;
      return h + (m / 60.0);
    }
    return double.tryParse(clean) ?? 0.0;
  }

  bool _matchesMetricFilter(PeriodicReportRow row, String metric, String op, double threshold) {
    if (metric == 'all') return true;

    double value = 0.0;
    switch (metric) {
      case 'overtime':
        value = row.totalOvertimeHours;
        break;
      case 'extra_time':
        value = row.extraTimeHours;
        break;
      case 'deficit':
        value = row.deficitHours;
        break;
      case 'delay':
        value = row.delayMinutes / 60.0;
        break;
      case 'early_exit':
        value = row.earlyExitMinutes / 60.0;
        break;
      case 'absence':
        value = row.absentDays.toDouble();
        break;
      case 'leave':
        value = (row.dailyLeaveDays + (row.hourlyLeaveHours / 8.0)).toDouble();
        break;
      case 'penalties':
        value = row.penaltyDeductions;
        break;
    }

    if (op == 'any') {
      return value > 0;
    }

    switch (op) {
      case '>=':
        return value >= threshold && value > 0;
      case '<=':
        return value <= threshold && value > 0;
      case '>':
        return value > threshold;
      case '<':
        return value < threshold && value > 0;
      default:
        return value > 0;
    }
  }


  Future<void> _pickDateRange() async {
    final picked = await showCompactDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _isMonthMode = false;
        _startDate = picked.start;
        _endDate = picked.end;
      });
      if (!mounted) return;
      final provider = Provider.of<AttendanceProvider>(context, listen: false);
      final sixtyDaysAgo = DateTime.now().subtract(const Duration(days: 60));
      if (_startDate.isBefore(sixtyDaysAgo)) {
        provider.loadHistoricalRecordsForRange(_startDate, _endDate);
      }
    }
  }

  List<PeriodicReportRow> _calculateReportRows(AttendanceProvider provider) {
    final q = _searchController.text.trim().toLowerCase();

    // Filter employees
    final emps = provider.employees.where((e) {
      if (_selectedStructureId != null &&
          _selectedStructureId!.isNotEmpty &&
          e.structureId != _selectedStructureId) {
        return false;
      }
      if (_selectedGroupId != null &&
          _selectedGroupId!.isNotEmpty &&
          e.groupId != _selectedGroupId) {
        return false;
      }
      if (q.isNotEmpty) {
        final matchesName = e.name.toLowerCase().contains(q);
        final matchesId = e.id.toLowerCase().contains(q);
        final matchesEmail = e.email.toLowerCase().contains(q);
        if (!matchesName && !matchesId && !matchesEmail) return false;
      }
      return true;
    }).toList();

    final allCompanyRequests = [
      ...provider.allCompanyRequests,
      ...provider.requests,
    ];

    final cleanStart = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final cleanEnd = DateTime(_endDate.year, _endDate.month, _endDate.day);
    final totalDaysCount = cleanEnd.difference(cleanStart).inDays + 1;

    final rows = <PeriodicReportRow>[];

    for (final emp in emps) {
      // Structure info
      final structure = provider.structures.firstWhere(
        (s) => s.id == emp.structureId,
        orElse: () => OrgStructure(id: '', name: '-', location: '', capacity: 0),
      );

      // Group info
      final group = provider.groups.firstWhere(
        (g) => g.id == emp.groupId,
        orElse: () => EmployeeGroup(id: '', name: '-', shiftId: ''),
      );

      // Shift info
      final defaultShift = provider.shifts.firstWhere(
        (s) => s.id == group.shiftId,
        orElse: () => WorkShift(
          id: '',
          name: '-',
          startTime: '09:00',
          endTime: '17:00',
          workingDays: [1, 2, 3, 4, 5],
        ),
      );

      final empRequests = allCompanyRequests.where((r) {
        return provider.matchesEmployeeRequest(r, emp);
      }).toList();

      final empRecords = (emp.id == provider.currentEmployee?.id && (emp.companyCode.isEmpty || emp.companyCode.toLowerCase() == provider.currentCompanyCode.toLowerCase()))
          ? provider.records
          : provider.allCompanyRecords.where((r) {
              return provider.matchesEmployeeRecord(r, emp);
            }).toList();

      int totalRequiredMinutes = 0;
      int totalActualMinutes = 0;
      int totalDeficitMinutes = 0;
      int totalDelayMinutes = 0;
      int delayCount = 0;
      int totalEarlyExitMinutes = 0;
      int earlyExitCount = 0;
      double totalPenalties = 0.0;
      int totalExtraMinutes = 0;
      int totalOvertimeMinutes = 0;
      int totalDayOtMinutes = 0;
      int totalNightOtMinutes = 0;
      int dailyLeaveDays = 0;
      double hourlyLeaveMinutes = 0.0;
      int absentDays = 0;
      int presentDays = 0;

      // Tier occurrence tracking for penalties matching attendance_provider.dart
      int delayTier1Occurrences = 0;
      int delayTier2Occurrences = 0;
      int delayTier3Occurrences = 0;
      int earlyExitTier1Occurrences = 0;
      int earlyExitTier2Occurrences = 0;
      int earlyExitTier3Occurrences = 0;

      final dailyAuditLogs = <PeriodicDailyAudit>[];

      DateTime? empStart;
      if (emp.startDate.isNotEmpty) {
        try {
          empStart = DateTime.parse(emp.startDate);
        } catch (_) {}
      }
      DateTime? empEnd;
      if (emp.endDate != null && emp.endDate!.isNotEmpty) {
        try {
          empEnd = DateTime.parse(emp.endDate!);
        } catch (_) {}
      }

      for (int i = 0; i < totalDaysCount; i++) {
        final date = cleanStart.add(Duration(days: i));
        final cleanDate = DateTime(date.year, date.month, date.day);
        if (empStart != null) {
          final sOnly = DateTime(empStart.year, empStart.month, empStart.day);
          if (cleanDate.isBefore(sOnly)) continue;
        }
        if (empEnd != null) {
          final eOnly = DateTime(empEnd.year, empEnd.month, empEnd.day);
          if (cleanDate.isAfter(eOnly)) continue;
        }
        final dateStrFormatted = DateFormat('MMMM d, yyyy').format(date);
        final shortDateStr = DateFormat('MMMM d').format(date);

        final dayShift = provider.getShiftForDate(emp, date);
        final isWorkingDay = dayShift.isWorkingDay(date);

        final holiday = provider.getHolidayForEmployee(date, group.id);
        final isHoliday = holiday != null;

        final dayRecords = provider.getRecordsForDate(
          date,
          emp: emp,
          recordsPool: empRecords,
          requestsPool: empRequests,
        )..sort((a, b) => a.checkIn.compareTo(b.checkIn));

        final dayRequests = <Request>[];
        bool hasApprovedLeave = false;
        String approvedLeaveType = '';
        double dayHourlyMinutes = 0.0;
        bool hasApprovedMissingPunch = false;
        bool hasApprovedOt = false;
        int approvedOtMinutes = 0;

        for (var req in empRequests) {
          final reqDate = req.date;
          bool matches = false;
          if (reqDate.contains(' - ')) {
            try {
              final parts = reqDate.split(' - ');
              final end = DateFormat('MMMM d, yyyy').parse(parts[1].trim());
              var startStr = parts[0].trim();
              if (!startStr.contains(',')) startStr = '$startStr, ${end.year}';
              final start = DateFormat('MMMM d, yyyy').parse(startStr);
              final sOnly = DateTime(start.year, start.month, start.day);
              final eOnly = DateTime(end.year, end.month, end.day);
              if ((date.isAtSameMomentAs(sOnly) || date.isAfter(sOnly)) &&
                  (date.isAtSameMomentAs(eOnly) || date.isBefore(eOnly))) {
                matches = true;
              }
            } catch (_) {}
          } else if (reqDate.contains(dateStrFormatted) || reqDate.contains(shortDateStr)) {
            matches = true;
          }

          if (matches) {
            dayRequests.add(req);
            if (req.status == 'Approved') {
              if (req.type == 'Hourly Leave' || req.type.toLowerCase().contains('hourly')) {
                final mins = parseHourlyLeaveDurationMinutes(req.duration);
                dayHourlyMinutes += mins > 0 ? mins : 60;
              } else if (req.type.contains('Leave')) {
                hasApprovedLeave = true;
                approvedLeaveType = req.type;
              } else if (req.type == 'Missing Punch' ||
                  req.type == 'Forgot to Clock In' ||
                  req.type == 'Forgot to Clock Out') {
                hasApprovedMissingPunch = true;
              } else if (req.type == 'Overtime Approval') {
                hasApprovedOt = true;
                final mins = parseOvertimeApprovalDurationMinutes(req.duration);
                approvedOtMinutes += mins > 0 ? mins : 0;
              }
            }
          }
        }

        final startTimeStr = dayShift.getStartTimeForDate(date);
        final endTimeStr = dayShift.getEndTimeForDate(date);
        final sParts = startTimeStr.split(':');
        final eParts = endTimeStr.split(':');
        final shiftStartMins = sParts.length >= 2 ? int.parse(sParts[0]) * 60 + int.parse(sParts[1]) : 540;
        final shiftEndMins = eParts.length >= 2 ? int.parse(eParts[0]) * 60 + int.parse(eParts[1]) : 1020;
        int shiftDurationMins = dayShift.getShiftDurationMinutesForDate(date);

        final shiftStart = DateTime(
          date.year,
          date.month,
          date.day,
          shiftStartMins ~/ 60,
          shiftStartMins % 60,
        );
        var shiftEnd = DateTime(
          date.year,
          date.month,
          date.day,
          shiftEndMins ~/ 60,
          shiftEndMins % 60,
        );
        if (shiftEnd.isBefore(shiftStart) ||
            shiftEnd.isAtSameMomentAs(shiftStart)) {
          shiftEnd = shiftEnd.add(const Duration(days: 1));
        }

        final isToday = DateUtils.isSameDay(date, DateTime.now());
        final hasUnexcusedMissedPunch = !hasApprovedMissingPunch &&
            dayRecords.isNotEmpty &&
            dayRecords.any((rec) {
              if (rec.checkIn == rec.checkOut) return true;
              if (rec.checkOut == null) {
                if (!isToday) return true;
                if (DateTime.now().isAfter(shiftEnd)) return true;
              }
              return false;
            });

        int dayDelayMins = 0;
        int dayEarlyMins = 0;
        int dayActualMins = 0;
        int dayExtraMins = 0;
        int dayNightExtraMins = 0;
        int dayOtMins = 0;
        String dayStatus = 'Off Day';

        if (dayRecords.isEmpty) {
          if (isHoliday) {
            dayStatus = 'Holiday: ${holiday.name}';
          } else if (!isWorkingDay) {
            dayStatus = 'Weekend / Off Day';
          } else if (hasApprovedLeave) {
            dayStatus = approvedLeaveType;
            dailyLeaveDays++;
          } else {
            if (dayHourlyMinutes > 0) {
              hourlyLeaveMinutes += dayHourlyMinutes;
            }
            dayStatus = dayHourlyMinutes > 0
                ? 'Absent (${(dayHourlyMinutes / 60).toStringAsFixed(1)}h Leave)'
                : 'Absent';
            absentDays++;
            totalRequiredMinutes += shiftDurationMins;
            final deficit = (shiftDurationMins - dayHourlyMinutes).clamp(0, shiftDurationMins).toInt();
            totalDeficitMinutes += deficit;
          }
        } else if (hasUnexcusedMissedPunch) {
          if (isHoliday) {
            dayStatus = 'Missed Punch (Holiday)';
          } else if (!isWorkingDay) {
            dayStatus = 'Missed Punch (Off Day)';
          } else {
            if (dayHourlyMinutes > 0) {
              hourlyLeaveMinutes += dayHourlyMinutes;
            }
            dayStatus = 'Missed Punch';
            totalRequiredMinutes += shiftDurationMins;
            final deficit = (shiftDurationMins - dayHourlyMinutes).clamp(0, shiftDurationMins).toInt();
            totalDeficitMinutes += deficit;
          }
        } else {
          // Employee has valid records on this day
          presentDays++;

          for (var r in dayRecords) {
            dayActualMins += r.duration.inMinutes;
          }
          totalActualMinutes += dayActualMins;

          final isSpecial = dayShift.isSpecialShiftForDate(date);

          if (!isWorkingDay || isHoliday) {
            // Worked on Weekend or Holiday: 0 required hours, all worked time is Extra Time!
            dayExtraMins = dayActualMins;
            dayDelayMins = 0;
            dayEarlyMins = 0;

            if (group.nightOvertimeAllowed) {
              for (var r in dayRecords) {
                final cIn = r.checkIn;
                final cOut = r.checkOut ?? cIn;
                dayNightExtraMins += group.calculateNightMinutes(cIn, cOut);
              }
            }

            dayStatus = isHoliday
                ? 'Worked on Holiday (${holiday.name})'
                : 'Worked on Off Day';
          } else if (hasApprovedLeave) {
            dailyLeaveDays++;
            dayExtraMins = dayActualMins;
            dayDelayMins = 0;
            dayEarlyMins = 0;
            dayStatus = '$approvedLeaveType (Worked ${(dayActualMins / 60.0).toStringAsFixed(1)}h)';
          } else {
            // Normal working day attendance
            totalRequiredMinutes += shiftDurationMins;

            if (isSpecial) {
              // Special Shift (12h/24h): continuous, no delay/early exit penalties
              dayDelayMins = 0;
              dayEarlyMins = 0;
              if (dayActualMins > shiftDurationMins) {
                dayExtraMins = dayActualMins - shiftDurationMins;
                if (group.nightOvertimeAllowed && dayRecords.isNotEmpty) {
                  final lastRec = dayRecords.last;
                  final lastOut = lastRec.checkOut ?? lastRec.checkIn;
                  final extraStart = lastOut.subtract(Duration(minutes: dayExtraMins));
                  dayNightExtraMins = group.calculateNightMinutes(extraStart, lastOut);
                }
              }
            } else {
              // Standard shift: calculate extra time before/after shift, delay, and early exit
              for (var r in dayRecords) {
                final cIn = r.checkIn;
                final cOut = r.checkOut ?? cIn;

                if (cIn.isBefore(shiftStart)) {
                  final endBefore = cOut.isBefore(shiftStart) ? cOut : shiftStart;
                  dayExtraMins += endBefore.difference(cIn).inMinutes;
                  if (group.nightOvertimeAllowed) {
                    dayNightExtraMins += group.calculateNightMinutes(cIn, endBefore);
                  }
                }
                if (cOut.isAfter(shiftEnd)) {
                  final startAfter = cIn.isAfter(shiftEnd) ? cIn : shiftEnd;
                  dayExtraMins += cOut.difference(startAfter).inMinutes;
                  if (group.nightOvertimeAllowed) {
                    dayNightExtraMins += group.calculateNightMinutes(startAfter, cOut);
                  }
                }
              }

              // Delay calculation with forgiveness
              final shiftRecords = dayRecords.where((r) => r.checkIn.isBefore(shiftEnd)).toList();
              if (shiftRecords.isNotEmpty) {
                final firstRec = shiftRecords.first;
                final diff = firstRec.checkIn.difference(shiftStart).inMinutes;
                if (diff > dayShift.forgivenessOfDelay) {
                  dayDelayMins = diff;
                }

                // Early exit calculation with forgiveness
                final lastRec = shiftRecords.last;
                if (lastRec.checkOut != null) {
                  final diffEarly = shiftEnd.difference(lastRec.checkOut!).inMinutes;
                  if (diffEarly > dayShift.earlyExit) {
                    dayEarlyMins = diffEarly;
                  }
                }
              }
            }

            // Excuse delay & early exit with approved hourly leave
            if (dayHourlyMinutes > 0) {
              hourlyLeaveMinutes += dayHourlyMinutes;
              int remainingHourly = dayHourlyMinutes.toInt();
              if (dayDelayMins > 0) {
                final excused = math.min(dayDelayMins, remainingHourly);
                dayDelayMins -= excused;
                remainingHourly -= excused;
              }
              if (dayEarlyMins > 0 && remainingHourly > 0) {
                final excused = math.min(dayEarlyMins, remainingHourly);
                dayEarlyMins -= excused;
                remainingHourly -= excused;
              }
            }

            // Deficit on working day
            final effectiveRequiredMins = (shiftDurationMins - dayHourlyMinutes).clamp(0, shiftDurationMins).toInt();
            if (dayActualMins < effectiveRequiredMins) {
              final deficit = effectiveRequiredMins - dayActualMins;
              totalDeficitMinutes += deficit;
            }

            // Delay & Early Exit penalty evaluations per tier with forgiveness
            double delayPenalty = 0.0;
            if (dayDelayMins > 0 && group.delayPenaltiesEnabled) {
              totalDelayMinutes += dayDelayMins;
              delayCount++;
              if (dayDelayMins >= group.delayTier1Min && dayDelayMins <= group.delayTier1Max) {
                delayTier1Occurrences++;
                if (delayTier1Occurrences > group.delayTier1Forgiveness) {
                  delayPenalty = group.delayTier1Penalty;
                }
              } else if (dayDelayMins >= group.delayTier2Min && dayDelayMins <= group.delayTier2Max) {
                delayTier2Occurrences++;
                if (delayTier2Occurrences > group.delayTier2Forgiveness) {
                  delayPenalty = group.delayTier2Penalty;
                }
              } else if (dayDelayMins >= group.delayTier3Min) {
                delayTier3Occurrences++;
                if (delayTier3Occurrences > group.delayTier3Forgiveness) {
                  delayPenalty = group.delayTier3Penalty;
                }
              }
            }

            double earlyExitPenalty = 0.0;
            if (dayEarlyMins > 0 && group.earlyExitPenaltiesEnabled) {
              totalEarlyExitMinutes += dayEarlyMins;
              earlyExitCount++;
              if (dayEarlyMins >= group.earlyExitTier1Min && dayEarlyMins <= group.earlyExitTier1Max) {
                earlyExitTier1Occurrences++;
                if (earlyExitTier1Occurrences > group.earlyExitTier1Forgiveness) {
                  earlyExitPenalty = group.earlyExitTier1Penalty;
                }
              } else if (dayEarlyMins >= group.earlyExitTier2Min && dayEarlyMins <= group.earlyExitTier2Max) {
                earlyExitTier2Occurrences++;
                if (earlyExitTier2Occurrences > group.earlyExitTier2Forgiveness) {
                  earlyExitPenalty = group.earlyExitTier2Penalty;
                }
              } else if (dayEarlyMins >= group.earlyExitTier3Min) {
                earlyExitTier3Occurrences++;
                if (earlyExitTier3Occurrences > group.earlyExitTier3Forgiveness) {
                  earlyExitPenalty = group.earlyExitTier3Penalty;
                }
              }
            }

            totalPenalties += (delayPenalty + earlyExitPenalty);

            // Set day status
            if (dayDelayMins > 0 && dayEarlyMins > 0) {
              dayStatus = 'Late ($dayDelayMins m) & Early Exit ($dayEarlyMins m)';
            } else if (dayDelayMins > 0) {
              dayStatus = 'Late ($dayDelayMins m)';
            } else if (dayEarlyMins > 0) {
              dayStatus = 'Early Exit ($dayEarlyMins m)';
            } else if (dayExtraMins > 0) {
              dayStatus = 'Present (+${(dayExtraMins / 60.0).toStringAsFixed(1)}h Extra)';
            } else {
              dayStatus = 'Present';
            }
          }

          // Accumulate raw Extra Time
          totalExtraMinutes += dayExtraMins;

          // Overtime calculation with group multipliers
          if (dayExtraMins > 0) {
            final effectiveOtExtra = hasApprovedOt && approvedOtMinutes > 0
                ? math.min(dayExtraMins, approvedOtMinutes)
                : dayExtraMins;

            if (group.overtimeAllowed || hasApprovedOt) {
              final effNight = dayExtraMins > 0
                  ? (dayNightExtraMins * (effectiveOtExtra / dayExtraMins)).round()
                  : 0;

              dayOtMins = group.calculateOvertimeMinutes(
                dayExtraMinutes: effectiveOtExtra,
                nightExtraMinutes: effNight,
                isWeekend: !isWorkingDay,
                isHoliday: isHoliday,
              );

              final standardRatio = isHoliday
                  ? group.holidayOvertimeRatio
                  : (!isWorkingDay ? group.weekendOvertimeRatio : 1.0);

              if (group.nightOvertimeAllowed && effNight > 0) {
                final nightOtPart = (effectiveOtExtra * (effNight / dayExtraMins)).round();
                final dayOtPart = effectiveOtExtra - nightOtPart;
                totalDayOtMinutes += (dayOtPart * standardRatio).toInt();
                totalNightOtMinutes += (nightOtPart * group.nightOvertimeRatio).toInt();
              } else {
                totalDayOtMinutes += (effectiveOtExtra * standardRatio).toInt();
              }
              totalOvertimeMinutes += dayOtMins;
            } else {
              dayOtMins = 0;
            }
          }
        }

        dailyAuditLogs.add(PeriodicDailyAudit(
          date: date,
          dateStr: DateFormat('yyyy-MM-dd').format(date),
          dayName: DateFormat('EEEE').format(date),
          shiftName: dayShift.name,
          shiftTime: '$startTimeStr - $endTimeStr',
          isWorkingDay: isWorkingDay,
          isHoliday: isHoliday,
          holidayName: holiday?.name ?? '',
          hasRecord: dayRecords.isNotEmpty,
          checkIn: dayRecords.isNotEmpty ? DateFormat('HH:mm').format(dayRecords.first.checkIn) : '-',
          checkOut: (dayRecords.isNotEmpty && dayRecords.last.checkOut != null)
              ? DateFormat('HH:mm').format(dayRecords.last.checkOut!)
              : '-',
          delayMinutes: dayDelayMins,
          earlyExitMinutes: dayEarlyMins,
          actualMinutes: dayActualMins,
          scheduledMinutes: (isWorkingDay && !isHoliday) ? shiftDurationMins : 0,
          overtimeMinutes: dayOtMins,
          extraTimeMinutes: dayExtraMins,
          status: dayStatus,
          requests: dayRequests,
        ));
      }

      rows.add(PeriodicReportRow(
        employee: emp,
        structureName: structure.name,
        groupName: group.name,
        shiftName: defaultShift.name,
        requiredHours: totalRequiredMinutes / 60.0,
        actualWorkedHours: totalActualMinutes / 60.0,
        deficitHours: totalDeficitMinutes / 60.0,
        delayMinutes: totalDelayMinutes,
        delayCount: delayCount,
        earlyExitMinutes: totalEarlyExitMinutes,
        earlyExitCount: earlyExitCount,
        penaltyDeductions: totalPenalties,
        penaltyDays: totalPenalties.round(),
        extraTimeHours: totalExtraMinutes / 60.0,
        totalOvertimeHours: totalOvertimeMinutes / 60.0,
        dayOvertimeHours: totalDayOtMinutes / 60.0,
        nightOvertimeHours: totalNightOtMinutes / 60.0,
        dailyLeaveDays: dailyLeaveDays,
        hourlyLeaveHours: hourlyLeaveMinutes / 60.0,
        remainingAnnualHours: emp.annualLeaveBalance,
        remainingAnnualDays: emp.annualLeaveBalance / 8.0,
        absentDays: absentDays,
        presentDays: presentDays,
        dailyAuditLogs: dailyAuditLogs,
      ));
    }

    if (_selectedMetricFilter != 'all') {
      final threshold = _parseThresholdToHours(_thresholdController.text);
      return rows.where((row) {
        return _matchesMetricFilter(row, _selectedMetricFilter, _filterOperator, threshold);
      }).toList();
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rows = _calculateReportRows(provider);

    // Aggregate totals for KPI Cards
    double aggDeficitHours = 0;
    double aggExtraHours = 0;
    double aggOvertimeHours = 0;
    int aggDelayCount = 0;
    int aggEarlyCount = 0;
    double aggPenalties = 0;
    int aggAbsences = 0;
    int aggLeaves = 0;

    for (var r in rows) {
      aggDeficitHours += r.deficitHours;
      aggExtraHours += r.extraTimeHours;
      aggOvertimeHours += r.totalOvertimeHours;
      aggDelayCount += r.delayCount;
      aggEarlyCount += r.earlyExitCount;
      aggPenalties += r.penaltyDeductions;
      aggAbsences += r.absentDays;
      aggLeaves += r.dailyLeaveDays;
    }

    return Column(
      children: [
        // Top Filter Bar & Time Presets
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            children: [
              _buildControlToolbar(provider, isDark, rows),
              const SizedBox(height: 12),
              _buildKpiSummaryCards(
                isDark: isDark,
                provider: provider,
                totalDeficitHours: aggDeficitHours,
                totalExtraHours: aggExtraHours,
                totalOvertimeHours: aggOvertimeHours,
                totalDelays: aggDelayCount,
                totalEarlyExits: aggEarlyCount,
                totalPenalties: aggPenalties,
                totalAbsences: aggAbsences,
                totalLeaves: aggLeaves,
                totalEmployees: rows.length,
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Main Data Table
        Expanded(
          child: rows.isEmpty
              ? _buildEmptyState(isDark, provider)
              : _buildReportTable(rows, isDark, provider),
        ),
      ],
    );
  }

  Widget _buildControlToolbar(AttendanceProvider provider, bool isDark, List<PeriodicReportRow> rows) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 850;

        final modeAndDatePicker = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mode Segment
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  _buildModeButton(
                    title: provider.translate('month_view'),
                    isSelected: _isMonthMode,
                    icon: Icons.calendar_month_outlined,
                    onTap: () => setState(() => _isMonthMode = true),
                    isDark: isDark,
                  ),
                  _buildModeButton(
                    title: provider.translate('custom_range'),
                    isSelected: !_isMonthMode,
                    icon: Icons.date_range_outlined,
                    onTap: () => setState(() => _isMonthMode = false),
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // Date Picker Display
            if (_isMonthMode) ...[
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: provider.translate('previous_month'),
                onPressed: () => _onMonthChanged(DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Text(
                      '${provider.translate('month_${_selectedMonth.month}')} ${_selectedMonth.year}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: provider.translate('next_month'),
                onPressed: () => _onMonthChanged(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1)),
              ),
            ] else ...[
              InkWell(
                onTap: _pickDateRange,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Text(
                        '${DateFormat('yyyy-MM-dd').format(_startDate)}  ➔  ${DateFormat('yyyy-MM-dd').format(_endDate)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_drop_down_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );

        final structureDropdown = Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedStructureId,
              hint: Text(provider.translate('all_structures_dropdown'), style: const TextStyle(fontSize: 12.5)),
              icon: const Icon(Icons.apartment_rounded, size: 16),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(provider.translate('all_structures_dropdown'), style: const TextStyle(fontSize: 12.5)),
                ),
                ...provider.structures.map((s) => DropdownMenuItem<String?>(
                      value: s.id,
                      child: Text(s.name, style: const TextStyle(fontSize: 12.5)),
                    )),
              ],
              onChanged: (val) => setState(() => _selectedStructureId = val),
            ),
          ),
        );

        final groupDropdown = Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedGroupId,
              hint: Text(provider.translate('all_groups_dropdown'), style: const TextStyle(fontSize: 12.5)),
              icon: const Icon(Icons.people_alt_outlined, size: 16),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(provider.translate('all_groups_dropdown'), style: const TextStyle(fontSize: 12.5)),
                ),
                ...provider.groups.map((g) => DropdownMenuItem<String?>(
                      value: g.id,
                      child: Text(g.name, style: const TextStyle(fontSize: 12.5)),
                    )),
              ],
              onChanged: (val) => setState(() => _selectedGroupId = val),
            ),
          ),
        );

        final searchField = SizedBox(
          height: 38,
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              hintText: provider.translate('search_periodic_employee_hint'),
              hintStyle: const TextStyle(fontSize: 12.5),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
              ),
            ),
          ),
        );

        final exportButtons = [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            icon: const Icon(Icons.table_chart_rounded, size: 16),
            label: Text(provider.translate('excel_export_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            onPressed: _isExporting ? null : () => _exportExcel(rows, provider),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: Text(provider.translate('pdf_export_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            onPressed: _isExporting ? null : () => _exportPdf(rows, provider),
          ),
        ];

        if (isMobile) {
          return GlassContainer(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: modeAndDatePicker,
                ),
                const SizedBox(height: 10),
                searchField,
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      structureDropdown,
                      const SizedBox(width: 8),
                      groupDropdown,
                      const SizedBox(width: 8),
                      _buildMetricFilterControls(isDark, provider),
                      const SizedBox(width: 10),
                      ...exportButtons,
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return GlassContainer(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              modeAndDatePicker,
              const SizedBox(height: 12),
              Row(
                children: [
                  structureDropdown,
                  const SizedBox(width: 10),
                  groupDropdown,
                  const SizedBox(width: 10),
                  _buildMetricFilterControls(isDark, provider),
                  const SizedBox(width: 10),
                  Expanded(child: searchField),
                  const SizedBox(width: 12),
                  ...exportButtons,
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeButton({
    required String title,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.25) : const Color(0xFF10B981))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? (isDark ? const Color(0xFF34D399) : Colors.white) : Colors.grey,
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? (isDark ? const Color(0xFF34D399) : Colors.white) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricFilterControls(bool isDark, AttendanceProvider provider) {
    final isFiltering = _selectedMetricFilter != 'all';
    final isCount = _isCountMetric(_selectedMetricFilter);

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isFiltering
            ? const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.15 : 0.08)
            : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFiltering
              ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
              : (isDark ? Colors.white24 : Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_alt_outlined,
            size: 16,
            color: isFiltering ? const Color(0xFF3B82F6) : (isDark ? Colors.white60 : Colors.blueGrey),
          ),
          const SizedBox(width: 6),

          // Metric Dropdown
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedMetricFilter,
              isDense: true,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isFiltering ? FontWeight.bold : FontWeight.w500,
                color: isFiltering ? const Color(0xFF3B82F6) : (isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
              items: [
                DropdownMenuItem(value: 'all', child: Text(provider.translate('all_employees'))),
                DropdownMenuItem(value: 'overtime', child: Text(provider.translate('overtime'))),
                DropdownMenuItem(value: 'extra_time', child: Text(provider.translate('extra_time'))),
                DropdownMenuItem(value: 'deficit', child: Text(provider.translate('attendance_deficit'))),
                DropdownMenuItem(value: 'delay', child: Text(provider.translate('late_arrival'))),
                DropdownMenuItem(value: 'early_exit', child: Text(provider.translate('early_exit'))),
                DropdownMenuItem(value: 'absence', child: Text(provider.translate('unexcused_absence'))),
                DropdownMenuItem(value: 'leave', child: Text(provider.translate('leaves_filter'))),
                DropdownMenuItem(value: 'penalties', child: Text(provider.translate('penalties'))),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedMetricFilter = val;
                    if (_selectedMetricFilter == 'absence' || _selectedMetricFilter == 'leave') {
                      _thresholdController.text = '1';
                    } else if (_thresholdController.text == '1') {
                      _thresholdController.text = '01:00';
                    }
                  });
                }
              },
            ),
          ),

          if (isFiltering) ...[
            const SizedBox(width: 6),
            Container(width: 1, height: 20, color: isDark ? Colors.white24 : Colors.grey.shade300),
            const SizedBox(width: 6),

            // Operator Dropdown
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterOperator,
                isDense: true,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                items: [
                  DropdownMenuItem(value: 'any', child: Text(provider.translate('any_operator'))),
                  DropdownMenuItem(value: '>=', child: Text(provider.translate('operator_gte'))),
                  DropdownMenuItem(value: '<=', child: Text(provider.translate('operator_lte'))),
                  DropdownMenuItem(value: '>', child: Text(provider.translate('operator_gt'))),
                  DropdownMenuItem(value: '<', child: Text(provider.translate('operator_lt'))),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _filterOperator = val);
                  }
                },
              ),
            ),

            if (_filterOperator != 'any') ...[
              const SizedBox(width: 6),

              // Threshold text field
              Container(
                width: isCount ? 55 : 68,
                height: 28,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                  ),
                ),
                child: TextField(
                  controller: _thresholdController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B82F6),
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    border: InputBorder.none,
                    hintText: isCount ? '1' : '01:00',
                    hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),

              // Quick preset popup for threshold
              PopupMenuButton<String>(
                tooltip: provider.translate('quick_values'),
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: Icon(
                  Icons.arrow_drop_down_circle_outlined,
                  size: 16,
                  color: isDark ? Colors.white60 : Colors.blueGrey.shade600,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onSelected: (val) {
                  setState(() {
                    _thresholdController.text = val;
                  });
                },
                itemBuilder: (context) {
                  if (isCount) {
                    return [
                      PopupMenuItem(value: '1', child: Text(provider.translate('one_day'))),
                      PopupMenuItem(value: '2', child: Text(provider.translate('n_days', params: {'count': '2'}))),
                      PopupMenuItem(value: '3', child: Text(provider.translate('n_days', params: {'count': '3'}))),
                      PopupMenuItem(value: '5', child: Text(provider.translate('n_days', params: {'count': '5'}))),
                    ];
                  }
                  return [
                    PopupMenuItem(value: '00:30', child: Text('${provider.translate('n_mins', params: {'count': '30'})} (00:30)')),
                    PopupMenuItem(value: '01:00', child: Text('${provider.translate('one_hour')} (01:00)')),
                    PopupMenuItem(value: '01:30', child: const Text('01:30')),
                    PopupMenuItem(value: '02:00', child: Text('${provider.translate('n_hours', params: {'count': '2'})} (02:00)')),
                    PopupMenuItem(value: '03:00', child: Text('${provider.translate('n_hours', params: {'count': '3'})} (03:00)')),
                    PopupMenuItem(value: '05:00', child: Text('${provider.translate('n_hours', params: {'count': '5'})} (05:00)')),
                  ];
                },
              ),
            ],

            // Clear button
            InkWell(
              onTap: () {
                setState(() {
                  _selectedMetricFilter = 'all';
                  _filterOperator = '>=';
                  _thresholdController.text = '01:00';
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(Icons.close_rounded, size: 15, color: Colors.grey),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKpiSummaryCards({
    required bool isDark,
    required AttendanceProvider provider,
    required double totalDeficitHours,
    required double totalExtraHours,
    required double totalOvertimeHours,
    required int totalDelays,
    required int totalEarlyExits,
    required double totalPenalties,
    required int totalAbsences,
    required int totalLeaves,
    required int totalEmployees,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        final tiles = [
          _buildMetricTile(
            title: provider.translate('total_deficit_card'),
            value: '${totalDeficitHours.toStringAsFixed(1)} ${provider.translate('unit_hrs_short')}',
            subtitle: provider.translate('missing_duty_hours_sub'),
            icon: Icons.hourglass_bottom_rounded,
            accentColor: const Color(0xFFEF4444),
            isDark: isDark,
          ),
          _buildMetricTile(
            title: provider.translate('total_overtime_card'),
            value: '${totalOvertimeHours.toStringAsFixed(1)} ${provider.translate('unit_hrs_short')}',
            subtitle: '${provider.translate('extra_time')}: ${totalExtraHours.toStringAsFixed(1)} ${provider.translate('unit_hrs_short')}',
            icon: Icons.bolt_rounded,
            accentColor: const Color(0xFF10B981),
            isDark: isDark,
          ),
          _buildMetricTile(
            title: provider.translate('delays_early_exits_card'),
            value: '$totalDelays | $totalEarlyExits',
            subtitle: provider.translate('lates_early_departs_sub'),
            icon: Icons.timer_outlined,
            accentColor: const Color(0xFFF59E0B),
            isDark: isDark,
          ),
          _buildMetricTile(
            title: provider.translate('penalties_deductions_card'),
            value: '${totalPenalties.toStringAsFixed(1)} ${provider.translate('unit_days_short')}',
            subtitle: provider.translate('policy_deductions_sub'),
            icon: Icons.gavel_rounded,
            accentColor: const Color(0xFF8B5CF6),
            isDark: isDark,
          ),
          _buildMetricTile(
            title: provider.translate('absences_leaves_card'),
            value: '$totalAbsences ${provider.translate('unit_absences_short')} | $totalLeaves ${provider.translate('unit_leaves_short')}',
            subtitle: provider.translate('for_n_employees_sub', params: {'count': '$totalEmployees'}),
            icon: Icons.event_busy_rounded,
            accentColor: const Color(0xFF0284C7),
            isDark: isDark,
          ),
        ];

        if (isMobile) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (int i = 0; i < tiles.length; i++) ...[
                  SizedBox(width: 155, child: tiles[i]),
                  if (i < tiles.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          );
        }

        return Row(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              Expanded(child: tiles[i]),
              if (i < tiles.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTable(List<PeriodicReportRow> rows, bool isDark, AttendanceProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: GlassContainer(
        padding: const EdgeInsets.all(0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Scrollbar(
            controller: _verticalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _verticalController,
              scrollDirection: Axis.vertical,
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 46,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    horizontalMargin: 16,
                    columnSpacing: 18,
                    headingRowColor: WidgetStateProperty.all(
                      isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
                    ),
                    columns: [
                      _buildHeaderCol(provider.translate('employee_col'), isDark: isDark),
                      _buildHeaderCol(provider.translate('dept_col'), isDark: isDark),
                      _buildHeaderCol(provider.translate('group_policy_col'), isDark: isDark),
                      _buildHeaderCol(provider.translate('req_hrs_col'), isDark: isDark, isNumeric: true),
                      _buildHeaderCol(provider.translate('actual_hrs_col'), isDark: isDark, isNumeric: true),
                      _buildHeaderCol(provider.translate('deficit_shortage_col'), isDark: isDark, isNumeric: true),
                      _buildHeaderCol(provider.translate('delay_m_col'), isDark: isDark, isNumeric: true),
                      _buildHeaderCol(provider.translate('early_exit_m_col'), isDark: isDark, isNumeric: true),
                      _buildHeaderCol(provider.translate('penalties_col'), isDark: isDark, isNumeric: true),
                      _buildHeaderCol(provider.translate('extra_time_hrs_col'), isDark: isDark, isNumeric: true),
                      _buildHeaderCol(provider.translate('overtime_hrs_col'), isDark: isDark, isNumeric: true),
                      _buildHeaderCol(provider.translate('daily_leaves_col'), isDark: isDark, isNumeric: true),
                      _buildHeaderCol(provider.translate('hourly_perm_col'), isDark: isDark, isNumeric: true),
                      _buildHeaderCol(provider.translate('remaining_annual_col'), isDark: isDark, isNumeric: true),
                      _buildHeaderCol(provider.translate('absences_col'), isDark: isDark, isNumeric: true),
                      _buildHeaderCol(provider.translate('daily_audit_col'), isDark: isDark),
                    ],
                    rows: rows.map((r) {
                      final hasDeficit = r.deficitHours > 0;
                      final hasDelay = r.delayMinutes > 0;
                      final hasEarly = r.earlyExitMinutes > 0;
                      final hasOt = r.totalOvertimeHours > 0;
                      final hasAbsence = r.absentDays > 0;

                      return DataRow(
                        color: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9);
                          }
                          return rows.indexOf(r) % 2 == 0
                              ? Colors.transparent
                              : (isDark ? Colors.white.withValues(alpha: 0.015) : const Color(0xFFF8FAFC));
                        }),
                        cells: [
                          // Employee Cell
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  child: Text(
                                    r.employee.name.isNotEmpty ? r.employee.name[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.employee.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      'ID: ${r.employee.id} • ${r.employee.position}',
                                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Department
                          DataCell(Text(r.structureName, style: const TextStyle(fontSize: 12))),

                          // Group Policy
                          DataCell(Text(r.groupName, style: const TextStyle(fontSize: 12))),

                          // Required Hours
                          DataCell(Text('${r.requiredHours.toStringAsFixed(1)}${provider.translate('unit_hrs_short')}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5))),

                          // Actual Hours
                          DataCell(Text('${r.actualWorkedHours.toStringAsFixed(1)}${provider.translate('unit_hrs_short')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),

                          // Deficit Hours
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: hasDeficit ? const Color(0xFFEF4444).withValues(alpha: 0.12) : const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: hasDeficit ? const Color(0xFFEF4444).withValues(alpha: 0.3) : const Color(0xFF10B981).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                hasDeficit ? '-${r.deficitHours.toStringAsFixed(1)}${provider.translate('unit_hrs_short')}' : '0.0${provider.translate('unit_hrs_short')}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: hasDeficit ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ),

                          // Delay
                          DataCell(
                            Text(
                              hasDelay ? '${r.delayMinutes}m (${r.delayCount}x)' : '-',
                              style: TextStyle(
                                fontWeight: hasDelay ? FontWeight.bold : FontWeight.normal,
                                color: hasDelay ? const Color(0xFFF59E0B) : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),

                          // Early Exit
                          DataCell(
                            Text(
                              hasEarly ? '${r.earlyExitMinutes}m (${r.earlyExitCount}x)' : '-',
                              style: TextStyle(
                                fontWeight: hasEarly ? FontWeight.bold : FontWeight.normal,
                                color: hasEarly ? const Color(0xFFF59E0B) : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),

                          // Penalties
                          DataCell(
                            Text(
                              r.penaltyDeductions > 0 ? '${r.penaltyDeductions.toStringAsFixed(1)}d' : '-',
                              style: TextStyle(
                                fontWeight: r.penaltyDeductions > 0 ? FontWeight.bold : FontWeight.normal,
                                color: r.penaltyDeductions > 0 ? const Color(0xFF8B5CF6) : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),

                          // Extra Time
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: r.extraTimeHours > 0 ? const Color(0xFF0284C7).withValues(alpha: 0.12) : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                r.extraTimeHours > 0 ? '+${r.extraTimeHours.toStringAsFixed(1)}${provider.translate('unit_hrs_short')}' : '-',
                                style: TextStyle(
                                  fontWeight: r.extraTimeHours > 0 ? FontWeight.bold : FontWeight.normal,
                                  color: r.extraTimeHours > 0 ? const Color(0xFF0284C7) : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),

                          // Overtime
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: hasOt ? const Color(0xFF10B981).withValues(alpha: 0.12) : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                hasOt ? '+${r.totalOvertimeHours.toStringAsFixed(1)}${provider.translate('unit_hrs_short')}' : '-',
                                style: TextStyle(
                                  fontWeight: hasOt ? FontWeight.bold : FontWeight.normal,
                                  color: hasOt ? const Color(0xFF10B981) : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),

                          // Daily Leaves
                          DataCell(
                            Text(
                              r.dailyLeaveDays > 0 ? '${r.dailyLeaveDays} ${provider.translate('unit_days_short')}' : '-',
                              style: TextStyle(fontSize: 12, fontWeight: r.dailyLeaveDays > 0 ? FontWeight.bold : FontWeight.normal),
                            ),
                          ),

                          // Hourly Leaves
                          DataCell(
                            Text(
                              r.hourlyLeaveHours > 0 ? '${r.hourlyLeaveHours.toStringAsFixed(1)}${provider.translate('unit_hrs_short')}' : '-',
                              style: TextStyle(fontSize: 12, fontWeight: r.hourlyLeaveHours > 0 ? FontWeight.bold : FontWeight.normal),
                            ),
                          ),

                          // Remaining Annual Leave Balance
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${r.remainingAnnualDays.toStringAsFixed(1)} ${provider.translate('unit_days_short')} (${r.remainingAnnualHours.toStringAsFixed(0)}${provider.translate('unit_hrs_short')})',
                                style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 11.5),
                              ),
                            ),
                          ),

                          // Absences
                          DataCell(
                            Text(
                              hasAbsence ? '${r.absentDays} ${provider.translate('unit_days_short')}' : '-',
                              style: TextStyle(
                                fontWeight: hasAbsence ? FontWeight.bold : FontWeight.normal,
                                color: hasAbsence ? const Color(0xFFEF4444) : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),

                          // Action: View Audit Log
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: Color(0xFF10B981)),
                              tooltip: provider.translate('view_daily_audit_tooltip'),
                              onPressed: () => _showAuditDialog(r, provider),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  DataColumn _buildHeaderCol(String label, {required bool isDark, bool isNumeric = false}) {
    return DataColumn(
      numeric: isNumeric,
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, AttendanceProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assessment_outlined, size: 54, color: isDark ? Colors.white24 : Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            provider.translate('no_records_periodic'),
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  String _localizeAuditStatus(PeriodicDailyAudit day, AttendanceProvider provider) {
    if (day.isHoliday) {
      return provider.translate('holiday_status_prefix', params: {'name': day.holidayName});
    }
    if (!day.isWorkingDay) {
      return provider.translate('weekend_off_day');
    }
    if (day.status == 'Absent') {
      return provider.translate('absent');
    }
    if (day.delayMinutes > 0 && day.earlyExitMinutes > 0) {
      return provider.translate('late_early_status', params: {
        'late': '${day.delayMinutes}',
        'early': '${day.earlyExitMinutes}',
      });
    }
    if (day.delayMinutes > 0) {
      return provider.translate('late_status', params: {'late': '${day.delayMinutes}'});
    }
    if (day.earlyExitMinutes > 0) {
      return provider.translate('early_status', params: {'early': '${day.earlyExitMinutes}'});
    }
    if (day.status == 'Present') {
      return provider.translate('present');
    }
    return day.status;
  }

  void _showAuditDialog(PeriodicReportRow row, AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 820,
            height: 600,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                          child: Text(
                            row.employee.name.isNotEmpty ? row.employee.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.employee.name,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'ID: ${row.employee.id} • ${row.structureName} • ${row.groupName}',
                              style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const Divider(height: 24),

                Text(
                  provider.translate('daily_punch_audit_title', params: {
                    'start': DateFormat('yyyy-MM-dd').format(_startDate),
                    'end': DateFormat('yyyy-MM-dd').format(_endDate),
                  }),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),

                const SizedBox(height: 10),

                // Table of days
                Expanded(
                  child: ListView.separated(
                    itemCount: row.dailyAuditLogs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final day = row.dailyAuditLogs[idx];
                      final isWork = day.isWorkingDay;
                      final isHol = day.isHoliday;
                      final isAbs = day.status == 'Absent';
                      final isLate = day.delayMinutes > 0;
                      final isEarly = day.earlyExitMinutes > 0;

                      final dayOfWeekKey = DateFormat('EEEE').format(day.date).toLowerCase();
                      final translatedDayName = provider.translate(dayOfWeekKey);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(day.dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text(translatedDayName, style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white54 : Colors.grey)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 140,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(day.shiftName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
                                  Text(day.shiftTime, style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 110,
                              child: Text(
                                day.hasRecord ? '${day.checkIn}  ➔  ${day.checkOut}' : '-',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: Text(
                                day.actualMinutes > 0
                                    ? '${(day.actualMinutes / 60.0).toStringAsFixed(1)}${provider.translate('unit_hrs_short')} ${provider.translate('worked_suffix')}'
                                    : '-',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isAbs
                                          ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                                          : isHol
                                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                                              : (isLate || isEarly)
                                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                                                  : !isWork
                                                      ? Colors.grey.withValues(alpha: 0.12)
                                                      : const Color(0xFF10B981).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _localizeAuditStatus(day, provider),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isAbs
                                            ? const Color(0xFFEF4444)
                                            : isHol
                                                ? const Color(0xFF8B5CF6)
                                                : (isLate || isEarly)
                                                    ? const Color(0xFFF59E0B)
                                                    : !isWork
                                                        ? Colors.grey
                                                        : const Color(0xFF10B981),
                                      ),
                                    ),
                                  ),
                                  if (day.extraTimeMinutes > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '+${(day.extraTimeMinutes / 60.0).toStringAsFixed(1)}${provider.translate('unit_hrs_short')} ${provider.translate('extra_time')}',
                                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                      ),
                                    ),
                                  ],
                                  if (day.overtimeMinutes > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '+${(day.overtimeMinutes / 60.0).toStringAsFixed(1)}${provider.translate('unit_hrs_short')} ${provider.translate('ot_suffix')}',
                                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportExcel(List<PeriodicReportRow> rows, AttendanceProvider provider) async {
    setState(() => _isExporting = true);
    try {
      await ExportService.exportPeriodicReportToExcel(
        rows: rows,
        startDate: _startDate,
        endDate: _endDate,
        profile: provider.companyProfile,
        languageCode: provider.currentLanguage,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.translate('periodic_excel_success')),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.translate('periodic_excel_failed', params: {'error': '$e'})),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPdf(List<PeriodicReportRow> rows, AttendanceProvider provider) async {
    setState(() => _isExporting = true);
    try {
      await ExportService.exportPeriodicReportToPdf(
        rows: rows,
        startDate: _startDate,
        endDate: _endDate,
        profile: provider.companyProfile,
        languageCode: provider.currentLanguage,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.translate('periodic_pdf_success')),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.translate('periodic_pdf_failed', params: {'error': '$e'})),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}
