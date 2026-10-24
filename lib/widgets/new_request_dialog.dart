import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hr_models.dart';
import '../models/request_model.dart';
import '../providers/attendance_provider.dart';
import 'glass_dialog.dart';
import 'picker_theme.dart';
import 'compact_date_picker_dialog.dart';

List<CompanyEmployee> _getSubordinatesList(AttendanceProvider provider) {
  final currentUser = provider.currentEmployee;
  final isHR =
      currentUser?.role == 'hr' ||
      currentUser?.role == 'admin' ||
      provider.canEditCompanyInfo ||
      provider.employeeId == 'emp_2';

  if (isHR) {
    final currentId = currentUser?.id ?? provider.employeeId;
    return provider.employees.where((e) => e.id != currentId).toList();
  }

  if (currentUser == null) return [];

  if (currentUser.role == 'supervisor') {
    final Set<String> subordinateIds = {};
    final List<CompanyEmployee> list = [];

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

    // Fallback: Lookup by current user's structureId
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
  return [];
}

DateTime? _parseRequestStartDate(String dateStr) {
  try {
    final trimmed = dateStr.trim();
    if (trimmed.contains(' - ')) {
      final parts = trimmed.split(' - ');
      final startPart = parts[0].trim();
      final endPart = parts[1].trim();
      if (RegExp(r'\d{4}').hasMatch(startPart)) {
        return DateFormat('MMMM d, yyyy').parse(startPart);
      }
      final yearMatch = RegExp(r'\d{4}').firstMatch(endPart);
      if (yearMatch != null) {
        final year = yearMatch.group(0);
        return DateFormat('MMMM d, yyyy').parse('$startPart, $year');
      }
      return DateFormat('MMMM d, yyyy').parse(endPart);
    }
    return DateFormat('MMMM d, yyyy').parse(trimmed);
  } catch (_) {
    try {
      return DateTime.parse(dateStr.trim());
    } catch (_) {
      return null;
    }
  }
}

void _addNewRequestHelper({
  required BuildContext context,
  required AttendanceProvider provider,
  required String type,
  required String date,
  required String duration,
  String? targetShiftId,
  CompanyEmployee? targetEmployee,
  String? note,
  VoidCallback? onSubmitted,
}) {
  final emp = targetEmployee ?? provider.currentEmployee;

  if (type == 'Missing Punch') {
    try {
      final parsedDate = _parseRequestStartDate(date);

      if (parsedDate != null) {
        int count = 0;
        final targetReqs = (emp != null)
            ? provider.requests.where((r) => r.employeeId == emp.id).toList()
            : provider.requests;

        for (var req in targetReqs) {
          if (req.type == 'Missing Punch') {
            final reqDate = _parseRequestStartDate(req.date);
            if (reqDate != null &&
                reqDate.year == parsedDate.year &&
                reqDate.month == parsedDate.month) {
              count++;
            }
          }
        }

        if (emp != null) {
          final groupId = provider.getGroupIdForDate(emp, parsedDate);
          final group = provider.groups.firstWhere(
            (g) => g.id == groupId,
            orElse: () => EmployeeGroup(
              id: '',
              name: 'None',
              shiftId: '',
              overtimeAllowed: false,
              minOvertimeMinutes: 0,
              maxOvertimeMinutes: 0,
            ),
          );
          final limit = group.missedPunchLimitPerMonth;

          if (limit > 0 && count >= limit) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Limit reached: You can only submit $limit Missed Punch requests per month.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking missed punch limit: $e');
    }
  }

  if (type == 'Annual Leave') {
    try {
      final parsedDate = _parseRequestStartDate(date);

      if (parsedDate != null && emp != null) {
        final groupId = provider.getGroupIdForDate(emp, parsedDate);
        final group = provider.groups.firstWhere(
          (g) => g.id == groupId,
          orElse: () => EmployeeGroup(
            id: '',
            name: 'None',
            shiftId: '',
            overtimeAllowed: false,
            minOvertimeMinutes: 0,
            maxOvertimeMinutes: 0,
          ),
        );

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final reqDate = DateTime(
          parsedDate.year,
          parsedDate.month,
          parsedDate.day,
        );

        // 1. Advance notice requirement (how many days in advance before leave start date)
        final minNotice = group.annualLeaveMinNoticeDays;
        if (minNotice > 0) {
          final noticeDays = reqDate.difference(today).inDays;
          if (noticeDays < minNotice) {
            final earliestDate = today.add(Duration(days: minNotice));
            final formattedEarliest =
                DateFormat('yyyy-MM-dd').format(earliestDate);
            final errPattern =
                provider.translate('annual_leave_min_notice_error');
            final msg = errPattern
                .replaceAll('{days}', minNotice.toString())
                .replaceAll('{date}', formattedEarliest);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  msg.isNotEmpty && !msg.contains('{')
                      ? msg
                      : 'Annual leave requires at least $minNotice days advance notice. Earliest available date is $formattedEarliest.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }

        // 2. Retroactive submission deadline
        final limit = group.annualLeaveRequestDeadlineDays;
        if (limit > 0) {
          final difference = today.difference(reqDate).inDays;
          if (difference > limit) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Deadline passed: You can only submit Annual Leave requests up to $limit days after the date.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }

        // 3. Application frequency limit per month
        final maxPerMonth = group.annualLeaveMaxRequestsPerPeriod;
        if (maxPerMonth > 0) {
          final allForEmp = <Request>{
            ...provider.getRequestsForEmployee(emp.id),
            ...provider.allCompanyRequests.where((r) => r.employeeId == emp.id),
            if (emp.id == provider.employeeId) ...provider.requests,
          }.toList();

          int count = 0;
          for (var req in allForEmp) {
            if (req.type == 'Annual Leave' && req.status != 'Rejected') {
              final rDate = _parseRequestStartDate(req.date);
              if (rDate != null) {
                final matchesMonth = rDate.year == parsedDate.year &&
                    rDate.month == parsedDate.month;
                if (matchesMonth) {
                  count++;
                }
              }
            }
          }

          if (count >= maxPerMonth) {
            final periodLabel = provider.translate('period_month');
            final effectivePeriod = periodLabel.isNotEmpty ? periodLabel : 'Month';
            final errPattern =
                provider.translate('annual_leave_period_limit_error');
            final msg = errPattern
                .replaceAll('{limit}', maxPerMonth.toString())
                .replaceAll('{period}', effectivePeriod);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  msg.isNotEmpty && !msg.contains('{')
                      ? msg
                      : 'Limit reached: You can only apply for $maxPerMonth Annual Leave requests per $effectivePeriod.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking annual leave rules: $e');
    }
  }

  if (type == 'Hourly Leave' && emp != null) {
    try {
      final parsedDate = _parseRequestStartDate(date) ?? DateTime.now();
      final groupId = provider.getGroupIdForDate(emp, parsedDate);
      final group = provider.groups.firstWhere(
        (g) => g.id == groupId,
        orElse: () => EmployeeGroup(id: '', name: 'None', shiftId: ''),
      );

      final reqMinutes = parseHourlyLeaveDurationMinutes(duration);
      final minMins = group.totalHourlyLeaveMinMinutes;
      if (minMins > 0 && reqMinutes < minMins) {
        final formattedMin = formatMinutesToHoursAndMinutes(minMins);
        final errPattern = provider.translate('hourly_leave_min_error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errPattern.replaceAll('{duration}', formattedMin),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final maxMins = group.totalHourlyLeaveMaxMinutes;
      if (maxMins > 0 && reqMinutes > maxMins) {
        final formattedMax = formatMinutesToHoursAndMinutes(maxMins);
        final errPattern = provider.translate('hourly_leave_max_error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errPattern.replaceAll('{duration}', formattedMax),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint('Error checking hourly leave rules: $e');
    }
  }

  if (provider.isDateStringInClosedMonth(date)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(provider.translate('cannot_modify_closed_month')),
        backgroundColor: Colors.amber.shade800,
      ),
    );
    return;
  }

  provider.submitRequest(
    type,
    date,
    duration,
    targetShiftId: targetShiftId,
    employeeId: emp?.id,
    note: note,
  );

  onSubmitted?.call();
}

Future<void> showNewRequestDialog({
  required BuildContext context,
  required AttendanceProvider provider,
  String? initialEmployeeId,
  DateTime? initialDate,
  VoidCallback? onSubmitted,
}) {
  final currentUser =
      provider.currentEmployee ??
      provider.employees.firstWhere(
        (e) => e.email == provider.email || e.name == provider.userName,
        orElse: () => CompanyEmployee(
          id: provider.employeeId,
          name: provider.userName,
          email: provider.email,
          position: provider.position,
        ),
      );

  final subordinates = _getSubordinatesList(provider);
  final canSubmitForOthers =
      currentUser.role == 'hr' ||
      currentUser.role == 'admin' ||
      currentUser.role == 'supervisor' ||
      provider.canEditCompanyInfo;

  final List<CompanyEmployee> selectableEmployees = [
    currentUser,
    ...subordinates.where((e) => e.id != currentUser.id),
  ];

  CompanyEmployee selectedEmployee = currentUser;
  if (initialEmployeeId != null) {
    final matched = selectableEmployees.where((e) => e.id == initialEmployeeId).firstOrNull ??
        provider.employees.where((e) => e.id == initialEmployeeId).firstOrNull;
    if (matched != null) {
      selectedEmployee = matched;
      if (!selectableEmployees.any((e) => e.id == matched.id)) {
        selectableEmployees.add(matched);
      }
    }
  }

  String selectedType = 'Annual Leave';
  String? selectedShiftId =
      provider.shifts.isNotEmpty ? provider.shifts.first.id : null;
  bool isClockIn = true;
  String? errorMessage;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final initGroupId = provider.getGroupIdForDate(selectedEmployee, today);
  final initGroup = provider.groups.firstWhere(
    (g) => g.id == initGroupId,
    orElse: () => EmployeeGroup(id: '', name: 'None', shiftId: ''),
  );
  final initNotice = initGroup.annualLeaveMinNoticeDays;
  final defaultStart = today.add(Duration(days: initNotice > 0 ? initNotice : 1));
  final defaultEnd = defaultStart.add(const Duration(days: 1));
  final initialDateStr = initialDate != null
      ? DateFormat('MMMM d, yyyy').format(initialDate)
      : '${DateFormat('MMMM d').format(defaultStart)} - ${DateFormat('MMMM d, yyyy').format(defaultEnd)}';
  final dateController = TextEditingController(
    text: initialDateStr,
  );
  final durController = TextEditingController(
    text: initialDate != null ? '1 Day' : '2 Days',
  );
  final timeController = TextEditingController(
    text: DateFormat('HH:mm').format(DateTime.now()),
  );
  final fromTimeController = TextEditingController(text: '17:00');
  final toTimeController = TextEditingController(text: '19:00');
  final noteController = TextEditingController();

  return showGlassDialog(
    context: context,
    title: provider.translate('new_request'),
    subtitle: provider.translate('submit_request_subtitle'),
    icon: Icons.edit_calendar,
    iconBackgroundColor: const [Color(0xFF2E65FF), Color(0xFF8236FE)],
    content: StatefulBuilder(
      builder: (context, setDialogState) {
        final isOvertime = selectedType == 'Overtime Approval';
        final group = provider.groups.firstWhere(
          (g) => g.id == selectedEmployee.groupId,
          orElse: () => EmployeeGroup(
            id: '',
            name: 'None',
            shiftId: '',
            overtimeAllowed: false,
            minOvertimeMinutes: 0,
            maxOvertimeMinutes: 0,
          ),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (errorMessage != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFF87171),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (canSubmitForOthers && selectableEmployees.length > 1) ...[
              _buildDropdownFieldWidget(
                context: context,
                label: provider.translate('employee'),
                value: selectedEmployee.id,
                items: selectableEmployees.map((emp) {
                  final isSelf = emp.id == currentUser.id;
                  final label = isSelf
                      ? '${emp.name} (${provider.translate('myself')})'
                      : '${emp.name} (${emp.position})';
                  return DropdownMenuItem(
                    value: emp.id,
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelf
                            ? const Color(0xFF2EBD96)
                            : ((Theme.of(context).textTheme.bodyLarge?.color ??
                                Colors.black)),
                        fontWeight:
                            isSelf ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() {
                      selectedEmployee = selectableEmployees.firstWhere(
                        (e) => e.id == val,
                      );
                      errorMessage = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
            _buildDropdownFieldWidget(
              context: context,
              label: provider.translate('request_type'),
              value: selectedType,
              items: [
                DropdownMenuItem(
                  value: 'Annual Leave',
                  child: Text(provider.translate('vacation_leave')),
                ),
                DropdownMenuItem(
                  value: 'Sick Leave',
                  child: Text(provider.translate('sick_leave')),
                ),
                DropdownMenuItem(
                  value: 'Overtime Approval',
                  child: Text(provider.translate('overtime_approval')),
                ),
                DropdownMenuItem(
                  value: 'Hourly Leave',
                  child: Text(provider.translate('hourly_leave')),
                ),
                DropdownMenuItem(
                  value: 'Missing Punch',
                  child: Text(provider.translate('missing_punch')),
                ),
                DropdownMenuItem(
                  value: 'Change Shift',
                  child: Text(provider.translate('change_shift')),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setDialogState(() {
                    selectedType = val;
                    if (selectedType == 'Annual Leave') {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final gId = provider.getGroupIdForDate(selectedEmployee, today);
                      final grp = provider.groups.firstWhere(
                        (g) => g.id == gId,
                        orElse: () => EmployeeGroup(id: '', name: 'None', shiftId: ''),
                      );
                      final notice = grp.annualLeaveMinNoticeDays;
                      final start = today.add(Duration(days: notice > 0 ? notice : 1));
                      final end = start.add(const Duration(days: 1));
                      dateController.text =
                          '${DateFormat('MMMM d').format(start)} - ${DateFormat('MMMM d, yyyy').format(end)}';
                      durController.text = '2 Days';
                    } else if (selectedType == 'Sick Leave') {
                      dateController.text = 'June 3, 2026';
                      durController.text = '1 Day';
                    } else if (selectedType == 'Missing Punch') {
                      dateController.text = 'June 2, 2026';
                      timeController.text =
                          DateFormat('HH:mm').format(DateTime.now());
                    } else if (selectedType == 'Change Shift') {
                      dateController.text =
                          DateFormat('MMMM d, yyyy').format(DateTime.now());
                      durController.text = '1 Day';
                    } else if (selectedType == 'Hourly Leave') {
                      dateController.text =
                          DateFormat('MMMM d, yyyy').format(DateTime.now());
                      fromTimeController.text = '15:00';
                      toTimeController.text = '16:00';
                      durController.text = formatHourlyLeaveDurationString(
                        fromTimeController.text,
                        toTimeController.text,
                      );
                    } else if (selectedType == 'Overtime Approval') {
                      dateController.text =
                          DateFormat('MMMM d, yyyy').format(DateTime.now());
                      fromTimeController.text = '17:00';
                      toTimeController.text = '19:00';
                      durController.text = '120';
                    }
                  });
                }
              },
            ),
            if (selectedType == 'Change Shift' &&
                provider.shifts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDropdownFieldWidget(
                context: context,
                label: provider.translate('target_shift'),
                value: selectedShiftId ?? provider.shifts.first.id,
                items: provider.shifts
                    .map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() {
                      selectedShiftId = val;
                    });
                  }
                },
              ),
            ],
            const SizedBox(height: 16),
            _buildDialogFieldWidget(
              context: context,
              label: (isOvertime || selectedType == 'Hourly Leave')
                  ? provider.translate('date')
                  : provider.translate('dates'),
              controller: dateController,
              readOnly: true,
              onTap: () async {
                DateTime firstPickerDate =
                    DateTime.now().subtract(const Duration(days: 365));
                if (selectedType == 'Annual Leave') {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final gId =
                      provider.getGroupIdForDate(selectedEmployee, today);
                  final grp = provider.groups.firstWhere(
                    (g) => g.id == gId,
                    orElse: () =>
                        EmployeeGroup(id: '', name: 'None', shiftId: ''),
                  );
                  if (grp.annualLeaveMinNoticeDays > 0) {
                    firstPickerDate =
                        today.add(Duration(days: grp.annualLeaveMinNoticeDays));
                  }
                }
                final lastPickerDate =
                    DateTime.now().add(const Duration(days: 365));
                if (firstPickerDate.isAfter(lastPickerDate)) {
                  firstPickerDate = lastPickerDate;
                }

                final picked = await showCompactDateRangePicker(
                  context: context,
                  firstDate: firstPickerDate,
                  lastDate: lastPickerDate,
                  isSingleDateOnly: (selectedType == 'Hourly Leave' || isOvertime),
                );
                if (picked != null) {
                  setDialogState(() {
                    if (selectedType == 'Hourly Leave' || isOvertime) {
                      dateController.text =
                          DateFormat('MMMM d, yyyy').format(picked.start);
                    } else if (picked.start == picked.end) {
                      dateController.text =
                          DateFormat('MMMM d, yyyy').format(picked.start);
                      durController.text = '1 Day';
                    } else {
                      dateController.text =
                          '${DateFormat('MMMM d').format(picked.start)} - ${DateFormat('MMMM d, yyyy').format(picked.end)}';
                      final days =
                          picked.end.difference(picked.start).inDays + 1;
                      durController.text = '$days Days';
                    }
                  });
                }
              },
            ),
            if (provider.isDateStringInClosedMonth(dateController.text)) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
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
            ],
            if (selectedType == 'Annual Leave') ...[
              Builder(
                builder: (context) {
                  final parsedDate = _parseRequestStartDate(dateController.text);
                  if (parsedDate != null) {
                    final groupId = provider.getGroupIdForDate(selectedEmployee, parsedDate);
                    final group = provider.groups.firstWhere(
                      (g) => g.id == groupId,
                      orElse: () => EmployeeGroup(id: '', name: 'None', shiftId: ''),
                    );
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final reqDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
                    final minNotice = group.annualLeaveMinNoticeDays;
                    if (minNotice > 0 && reqDate.difference(today).inDays < minNotice) {
                      final earliestDate = today.add(Duration(days: minNotice));
                      final formattedEarliest = DateFormat('yyyy-MM-dd').format(earliestDate);
                      final errPattern = provider.translate('annual_leave_min_notice_error');
                      final msg = errPattern
                          .replaceAll('{days}', minNotice.toString())
                          .replaceAll('{date}', formattedEarliest);
                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade700.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: Colors.red.shade400),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                msg.isNotEmpty && !msg.contains('{')
                                    ? msg
                                    : 'Annual leave requires at least $minNotice days advance notice. Earliest: $formattedEarliest.',
                                style: TextStyle(
                                  color: Colors.red.shade300,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            const SizedBox(height: 16),
            if (selectedType == 'Missing Punch') ...[
              Row(
                children: [
                  Text(
                    provider.translate('punch_type'),
                    style: TextStyle(
                      color:
                          ((Theme.of(context).textTheme.bodyLarge?.color ??
                                  Colors.black)
                              .withValues(alpha: 0.6)),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ToggleButtons(
                    isSelected: [isClockIn, !isClockIn],
                    onPressed: (index) {
                      setDialogState(() {
                        isClockIn = index == 0;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    selectedColor:
                        ((Theme.of(context).textTheme.bodyLarge?.color ??
                        Colors.black)),
                    fillColor: const Color(0xFF2E65FF).withValues(alpha: 0.8),
                    color: Colors.white70,
                    constraints: const BoxConstraints(minHeight: 36),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(provider.translate('clock_in_btn')),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(provider.translate('clock_out_btn')),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDialogFieldWidget(
                context: context,
                label: provider.translate('requested_time'),
                controller: timeController,
                readOnly: true,
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                    builder: buildAdaptivePickerTheme,
                  );
                  if (picked != null) {
                    setDialogState(() {
                      final now = DateTime.now();
                      final dt = DateTime(
                        now.year,
                        now.month,
                        now.day,
                        picked.hour,
                        picked.minute,
                      );
                      timeController.text = DateFormat('HH:mm').format(dt);
                    });
                  }
                },
              ),
            ] else if (isOvertime || selectedType == 'Hourly Leave') ...[
              Row(
                children: [
                  Expanded(
                    child: _buildDialogFieldWidget(
                      context: context,
                      label: provider.translate('from_hour'),
                      controller: fromTimeController,
                      readOnly: true,
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: int.tryParse(
                                  fromTimeController.text.split(':')[0],
                                ) ??
                                (selectedType == 'Hourly Leave' ? 15 : 17),
                            minute: int.tryParse(
                                  fromTimeController.text.split(':')[1],
                                ) ??
                                0,
                          ),
                          builder: buildAdaptivePickerTheme,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            final now = DateTime.now();
                            final dt = DateTime(
                              now.year,
                              now.month,
                              now.day,
                              picked.hour,
                              picked.minute,
                            );
                            fromTimeController.text =
                                DateFormat('HH:mm').format(dt);

                            try {
                              final fParts =
                                  fromTimeController.text.split(':');
                              final tParts = toTimeController.text.split(':');
                              final fMins = int.parse(fParts[0]) * 60 +
                                  int.parse(fParts[1]);
                              final tMins = int.parse(tParts[0]) * 60 +
                                  int.parse(tParts[1]);
                              int diff = tMins - fMins;
                              if (diff < 0) diff += 24 * 60;
                              if (selectedType == 'Hourly Leave') {
                                durController.text =
                                    formatHourlyLeaveDurationString(
                                  fromTimeController.text,
                                  toTimeController.text,
                                );
                              } else {
                                durController.text = diff.toString();
                              }
                            } catch (_) {}
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDialogFieldWidget(
                      context: context,
                      label: provider.translate('to_hour'),
                      controller: toTimeController,
                      readOnly: true,
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: int.tryParse(
                                  toTimeController.text.split(':')[0],
                                ) ??
                                (selectedType == 'Hourly Leave' ? 16 : 19),
                            minute: int.tryParse(
                                  toTimeController.text.split(':')[1],
                                ) ??
                                0,
                          ),
                          builder: buildAdaptivePickerTheme,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            final now = DateTime.now();
                            final dt = DateTime(
                              now.year,
                              now.month,
                              now.day,
                              picked.hour,
                              picked.minute,
                            );
                            toTimeController.text =
                                DateFormat('HH:mm').format(dt);

                            try {
                              final fParts =
                                  fromTimeController.text.split(':');
                              final tParts = toTimeController.text.split(':');
                              final fMins = int.parse(fParts[0]) * 60 +
                                  int.parse(fParts[1]);
                              final tMins = int.parse(tParts[0]) * 60 +
                                  int.parse(tParts[1]);
                              int diff = tMins - fMins;
                              if (diff < 0) diff += 24 * 60;
                              if (selectedType == 'Hourly Leave') {
                                durController.text =
                                    formatHourlyLeaveDurationString(
                                  fromTimeController.text,
                                  toTimeController.text,
                                );
                              } else {
                                durController.text = diff.toString();
                              }
                            } catch (_) {}
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDialogFieldWidget(
                context: context,
                label: provider.translate('calculated_duration'),
                controller: durController,
                readOnly: true,
              ),
            ] else ...[
              _buildDialogFieldWidget(
                context: context,
                label: provider.translate('duration_description'),
                controller: durController,
                keyboardType: TextInputType.text,
              ),
            ],
            if (selectedType == 'Hourly Leave') ...[
              Builder(
                builder: (context) {
                  final minMins = group.totalHourlyLeaveMinMinutes;
                  final maxMins = group.totalHourlyLeaveMaxMinutes;
                  if (minMins > 0 || maxMins > 0) {
                    final minStr = minMins > 0
                        ? '${formatMinutesToTimeString(minMins)} (${formatMinutesToHoursAndMinutes(minMins)})'
                        : '00:00';
                    final maxStr = maxMins > 0
                        ? '${formatMinutesToTimeString(maxMins)} (${formatMinutesToHoursAndMinutes(maxMins)})'
                        : 'unlimited';
                    final infoMsg = provider
                        .translate('allowed_hourly_limits')
                        .replaceAll('{min}', minStr)
                        .replaceAll('{max}', maxStr);
                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E65FF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF2E65FF).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xFF60A5FA),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              infoMsg,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            if (isOvertime) ...[
              const SizedBox(height: 12),
              if (group.overtimeAllowed)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFF34D399),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider
                              .translate('allowed_limits')
                              .replaceAll(
                                '{min}',
                                group.minOvertimeMinutes.toString(),
                              )
                              .replaceAll(
                                '{max}',
                                group.maxOvertimeMinutes.toString(),
                              ),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFF87171),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider
                              .translate('overtime_disabled')
                              .replaceAll('{groupName}', group.name),
                          style: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            _buildDialogFieldWidget(
              context: context,
              label: provider.translate('note_optional'),
              controller: noteController,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    provider.translate('cancel'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E65FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final type = selectedType;
                    final dateVal = dateController.text.trim();
                    final isMissingPunch = type == 'Missing Punch';
                    final timeStr = timeController.text.trim();
                    final durVal = isMissingPunch
                        ? '${isClockIn ? "Clock In" : "Clock Out"}: $timeStr'
                        : durController.text.trim();

                    if (dateVal.isEmpty || durVal.isEmpty) {
                      setDialogState(() {
                        errorMessage =
                            provider.translate('fill_fields_error');
                      });
                      return;
                    }

                    if (provider.isDateStringInClosedMonth(dateVal)) {
                      setDialogState(() {
                        errorMessage = provider.translate('cannot_modify_closed_month');
                      });
                      return;
                    }

                    if (type == 'Annual Leave') {
                      final match = RegExp(r'(\d+)').firstMatch(durVal);
                      int days = 1;
                      if (match != null) {
                        days = int.tryParse(match.group(1)!) ?? 1;
                      }

                      final shift = provider.shifts.firstWhere(
                        (s) => s.id == group.shiftId,
                        orElse: () => WorkShift(
                          id: '',
                          name: 'Default',
                          startTime: '09:00',
                          endTime: '17:00',
                        ),
                      );

                      DateTime reqDate = DateTime.now();
                      try {
                        reqDate = DateFormat('yyyy-MM-dd').parse(dateVal);
                      } catch (_) {}

                      final shiftMins =
                          shift.getShiftDurationMinutesForDate(reqDate);
                      double hoursPerDay =
                          shiftMins > 0 ? (shiftMins / 60.0) : 8.0;
                      double requestedHours = days * hoursPerDay;

                      if (requestedHours >
                          selectedEmployee.annualLeaveBalance) {
                        setDialogState(() {
                          errorMessage =
                              '${selectedEmployee.name} does not have enough balance for this request. (Requested: ${requestedHours.toStringAsFixed(1)}h, Balance: ${selectedEmployee.annualLeaveBalance.toStringAsFixed(1)}h)';
                        });
                        return;
                      }
                    }

                    if (type == 'Hourly Leave') {
                      final reqMinutes = parseHourlyLeaveDurationMinutes(durVal);
                      if (reqMinutes <= 0) {
                        setDialogState(() {
                          errorMessage = provider.translate('invalid_duration_error');
                        });
                        return;
                      }

                      final minMins = group.totalHourlyLeaveMinMinutes;
                      if (minMins > 0 && reqMinutes < minMins) {
                        final formattedMin = formatMinutesToHoursAndMinutes(minMins);
                        final errPattern = provider.translate('hourly_leave_min_error');
                        setDialogState(() {
                          errorMessage = errPattern.replaceAll('{duration}', formattedMin);
                        });
                        return;
                      }

                      final maxMins = group.totalHourlyLeaveMaxMinutes;
                      if (maxMins > 0 && reqMinutes > maxMins) {
                        final formattedMax = formatMinutesToHoursAndMinutes(maxMins);
                        final errPattern = provider.translate('hourly_leave_max_error');
                        setDialogState(() {
                          errorMessage = errPattern.replaceAll('{duration}', formattedMax);
                        });
                        return;
                      }
                    }

                    if (type == 'Overtime Approval') {
                      if (!group.overtimeAllowed) {
                        setDialogState(() {
                          errorMessage = provider
                              .translate('overtime_blocked_group')
                              .replaceAll('{groupName}', group.name);
                        });
                        return;
                      }

                      final minutes = int.tryParse(durVal);
                      if (minutes == null) {
                        setDialogState(() {
                          errorMessage =
                              provider.translate('invalid_duration_error');
                        });
                        return;
                      }

                      if (minutes < group.minOvertimeMinutes ||
                          minutes > group.maxOvertimeMinutes) {
                        setDialogState(() {
                          errorMessage = provider
                              .translate('overtime_limit_error')
                              .replaceAll(
                                '{min}',
                                group.minOvertimeMinutes.toString(),
                              )
                              .replaceAll(
                                '{max}',
                                group.maxOvertimeMinutes.toString(),
                              );
                        });
                        return;
                      }

                      try {
                        final fParts = fromTimeController.text.split(':');
                        final tParts = toTimeController.text.split(':');
                        if (fParts.length < 2 || tParts.length < 2) {
                          setDialogState(
                            () => errorMessage = 'Invalid time format.',
                          );
                          return;
                        }
                        int reqStartMins =
                            int.parse(fParts[0]) * 60 + int.parse(fParts[1]);
                        int reqEndMins =
                            int.parse(tParts[0]) * 60 + int.parse(tParts[1]);
                        if (reqEndMins < reqStartMins) {
                          reqEndMins += 24 * 60;
                        }

                        DateTime reqDate = DateTime.now();
                        try {
                          reqDate =
                              DateFormat('MMMM d, yyyy').parse(dateVal);
                        } catch (_) {}

                        final records = await provider.firebaseService
                            .getUserRecords(selectedEmployee.id);
                        final dayRecords = provider.getRecordsForDate(
                          reqDate,
                          emp: selectedEmployee,
                          recordsPool: records,
                        );

                        if (dayRecords.isEmpty) {
                          setDialogState(
                            () => errorMessage =
                                'No attendance records found for this date. Cannot request overtime.',
                          );
                          return;
                        }

                        final activeGroupId = provider.getGroupIdForDate(
                          selectedEmployee,
                          reqDate,
                        );
                        final activeGroup = provider.groups.firstWhere(
                          (g) => g.id == activeGroupId,
                          orElse: () => group,
                        );
                        final activeShift = provider.shifts.firstWhere(
                          (s) => s.id == activeGroup.shiftId,
                          orElse: () => WorkShift(
                            id: '',
                            name: '',
                            startTime: '09:00',
                            endTime: '17:00',
                          ),
                        );

                        final sParts = activeShift
                            .getStartTimeForDate(reqDate)
                            .split(':');
                        final eParts =
                            activeShift.getEndTimeForDate(reqDate).split(':');
                        final shiftStartMins = sParts.length >= 2
                            ? int.parse(sParts[0]) * 60 + int.parse(sParts[1])
                            : 540;
                        final shiftEndMins = eParts.length >= 2
                            ? int.parse(eParts[0]) * 60 + int.parse(eParts[1])
                            : 1020;

                        bool validOvertime = false;

                        for (var rec in dayRecords) {
                          int cInMins =
                              rec.checkIn.hour * 60 + rec.checkIn.minute;
                          int cOutMins = rec.checkOut != null
                              ? rec.checkOut!.hour * 60 +
                                  rec.checkOut!.minute
                              : cInMins;
                          if (cOutMins < cInMins) cOutMins += 24 * 60;

                          if (activeShift.isWorkingDay(reqDate)) {
                            if (cInMins < shiftStartMins) {
                              int eBeforeEnd = cOutMins < shiftStartMins
                                  ? cOutMins
                                  : shiftStartMins;
                              if (reqStartMins >= cInMins &&
                                  reqEndMins <= eBeforeEnd) {
                                validOvertime = true;
                                break;
                              }
                            }
                            if (cOutMins > shiftEndMins) {
                              int sAfterStart = cInMins > shiftEndMins
                                  ? cInMins
                                  : shiftEndMins;
                              if (reqStartMins >= sAfterStart &&
                                  reqEndMins <= cOutMins) {
                                validOvertime = true;
                                break;
                              }
                            }
                          } else {
                            if (reqStartMins >= cInMins &&
                                reqEndMins <= cOutMins) {
                              validOvertime = true;
                              break;
                            }
                          }
                        }

                        if (!validOvertime) {
                          setDialogState(
                            () => errorMessage =
                                'Requested time does not fall within actual extra time worked.',
                          );
                          return;
                        }
                      } catch (e) {
                        setDialogState(
                          () =>
                              errorMessage = 'Error validating overtime: $e',
                        );
                        return;
                      }

                      if (!context.mounted) return;
                      final double hoursVal = minutes / 60;
                      final durationFormatted =
                          'From ${fromTimeController.text} to ${toTimeController.text} (${hoursVal.toStringAsFixed(1).replaceAll('.0', '')} Hours)';

                      _addNewRequestHelper(
                        context: context,
                        provider: provider,
                        type: type,
                        date: dateVal,
                        duration: durationFormatted,
                        targetEmployee: selectedEmployee,
                        note: noteController.text.trim().isNotEmpty
                            ? noteController.text.trim()
                            : null,
                        onSubmitted: onSubmitted,
                      );
                    } else if (type == 'Change Shift') {
                      _addNewRequestHelper(
                        context: context,
                        provider: provider,
                        type: type,
                        date: dateVal,
                        duration: durVal,
                        targetShiftId: selectedShiftId,
                        targetEmployee: selectedEmployee,
                        note: noteController.text.trim().isNotEmpty
                            ? noteController.text.trim()
                            : null,
                        onSubmitted: onSubmitted,
                      );
                    } else {
                      _addNewRequestHelper(
                        context: context,
                        provider: provider,
                        type: type,
                        date: dateVal,
                        duration: durVal,
                        targetEmployee: selectedEmployee,
                        note: noteController.text.trim().isNotEmpty
                            ? noteController.text.trim()
                            : null,
                        onSubmitted: onSubmitted,
                      );
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    final isForSelf =
                        selectedEmployee.id == currentUser.id;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isForSelf
                              ? provider.translate('submit_success')
                              : provider
                                  .translate('submit_success_for')
                                  .replaceAll('{name}', selectedEmployee.name),
                        ),
                        backgroundColor: const Color(0xFF2EBD96),
                      ),
                    );
                  },
                  child: Text(
                    provider.translate('submit'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

Widget _buildDropdownFieldWidget({
  required BuildContext context,
  required String label,
  required String value,
  required List<DropdownMenuItem<String>> items,
  required ValueChanged<String?> onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color:
              ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)
                  .withValues(alpha: 0.6)),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E293B)
              : Colors.white,
        ),
        child: DropdownButton<String>(
          value: items.any((i) => i.value == value)
              ? value
              : (items.isNotEmpty ? items.first.value : null),
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          underline: Container(
            height: 1,
            color: (Theme.of(context).textTheme.bodyLarge?.color ??
                    Colors.black)
                .withValues(alpha: 0.2),
          ),
          icon: Icon(
            Icons.arrow_drop_down,
            color: (Theme.of(context).textTheme.bodyLarge?.color ??
                    Colors.black)
                .withValues(alpha: 0.6),
          ),
          style: TextStyle(
            color:
                ((Theme.of(context).textTheme.bodyLarge?.color ??
                Colors.black)),
            fontSize: 14,
          ),
        ),
      ),
    ],
  );
}

Widget _buildDialogFieldWidget({
  required BuildContext context,
  required String label,
  required TextEditingController controller,
  TextInputType keyboardType = TextInputType.text,
  bool readOnly = false,
  VoidCallback? onTap,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color:
              ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)
                  .withValues(alpha: 0.6)),
          fontSize: 12,
        ),
      ),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        style: TextStyle(
          color:
              ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
          fontSize: 14,
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF2E65FF)),
          ),
        ),
      ),
    ],
  );
}
