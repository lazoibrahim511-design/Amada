import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/platform_helper.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../models/hr_models.dart';
import '../models/attendance_record.dart';
import '../models/request_model.dart';
import '../widgets/glass_container.dart';
import '../services/export_service.dart';
import '../widgets/new_request_dialog.dart';
import '../widgets/neu_button.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _selectedEmployeeId;
  List<AttendanceRecord> _subordinateRecords = [];
  List<Request> _subordinateRequests = [];
  bool _isLoadingSubordinate = false;
  DateTime _reportMonth = DateTime.now();
  DateTime? _selectedDate;

  final ScrollController _tableHorizontalController = ScrollController();
  final ScrollController _tableVerticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<AttendanceProvider>(context, listen: false);
      final subordinates = _getSubordinates(provider);
      final targetId = _resolveActiveEmployeeId(provider, subordinates);
      if (targetId.isNotEmpty) {
        if (_selectedEmployeeId != targetId) {
          setState(() {
            _selectedEmployeeId = targetId;
          });
        }
        _loadSubordinateRecords(provider, targetId);
      }
    });
  }

  String _resolveActiveEmployeeId(
    AttendanceProvider provider,
    List<CompanyEmployee> subordinates,
  ) {
    if (_selectedEmployeeId != null &&
        subordinates.any((e) => e.id == _selectedEmployeeId)) {
      return _selectedEmployeeId!;
    }
    final current = provider.currentEmployee;
    if (current != null &&
        !AttendanceProvider.isSuperAdminUser(current) &&
        subordinates.any((e) => e.id == current.id)) {
      return current.id;
    }
    if (subordinates.isNotEmpty) {
      return subordinates.first.id;
    }
    return current?.id ?? provider.employeeId;
  }

  @override
  void dispose() {
    _tableHorizontalController.dispose();
    _tableVerticalController.dispose();
    super.dispose();
  }

  List<CompanyEmployee> _getSubordinates(AttendanceProvider provider) {
    final currentUser = provider.currentEmployee;
    if (currentUser == null) return [];

    if (currentUser.role == 'hr' || currentUser.role == 'admin' || provider.canEditCompanyInfo) {
      final list = <CompanyEmployee>[];
      if (!AttendanceProvider.isSuperAdminUser(currentUser)) {
        list.add(currentUser);
      }
      for (var e in provider.employees) {
        if (e.id != currentUser.id) {
          list.add(e);
        }
      }
      return list;
    }

    if (currentUser.role == 'supervisor') {
      final Set<String> subordinateIds = {};
      final List<CompanyEmployee> list = [currentUser];

      // 1. Get employees in structures supervised directly by this user
      final supervisedStructures = provider.structures
          .where((s) => s.supervisorId == currentUser.id)
          .map((s) => s.id)
          .toList();

      for (var structId in supervisedStructures) {
        final emps = provider.employees.where(
          (e) => e.id != currentUser.id && e.structureId == structId,
        );
        for (var e in emps) {
          if (subordinateIds.add(e.id)) {
            list.add(e);
          }
        }
      }

      // 2. Fallback: Lookup by current user's structureId
      if (currentUser.structureId != null &&
          currentUser.structureId!.isNotEmpty) {
        final emps = provider.employees.where(
          (e) =>
              e.id != currentUser.id &&
              e.structureId == currentUser.structureId &&
              e.role == 'employee',
        );
        for (var e in emps) {
          if (subordinateIds.add(e.id)) {
            list.add(e);
          }
        }
      }

      return list;
    }

    return [currentUser];
  }

  String? _currentlyLoadingId;

  void _loadSubordinateRecords(
    AttendanceProvider provider,
    String empId,
  ) async {
    if (_isLoadingSubordinate && _currentlyLoadingId == empId) return;

    setState(() {
      _isLoadingSubordinate = true;
      _currentlyLoadingId = empId;
    });

    try {
      final records = await provider.getEmployeeRecords(empId);
      final requests = await provider.getEmployeeRequests(empId);

      if (mounted) {
        setState(() {
          _subordinateRecords = records;
          _subordinateRequests = requests;
          _isLoadingSubordinate = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSubordinate = false;
        });
      }
    }
  }

  String formatMinutes(int minutes) {
    if (minutes <= 0) return '-';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);

    final subordinates = _getSubordinates(provider);
    final activeEmpId = _resolveActiveEmployeeId(provider, subordinates);
    if (_selectedEmployeeId != activeEmpId) {
      _selectedEmployeeId = activeEmpId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && activeEmpId.isNotEmpty) {
          _loadSubordinateRecords(provider, activeEmpId);
        }
      });
    }

    // Monthly Report Data Compilation Logic
    List<Map<String, dynamic>> compiledData = [];
    {
      final totalDays = DateUtils.getDaysInMonth(
        _reportMonth.year,
        _reportMonth.month,
      );
      final List<DateTime> datesInPeriod = List.generate(
        totalDays,
        (index) => DateTime(_reportMonth.year, _reportMonth.month, index + 1),
      );

      final isCurrentUser = activeEmpId == provider.currentEmployee?.id ||
          activeEmpId == provider.employeeId;

      // Resolve Employee and Shift
      final emp = provider.employees.firstWhere(
        (e) => e.id == activeEmpId,
        orElse: () => provider.currentEmployee ?? CompanyEmployee(id: activeEmpId, name: 'Employee', email: '', position: ''),
      );

      // Respect Employee Start Date (Hire Date) and End Date
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

      if (empStart != null) {
        final cleanStart = DateTime(empStart.year, empStart.month, empStart.day);
        datesInPeriod.removeWhere((d) => DateTime(d.year, d.month, d.day).isBefore(cleanStart));
      }
      if (empEnd != null) {
        final cleanEnd = DateTime(empEnd.year, empEnd.month, empEnd.day);
        datesInPeriod.removeWhere((d) => DateTime(d.year, d.month, d.day).isAfter(cleanEnd));
      }

      final List<AttendanceRecord> recordsToCompile;
      if (isCurrentUser) {
        // Current user: always prioritize live streaming records from provider.records
        if (provider.records.isNotEmpty) {
          recordsToCompile = provider.records;
        } else if (_subordinateRecords.isNotEmpty) {
          recordsToCompile = _subordinateRecords;
        } else {
          recordsToCompile = provider.allCompanyRecords
              .where((r) =>
                  r.employeeId != null &&
                  (r.employeeId!.trim().toLowerCase() == activeEmpId.trim().toLowerCase() ||
                   r.employeeId!.trim().toLowerCase() == emp.name.trim().toLowerCase() ||
                   r.employeeId!.trim().toLowerCase() == emp.email.trim().toLowerCase()))
              .toList();
        }
      } else {
        // Subordinate employee: merge live company stream with direct-fetched subordinate records
        final companyRecordsForEmp = provider.allCompanyRecords
            .where((r) =>
                r.employeeId != null &&
                (r.employeeId!.trim().toLowerCase() == activeEmpId.trim().toLowerCase() ||
                 r.employeeId!.trim().toLowerCase() == emp.name.trim().toLowerCase() ||
                 r.employeeId!.trim().toLowerCase() == emp.email.trim().toLowerCase()))
            .toList();

        if (companyRecordsForEmp.isNotEmpty && _subordinateRecords.isNotEmpty) {
          final Map<String, AttendanceRecord> recordMap = {};
          for (var r in _subordinateRecords) {
            final key = '${r.checkIn.year}-${r.checkIn.month}-${r.checkIn.day}_${r.checkIn.hour}:${r.checkIn.minute}';
            recordMap[key] = r;
          }
          // Live company records overwrite/augment with real-time stream updates
          for (var r in companyRecordsForEmp) {
            final key = '${r.checkIn.year}-${r.checkIn.month}-${r.checkIn.day}_${r.checkIn.hour}:${r.checkIn.minute}';
            recordMap[key] = r;
          }
          recordsToCompile = recordMap.values.toList()
            ..sort((a, b) => b.checkIn.compareTo(a.checkIn));
        } else if (companyRecordsForEmp.isNotEmpty) {
          recordsToCompile = companyRecordsForEmp;
        } else {
          recordsToCompile = _subordinateRecords;
        }
      }

      final List<Request> requestsToCompile;
      if (isCurrentUser) {
        // Current user: always prioritize live streaming requests from provider.requests
        if (provider.requests.isNotEmpty) {
          requestsToCompile = provider.requests;
        } else if (_subordinateRequests.isNotEmpty) {
          requestsToCompile = _subordinateRequests;
        } else {
          requestsToCompile = provider.allCompanyRequests
              .where((r) =>
                  r.employeeId != null &&
                  (r.employeeId!.trim().toLowerCase() == activeEmpId.trim().toLowerCase() ||
                   r.employeeId!.trim().toLowerCase() == emp.name.trim().toLowerCase() ||
                   r.employeeId!.trim().toLowerCase() == emp.email.trim().toLowerCase()))
              .toList();
        }
      } else {
        // Subordinate employee: merge live company requests stream with direct-fetched subordinate requests
        final companyRequestsForEmp = provider.allCompanyRequests
            .where((r) =>
                r.employeeId != null &&
                (r.employeeId!.trim().toLowerCase() == activeEmpId.trim().toLowerCase() ||
                 r.employeeId!.trim().toLowerCase() == emp.name.trim().toLowerCase() ||
                 r.employeeId!.trim().toLowerCase() == emp.email.trim().toLowerCase()))
            .toList();

        if (companyRequestsForEmp.isNotEmpty && _subordinateRequests.isNotEmpty) {
          final Map<String, Request> requestMap = {};
          for (var r in _subordinateRequests) {
            requestMap[r.id] = r;
          }
          // Live company requests overwrite/augment with real-time stream updates
          for (var r in companyRequestsForEmp) {
            requestMap[r.id] = r;
          }
          requestsToCompile = requestMap.values.toList();
        } else if (companyRequestsForEmp.isNotEmpty) {
          requestsToCompile = companyRequestsForEmp;
        } else {
          requestsToCompile = _subordinateRequests;
        }
      }

      int delayTier1Occurrences = 0;
      int delayTier2Occurrences = 0;
      int delayTier3Occurrences = 0;
      int earlyExitTier1Occurrences = 0;
      int earlyExitTier2Occurrences = 0;
      int earlyExitTier3Occurrences = 0;

      for (var date in datesInPeriod) {
        final activeGroupId = provider.getGroupIdForDate(emp, date);
        EmployeeGroup? group;
        try {
          group = provider.groups.firstWhere((g) => g.id == activeGroupId);
        } catch (_) {}
        final shift = provider.getShiftForDate(emp, date);
        final holiday = provider.getHolidayForEmployee(date, group?.id);

        final startTimeStr = shift.getStartTimeForDate(date);
        final endTimeStr = shift.getEndTimeForDate(date);
        final partsStart = startTimeStr.split(':');
        final partsEnd = endTimeStr.split(':');
        final shiftStartMinutes = partsStart.length >= 2
            ? int.parse(partsStart[0]) * 60 + int.parse(partsStart[1])
            : 540; // Default 09:00
        final shiftEndMinutes = partsEnd.length >= 2
            ? int.parse(partsEnd[0]) * 60 + int.parse(partsEnd[1])
            : 1020; // Default 17:00

        final shiftStart = DateTime(
          date.year,
          date.month,
          date.day,
          shiftStartMinutes ~/ 60,
          shiftStartMinutes % 60,
        );
        var shiftEnd = DateTime(
          date.year,
          date.month,
          date.day,
          shiftEndMinutes ~/ 60,
          shiftEndMinutes % 60,
        );
        if (shiftEnd.isBefore(shiftStart) ||
            shiftEnd.isAtSameMomentAs(shiftStart) ||
            shift.isOvernightForDate(date)) {
          shiftEnd = shiftEnd.add(const Duration(days: 1));
        }

        final dayShiftDurMins = shift.getShiftDurationMinutesForDate(date);
        final shiftWorkHoursStr = formatMinutes(dayShiftDurMins);

        final dateRecords = provider.getRecordsForDate(
          date,
          emp: emp,
          recordsPool: recordsToCompile,
          requestsPool: requestsToCompile,
        );

        int totalActualMinutes = 0;
        int dutyMinutes = 0;
        int restMinutes = 0;
        int unexcusedRestMinutes = 0;
        int delayMinutes = 0;
        int earlyExitMinutes = 0;
        int extraTimeMinutes = 0;
        int nightExtraMinutes = 0;
        int overtimeMinutes = 0;
        int usedHourlyForDelayAndEarly = 0;
        String clockTimeStr = '-';
        double penaltyAmount = 0.0;
        bool hasRecord = dateRecords.isNotEmpty;
        List<Request> dateApprovedRequests = [];
        bool hasFullDayLeave = false;
        int approvedHourlyLeaveMinutes = 0;
        List<HourlyLeaveTimeRange> approvedHourlyLeaveRanges = [];
        List<Request> allDayRequests = [];
        int approvedOvertimeMinutes = 0;
        bool hasApprovedOt = false;
        for (var req in requestsToCompile) {
          try {
            final dateStr = req.date;
            DateTime start;
            DateTime end;

            if (dateStr.contains(' - ')) {
              final parts = dateStr.split(' - ');
              end = DateFormat('MMMM d, yyyy').parse(parts[1].trim());
              String startStr = parts[0].trim();
              if (!startStr.contains(',')) {
                startStr = '$startStr, ${end.year}';
              }
              start = DateFormat('MMMM d, yyyy').parse(startStr);
            } else {
              start = DateFormat('MMMM d, yyyy').parse(dateStr.trim());
              end = start;
            }

            final target = DateTime(date.year, date.month, date.day);
            final startOnly = DateTime(start.year, start.month, start.day);
            final endOnly = DateTime(end.year, end.month, end.day);

            if ((target.isAtSameMomentAs(startOnly) ||
                    target.isAfter(startOnly)) &&
                (target.isAtSameMomentAs(endOnly) ||
                    target.isBefore(endOnly))) {
              allDayRequests.add(req);
              if (req.status == 'Approved' && req.type != 'Missing Punch') {
                dateApprovedRequests.add(req);
                if (req.type == 'Hourly Leave' ||
                    req.type.toLowerCase().contains('hourly')) {
                  final mins = parseHourlyLeaveDurationMinutes(req.duration);
                  approvedHourlyLeaveMinutes += mins > 0 ? mins : 60;
                  final range = parseHourlyLeaveTimeRange(req.duration);
                  if (range != null) {
                    approvedHourlyLeaveRanges.add(range);
                  }
                } else if (req.type == 'Overtime Approval') {
                  hasApprovedOt = true;
                  final mins = parseOvertimeApprovalDurationMinutes(req.duration);
                  approvedOvertimeMinutes += mins > 0 ? mins : 0;
                } else if (req.type.contains('Leave')) {
                  hasFullDayLeave = true;
                }
              }
            }
          } catch (e) {
            // Ignore parsing errors
          }
        }

        final isOvernightForMissing = shift.isOvernightForDate(date);
        final cutoffStrForMissing = shift.getCrossMidnightCutoffForDate(date);
        final cPartsForMissing = cutoffStrForMissing.split(':');
        final cutoffMinsForMissing = (int.tryParse(cPartsForMissing[0]) ?? 3) * 60 +
            (cPartsForMissing.length >= 2 ? (int.tryParse(cPartsForMissing[1]) ?? 0) : 0);

        final missingPunchReqs = requestsToCompile.where((req) {
          if (req.type != 'Missing Punch' &&
              req.type != 'Forgot to Clock In' &&
              req.type != 'Forgot to Clock Out') {
            return false;
          }
          if (req.status != 'Approved') return false;

          DateTime? rDate;
          try {
            final dStr = req.date.split(' - ').first.trim();
            if (dStr.contains(',')) {
              rDate = DateFormat('MMMM d, yyyy').parse(dStr);
            } else if (dStr.contains('/')) {
              final slashParts = dStr.split('/');
              if (slashParts.length == 3) {
                try {
                  rDate = DateFormat('dd/MM/yyyy').parse(dStr);
                } catch (_) {
                  rDate = DateFormat('MM/dd/yyyy').parse(dStr);
                }
              }
            } else {
              rDate = DateTime.tryParse(dStr);
            }
          } catch (_) {}
          if (rDate == null) return false;

          if (DateUtils.isSameDay(rDate, date)) return true;

          if (isOvernightForMissing &&
              DateUtils.isSameDay(rDate, date.add(const Duration(days: 1)))) {
            final dur = req.duration;
            final timeStr = dur.replaceAll('Clock In:', '').replaceAll('Clock Out:', '').trim();
            try {
              final parsedTime = timeStr.contains('AM') || timeStr.contains('PM')
                  ? DateFormat('hh:mm a').parse(timeStr)
                  : DateFormat('HH:mm').parse(timeStr);
              final punchMins = parsedTime.hour * 60 + parsedTime.minute;
              return punchMins < cutoffMinsForMissing;
            } catch (_) {}
          }
          return false;
        }).toList();
        final hasApprovedMissingPunch = missingPunchReqs.isNotEmpty;

        List<String> missingPunchTimes = [];
        final timeRegex = RegExp(r'(\d{1,2}:\d{2}(?:\s*(?:AM|PM|am|pm))?)');
        for (var req in missingPunchReqs) {
          final duration = req.duration;
          final matches = timeRegex.allMatches(duration);
          for (var m in matches) {
            final tStr = m.group(1)!;
            try {
              final parsedTime = tStr.contains('AM') || tStr.contains('PM')
                  ? DateFormat('hh:mm a').parse(tStr)
                  : DateFormat('HH:mm').parse(tStr);
              missingPunchTimes.add(DateFormat('HH:mm').format(parsedTime));
            } catch (_) {}
          }
        }

        if (hasApprovedMissingPunch && !hasRecord) {
          final missingPunchReq = missingPunchReqs.first;
          final duration = missingPunchReq.duration;
          if (duration.contains('Clock In:') &&
              duration.contains('Clock Out:')) {
            final inTime = duration
                .split('Clock Out:')[0]
                .replaceAll('Clock In:', '')
                .trim();
            final outTime = duration.split('Clock Out:')[1].trim();
            clockTimeStr = '$inTime - $outTime';
          } else {
            clockTimeStr = duration;
          }
        }

        final isToday = DateUtils.isSameDay(date, DateTime.now());
        final hasUnexcusedMissedPunch = !hasApprovedMissingPunch &&
            dateRecords.isNotEmpty &&
            dateRecords.any((rec) {
              if (rec.checkIn == rec.checkOut) return true;
              if (rec.checkOut == null) {
                if (!isToday) return true;
                if (DateTime.now().isAfter(shiftEnd)) return true;
              }
              return false;
            });

        if (hasRecord) {
          final sortedRecords = List<AttendanceRecord>.from(dateRecords)
            ..sort((a, b) => a.checkIn.compareTo(b.checkIn));

          // Format session times
          final List<String> sessionTimes = [];
          for (var rec in sortedRecords) {
            final isMissedCheckIn = rec.checkIn == rec.checkOut;
            final startStr = isMissedCheckIn
                ? '--:--'
                : DateFormat('HH:mm').format(rec.checkIn);
            final endStr = rec.checkOut != null
                ? DateFormat('HH:mm').format(rec.checkOut!)
                : (isToday
                      ? provider.translate('active')
                      : provider.translate('missing'));
            sessionTimes.add('$startStr - $endStr');
          }
          clockTimeStr = sessionTimes.join('\n');

          if (!hasUnexcusedMissedPunch) {
            int totalExcusedRestMinutes = 0;

            final breakStartStr = shift.getBreakStartForDate(date);
            final breakEndStr = shift.getBreakEndForDate(date);
            final allowedBreakDuration = shift.getBreakDurationForDate(date);

          DateTime? bStart;
          DateTime? bEnd;
          if (breakStartStr.isNotEmpty &&
              breakEndStr.isNotEmpty &&
              allowedBreakDuration > 0) {
            final bsParts = breakStartStr.split(':');
            final beParts = breakEndStr.split(':');
            if (bsParts.length >= 2 && beParts.length >= 2) {
              bStart = DateTime(
                date.year,
                date.month,
                date.day,
                int.parse(bsParts[0]),
                int.parse(bsParts[1]),
              );
              bEnd = DateTime(
                date.year,
                date.month,
                date.day,
                int.parse(beParts[0]),
                int.parse(beParts[1]),
              );
              if (bEnd.isBefore(bStart)) {
                bEnd = bEnd.add(const Duration(days: 1));
              }
            }
          }

          // Calculate rest minutes (gap between sessions within shift window)
          final isWorkingDay = shift.isWorkingDay(date);
          if (sortedRecords.length > 1 && isWorkingDay) {
            for (int i = 0; i < sortedRecords.length - 1; i++) {
              final currentOut = sortedRecords[i].checkOut;
              final nextIn = sortedRecords[i + 1].checkIn;
              if (currentOut != null && nextIn.isAfter(currentOut)) {
                // If the gap starts at or after shiftEnd, it's outside shift hours (e.g. night overtime gap)
                if (currentOut.isAfter(shiftEnd) || currentOut.isAtSameMomentAs(shiftEnd)) {
                  continue;
                }
                // If the employee does not return before shiftEnd, their departure is handled by Early Exit
                if (nextIn.isAfter(shiftEnd) || nextIn.isAtSameMomentAs(shiftEnd)) {
                  continue;
                }

                final gapStart = currentOut.isAfter(shiftStart) ? currentOut : shiftStart;
                final gapEnd = nextIn.isBefore(shiftEnd) ? nextIn : shiftEnd;
                if (!gapEnd.isAfter(gapStart)) continue;

                final gapDuration = gapEnd.difference(gapStart).inMinutes;
                if (bStart != null && bEnd != null) {
                  // Find intersection of gap with break window
                  final intersectStart = gapStart.isAfter(bStart)
                      ? gapStart
                      : bStart;
                  final intersectEnd = gapEnd.isBefore(bEnd) ? gapEnd : bEnd;

                  int excusedInGap = 0;
                  if (intersectEnd.isAfter(intersectStart)) {
                    excusedInGap = intersectEnd
                        .difference(intersectStart)
                        .inMinutes;
                  }

                  // Limit total excused across all gaps to allowedBreakDuration
                  if (totalExcusedRestMinutes + excusedInGap >
                      allowedBreakDuration) {
                    excusedInGap =
                        allowedBreakDuration - totalExcusedRestMinutes;
                    if (excusedInGap < 0) excusedInGap = 0;
                  }

                  totalExcusedRestMinutes += excusedInGap;
                  restMinutes +=
                      excusedInGap; // Only count excused rest time in the UI column
                  unexcusedRestMinutes += (gapDuration - excusedInGap);
                } else {
                  unexcusedRestMinutes += gapDuration;
                }
              }
            }
          }

          // 1. Sum Attendance (all worked minutes on this day)
          for (var rec in dateRecords) {
            totalActualMinutes += rec.duration.inMinutes;
          }

          // 2. Duty Time (worked minutes that fall within the shift bounds)
          for (var rec in dateRecords) {
            final rawStart = rec.checkIn;
            final rawEnd =
                rec.checkOut ?? (isToday ? DateTime.now() : rawStart);

            final sessionStart = DateTime(
              rawStart.year,
              rawStart.month,
              rawStart.day,
              rawStart.hour,
              rawStart.minute,
            );
            final sessionEnd = DateTime(
              rawEnd.year,
              rawEnd.month,
              rawEnd.day,
              rawEnd.hour,
              rawEnd.minute,
            );



            final intersectStart = sessionStart.isAfter(shiftStart)
                ? sessionStart
                : shiftStart;
            final intersectEnd = sessionEnd.isBefore(shiftEnd)
                ? sessionEnd
                : shiftEnd;

            if (intersectEnd.isAfter(intersectStart)) {
              dutyMinutes += intersectEnd.difference(intersectStart).inMinutes;
            }

            // Calculate Extra Time
            final isWeekend = !shift.isWorkingDay(date);
            if (isWeekend) {
              extraTimeMinutes += sessionEnd.difference(sessionStart).inMinutes;
              if (group?.nightOvertimeAllowed == true) {
                nightExtraMinutes += group!.calculateNightMinutes(
                  sessionStart,
                  sessionEnd,
                );
              }
            } else {
              // Calculate Extra Time (only worked minutes outside of shift bounds)
              if (sessionStart.isBefore(shiftStart)) {
                final endForBefore = sessionEnd.isBefore(shiftStart)
                    ? sessionEnd
                    : shiftStart;
                extraTimeMinutes += endForBefore
                    .difference(sessionStart)
                    .inMinutes;
                if (group?.nightOvertimeAllowed == true) {
                  nightExtraMinutes += group!.calculateNightMinutes(
                    sessionStart,
                    endForBefore,
                  );
                }
              }
              if (sessionEnd.isAfter(shiftEnd)) {
                final startForAfter = sessionStart.isAfter(shiftEnd)
                    ? sessionStart
                    : shiftEnd;
                extraTimeMinutes += sessionEnd
                    .difference(startForAfter)
                    .inMinutes;
                if (group?.nightOvertimeAllowed == true) {
                  nightExtraMinutes += group!.calculateNightMinutes(
                    startForAfter,
                    sessionEnd,
                  );
                }
              }
            }
          }

          final isSpecial = shift.isSpecialShiftForDate(date);
          if (isSpecial) {
            dutyMinutes = totalActualMinutes > dayShiftDurMins ? dayShiftDurMins : totalActualMinutes;
            extraTimeMinutes = totalActualMinutes > dayShiftDurMins ? (totalActualMinutes - dayShiftDurMins) : 0;
            if (group?.nightOvertimeAllowed == true && extraTimeMinutes > 0 && dateRecords.isNotEmpty) {
              final lastRec = dateRecords.last;
              final rawEnd = lastRec.checkOut ?? (isToday ? DateTime.now() : lastRec.checkIn);
              final extraStart = rawEnd.subtract(Duration(minutes: extraTimeMinutes));
              nightExtraMinutes = group!.calculateNightMinutes(extraStart, rawEnd);
            }
            delayMinutes = 0;
            earlyExitMinutes = 0;
            penaltyAmount = 0.0;
          }

          final isWeekendForDelay = !shift.isWorkingDay(date);
          if (!isSpecial && !isWeekendForDelay) {
            final hasOnlyOnePunch =
                sortedRecords.length == 1 &&
                (sortedRecords.first.checkIn == sortedRecords.first.checkOut ||
                    sortedRecords.first.checkOut == null);

            final shiftRecords = sortedRecords
                .where((r) => r.checkIn.isBefore(shiftEnd))
                .toList();

            if (shiftRecords.isNotEmpty) {
              // 3. Delay Minutes (late arrival on the first session of shift)
              final firstRec = shiftRecords.first;
              final isMissedCheckIn = firstRec.checkIn == firstRec.checkOut;
              if (!isMissedCheckIn && !hasOnlyOnePunch) {
                final delay = firstRec.checkIn.difference(shiftStart).inMinutes;
                if (delay > shift.forgivenessOfDelay) {
                  delayMinutes = delay;
                }
              }

              // 4. Early Exit Minutes (leaving early on the last completed session of shift)
              final lastRec = shiftRecords.last;
              if (lastRec.checkOut != null && !hasOnlyOnePunch) {
                final earlyExit =
                    shiftEnd.difference(lastRec.checkOut!).inMinutes;
                if (earlyExit > shift.earlyExit) {
                  earlyExitMinutes = earlyExit;
                }
              }

              // Excuse delay / early exit with approved hourly leave before penalty computation
              if (approvedHourlyLeaveMinutes > 0) {
                int remainingHourly = approvedHourlyLeaveMinutes;
                if (approvedHourlyLeaveRanges.isNotEmpty) {
                  for (final r in approvedHourlyLeaveRanges) {
                    if (delayMinutes > 0 &&
                        r.startMinutes <= shiftStartMinutes + shift.forgivenessOfDelay + 30) {
                      final excused = math.min(delayMinutes, r.durationMinutes);
                      delayMinutes -= excused;
                      remainingHourly = math.max(0, remainingHourly - excused);
                      usedHourlyForDelayAndEarly += excused;
                    }
                    if (earlyExitMinutes > 0 &&
                        r.endMinutes >= shiftEndMinutes - shift.earlyExit - 30) {
                      final excused = math.min(earlyExitMinutes, r.durationMinutes);
                      earlyExitMinutes -= excused;
                      remainingHourly = math.max(0, remainingHourly - excused);
                      usedHourlyForDelayAndEarly += excused;
                    }
                  }
                } else {
                  if (delayMinutes > 0 && remainingHourly > 0) {
                    final excused = math.min(delayMinutes, remainingHourly);
                    delayMinutes -= excused;
                    remainingHourly -= excused;
                    usedHourlyForDelayAndEarly += excused;
                  }
                  if (earlyExitMinutes > 0 && remainingHourly > 0) {
                    final excused = math.min(earlyExitMinutes, remainingHourly);
                    earlyExitMinutes -= excused;
                    remainingHourly -= excused;
                    usedHourlyForDelayAndEarly += excused;
                  }
                }
              }
            }
          }

          // 5. Overtime calculation (based on extra time minutes and approved overtime requests)
          final dateStr = DateFormat('MMMM d, yyyy').format(date);
          final matchingOtReqs = requestsToCompile.where(
            (req) =>
                req.type == 'Overtime Approval' &&
                req.status == 'Approved' &&
                (req.date == dateStr || req.date.startsWith(dateStr)),
          );
          for (final req in matchingOtReqs) {
            if (!dateApprovedRequests.contains(req)) {
              hasApprovedOt = true;
              final mins = parseOvertimeApprovalDurationMinutes(req.duration);
              approvedOvertimeMinutes += mins > 0 ? mins : 0;
            }
          }

          if (extraTimeMinutes > 0 && hasApprovedOt) {
            final effectiveOtExtra = approvedOvertimeMinutes > 0
                ? math.min(extraTimeMinutes, approvedOvertimeMinutes)
                : extraTimeMinutes;

            if (effectiveOtExtra > 0) {
              final nightPortion = extraTimeMinutes > 0
                  ? (nightExtraMinutes * (effectiveOtExtra / extraTimeMinutes)).round()
                  : 0;

              if (group != null) {
                overtimeMinutes = group.calculateOvertimeMinutes(
                  dayExtraMinutes: effectiveOtExtra,
                  nightExtraMinutes: nightPortion,
                  isWeekend: !shift.isWorkingDay(date),
                  isHoliday: holiday != null,
                );
              } else {
                final baseOt = effectiveOtExtra.clamp(0, 480);
                final isWeekend = !shift.isWorkingDay(date);
                overtimeMinutes = isWeekend ? (baseOt * 1.5).toInt() : baseOt;
              }

              if (overtimeMinutes > 0) {
                extraTimeMinutes = math.max(0, extraTimeMinutes - effectiveOtExtra);
              }
            }
          }

          // 6. Penalty calculations by Group rules (with forgiveness per tier)
          double delayPenalty = 0.0;
          if (delayMinutes > 0 && (group?.delayPenaltiesEnabled ?? true)) {
            final g = group;
            if (g != null) {
              if (delayMinutes >= g.delayTier1Min &&
                  delayMinutes <= g.delayTier1Max) {
                delayTier1Occurrences++;
                if (delayTier1Occurrences > g.delayTier1Forgiveness) {
                  delayPenalty = g.delayTier1Penalty;
                }
              } else if (delayMinutes >= g.delayTier2Min &&
                  delayMinutes <= g.delayTier2Max) {
                delayTier2Occurrences++;
                if (delayTier2Occurrences > g.delayTier2Forgiveness) {
                  delayPenalty = g.delayTier2Penalty;
                }
              } else if (delayMinutes >= g.delayTier3Min) {
                delayTier3Occurrences++;
                if (delayTier3Occurrences > g.delayTier3Forgiveness) {
                  delayPenalty = g.delayTier3Penalty;
                }
              }
            }
          }

          double earlyExitPenalty = 0.0;
          if (earlyExitMinutes > 0 &&
              (group?.earlyExitPenaltiesEnabled ?? true)) {
            final g = group;
            if (g != null) {
              if (earlyExitMinutes >= g.earlyExitTier1Min &&
                  earlyExitMinutes <= g.earlyExitTier1Max) {
                earlyExitTier1Occurrences++;
                if (earlyExitTier1Occurrences > g.earlyExitTier1Forgiveness) {
                  earlyExitPenalty = g.earlyExitTier1Penalty;
                }
              } else if (earlyExitMinutes >= g.earlyExitTier2Min &&
                  earlyExitMinutes <= g.earlyExitTier2Max) {
                earlyExitTier2Occurrences++;
                if (earlyExitTier2Occurrences > g.earlyExitTier2Forgiveness) {
                  earlyExitPenalty = g.earlyExitTier2Penalty;
                }
              } else if (earlyExitMinutes >= g.earlyExitTier3Min) {
                earlyExitTier3Occurrences++;
                if (earlyExitTier3Occurrences > g.earlyExitTier3Forgiveness) {
                  earlyExitPenalty = g.earlyExitTier3Penalty;
                }
              }
            }
          }

            penaltyAmount = delayPenalty + earlyExitPenalty;
          }
        }

        if (holiday != null) {
          if (!hasRecord) {
            clockTimeStr = holiday.name;
          } else {
            clockTimeStr = '${holiday.name}\n$clockTimeStr';
          }
          delayMinutes = 0;
          earlyExitMinutes = 0;
          penaltyAmount = 0.0;
        }

        if (dateApprovedRequests.isNotEmpty) {
          final requestTypes = dateApprovedRequests
              .map((r) {
                if (r.type == 'Annual Leave') {
                  return provider.translate('vacation_leave');
                }
                if (r.type == 'Sick Leave') {
                  return provider.translate('sick_leave');
                }
                if (r.type == 'Unpaid Leave') {
                  return provider.translate('unpaid_leave');
                }
                if (r.type == 'Hourly Unpaid Leave') {
                  return provider.translate('hourly_unpaid_leave');
                }
                if (r.type == 'Overtime Approval') {
                  return provider.translate('overtime_approval');
                }
                if (r.type == 'Hourly Leave') {
                  return provider.translate('hourly_leave');
                }
                return r.type;
              })
              .join('\n');

          if (clockTimeStr == '-' || clockTimeStr.isEmpty) {
            clockTimeStr = requestTypes;
          } else {
            clockTimeStr = '$clockTimeStr\n$requestTypes';
          }

          if (hasFullDayLeave) {
            delayMinutes = 0;
            earlyExitMinutes = 0;
            penaltyAmount = 0.0;
          }
        }

        int deficitMinutes = 0;
        final isWeekendDay = !shift.isWorkingDay(date);
        final isFutureDay = date.isAfter(DateTime.now());
        final isSpecialShiftDay = shift.isSpecialShiftForDate(date);

        if (hasUnexcusedMissedPunch) {
          delayMinutes = 0;
          earlyExitMinutes = 0;
          penaltyAmount = 0.0;
          if (!isWeekendDay && !hasFullDayLeave && holiday == null && !isFutureDay) {
            deficitMinutes = dayShiftDurMins;
            if (approvedHourlyLeaveMinutes > 0) {
              deficitMinutes = math.max(0, deficitMinutes - approvedHourlyLeaveMinutes);
            }
          } else {
            deficitMinutes = 0;
          }
        } else if (isSpecialShiftDay) {
          delayMinutes = 0;
          earlyExitMinutes = 0;
          penaltyAmount = 0.0;
          if (!isWeekendDay && !hasFullDayLeave && holiday == null && !isFutureDay) {
            final effectiveDur = math.max(0, dayShiftDurMins - approvedHourlyLeaveMinutes);
            if (totalActualMinutes < effectiveDur) {
              deficitMinutes = effectiveDur - totalActualMinutes;
            } else {
              deficitMinutes = 0;
            }
          }
        } else {
          final shiftRecords = dateRecords
              .where((r) => r.checkIn.isBefore(shiftEnd))
              .toList();

          if (!isWeekendDay &&
              !hasFullDayLeave &&
              holiday == null &&
              !isFutureDay) {
            deficitMinutes =
                delayMinutes + earlyExitMinutes + unexcusedRestMinutes;

            if (!hasApprovedMissingPunch) {
              int shiftDur = shiftEndMinutes - shiftStartMinutes;
              if (shiftDur < 0) shiftDur += 24 * 60;

              int missingPunchDeficit = 0;
              final hasOnlyOnePunch =
                  dateRecords.length == 1 &&
                  (dateRecords.first.checkIn == dateRecords.first.checkOut ||
                      dateRecords.first.checkOut == null);
              if (hasOnlyOnePunch) {
                missingPunchDeficit = shiftDur;
              } else if (!hasRecord || shiftRecords.isEmpty) {
                missingPunchDeficit = shiftDur;
              } else {
                for (var r in dateRecords) {
                  if (r.checkIn == r.checkOut) {
                    final outMinutes =
                        r.checkOut!.hour * 60 + r.checkOut!.minute;
                    final clampedOut = outMinutes > shiftEndMinutes
                        ? shiftEndMinutes
                        : outMinutes;
                    if (clampedOut > shiftStartMinutes) {
                      missingPunchDeficit += (clampedOut - shiftStartMinutes);
                    }
                  } else if (r.checkOut == null) {
                    final isToday = DateUtils.isSameDay(date, DateTime.now());
                    if (!isToday) {
                      final inMinutes =
                          r.checkIn.hour * 60 + r.checkIn.minute;
                      final clampedIn = inMinutes < shiftStartMinutes
                          ? shiftStartMinutes
                          : inMinutes;
                      if (shiftEndMinutes > clampedIn) {
                        missingPunchDeficit += (shiftEndMinutes - clampedIn);
                      }
                    }
                  }
                }
              }

              deficitMinutes += missingPunchDeficit;
            }

            // Deficit cannot exceed the shift duration for the day
            if (deficitMinutes > dayShiftDurMins) {
              deficitMinutes = dayShiftDurMins;
            }

            // Deduct unused approved hourly leave from deficit
            final unusedHourly = math.max(0, approvedHourlyLeaveMinutes - usedHourlyForDelayAndEarly);
            if (unusedHourly > 0) {
              deficitMinutes = math.max(0, deficitMinutes - unusedHourly);
            }
          } else {
            deficitMinutes = 0;
          }
        }

        int dayUnpaidMinutes = 0;
        for (var req in dateApprovedRequests) {
          if (req.type == 'Unpaid Leave') {
            dayUnpaidMinutes += dayShiftDurMins;
          } else if (req.type == 'Hourly Unpaid Leave') {
            final mins = parseHourlyLeaveDurationMinutes(req.duration);
            dayUnpaidMinutes += mins > 0 ? mins : 60;
          }
        }

        compiledData.add({
          'date': date,
          'hasRecord': hasRecord,
          'attendance': totalActualMinutes,
          'duty': dutyMinutes,
          'rest': restMinutes,
          'delay': delayMinutes,
          'earlyExit': earlyExitMinutes,
          'deficit': deficitMinutes,
          'extraTime': extraTimeMinutes,
          'overtime': overtimeMinutes,
          'clockTime': clockTimeStr,
          'penalty': penaltyAmount,
          'isLeave': hasFullDayLeave || holiday != null,
          'hasFullDayLeave': hasFullDayLeave,
          'hasHourlyLeave': approvedHourlyLeaveMinutes > 0,
          'hourlyLeaveMinutes': approvedHourlyLeaveMinutes,
          'unpaidLeaveMinutes': dayUnpaidMinutes,
          'hasUnpaidLeave': dayUnpaidMinutes > 0,
          'isMissingPunch': hasApprovedMissingPunch,
          'hasUnexcusedMissedPunch': hasUnexcusedMissedPunch,
          'missingPunchTimes': missingPunchTimes,
          'isWeekend': isWeekendDay,
          'requests': allDayRequests,
          'shiftName': shift.name,
          'shiftWorkHours': shiftWorkHoursStr,
          'shiftTiming': '$startTimeStr - $endTimeStr',
          'shiftDurationMinutes': dayShiftDurMins,
        });
      }
    }

    return Directionality(
      textDirection: provider.currentLanguageDirection,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Controls (Dropdown, Month Selector, Export, Add Request)
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 860) {
                      return Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: subordinates.isNotEmpty
                                  ? ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 320),
                                      child: _buildEmployeeDropdown(provider, subordinates),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                          _buildMonthSelector(),
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildRefreshButton(provider, subordinates),
                                  const SizedBox(width: 8),
                                  _buildExportButton(provider, subordinates, compiledData),
                                  const SizedBox(width: 12),
                                  _buildAddRequestButton(provider, subordinates),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              if (subordinates.isNotEmpty) ...[
                                Expanded(
                                  child: _buildEmployeeDropdown(provider, subordinates),
                                ),
                                const SizedBox(width: 8),
                              ],
                              _buildRefreshButton(provider, subordinates),
                              const SizedBox(width: 8),
                              _buildExportButton(provider, subordinates, compiledData),
                              const SizedBox(width: 8),
                              _buildAddRequestButton(provider, subordinates, isCompact: constraints.maxWidth < 420),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: _buildMonthSelector(),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Main content area
              Expanded(
                child: _isLoadingSubordinate && compiledData.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2E65FF),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSummaryCards(compiledData),
                          const SizedBox(height: 14),
                          _buildReportTable(compiledData),
                        ],
                      ),
              ),
              // Spacer for mobile bottom nav bar
              if (!isWebOrDesktopLayout(context)) const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClockTimeWidget(
    String text,
    List<String> highlights,
    bool isLeave,
  ) {
    if (isLeave) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.2,
          color: Color(0xFF5B9BFF),
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (highlights.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.2,
          color:
              ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
        ),
      );
    }

    final pattern = highlights.map((t) => RegExp.escape(t)).join('|');
    final regex = RegExp('($pattern)');
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.2,
          color:
              ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
        ),
      );
    }

    int lastMatchEnd = 0;
    List<TextSpan> spans = [];

    for (var match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            color: Color(0xFF5B9BFF),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 12,
          height: 1.2,
          color:
              ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
        ),
        children: spans,
      ),
    );
  }

  Widget _buildMonthSelector() {
    final monthStr = DateFormat('MMMM yyyy').format(_reportMonth);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NeuIconButton(
          size: 36,
          variant: NeuButtonVariant.whitePill,
          icon: const Icon(Icons.chevron_left_rounded, size: 22),
          onPressed: () {
            setState(() {
              _reportMonth = DateTime(
                _reportMonth.year,
                _reportMonth.month - 1,
              );
              _selectedDate = null;
            });
          },
        ),
        const SizedBox(width: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            monthStr,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(width: 14),
        NeuIconButton(
          size: 36,
          variant: NeuButtonVariant.whitePill,
          icon: const Icon(Icons.chevron_right_rounded, size: 22),
          onPressed: () {
            setState(() {
              _reportMonth = DateTime(
                _reportMonth.year,
                _reportMonth.month + 1,
              );
              _selectedDate = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSummaryCards(List<Map<String, dynamic>> compiledData) {
    final provider = Provider.of<AttendanceProvider>(context);
    int totalAttendance = 0;
    int totalDuty = 0;
    int totalRest = 0;
    int totalDelay = 0;
    int totalEarlyExit = 0;
    int totalDeficit = 0;
    int totalOvertime = 0;
    double totalPenalties = 0.0;
    int activeDays = 0;

    for (var row in compiledData) {
      final hasRecord = row['hasRecord'] as bool;
      final isWeekend = row['isWeekend'] as bool;

      if (hasRecord &&
          (row['attendance'] as int) > 0 &&
          !(row['hasUnexcusedMissedPunch'] as bool? ?? false)) {
        activeDays++;
        totalAttendance += row['attendance'] as int;
        totalDuty += row['duty'] as int;
        totalRest += (row['rest'] ?? 0) as int;
        totalDelay += row['delay'] as int;
        totalEarlyExit += row['earlyExit'] as int;
        totalOvertime += row['overtime'] as int;
        totalPenalties += row['penalty'] as double;
      }

      if (!isWeekend || hasRecord) {
        totalDeficit += (row['deficit'] as int?) ?? 0;
      }
    }

    final String totalAttendanceStr =
        '${totalAttendance ~/ 60}h ${totalAttendance % 60}m';
    final String totalDutyStr = '${totalDuty ~/ 60}h ${totalDuty % 60}m';
    final String totalRestStr = '${totalRest ~/ 60}h ${totalRest % 60}m';
    final String totalOvertimeStr =
        '${totalOvertime ~/ 60}h ${totalOvertime % 60}m';
    final String totalDeficitStr =
        '${totalDeficit ~/ 60}h ${totalDeficit % 60}m';

    int totalUnpaidLeave = 0;
    for (var row in compiledData) {
      totalUnpaidLeave += (row['unpaidLeaveMinutes'] as int?) ?? 0;
    }

    final cards = [
      _buildMiniSummaryCard(
        provider.translate('duty_days'),
        '$activeDays days',
        const Color(0xFF2E65FF),
      ),
      _buildMiniSummaryCard(
        provider.translate('total_attendance'),
        totalAttendanceStr,
        const Color(0xFF2EBD96),
      ),
      _buildMiniSummaryCard(
        provider.translate('rest_time'),
        totalRestStr,
        const Color(0xFF2EBD96),
      ),
      _buildMiniSummaryCard(
        provider.translate('total_duty'),
        totalDutyStr,
        const Color(0xFF5B9BFF),
      ),
      _buildMiniSummaryCard(
        provider.translate('overtime'),
        totalOvertimeStr,
        const Color(0xFF00FF87),
      ),
      _buildMiniSummaryCard(
        provider.translate('delay'),
        '${totalDelay}m',
        const Color(0xFFFF5C5C),
      ),
      _buildMiniSummaryCard(
        provider.translate('early_exit'),
        '${totalEarlyExit}m',
        const Color(0xFFFF5C5C),
      ),
      _buildMiniSummaryCard(
        provider.translate('deficit'),
        totalDeficitStr,
        const Color(0xFFFF5C5C),
      ),
      _buildMiniSummaryCard(
        provider.translate('penalty'),
        '${NumberFormat('#,##0').format(totalPenalties)} IQD',
        const Color(0xFFFF5C5C),
      ),
      if (totalUnpaidLeave > 0)
        _buildMiniSummaryCard(
          provider.translate('unpaid_leave'),
          '${totalUnpaidLeave ~/ 60}h ${totalUnpaidLeave % 60}m',
          const Color(0xFFF59E0B),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return Row(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: cards[i]),
                ],
              ],
            );
          } else {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    cards[i],
                  ],
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildMiniSummaryCard(String label, String value, Color accentColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: accentColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    String title, {
    Color? color,
    TextAlign textAlign = TextAlign.start,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
      child: Text(
        title,
        textAlign: textAlign,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: color ??
              ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
        ),
      ),
    );
  }

  Widget _buildReportTable(List<Map<String, dynamic>> compiledData) {
    final provider = Provider.of<AttendanceProvider>(context);
    final subordinates = _getSubordinates(provider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bodyTextColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final dividerColor = bodyTextColor.withValues(alpha: 0.08);
    final headerBgColor = bodyTextColor.withValues(alpha: 0.06);

    const columnWidths = <int, TableColumnWidth>{
      0: FlexColumnWidth(1.5),  // Date & Shift
      1: FlexColumnWidth(2.2),  // Clock Time
      2: FlexColumnWidth(1.1),  // Attendance
      3: FlexColumnWidth(1.0),  // Rest Time
      4: FlexColumnWidth(1.0),  // Duty
      5: FlexColumnWidth(0.9),  // Delay
      6: FlexColumnWidth(0.9),  // Early Exit
      7: FlexColumnWidth(0.95), // Deficit
      8: FlexColumnWidth(1.0),  // Extra Time
      9: FlexColumnWidth(1.0),  // Overtime
      10: FlexColumnWidth(1.15), // Penalty
    };

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: GlassContainer(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = math.max(constraints.maxWidth, 1250.0);

                return Scrollbar(
                  controller: _tableHorizontalController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _tableHorizontalController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: tableWidth,
                      height: constraints.maxHeight,
                      child: Column(
                        children: [
                          // Sticky Fixed Header
                          Container(
                            decoration: BoxDecoration(
                              color: headerBgColor,
                              border: Border(
                                bottom: BorderSide(
                                  color: dividerColor,
                                  width: 1.0,
                                ),
                              ),
                            ),
                            child: Table(
                              columnWidths: columnWidths,
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              children: [
                                TableRow(
                                  children: [
                                    _buildHeaderCell(provider.translate('date')),
                                    _buildHeaderCell(
                                      provider.translate('clock_time'),
                                      color: const Color(0xFF5B9BFF),
                                    ),
                                    _buildHeaderCell(
                                      provider.translate('attendance'),
                                    ),
                                    _buildHeaderCell(
                                      provider.translate('rest_time'),
                                      color: const Color(0xFF2EBD96),
                                    ),
                                    _buildHeaderCell(provider.translate('duty')),
                                    _buildHeaderCell(
                                      provider.translate('delay'),
                                      color: const Color(0xFFFF5C5C),
                                    ),
                                    _buildHeaderCell(
                                      provider.translate('early_exit'),
                                      color: const Color(0xFFFF5C5C),
                                    ),
                                    _buildHeaderCell(
                                      provider.translate('deficit'),
                                      color: const Color(0xFFFF5C5C),
                                    ),
                                    _buildHeaderCell(
                                      provider.translate('extra_time'),
                                      color: const Color(0xFFFF9800),
                                    ),
                                    _buildHeaderCell(
                                      provider.translate('overtime'),
                                      color: const Color(0xFF00FF87),
                                    ),
                                    _buildHeaderCell(
                                      provider.translate('penalty'),
                                      color: const Color(0xFFFF5C5C),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Scrollable Body
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: () async {
                                final activeEmpId = _resolveActiveEmployeeId(
                                  provider,
                                  subordinates,
                                );
                                if (activeEmpId.isNotEmpty) {
                                  _loadSubordinateRecords(provider, activeEmpId);
                                }
                              },
                              child: Scrollbar(
                                controller: _tableVerticalController,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _tableVerticalController,
                                  scrollDirection: Axis.vertical,
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  child: compiledData.isEmpty
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                                          alignment: Alignment.center,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.calendar_month_rounded,
                                                size: 44,
                                                color: bodyTextColor.withValues(alpha: 0.25),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                provider.translate('no_records'),
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: bodyTextColor.withValues(alpha: 0.6),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Table(
                                  columnWidths: columnWidths,
                                  defaultVerticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  border: TableBorder(
                                    horizontalInside: BorderSide(
                                      color: dividerColor,
                                      width: 1.0,
                                    ),
                                    bottom: BorderSide(
                                      color: dividerColor,
                                      width: 1.0,
                                    ),
                                  ),
                                  children: compiledData.map((row) {
                                    final date = row['date'] as DateTime;
                                    final isSelected = _selectedDate != null &&
                                        DateUtils.isSameDay(_selectedDate, date);
                                    final dayRequests =
                                        (row['requests'] as List<Request>?) ??
                                            [];
                                    final hasRequests = dayRequests.isNotEmpty;

                                    final dayNameEng = DateFormat(
                                      'EEEE',
                                    ).format(date).toLowerCase();
                                    final translatedDay =
                                        provider.translate(dayNameEng);
                                    final dateStr =
                                        '$translatedDay\n${DateFormat('dd MMM').format(date)}';
                                    final isWeekend =
                                        row['isWeekend'] as bool;

                                    final attendanceStr = formatMinutes(
                                      row['attendance'] as int,
                                    );
                                    final restStr = formatMinutes(
                                      (row['rest'] ?? 0) as int,
                                    );
                                    final dutyStr =
                                        formatMinutes(row['duty'] as int);
                                    final delayStr =
                                        formatMinutes(row['delay'] as int);
                                    final earlyExitStr = formatMinutes(
                                      row['earlyExit'] as int,
                                    );
                                    final extraTimeStr = formatMinutes(
                                      row['extraTime'] as int,
                                    );
                                    final overtimeStr = formatMinutes(
                                      row['overtime'] as int,
                                    );
                                    final penaltyVal =
                                        row['penalty'] as double;
                                    final penaltyStr = penaltyVal > 0
                                        ? '${NumberFormat('#,##0').format(penaltyVal)} IQD'
                                        : '-';
                                    final shiftName =
                                        (row['shiftName'] as String?) ?? '';
                                    final shiftWorkHours =
                                        (row['shiftWorkHours'] as String?) ?? '';

                                    final rowColor = isSelected
                                        ? (isDark
                                            ? const Color(0xFF2E65FF)
                                                .withValues(alpha: 0.22)
                                            : const Color(0xFF2E65FF)
                                                .withValues(alpha: 0.12))
                                        : (isWeekend
                                            ? bodyTextColor.withValues(
                                                alpha: 0.02,
                                              )
                                            : Colors.transparent);

                                    Widget wrapCell(Widget cell) {
                                      return MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            setState(() {
                                              if (_selectedDate != null &&
                                                  DateUtils.isSameDay(
                                                    _selectedDate,
                                                    date,
                                                  )) {
                                                _selectedDate = null;
                                              } else {
                                                _selectedDate = date;
                                              }
                                            });
                                          },
                                          onDoubleTap: () {
                                            setState(() {
                                              _selectedDate = date;
                                            });
                                            _showDayRequestsDialog(
                                              context,
                                              provider,
                                              row,
                                            );
                                          },
                                          child: cell,
                                        ),
                                      );
                                    }

                                    return TableRow(
                                      decoration: BoxDecoration(
                                        color: rowColor,
                                      ),
                                      children: [
                                        // Date
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                if (isSelected)
                                                  Container(
                                                    width: 3.5,
                                                    height: 24,
                                                    margin:
                                                        const EdgeInsets.only(
                                                          right: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF2E65FF,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            2,
                                                          ),
                                                    ),
                                                  ),
                                                Expanded(
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        dateStr,
                                                        style: TextStyle(
                                                          color: isSelected
                                                              ? const Color(
                                                                0xFF2E65FF,
                                                              )
                                                              : (isWeekend
                                                                  ? bodyTextColor
                                                                      .withValues(
                                                                        alpha: 0.38,
                                                                      )
                                                                  : bodyTextColor
                                                                      .withValues(
                                                                        alpha: 0.7,
                                                                      )),
                                                          fontWeight: isSelected
                                                              ? FontWeight.bold
                                                              : FontWeight.w600,
                                                          fontSize: 12,
                                                          height: 1.2,
                                                        ),
                                                      ),
                                                      if (shiftName.isNotEmpty) ...[
                                                        const SizedBox(height: 3),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                horizontal: 5,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: (isSelected
                                                                    ? const Color(
                                                                        0xFF2E65FF,
                                                                      )
                                                                    : bodyTextColor)
                                                                .withValues(
                                                                  alpha: 0.07,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                            border: Border.all(
                                                              color: (isSelected
                                                                      ? const Color(
                                                                          0xFF2E65FF,
                                                                        )
                                                                      : bodyTextColor)
                                                                  .withValues(
                                                                    alpha: 0.12,
                                                                  ),
                                                              width: 0.8,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            shiftWorkHours.isNotEmpty
                                                                ? '$shiftName • $shiftWorkHours'
                                                                : shiftName,
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight.w600,
                                                              color: isSelected
                                                                  ? const Color(
                                                                      0xFF2E65FF,
                                                                    )
                                                                  : bodyTextColor
                                                                      .withValues(
                                                                        alpha:
                                                                            0.75,
                                                                      ),
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                if (hasRequests)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                          horizontal: 5,
                                                          vertical: 2,
                                                        ),
                                                    margin:
                                                        const EdgeInsets.only(
                                                          left: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF2E65FF,
                                                      ).withValues(alpha: 0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '${dayRequests.length}',
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF2E65FF,
                                                        ),
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // Clock Time
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: _buildClockTimeWidget(
                                              row['clockTime'] as String,
                                              row['missingPunchTimes']
                                                      as List<String>? ??
                                                  [],
                                              row['isLeave'] as bool? ?? false,
                                            ),
                                          ),
                                        ),
                                        // Attendance
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              (row['isLeave'] as bool? ??
                                                          false) &&
                                                      !(row['hasRecord'] as bool)
                                                  ? '-'
                                                  : attendanceStr,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Rest Time
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              (row['isLeave'] as bool? ??
                                                          false) &&
                                                      !(row['hasRecord'] as bool)
                                                  ? '-'
                                                  : restStr,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF2EBD96),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Duty
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              (row['isLeave'] as bool? ??
                                                          false) &&
                                                      !(row['hasRecord'] as bool)
                                                  ? '-'
                                                  : dutyStr,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Delay
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              delayStr,
                                              style: TextStyle(
                                                color: row['delay'] as int > 0
                                                    ? const Color(0xFFFF5C5C)
                                                    : (isDark
                                                        ? Colors.white60
                                                        : Colors.black54),
                                                fontWeight:
                                                    row['delay'] as int > 0
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Early Exit
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              earlyExitStr,
                                              style: TextStyle(
                                                color:
                                                    row['earlyExit'] as int > 0
                                                        ? const Color(
                                                          0xFFFF5C5C,
                                                        )
                                                        : (isDark
                                                            ? Colors.white60
                                                            : Colors.black54),
                                                fontWeight:
                                                    row['earlyExit'] as int > 0
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Deficit
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              formatMinutes(
                                                (row['deficit'] as int?) ?? 0,
                                              ),
                                              style: TextStyle(
                                                color:
                                                    ((row['deficit'] as int?) ??
                                                                0) >
                                                            0
                                                        ? const Color(
                                                          0xFFFF5C5C,
                                                        )
                                                        : (isDark
                                                            ? Colors.white60
                                                            : Colors.black54),
                                                fontWeight:
                                                    ((row['deficit'] as int?) ??
                                                                0) >
                                                            0
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Extra Time
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              extraTimeStr,
                                              style: TextStyle(
                                                color:
                                                    row['extraTime'] as int > 0
                                                        ? const Color(
                                                          0xFFFF9800,
                                                        )
                                                        : (isDark
                                                            ? Colors.white60
                                                            : Colors.black54),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Overtime
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              overtimeStr,
                                              style: TextStyle(
                                                color:
                                                    row['overtime'] as int > 0
                                                        ? const Color(
                                                          0xFF00FF87,
                                                        )
                                                        : (isDark
                                                            ? Colors.white60
                                                            : Colors.black54),
                                                fontWeight:
                                                    row['overtime'] as int > 0
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Penalty
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              penaltyStr,
                                              style: TextStyle(
                                                color: penaltyVal > 0
                                                    ? const Color(0xFFFF5C5C)
                                                    : (isDark
                                                        ? Colors.white60
                                                        : Colors.black54),
                                                fontWeight: penaltyVal > 0
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                fontSize: 12,
                                              ),
                                            ),
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
                      ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeDropdown(
    AttendanceProvider provider,
    List<CompanyEmployee> subordinates,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final menuBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    final seenIds = <String>{};
    final uniqueSubordinates =
        subordinates.where((e) => seenIds.add(e.id)).toList();
    final activeId = _resolveActiveEmployeeId(provider, uniqueSubordinates);

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Theme(
        data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
          canvasColor: menuBgColor,
          menuButtonTheme: MenuButtonThemeData(
            style: MenuItemButton.styleFrom(
              foregroundColor: itemTextColor,
            ),
          ),
        ),
        child: DropdownMenu<String>(
          key: ValueKey('emp_dropdown_${activeId}_${uniqueSubordinates.length}'),
          initialSelection: activeId,
          enableFilter: true,
          enableSearch: true,
          expandedInsets: EdgeInsets.zero,
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(
              menuBgColor.withValues(alpha: 0.98),
            ),
            elevation: WidgetStateProperty.all(8),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          textStyle: TextStyle(
            color: itemTextColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          dropdownMenuEntries: uniqueSubordinates.map((emp) {
            return DropdownMenuEntry<String>(
              value: emp.id,
              label: '${emp.name} (${emp.position})',
              style: MenuItemButton.styleFrom(
                foregroundColor: itemTextColor,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onSelected: (val) {
            if (val != null) {
              if (_selectedEmployeeId != val) {
                setState(() {
                  _selectedEmployeeId = val;
                  _selectedDate = null;
                  _subordinateRecords = [];
                  _subordinateRequests = [];
                });
                _loadSubordinateRecords(provider, val);
              } else if (_subordinateRecords.isEmpty) {
                _loadSubordinateRecords(provider, val);
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildRefreshButton(
    AttendanceProvider provider,
    List<CompanyEmployee> subordinates,
  ) {
    return NeuIconButton(
      size: 44,
      variant: NeuButtonVariant.whitePill,
      tooltip: provider.translate('refresh'),
      icon: _isLoadingSubordinate
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF2E65FF),
              ),
            )
          : const Icon(Icons.refresh_rounded, size: 20),
      onPressed: _isLoadingSubordinate
          ? null
          : () async {
              final activeEmpId = _resolveActiveEmployeeId(provider, subordinates);
              if (activeEmpId.isNotEmpty) {
                _loadSubordinateRecords(provider, activeEmpId);
              }
            },
    );
  }

  Widget _buildAddRequestButton(
    AttendanceProvider provider,
    List<CompanyEmployee> subordinates, {
    bool isCompact = false,
  }) {
    final activeEmpId = _resolveActiveEmployeeId(provider, subordinates);
    final isClosed = _selectedDate != null && provider.isMonthClosed(_selectedDate!);
    if (isCompact) {
      return NeuIconButton(
        size: 44,
        variant: NeuButtonVariant.primary,
        tooltip: provider.translate('new_request'),
        icon: Icon(isClosed ? Icons.lock_outline : Icons.add, size: 20),
        onPressed: isClosed
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(provider.translate('cannot_modify_closed_month')),
                    backgroundColor: Colors.amber.shade800,
                  ),
                );
              }
            : () {
                showNewRequestDialog(
                  context: context,
                  provider: provider,
                  initialEmployeeId: activeEmpId,
                  initialDate: _selectedDate,
                  onSubmitted: () {
                    _loadSubordinateRecords(provider, activeEmpId);
                  },
                );
              },
      );
    }
    return NeuButton(
      onPressed: isClosed
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(provider.translate('cannot_modify_closed_month')),
                  backgroundColor: Colors.amber.shade800,
                ),
              );
            }
          : () {
              showNewRequestDialog(
                context: context,
                provider: provider,
                initialEmployeeId: activeEmpId,
                initialDate: _selectedDate,
                onSubmitted: () {
                  _loadSubordinateRecords(provider, activeEmpId);
                },
              );
            },
      icon: Icon(isClosed ? Icons.lock_outline : Icons.add),
      label: provider.translate('new_request'),
    );
  }

  Widget _buildExportButton(
    AttendanceProvider provider,
    List<CompanyEmployee> subordinates,
    List<Map<String, dynamic>> records,
  ) {
    return NeuIconButton(
      size: 44,
      variant: NeuButtonVariant.whitePill,
      tooltip: 'Export PDF',
      icon: const Icon(Icons.file_download_outlined, size: 20),
      onPressed: () async {
        final activeEmpId = _resolveActiveEmployeeId(provider, subordinates);
        final employee = provider.employees.firstWhere(
          (e) => e.id == activeEmpId,
          orElse: () => provider.currentEmployee ?? CompanyEmployee(id: activeEmpId, name: 'Employee', email: '', position: ''),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exporting attendance history...')),
        );

        await ExportService.exportHistoryToPdf(
          records: records,
          employee: employee,
          month: _reportMonth,
          profile: provider.companyProfile,
          languageCode: provider.currentLanguage,
        );
      },
    );
  }

  void _showDayRequestsDialog(
    BuildContext context,
    AttendanceProvider provider,
    Map<String, dynamic> rowData,
  ) {
    final date = rowData['date'] as DateTime;
    final dayNameEng = DateFormat('EEEE').format(date).toLowerCase();
    final translatedDay = provider.translate(dayNameEng);
    final formattedDateStr =
        '$translatedDay, ${_formatLocalizedDate(date, provider)}';
    final List<Request> requests = List<Request>.from(
        (rowData['requests'] as List<Request>?) ?? []);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final isDayMonthClosed =
        provider.isMonthClosed(date) ||
        provider.isDateStringInClosedMonth(rowData['date'] ?? date);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Dialog Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF2E65FF).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.assignment_outlined,
                                color: Color(0xFF2E65FF),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    provider.translate('requests'),
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formattedDateStr,
                                    style: TextStyle(
                                      color: textColor.withValues(alpha: 0.6),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: const Icon(Icons.close),
                              splashRadius: 20,
                              color: textColor.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1, thickness: 1),

                      // Day Summary Strip (Attendance Context)
                      Container(
                        color: textColor.withValues(alpha: isDark ? 0.04 : 0.02),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceAround,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if ((rowData['shiftName'] as String?)?.isNotEmpty ?? false)
                              _buildDialogDayStat(
                                label: provider.translate('shift'),
                                value: (rowData['shiftWorkHours'] as String?)?.isNotEmpty ?? false
                                    ? '${rowData['shiftName']} (${rowData['shiftWorkHours']})'
                                    : '${rowData['shiftName']}',
                                color: const Color(0xFF10B981),
                              ),
                            _buildDialogDayStat(
                              label: provider.translate('attendance'),
                              value: (rowData['isLeave'] as bool? ?? false) &&
                                      !(rowData['hasRecord'] as bool)
                                  ? '-'
                                  : formatMinutes(rowData['attendance'] as int),
                              color: const Color(0xFF2E65FF),
                            ),
                            _buildDialogDayStat(
                              label: provider.translate('clock_time'),
                              value: (rowData['clockTime'] as String).replaceAll(
                                '\n',
                                ', ',
                              ),
                              color: const Color(0xFF5B9BFF),
                            ),
                            _buildDialogDayStat(
                              label: provider.translate('duty'),
                              value: formatMinutes(rowData['duty'] as int),
                              color: textColor.withValues(alpha: 0.7),
                            ),
                            _buildDialogDayStat(
                              label: provider.translate('delay'),
                              value: '${rowData['delay']}m',
                              color: (rowData['delay'] as int) > 0
                                  ? const Color(0xFFFF5C5C)
                                  : textColor.withValues(alpha: 0.7),
                            ),
                            if (((rowData['deficit'] as int?) ?? 0) > 0)
                              _buildDialogDayStat(
                                label: provider.translate('deficit'),
                                value: formatMinutes((rowData['deficit'] as int?) ?? 0),
                                color: const Color(0xFFFF5C5C),
                              ),
                            if (((rowData['extraTime'] as int?) ?? 0) > 0)
                              _buildDialogDayStat(
                                label: provider.translate('extra_time'),
                                value: formatMinutes((rowData['extraTime'] as int?) ?? 0),
                                color: const Color(0xFFFF9800),
                              ),
                            if (((rowData['overtime'] as int?) ?? 0) > 0)
                              _buildDialogDayStat(
                                label: provider.translate('overtime'),
                                value: formatMinutes((rowData['overtime'] as int?) ?? 0),
                                color: const Color(0xFF00FF87),
                              ),
                          ],
                        ),
                      ),

                      const Divider(height: 1, thickness: 1),

                      // Closed month warning banner
                      if (isDayMonthClosed)
                        Container(
                          margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade900.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock_rounded, size: 16, color: Colors.amber.shade400),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  provider.translate('cannot_modify_closed_month'),
                                  style: TextStyle(
                                    color: Colors.amber.shade300,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Requests Content
                      Flexible(
                        child: requests.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 40,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: textColor.withValues(alpha: 0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.article_outlined,
                                        size: 32,
                                        color: textColor.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      provider.translate('no_requests'),
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      provider.translate('no_requests_for_date'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: textColor.withValues(alpha: 0.5),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                    if (!isDayMonthClosed) ...[
                                      const SizedBox(height: 20),
                                      NeuButton(
                                        onPressed: () {
                                          Navigator.of(ctx).pop();
                                          final activeEmpId = _resolveActiveEmployeeId(provider, _getSubordinates(provider));
                                          showNewRequestDialog(
                                            context: context,
                                            provider: provider,
                                            initialEmployeeId: activeEmpId,
                                            initialDate: date,
                                            onSubmitted: () {
                                              _loadSubordinateRecords(provider, activeEmpId);
                                            },
                                          );
                                        },
                                        icon: const Icon(Icons.add),
                                        label: provider.translate('new_request'),
                                        height: 40,
                                        fontSize: 13,
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(20),
                                itemCount: requests.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final req = requests[index];
                                  final isReqClosed = isDayMonthClosed || provider.isDateStringInClosedMonth(req.date);
                                  return _buildRequestDetailCard(
                                    req,
                                    provider,
                                    isDark,
                                    textColor,
                                    onDelete: isReqClosed ? null : () async {
                                      final confirm = await showDialog<bool>(
                                        context: dialogCtx,
                                        builder: (c) => AlertDialog(
                                          backgroundColor: isDark
                                              ? const Color(0xFF1E293B)
                                              : Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          title: Row(
                                            children: [
                                              const Icon(
                                                Icons.delete_outline,
                                                color: Colors.redAccent,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                provider.translate('delete_request'),
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          content: Text(
                                            provider.translate(
                                                'confirm_delete_request'),
                                            style: TextStyle(
                                              color: textColor
                                                  .withValues(alpha: 0.8),
                                              fontSize: 14,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(c).pop(false),
                                              child: Text(
                                                provider.translate('cancel'),
                                                style: TextStyle(
                                                  color: textColor
                                                      .withValues(alpha: 0.6),
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.of(c).pop(true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.redAccent,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: Text(
                                                  provider.translate('delete')),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm != true) return;

                                      final activeEmpId = _resolveActiveEmployeeId(provider, _getSubordinates(provider));
                                      final empId = req.employeeId ?? activeEmpId;

                                      await provider.deleteRequest(empId, req.id);

                                      setDialogState(() {
                                        requests.removeWhere((r) => r.id == req.id);
                                        rowData['requests'] = requests;
                                      });

                                      _loadSubordinateRecords(provider, activeEmpId);

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              provider.translate(
                                                  'request_deleted'),
                                            ),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    },
                                  );
                                },
                              ),
                      ),

                      // Footer
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                provider.translate('close'),
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestDetailCard(
    Request req,
    AttendanceProvider provider,
    bool isDark,
    Color textColor, {
    VoidCallback? onDelete,
  }) {
    final statusColor = req.statusColor;
    final statusLabel = _translateRequestStatus(req.status, provider);
    final typeLabel = _translateRequestType(req.type, provider);

    IconData typeIcon = Icons.assignment_outlined;
    if (req.type.contains('Leave')) {
      typeIcon = Icons.beach_access_rounded;
    } else if (req.type == 'Change Shift') {
      typeIcon = Icons.swap_horiz_rounded;
    } else if (req.type == 'Missing Punch' ||
        req.type == 'Forgot to Clock Out') {
      typeIcon = Icons.fingerprint;
    } else if (req.type.contains('Overtime')) {
      typeIcon = Icons.more_time_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: textColor.withValues(alpha: isDark ? 0.12 : 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type and Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(typeIcon, size: 18, color: statusColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      req.date
                          .replaceAll('January', provider.translate('month_1'))
                          .replaceAll('February', provider.translate('month_2'))
                          .replaceAll('March', provider.translate('month_3'))
                          .replaceAll('April', provider.translate('month_4'))
                          .replaceAll('May', provider.translate('month_5'))
                          .replaceAll('June', provider.translate('month_6'))
                          .replaceAll('July', provider.translate('month_7'))
                          .replaceAll('August', provider.translate('month_8'))
                          .replaceAll('September', provider.translate('month_9'))
                          .replaceAll('October', provider.translate('month_10'))
                          .replaceAll('November', provider.translate('month_11'))
                          .replaceAll('December', provider.translate('month_12')),
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: provider.translate('delete_request'),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Duration or Shift details
          if (req.type == 'Change Shift' && req.targetShiftId != null) ...[
            _buildDetailRow(
              icon: Icons.schedule,
              label: provider.translate('target_shift'),
              value: provider.shifts
                  .firstWhere(
                    (s) => s.id == req.targetShiftId,
                    orElse: () => WorkShift(
                      id: '',
                      name: 'Unknown',
                      startTime: '',
                      endTime: '',
                    ),
                  )
                  .name,
              textColor: textColor,
            ),
          ] else if (req.duration.isNotEmpty) ...[
            _buildDetailRow(
              icon: Icons.timer_outlined,
              label: provider.translate('duration'),
              value: req.duration
                  .replaceAll('Clock In:', provider.translate('clock_in_colon'))
                  .replaceAll('Clock Out:', provider.translate('clock_out_colon'))
                  .replaceAll(RegExp(r'\bDays\b', caseSensitive: false), provider.translate('unit_days'))
                  .replaceAll(RegExp(r'\bDay\b', caseSensitive: false), provider.translate('day_unit')),
              textColor: textColor,
            ),
          ],

          // Note
          if (req.note != null && req.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildDetailRow(
              icon: Icons.notes_rounded,
              label: provider.translate('note'),
              value: req.note!,
              textColor: textColor,
            ),
          ],

          // Detailed Approval Workflow Timeline
          _buildWorkflowTimeline(
            req: req,
            provider: provider,
            isDark: isDark,
            textColor: textColor,
          ),

          // Action button: Delete Request
          if (onDelete != null) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Colors.redAccent,
                  ),
                  label: Text(
                    provider.translate('delete_request'),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: Colors.redAccent.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkflowTimeline({
    required Request req,
    required AttendanceProvider provider,
    required bool isDark,
    required Color textColor,
  }) {
    // 1. Submitter Resolution
    String submitterName = 'Employee';
    String submitterRole = 'Staff';
    CompanyEmployee? submitterEmp;
    if (req.employeeId != null && req.employeeId!.isNotEmpty) {
      submitterEmp = provider.employees.where(
        (e) => e.id == req.employeeId || e.email == req.employeeId,
      ).firstOrNull;
      if (submitterEmp != null) {
        submitterName = submitterEmp.name;
        submitterRole = submitterEmp.position.isNotEmpty ? submitterEmp.position : submitterEmp.role;
      } else if (provider.currentEmployee != null &&
          (provider.currentEmployee!.id == req.employeeId ||
           provider.currentEmployee!.name == req.employeeId)) {
        submitterEmp = provider.currentEmployee;
        submitterName = provider.currentEmployee!.name;
        submitterRole = provider.currentEmployee!.position;
      }
    } else if (provider.currentEmployee != null) {
      submitterEmp = provider.currentEmployee;
      submitterName = provider.currentEmployee!.name;
      submitterRole = provider.currentEmployee!.position;
    }

    // 2. Submission Date & Time
    DateTime submitDate = DateTime.now();
    if (req.createdAt != null && req.createdAt!.isNotEmpty) {
      submitDate = DateTime.tryParse(req.createdAt!) ?? submitDate;
    } else {
      try {
        if (req.date.contains(' - ')) {
          submitDate = DateFormat('MMMM d, yyyy').parse(req.date.split(' - ')[0].trim());
        } else {
          submitDate = DateFormat('MMMM d, yyyy').parse(req.date.trim());
        }
        submitDate = DateTime(submitDate.year, submitDate.month, submitDate.day, 8, 30);
      } catch (_) {}
    }
    final formattedSubmitDate = _formatLocalizedDateTime(submitDate, provider);

    // 3. Structure Supervisor Resolution
    String supervisorName = provider.translate('role_supervisor');
    String supervisorRole = provider.translate('role_supervisor');
    if (req.supervisorActionBy != null && req.supervisorActionBy!.isNotEmpty) {
      final sMatch = provider.employees.where(
        (e) => e.id == req.supervisorActionBy || e.name.toLowerCase() == req.supervisorActionBy!.toLowerCase(),
      ).firstOrNull;
      if (sMatch != null) {
        supervisorName = sMatch.name;
        supervisorRole = sMatch.position.isNotEmpty ? sMatch.position : provider.translate('role_supervisor');
      }
    } else {
      // Find supervisor of the employee's structure
      if (submitterEmp?.structureId != null && submitterEmp!.structureId!.isNotEmpty) {
        final struct = provider.structures.where((s) => s.id == submitterEmp!.structureId).firstOrNull;
        if (struct?.supervisorId != null) {
          final sMatch = provider.employees.where((e) => e.id == struct!.supervisorId).firstOrNull;
          if (sMatch != null) {
            supervisorName = sMatch.name;
            supervisorRole = sMatch.position.isNotEmpty ? sMatch.position : provider.translate('role_supervisor');
          }
        }
      }
    }
    supervisorRole = _translateRole(supervisorRole, provider);

    DateTime supervisorDate = submitDate.add(const Duration(minutes: 30));
    if (req.supervisorActionDate != null && req.supervisorActionDate!.isNotEmpty) {
      supervisorDate = DateTime.tryParse(req.supervisorActionDate!) ?? supervisorDate;
    }
    final formattedSupervisorDate = _formatLocalizedDateTime(supervisorDate, provider);

    // 4. HR Manager Resolution
    String hrName = provider.translate('role_hr_manager');
    String hrRole = provider.translate('role_hr_manager');
    final hrActionTarget = req.hrActionBy ?? (req.supervisorActionBy == null ? req.actionBy : null);
    if (hrActionTarget != null && hrActionTarget.isNotEmpty) {
      final hMatch = provider.employees.where(
        (e) => e.id == hrActionTarget || e.name.toLowerCase() == hrActionTarget.toLowerCase(),
      ).firstOrNull;
      if (hMatch != null) {
        hrName = hMatch.name;
        hrRole = hMatch.position.isNotEmpty ? hMatch.position : provider.translate('role_hr_manager');
      }
    } else {
      final hrEmp = provider.employees.where(
        (e) => (e.role == 'hr' || e.role == 'admin') && e.id != req.employeeId,
      ).firstOrNull ?? provider.employees.where((e) => e.role == 'hr' || e.role == 'admin').firstOrNull;
      if (hrEmp != null) {
        hrName = hrEmp.name;
        hrRole = hrEmp.position.isNotEmpty ? hrEmp.position : provider.translate('role_hr_manager');
      }
    }
    hrRole = _translateRole(hrRole, provider);

    DateTime hrDate = supervisorDate.add(const Duration(minutes: 30));
    final hrDateTarget = req.hrActionDate ?? (req.supervisorActionDate == null ? req.actionDate : null);
    if (hrDateTarget != null && hrDateTarget.isNotEmpty) {
      hrDate = DateTime.tryParse(hrDateTarget) ?? hrDate;
    }
    final formattedHrDate = _formatLocalizedDateTime(hrDate, provider);

    final isApproved = req.status == 'Approved';
    final isRejected = req.status == 'Rejected';

    // Badge status styling
    final Color overallColor = isApproved
        ? const Color(0xFF10B981)
        : (isRejected
            ? const Color(0xFFEF4444)
            : (req.status == 'Pending HR' ? const Color(0xFF8B5CF6) : const Color(0xFFF59E0B)));

    final IconData overallIcon = isApproved
        ? Icons.check_circle_rounded
        : (isRejected
            ? Icons.cancel_rounded
            : Icons.hourglass_top_rounded);

    // Determine Step 2 (Supervisor) State
    final bool isSupApproved = req.supervisorStatus == 'Approved' ||
        (req.supervisorActionBy != null && req.status != 'Rejected') ||
        (req.status == 'Pending HR' && req.supervisorActionBy != null);
    final bool isSupRejected = req.supervisorStatus == 'Rejected' ||
        (isRejected && req.supervisorActionBy != null && req.hrActionBy == null);
    final bool isSupPending = req.status == 'Pending Supervisor';
    final bool isSupBypassed = req.supervisorActionBy == null && (req.status == 'Pending HR' || req.status == 'Approved');

    Color supColor;
    IconData supIcon;
    String supTitle;
    String supSubtitle;

    if (isSupApproved) {
      supColor = const Color(0xFF10B981);
      supIcon = Icons.check_circle_rounded;
      supTitle = provider.translate('approved_by').replaceAll('{name}', supervisorName);
      supSubtitle = '$supervisorRole • $formattedSupervisorDate';
    } else if (isSupRejected) {
      supColor = const Color(0xFFEF4444);
      supIcon = Icons.cancel_rounded;
      supTitle = provider.translate('rejected_by').replaceAll('{name}', supervisorName);
      supSubtitle = '$supervisorRole • $formattedSupervisorDate';
    } else if (isSupPending) {
      supColor = const Color(0xFFF59E0B);
      supIcon = Icons.hourglass_top_rounded;
      supTitle = provider.translate('awaiting_supervisor_review');
      supSubtitle = provider.translate('pending_review_by')
          .replaceAll('{name}', supervisorName)
          .replaceAll('{role}', supervisorRole);
    } else if (isSupBypassed) {
      supColor = const Color(0xFF3B82F6);
      supIcon = Icons.check_circle_outline_rounded;
      supTitle = provider.translate('passed_supervisor_review');
      supSubtitle = provider.translate('no_supervisor_assigned');
    } else {
      supColor = textColor.withValues(alpha: 0.3);
      supIcon = Icons.radio_button_unchecked_rounded;
      supTitle = provider.translate('supervisor_review');
      supSubtitle = provider.translate('status_pending');
    }

    // Determine Step 3 (HR Manager) State
    final bool hasHRManager = provider.employees.any(
      (e) => (e.role == 'hr' || e.role == 'admin') && e.id != req.employeeId,
    );
    final bool isHrApproved = isApproved;
    final bool isHrRejected = isRejected && !isSupRejected;
    final bool isHrPending = req.status == 'Pending HR';

    Color hrColor;
    IconData hrIcon;
    String hrTitle;
    String hrSubtitle;

    if (isHrApproved) {
      if (req.hrActionBy == null && req.supervisorActionBy != null && !hasHRManager) {
        hrColor = const Color(0xFF10B981);
        hrIcon = Icons.check_circle_rounded;
        hrTitle = provider.translate('approved_passed_hr');
        hrSubtitle = provider.translate('no_hr_configured');
      } else if (req.hrActionBy == null && req.supervisorActionBy == null && !hasHRManager) {
        hrColor = const Color(0xFF10B981);
        hrIcon = Icons.check_circle_rounded;
        hrTitle = provider.translate('auto_approved');
        hrSubtitle = provider.translate('no_supervisor_hr_required');
      } else {
        hrColor = const Color(0xFF10B981);
        hrIcon = Icons.check_circle_rounded;
        hrTitle = provider.translate('approved_by').replaceAll('{name}', hrName);
        hrSubtitle = '$hrRole • $formattedHrDate ${provider.translate('msg_sent_employee')}';
      }
    } else if (isHrRejected) {
      hrColor = const Color(0xFFEF4444);
      hrIcon = Icons.cancel_rounded;
      hrTitle = provider.translate('rejected_by').replaceAll('{name}', hrName);
      hrSubtitle = '$hrRole • $formattedHrDate';
    } else if (isHrPending) {
      hrColor = const Color(0xFF8B5CF6);
      hrIcon = Icons.hourglass_top_rounded;
      hrTitle = provider.translate('awaiting_hr_approval');
      hrSubtitle = provider.translate('assigned_to')
          .replaceAll('{name}', hrName)
          .replaceAll('{role}', hrRole);
    } else if (isSupRejected) {
      hrColor = textColor.withValues(alpha: 0.3);
      hrIcon = Icons.block_rounded;
      hrTitle = provider.translate('hr_manager_review');
      hrSubtitle = provider.translate('terminated_supervisor_rejection');
    } else {
      hrColor = textColor.withValues(alpha: 0.3);
      hrIcon = Icons.radio_button_unchecked_rounded;
      hrTitle = provider.translate('hr_manager_review');
      hrSubtitle = provider.translate('pending_supervisor_approval');
    }

    submitterRole = _translateRole(submitterRole, provider);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.7) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: textColor.withValues(alpha: isDark ? 0.1 : 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.alt_route_rounded,
                size: 16,
                color: Color(0xFF2E65FF),
              ),
              const SizedBox(width: 8),
              Text(
                provider.translate('approval_workflow'),
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: overallColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(overallIcon, size: 12, color: overallColor),
                    const SizedBox(width: 4),
                    Text(
                      _translateRequestStatus(req.status, provider),
                      style: TextStyle(
                        color: overallColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Step 1: Submission
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E65FF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      size: 12,
                      color: Color(0xFF2E65FF),
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 28,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.translate('registered_by_step').replaceAll('{name}', submitterName),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$submitterRole • $formattedSubmitDate',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Step 2: Structure Supervisor Review
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: supColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      supIcon,
                      size: 13,
                      color: supColor,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 28,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '2. $supTitle',
                        style: TextStyle(
                          color: isSupApproved || isSupRejected ? textColor : textColor.withValues(alpha: 0.75),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        supSubtitle,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Step 3: HR Manager Final Approval
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: hrColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hrIcon,
                  size: 13,
                  color: hrColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '3. $hrTitle',
                        style: TextStyle(
                          color: isHrApproved || isHrRejected ? textColor : textColor.withValues(alpha: 0.75),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hrSubtitle,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: textColor.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.55),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogDayStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _translateRequestType(String rawType, AttendanceProvider provider) {
    switch (rawType) {
      case 'Annual Leave':
        return provider.translate('vacation_leave');
      case 'Sick Leave':
        return provider.translate('sick_leave');
      case 'Overtime Approval':
        return provider.translate('overtime_approval');
      case 'Forgot to Clock Out':
        return provider.translate('forgot_to_clock_out');
      case 'Hourly Leave':
        return provider.translate('hourly_leave') != 'hourly_leave'
            ? provider.translate('hourly_leave')
            : 'Hourly Leave';
      case 'Unpaid Leave':
        return provider.translate('unpaid_leave') != 'unpaid_leave'
            ? provider.translate('unpaid_leave')
            : 'Unpaid Leave';
      case 'Hourly Unpaid Leave':
        return provider.translate('hourly_unpaid_leave') != 'hourly_unpaid_leave'
            ? provider.translate('hourly_unpaid_leave')
            : 'Hourly Unpaid Leave';
      case 'Change Shift':
        return provider.translate('change_shift') != 'change_shift'
            ? provider.translate('change_shift')
            : 'Change Shift';
      case 'Missing Punch':
        return provider.translate('missing_punch');
      default:
        return rawType;
    }
  }

  String _translateRole(String rawRole, AttendanceProvider provider) {
    final lower = rawRole.trim().toLowerCase();
    if (lower == 'super administrator' || lower == 'super admin' || lower == 'admin') {
      return provider.translate('role_super_admin');
    }
    if (lower == 'structure supervisor' || lower == 'supervisor') {
      return provider.translate('role_supervisor');
    }
    if (lower == 'hr management' || lower == 'hr manager' || lower == 'hr') {
      return provider.translate('role_hr_manager');
    }
    if (lower == 'employee' || lower == 'staff') {
      return provider.translate('role_employee');
    }
    return rawRole;
  }

  String _formatLocalizedDate(DateTime dt, AttendanceProvider provider) {
    final monthName = provider.translate('month_${dt.month}');
    return '$monthName ${dt.day}, ${dt.year}';
  }

  String _formatLocalizedDateTime(DateTime dt, AttendanceProvider provider) {
    final monthName = provider.translate('month_${dt.month}');
    final timeStr = DateFormat('hh:mm a').format(dt);
    return '$monthName ${dt.day}, ${dt.year} • $timeStr';
  }

  String _translateRequestStatus(
    String rawStatus,
    AttendanceProvider provider,
  ) {
    switch (rawStatus) {
      case 'Approved':
        return provider.translate('status_approved');
      case 'Pending':
        return provider.translate('status_pending');
      case 'Pending Supervisor':
        return provider.translate('status_pending_supervisor');
      case 'Pending HR':
        return provider.translate('status_pending_hr');
      case 'Rejected':
        return provider.translate('status_rejected');
      default:
        return rawStatus;
    }
  }
}
