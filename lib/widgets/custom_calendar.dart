import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/attendance_record.dart';
import '../providers/attendance_provider.dart';
import '../models/hr_models.dart';
import '../models/request_model.dart';
import 'glass_container.dart';

enum DayStatus { none, normal, extraTime, deficit, deficitAndExtraTime, incomplete, missed, leave }

class CustomCalendar extends StatefulWidget {
  const CustomCalendar({super.key});

  @override
  State<CustomCalendar> createState() => _CustomCalendarState();
}

class _CustomCalendarState extends State<CustomCalendar> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  int _parseTimeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return 0;
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  DayStatus _getDayStatus(
    DateTime date,
    List<AttendanceRecord> dayRecords,
    WorkShift shift,
    List<Request> requests,
    bool isToday,
    Request? approvedLeave,
    Holiday? holiday,
  ) {
    if (holiday != null || approvedLeave != null) {
      return DayStatus.leave;
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    if (dayRecords.isEmpty) {
      // Future days with no record
      if (date.isAfter(now) && !DateUtils.isSameDay(date, now)) {
        return DayStatus.none;
      }

      // If it is in the past, and it is a working day, and they were not on approved leave, it is missed!
      if (date.isBefore(todayStart)) {
        final isWeekday = shift.isWorkingDay(date);
        if (isWeekday) {
          return DayStatus.missed;
        }
      }
      return DayStatus.none;
    }

    final startTimeStr = shift.getStartTimeForDate(date);
    final endTimeStr = shift.getEndTimeForDate(date);
    if (startTimeStr.isEmpty || endTimeStr.isEmpty) {
      return DayStatus.normal;
    }

    final shiftStartMinutes = _parseTimeToMinutes(startTimeStr);
    final shiftEndMinutes = _parseTimeToMinutes(endTimeStr);

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

    final hasApprovedMissingPunch = requests.any((req) =>
        req.status == 'Approved' &&
        (req.type == 'Missing Punch' ||
            req.type == 'Forgot to Clock In' ||
            req.type == 'Forgot to Clock Out'));

    final hasUnexcusedMissedPunch = !hasApprovedMissingPunch &&
        dayRecords.any((rec) {
          if (rec.checkIn == rec.checkOut) return true;
          if (rec.checkOut == null) {
            if (!isToday) return true;
            if (DateTime.now().isAfter(shiftEnd)) return true;
          }
          return false;
        });

    if (hasUnexcusedMissedPunch) {
      return DayStatus.incomplete;
    }

    // Sort records to find first check-in and last check-out
    final sortedRecords = List<AttendanceRecord>.from(dayRecords)
      ..sort((a, b) => a.checkIn.compareTo(b.checkIn));

    final firstRecord = sortedRecords.first;
    final lastRecord = sortedRecords.last;

    // Parse first record check-in
    final checkInMinutes =
        firstRecord.checkIn.hour * 60 + firstRecord.checkIn.minute;

    final isSpecial = shift.isSpecialShiftForDate(date);

    // Delay check (late check-in based on first session) - disabled for special shifts
    final delay = checkInMinutes - shiftStartMinutes;
    final isDelayed = !isSpecial && (delay > shift.forgivenessOfDelay);

    // Early exit check (based on last session checkout if completed) - disabled for special shifts
    bool isEarlyExit = false;
    if (!isSpecial && lastRecord.checkOut != null) {
      final checkOutMinutes =
          lastRecord.checkOut!.hour * 60 + lastRecord.checkOut!.minute;
      final earlyExit = shiftEndMinutes - checkOutMinutes;
      isEarlyExit = earlyExit > shift.earlyExit;
    }

    // Expected duration vs actual (handles 12h day/night, 24h, and standard)
    final int expectedDurationMinutes;
    if (shiftEndMinutes < shiftStartMinutes) {
      expectedDurationMinutes = (24 * 60) - shiftStartMinutes + shiftEndMinutes;
    } else if (shiftEndMinutes == shiftStartMinutes) {
      expectedDurationMinutes = 24 * 60;
    } else {
      expectedDurationMinutes = shiftEndMinutes - shiftStartMinutes;
    }
    final netExpectedDuration =
        expectedDurationMinutes - shift.getBreakDurationForDate(date);

    // Sum of all session durations
    int totalActualDurationMinutes = 0;
    int extraMinutes = 0;
    for (var rec in dayRecords) {
      totalActualDurationMinutes += rec.duration.inMinutes;

      final sessionStart = rec.checkIn;
      final sessionEnd =
          rec.checkOut ?? (isToday ? DateTime.now() : sessionStart);

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
      if (shiftEnd.isBefore(shiftStart) || shiftEnd.isAtSameMomentAs(shiftStart) || shift.isOvernightForDate(date)) {
        shiftEnd = shiftEnd.add(const Duration(days: 1));
      }

      // Calculate Extra Time (only worked minutes outside of shift bounds)
      final isWeekend = !shift.isWorkingDay(date);
      if (isWeekend) {
        extraMinutes += sessionEnd.difference(sessionStart).inMinutes;
      } else {
        if (sessionStart.isBefore(shiftStart)) {
          final endForBefore = sessionEnd.isBefore(shiftStart)
              ? sessionEnd
              : shiftStart;
          extraMinutes += endForBefore.difference(sessionStart).inMinutes;
        }
        if (sessionEnd.isAfter(shiftEnd)) {
          final startForAfter = sessionStart.isAfter(shiftEnd)
              ? sessionStart
              : shiftEnd;
          extraMinutes += sessionEnd.difference(startForAfter).inMinutes;
        }
      }
    }

    final isDeficit = totalActualDurationMinutes < netExpectedDuration;

    final isExtraTime = extraMinutes > 0;

    final hasDeficit = isSpecial ? isDeficit : (isDelayed || isEarlyExit || isDeficit);

    if (hasDeficit && isExtraTime) {
      return DayStatus.deficitAndExtraTime;
    } else if (hasDeficit) {
      return DayStatus.deficit;
    } else if (isExtraTime) {
      return DayStatus.extraTime;
    }

    return DayStatus.normal;
  }

  /// Shows the attendance details dialog for the tapped [date].
  void _showAttendanceDetailsDialog(
    BuildContext context,
    DateTime date,
    List<AttendanceRecord> dayRecords,
    bool isActiveToday,
    DayStatus status,
    WorkShift shift,
    Request? leaveReq,
    Holiday? holiday,
  ) {
    final String dateLabel = DateFormat('MMMM d').format(date);

    int totalMinutes = 0;
    if (status != DayStatus.incomplete) {
      for (var rec in dayRecords) {
        totalMinutes += rec.duration.inMinutes;
      }
    }
    final int hrs = totalMinutes ~/ 60;
    final int mins = totalMinutes % 60;
    final String totalHoursStr = hrs > 0 ? '${hrs}h ${mins}m' : '${mins}m';

    // Calculate extra minutes worked outside shift bounds on this day
    final shiftStartMinutes = _parseTimeToMinutes(shift.getStartTimeForDate(date));
    final shiftEndMinutes = _parseTimeToMinutes(shift.getEndTimeForDate(date));
    int extraMinutes = 0;
    for (var rec in dayRecords) {
      final sessionStart = rec.checkIn;
      final sessionEnd =
          rec.checkOut ?? (isActiveToday ? DateTime.now() : sessionStart);

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
      if (shiftEnd.isBefore(shiftStart)) {
        shiftEnd = shiftEnd.add(const Duration(days: 1));
      }

      final isWeekend = !shift.isWorkingDay(date);
      if (isWeekend) {
        extraMinutes += sessionEnd.difference(sessionStart).inMinutes;
      } else {
        if (sessionStart.isBefore(shiftStart)) {
          final endForBefore = sessionEnd.isBefore(shiftStart)
              ? sessionEnd
              : shiftStart;
          extraMinutes += endForBefore.difference(sessionStart).inMinutes;
        }
        if (sessionEnd.isAfter(shiftEnd)) {
          final startForAfter = sessionStart.isAfter(shiftEnd)
              ? sessionStart
              : shiftEnd;
          extraMinutes += sessionEnd.difference(startForAfter).inMinutes;
        }
      }
    }

    final expectedDurationMinutes = shift.getShiftDurationMinutesForDate(date);
    final netExpectedDuration =
        expectedDurationMinutes - shift.getBreakDurationForDate(date);

    int deficitMinutes = 0;
    if (status == DayStatus.incomplete) {
      deficitMinutes = netExpectedDuration;
    } else if ((status == DayStatus.deficit || status == DayStatus.deficitAndExtraTime) && totalMinutes < netExpectedDuration) {
      deficitMinutes = netExpectedDuration - totalMinutes;
    }

    // Parse and format dynamic shift start/end times
    String shiftTimeStr = '09:00 AM - 05:00 PM';
    final startTimeStr = shift.getStartTimeForDate(date);
    final endTimeStr = shift.getEndTimeForDate(date);
    if (startTimeStr.isNotEmpty && endTimeStr.isNotEmpty) {
      try {
        final startParts = startTimeStr.split(':');
        final endParts = endTimeStr.split(':');
        final startHour = int.parse(startParts[0]);
        final startMin = int.parse(startParts[1]);
        final endHour = int.parse(endParts[0]);
        final endMin = int.parse(endParts[1]);

        final startTimeObj = DateTime(2000, 1, 1, startHour, startMin);
        final endTimeObj = DateTime(2000, 1, 1, endHour, endMin);

        shiftTimeStr =
            '${DateFormat('HH:mm').format(startTimeObj)} - ${DateFormat('HH:mm').format(endTimeObj)}';
      } catch (e) {
        shiftTimeStr = '$startTimeStr - $endTimeStr';
      }
    }

    // Determine status label and color
    String statusLabel = 'No Record';
    Color statusColor = (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38);

    switch (status) {
      case DayStatus.normal:
        statusLabel = '✓ On Time';
        statusColor = const Color(0xFF2EBD96);
        break;
      case DayStatus.leave:
        if (holiday != null) {
          statusLabel = '✓ ${holiday.name}';
        } else {
          statusLabel = leaveReq != null
              ? '✓ ${leaveReq.type}'
              : '✓ Approved Leave';
        }
        statusColor = const Color(0xFF5B9BFF);
        break;
      case DayStatus.extraTime:
        statusLabel = '✓ Overtime';
        statusColor = const Color(0xFF00FF87);
        break;
      case DayStatus.deficit:
        statusLabel = '✗ Attendance Deficit';
        statusColor = const Color(0xFFFF5C5C);
        break;
      case DayStatus.deficitAndExtraTime:
        statusLabel = '✗ Deficit & Overtime';
        statusColor = const Color(0xFFFF5C5C);
        break;
      case DayStatus.incomplete:
        statusLabel = '⚠ Incomplete Record';
        statusColor = const Color(0xFFFFCC00);
        break;
      case DayStatus.missed:
        statusLabel = '⚠ Missed Attendance';
        statusColor = const Color(0xFFFFCC00);
        break;
      case DayStatus.none:
        statusLabel = 'No Record';
        statusColor = (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38);
        break;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Attendance Details',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, secondAnim, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
      pageBuilder: (ctx, anim, secondAnim) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.18)),
                          ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.06)),
                        ],
                      ),
                      border: Border.all(
                        color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.22)),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Header ──────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                          child: Row(
                            children: [
                              // Calendar icon bubble
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2E65FF),
                                      Color(0xFF8236FE),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.calendar_month_rounded,
                                  color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                                  size: 22,
                                ),
                              ),
                              SizedBox(width: 14),
                              // Title & subtitle
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dateLabel,
                                      style: TextStyle(
                                        color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Attendance Details',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Close button
                              GestureDetector(
                                onTap: () => Navigator.of(ctx).pop(),
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.12)),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Divider
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.12)),
                        ),

                        // ── Body ─────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                          child: Column(
                            children: [
                              // Status badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.5),
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusColor == (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38)
                                        ? (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54)
                                        : statusColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              SizedBox(height: 18),

                              // Sessions list (Dynamic list of all daily sessions)
                              Builder(
                                builder: (context) {
                                  if (dayRecords.isEmpty) {
                                    return Column(
                                      children: [
                                        _buildDetailRow(
                                          iconColor: const Color(0xFF2EBD96),
                                          icon:
                                              Icons.arrow_circle_right_rounded,
                                          label: 'Check In',
                                          value: '--:-- --',
                                        ),
                                        SizedBox(height: 10),
                                        _buildDetailRow(
                                          iconColor: const Color(0xFFFF6B6B),
                                          icon: Icons.arrow_circle_left_rounded,
                                          label: 'Check Out',
                                          value: '--:-- --',
                                        ),
                                      ],
                                    );
                                  }

                                  final sortedRecords =
                                      List<AttendanceRecord>.from(dayRecords)
                                        ..sort(
                                          (a, b) =>
                                              a.checkIn.compareTo(b.checkIn),
                                        );

                                  return Container(
                                    constraints: const BoxConstraints(
                                      maxHeight: 220,
                                    ),
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Column(
                                        children: List.generate(sortedRecords.length, (
                                          idx,
                                        ) {
                                          final rec = sortedRecords[idx];
                                          final isMissedCheckIn = rec.checkIn == rec.checkOut;
                                          final checkInStr = isMissedCheckIn ? '--:--' : DateFormat(
                                            'HH:mm',
                                          ).format(rec.checkIn);
                                          final attendanceProvider =
                                              Provider.of<AttendanceProvider>(
                                                context,
                                                listen: false,
                                              );
                                          final isCurrentActive =
                                              rec.checkOut == null &&
                                              isActiveToday &&
                                              attendanceProvider.activeRecord !=
                                                  null &&
                                              rec.checkIn ==
                                                  attendanceProvider
                                                      .activeRecord!
                                                      .checkIn;

                                          final checkOutStr =
                                              rec.checkOut != null
                                              ? DateFormat(
                                                  'HH:mm',
                                                ).format(rec.checkOut!)
                                              : (isCurrentActive
                                                    ? 'Active Now'
                                                    : '--:-- --');

                                          return Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              color: Colors.white.withValues(
                                                alpha: 0.05,
                                              ),
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                  alpha: 0.08,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                // Index bubble
                                                Container(
                                                  width: 28,
                                                  height: 28,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: const Color(
                                                      0xFF2E65FF,
                                                    ).withValues(alpha: 0.15),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFF2E65FF,
                                                      ).withValues(alpha: 0.35),
                                                      width: 1.2,
                                                    ),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    '${idx + 1}',
                                                    style: TextStyle(
                                                      color: Color(0xFF5B9BFF),
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 14),
                                                // Times Info
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .arrow_circle_right_rounded,
                                                            color: Color(
                                                              0xFF2EBD96,
                                                            ),
                                                            size: 14,
                                                          ),
                                                          SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            'In: $checkInStr',
                                                            style:
                                                                TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .arrow_circle_left_rounded,
                                                            color: Color(
                                                              0xFFFF6B6B,
                                                            ),
                                                            size: 14,
                                                          ),
                                                          SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            'Out: $checkOutStr',
                                                            style: TextStyle(
                                                              color:
                                                                  rec.checkOut ==
                                                                          null &&
                                                                      isActiveToday &&
                                                                      idx ==
                                                                          sortedRecords.length -
                                                                              1
                                                                  ? const Color(
                                                                      0xFF00FF87,
                                                                    )
                                                                  : ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black))
                                                                        .withValues(
                                                                          alpha:
                                                                              0.8,
                                                                        ),
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(width: 10),
                                                // Duration
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      'Duration',
                                                      style: TextStyle(
                                                        color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black))
                                                            .withValues(
                                                              alpha: 0.4,
                                                            ),
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      rec.durationString,
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xFF00FF87,
                                                        ),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 10),

                              // Shift Time row
                              _buildDetailRow(
                                iconColor: const Color(0xFF5B9BFF),
                                icon: Icons.access_time_rounded,
                                label: 'Shift Time',
                                value: shiftTimeStr,
                              ),
                              SizedBox(height: 14),

                              // Total Hours card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF4A6FE3),
                                      Color(0xFF8B5FD8),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF4A6FE3,
                                      ).withValues(alpha: 0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Total Hours',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.75,
                                        ),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      totalHoursStr,
                                      style: TextStyle(
                                        color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Overtime Request Card Section
                              if (extraMinutes > 0) ...[
                                SizedBox(height: 16),
                                Builder(
                                  builder: (context) {
                                    final provider =
                                        Provider.of<AttendanceProvider>(
                                          context,
                                          listen: false,
                                        );
                                    final dateStr = DateFormat(
                                      'MMMM d, yyyy',
                                    ).format(date);

                                    Request? otRequest;
                                    try {
                                      otRequest = provider.requests.firstWhere(
                                        (req) =>
                                            req.type == 'Overtime Approval' &&
                                            req.date == dateStr,
                                      );
                                    } catch (_) {}

                                    if (otRequest == null) {
                                      return Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.12,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.more_time,
                                                      color: Color(0xFFFF9800),
                                                      size: 20,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Extra Time Detected',
                                                      style: TextStyle(
                                                        color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  '${extraMinutes ~/ 60}h ${extraMinutes % 60}m',
                                                  style: TextStyle(
                                                    color: Color(0xFFFF9800),
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 12),
                                            GestureDetector(
                                              onTap: () {
                                                provider.submitRequest(
                                                  'Overtime Approval',
                                                  dateStr,
                                                  '${(extraMinutes / 60.0).toStringAsFixed(1)} Hours',
                                                );
                                                Navigator.of(context).pop();
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Overtime approval requested successfully!',
                                                    ),
                                                    backgroundColor: Color(
                                                      0xFF2E65FF,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                height: 40,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                        colors: [
                                                          Color(0xFF2E65FF),
                                                          Color(0xFF8236FE),
                                                        ],
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'Request Overtime',
                                                  style: TextStyle(
                                                    color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    // Display status of existing request
                                    Color statusColor;
                                    String statusText;
                                    IconData statusIcon;

                                    if (otRequest.status == 'Approved') {
                                      statusColor = const Color(0xFF00FF87);
                                      statusText =
                                          'Overtime Approved (${otRequest.duration})';
                                      statusIcon = Icons.check_circle_rounded;
                                    } else if (otRequest.status == 'Rejected') {
                                      statusColor = const Color(0xFFFF5C5C);
                                      statusText = 'Overtime Request Rejected';
                                      statusIcon = Icons.cancel_rounded;
                                    } else {
                                      statusColor = const Color(0xFF5B9BFF);
                                      statusText = 'Overtime Request Pending';
                                      statusIcon =
                                          Icons.hourglass_empty_rounded;
                                    }

                                    return Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        color: statusColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        border: Border.all(
                                          color: statusColor.withValues(
                                            alpha: 0.35,
                                          ),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            statusIcon,
                                            color: statusColor,
                                            size: 20,
                                          ),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              statusText,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],

                              // Deficit Request Card Section
                              if (deficitMinutes > 0) ...[
                                SizedBox(height: 16),
                                Builder(
                                  builder: (context) {
                                    final provider =
                                        Provider.of<AttendanceProvider>(
                                          context,
                                          listen: false,
                                        );
                                    final dateStr = DateFormat(
                                      'MMMM d, yyyy',
                                    ).format(date);

                                    Request? leaveRequest;
                                    try {
                                      leaveRequest = provider.requests.firstWhere(
                                        (req) =>
                                            req.type == 'Hourly Leave' &&
                                            req.date == dateStr,
                                      );
                                    } catch (_) {}

                                    if (leaveRequest == null) {
                                      return Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.12,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.warning_amber_rounded,
                                                      color: Color(0xFFFF5C5C),
                                                      size: 20,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Deficit Detected',
                                                      style: TextStyle(
                                                        color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  '${deficitMinutes ~/ 60}h ${deficitMinutes % 60}m',
                                                  style: TextStyle(
                                                    color: Color(0xFFFF5C5C),
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 12),
                                            GestureDetector(
                                              onTap: () {
                                                provider.submitRequest(
                                                  'Hourly Leave',
                                                  dateStr,
                                                  '${(deficitMinutes / 60.0).toStringAsFixed(1)} Hours',
                                                );
                                                Navigator.of(context).pop();
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Hourly leave requested successfully!',
                                                    ),
                                                    backgroundColor: Color(
                                                      0xFF2E65FF,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                height: 40,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                        colors: [
                                                          Color(0xFF2E65FF),
                                                          Color(0xFF8236FE),
                                                        ],
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'Request Hourly Leave',
                                                  style: TextStyle(
                                                    color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    // Display status of existing request
                                    Color statusColor;
                                    String statusText;
                                    IconData statusIcon;

                                    if (leaveRequest.status == 'Approved') {
                                      statusColor = const Color(0xFF00FF87);
                                      statusText =
                                          'Hourly Leave Approved (${leaveRequest.duration})';
                                      statusIcon = Icons.check_circle_rounded;
                                    } else if (leaveRequest.status == 'Rejected') {
                                      statusColor = const Color(0xFFFF5C5C);
                                      statusText = 'Hourly Leave Rejected';
                                      statusIcon = Icons.cancel_rounded;
                                    } else {
                                      statusColor = const Color(0xFF5B9BFF);
                                      statusText = 'Hourly Leave Pending';
                                      statusIcon =
                                          Icons.hourglass_empty_rounded;
                                    }

                                    return Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        color: statusColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        border: Border.all(
                                          color: statusColor.withValues(
                                            alpha: 0.35,
                                          ),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            statusIcon,
                                            color: statusColor,
                                            size: 20,
                                          ),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              statusText,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds a single detail info row (Check In, Check Out, Shift Time).
  Widget _buildDetailRow({
    required Color iconColor,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.07)),
        border: Border.all(color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          // Icon bubble
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.55)),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = Provider.of<AttendanceProvider>(context);

    // Resolve shift for current employee
    final employee = attendanceProvider.currentEmployee;
    EmployeeGroup? group;
    WorkShift? shift;
    if (employee != null) {
      try {
        group = attendanceProvider.groups.firstWhere(
          (g) => g.id == employee.groupId,
        );
        shift = attendanceProvider.shifts.firstWhere(
          (s) => s.id == group!.shiftId,
        );
      } catch (_) {}
    }

    // Fallback shift if not found
    shift ??= WorkShift(
      id: 'default',
      name: 'Standard Shift',
      startTime: '09:00',
      endTime: '17:00',
      forgivenessOfDelay: 15,
      earlyExit: 10,
      breakDurationMinutes: 60,
    );

    final requests = attendanceProvider.requests;

    final totalDays = DateUtils.getDaysInMonth(
      _currentMonth.year,
      _currentMonth.month,
    );
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final int leadingEmptyDays = firstDay.weekday == 7 ? 0 : firstDay.weekday;

    final weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return GlassContainer(
      child: Column(
        children: [
          // Header: Month, Year and Nav buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: TextStyle(
                  color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  if (attendanceProvider.isLoading)
                    Container(
                      width: 28,
                      height: 28,
                      padding: const EdgeInsets.all(6),
                      child: CircularProgressIndicator(
                        color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                        strokeWidth: 2,
                      ),
                    )
                  else
                    _buildNavButton(Icons.refresh_rounded, () {
                      attendanceProvider.refreshData();
                    }),
                  SizedBox(width: 8),
                  _buildNavButton(Icons.chevron_left, _previousMonth),
                  SizedBox(width: 8),
                  _buildNavButton(Icons.chevron_right, _nextMonth),
                ],
              ),
            ],
          ),
          SizedBox(height: 20),

          // Weekdays row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.6)),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 12),

          // Calendar days grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingEmptyDays + totalDays,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.82,
              crossAxisSpacing: 8,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              if (index < leadingEmptyDays) {
                return const SizedBox.shrink();
              }

              final day = index - leadingEmptyDays + 1;
              final date = DateTime(
                _currentMonth.year,
                _currentMonth.month,
                day,
              );

              final now = DateTime.now();
              final isToday =
                  date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;

              final bool isActiveToday =
                  isToday && attendanceProvider.isClockedIn;

              // Find all attendance records for this date
              final emp = attendanceProvider.currentEmployee;
              final List<AttendanceRecord> dayRecords = emp != null
                  ? attendanceProvider.getRecordsForDate(
                      date,
                      emp: emp,
                      recordsPool: attendanceProvider.records,
                      requestsPool: attendanceProvider.requests,
                    )
                  : attendanceProvider.records
                      .where(
                        (rec) =>
                            rec.checkIn.year == date.year &&
                            rec.checkIn.month == date.month &&
                            rec.checkIn.day == date.day,
                      )
                      .toList();

              if (isActiveToday && attendanceProvider.activeRecord != null) {
                final alreadyHasActive = dayRecords.any(
                  (rec) =>
                      rec.checkIn == attendanceProvider.activeRecord!.checkIn,
                );
                if (!alreadyHasActive) {
                  dayRecords.add(attendanceProvider.activeRecord!);
                }
              }

              final approvedLeave = attendanceProvider.getApprovedLeaveForDate(
                date,
                employeeId: attendanceProvider.currentEmployee?.id,
              );
              
              // Resolve active group and shift for this specific date
              final dayGroupId = employee != null ? attendanceProvider.getGroupIdForDate(employee, date) : null;
              EmployeeGroup? activeGroup;
              if (dayGroupId != null) {
                try {
                  activeGroup = attendanceProvider.groups.firstWhere((g) => g.id == dayGroupId);
                } catch (_) {}
              }
              WorkShift? activeShift = employee != null ? attendanceProvider.getShiftForDate(employee, date) : null;

              activeShift ??= shift ?? WorkShift(
                id: 'default',
                name: 'Standard Shift',
                startTime: '09:00',
                endTime: '17:00',
                forgivenessOfDelay: 15,
                earlyExit: 10,
                breakDurationMinutes: 60,
              );

              final holiday = attendanceProvider.getHolidayForEmployee(
                date,
                activeGroup?.id,
              );

              final DayStatus status = _getDayStatus(
                date,
                dayRecords,
                activeShift,
                requests,
                isToday,
                approvedLeave,
                holiday,
              );

              final isWeekend = !activeShift.isWorkingDay(date);

              return GestureDetector(
                onTap: () => _showAttendanceDetailsDialog(
                  context,
                  date,
                  dayRecords,
                  isActiveToday,
                  status,
                  activeShift!,
                  approvedLeave,
                  holiday,
                ),
                child: _buildCalendarDay(
                  day,
                  isToday,
                  status,
                  isWeekend: isWeekend,
                ),
              );
            },
          ),
          SizedBox(height: 16),
          Divider(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12)),
          SizedBox(height: 8),

          // Calendar Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildLegendItem(
                color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.6)),
                label: 'On Time',
                isIcon: false,
              ),
              _buildLegendItem(
                color: const Color(0xFF00FF87),
                label: 'Overtime',
                isIcon: false,
              ),
              _buildLegendItem(
                color: const Color(0xFFFF3B30),
                label: attendanceProvider.translate('deficit'),
                isIcon: false,
              ),
              _buildLegendItem(
                color: const Color(0xFFFFCC00),
                label: 'Incomplete',
                isIcon: true,
                iconData: Icons.warning_rounded,
              ),
              _buildLegendItem(
                color: const Color(0xFFFF5C5C),
                label: 'Absence',
                isIcon: false,
              ),
              _buildLegendItem(
                color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                label: 'Today',
                isOutline: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onPressed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Icon(
            icon,
            color: isDark ? const Color(0xFF00F0D8) : const Color(0xFF102B94),
            size: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarDay(
    int day,
    bool isToday,
    DayStatus status, {
    bool isWeekend = false,
  }) {
    BoxDecoration decoration;
    TextStyle textStyle = TextStyle(
      color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );

    final bool isWorked =
        status == DayStatus.normal ||
        status == DayStatus.extraTime ||
        status == DayStatus.deficit ||
        status == DayStatus.deficitAndExtraTime;

    if (isToday) {
      decoration = BoxDecoration(
        color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)), width: 1.5),
      );
    } else if (isWorked) {
      decoration = BoxDecoration(
        color: const Color(0xFF2EBD96),
        borderRadius: BorderRadius.circular(12),
      );
      textStyle = TextStyle(
        color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
        fontSize: 15,
        fontWeight: FontWeight.bold,
      );
    } else if (status == DayStatus.incomplete) {
      decoration = BoxDecoration(
        color: const Color(0xFFFFCC00).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFCC00).withValues(alpha: 0.4),
          width: 1.2,
        ),
      );
      textStyle = TextStyle(
        color: Color(0xFFFFCC00),
        fontSize: 15,
        fontWeight: FontWeight.bold,
      );
    } else if (status == DayStatus.missed) {
      decoration = BoxDecoration(
        color: const Color(0xFFFF5C5C).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF5C5C).withValues(alpha: 0.2),
          width: 1,
        ),
      );
      textStyle = TextStyle(
        color: Color(0xFFFF5C5C),
        fontSize: 15,
        fontWeight: FontWeight.bold,
      );
    } else if (status == DayStatus.leave) {
      decoration = BoxDecoration(
        color: const Color(0xFF5B9BFF).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF5B9BFF).withValues(alpha: 0.5),
          width: 1.2,
        ),
      );
      textStyle = TextStyle(
        color: Color(0xFF5B9BFF),
        fontSize: 15,
        fontWeight: FontWeight.bold,
      );
    } else {
      decoration = const BoxDecoration();
      if (isWeekend) {
        textStyle = TextStyle(
          color: Color(0xFF2EBD96),
          fontSize: 15,
          fontWeight: FontWeight.bold,
        );
      } else {
        textStyle = TextStyle(
          color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.8)),
          fontSize: 15,
          fontWeight: FontWeight.normal,
        );
      }
    }

    Widget indicator;
    switch (status) {
      case DayStatus.extraTime:
        indicator = Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: Color(0xFF00FF87),
            shape: BoxShape.circle,
          ),
        );
        break;
      case DayStatus.deficit:
        indicator = Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: Color(0xFFFF3B30),
            shape: BoxShape.circle,
          ),
        );
        break;
      case DayStatus.deficitAndExtraTime:
        indicator = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFFFF3B30),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 2),
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFF00FF87),
                shape: BoxShape.circle,
              ),
            ),
          ],
        );
        break;
      case DayStatus.incomplete:
        indicator = Icon(
          Icons.warning_rounded,
          color: Color(0xFFFFCC00),
          size: 10,
        );
        break;
      case DayStatus.missed:
        indicator = const SizedBox.shrink();
        break;
      case DayStatus.leave:
        indicator = Icon(
          Icons.event_available,
          color: Color(0xFF5B9BFF),
          size: 10,
        );
        break;
      case DayStatus.normal:
        indicator = Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.6)),
            shape: BoxShape.circle,
          ),
        );
        break;
      case DayStatus.none:
        indicator = const SizedBox.shrink();
        break;
    }

    return Column(
      children: [
        // Day number block
        Expanded(
          child: Container(
            alignment: Alignment.center,
            decoration: decoration,
            child: Text('$day', style: textStyle),
          ),
        ),
        SizedBox(height: 4),
        // Status indicator underneath
        SizedBox(height: 10, child: Center(child: indicator)),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    bool isOutline = false,
    bool isIcon = false,
    IconData? iconData,
  }) {
    Widget indicator;
    if (isIcon && iconData != null) {
      indicator = Icon(iconData, color: color, size: 12);
    } else {
      indicator = Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: isOutline ? Colors.transparent : color,
          borderRadius: isOutline ? BorderRadius.circular(3) : null,
          border: isOutline ? Border.all(color: color, width: 1.5) : null,
          shape: isOutline ? BoxShape.rectangle : BoxShape.circle,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicator,
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.7)),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
