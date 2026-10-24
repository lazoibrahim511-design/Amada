import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../widgets/glass_dialog.dart';
import 'package:provider/provider.dart';
import '../widgets/glass_container.dart';
import '../providers/attendance_provider.dart';
import '../models/hr_models.dart';
import '../models/request_model.dart';
import '../widgets/avatar_image_helper.dart';
import '../widgets/neu_button.dart';
import '../widgets/picker_theme.dart';
import '../widgets/compact_date_picker_dialog.dart';
import 'package:intl/intl.dart';

class RequestsScreen extends StatefulWidget {
  final bool initialSubordinateTab;
  final bool showAddDialog;
  const RequestsScreen({
    super.key,
    this.initialSubordinateTab = false,
    this.showAddDialog = false,
  });

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  late bool _showSubordinateRequests;
  List<Map<String, dynamic>> _subordinateRequests = [];
  bool _isLoadingSubordinates = false;
  String? _lastEmployeeId;

  @override
  void initState() {
    super.initState();
    _showSubordinateRequests = widget.initialSubordinateTab;
    if (widget.showAddDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showNewRequestDialog(
            Provider.of<AttendanceProvider>(context, listen: false),
          );
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AttendanceProvider>(context, listen: false);
      final isSuperOrHR =
          provider.currentEmployee?.role == 'supervisor' ||
          provider.currentEmployee?.role == 'hr' ||
          provider.currentEmployee?.role == 'admin' ||
          provider.canEditCompanyInfo;
      if (isSuperOrHR) {
        _loadAllSubordinateRequests(provider);
      }
    });
  }

  @override
  void didUpdateWidget(RequestsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubordinateTab != oldWidget.initialSubordinateTab) {
      setState(() {
        _showSubordinateRequests = widget.initialSubordinateTab;
      });
      final provider = Provider.of<AttendanceProvider>(context, listen: false);
      _loadAllSubordinateRequests(provider);
    }
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

  void _addNewRequest(
    String type,
    String date,
    String duration, {
    String? targetShiftId,
    CompanyEmployee? targetEmployee,
    String? note,
  }) {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final emp = targetEmployee ?? provider.currentEmployee;

    if (provider.isDateStringInClosedMonth(date)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.translate('cannot_modify_closed_month')),
          backgroundColor: Colors.amber.shade800,
        ),
      );
      return;
    }

    if (type == 'Missing Punch') {
      try {
        final parsedDate = _parseRequestStartDate(date);

        if (parsedDate != null) {
          int count = 0;
          final targetReqs = (emp != null)
              ? (emp.id == provider.employeeId
                    ? provider.requests
                    : (_subordinateRequests
                          .where(
                            (item) =>
                                (item['employee'] as CompanyEmployee?)?.id ==
                                emp.id,
                          )
                          .map((item) => item['request'] as Request)
                          .toList()))
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

          // 1. Minimum Advance Notice Days Rule
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

          // 2. Retroactive Submission Deadline Rule
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

          // 3. Application Frequency Limit per Month
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

    provider.submitRequest(
      type,
      date,
      duration,
      targetShiftId: targetShiftId,
      employeeId: emp?.id,
      note: note,
    );

    final isSuperOrHR =
        provider.currentEmployee?.role == 'supervisor' ||
        provider.currentEmployee?.role == 'hr' ||
        provider.currentEmployee?.role == 'admin' ||
        provider.canEditCompanyInfo;
    if (isSuperOrHR) {
      _loadAllSubordinateRequests(provider);
    }
  }

  List<CompanyEmployee> _getSubordinates(AttendanceProvider provider) {
    final currentUser = provider.currentEmployee;
    final isHR =
        currentUser?.role == 'hr' ||
        currentUser?.role == 'admin' ||
        provider.canEditCompanyInfo ||
        provider.employeeId == 'emp_2';

    if (isHR) {
      // HR/Admin sees all other employees
      final currentId = currentUser?.id ?? provider.employeeId;
      return provider.employees.where((e) => e.id != currentId).toList();
    }

    if (currentUser == null) return [];

    if (currentUser.role == 'supervisor') {
      final Set<String> subordinateIds = {};
      final List<CompanyEmployee> list = [];

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

    return [];
  }

  List<Map<String, dynamic>> _getSubordinateRequests(
    AttendanceProvider provider,
  ) {
    final subordinates = _getSubordinates(provider);
    final List<Map<String, dynamic>> combined = [];

    final currentUser = provider.currentEmployee;
    final isHR =
        currentUser?.role == 'hr' ||
        currentUser?.role == 'admin' ||
        provider.canEditCompanyInfo ||
        provider.employeeId == 'emp_2';
    final subordinateIds = subordinates.map((e) => e.id).toSet();

    // 1. First add from provider.allCompanyRequests (live Firestore stream)
    for (var r in provider.allCompanyRequests) {
      if (r.employeeId != null && r.employeeId != provider.employeeId) {
        if (isHR || subordinateIds.contains(r.employeeId)) {
          final emp = provider.employees.firstWhere(
            (e) => e.id == r.employeeId,
            orElse: () => CompanyEmployee(
              id: r.employeeId!,
              name: 'Employee (${r.employeeId})',
              email: '',
              position: 'Staff',
              salaryCurrency: 'USD',
            ),
          );
          combined.add({'employee': emp, 'request': r});
        }
      }
    }

    // 2. Also check any cached in provider's _allRequestsMap
    for (var emp in subordinates) {
      final cachedReqs = provider.getRequestsForEmployee(emp.id);
      for (var r in cachedReqs) {
        if (!combined.any((item) => (item['request'] as Request).id == r.id)) {
          combined.add({'employee': emp, 'request': r});
        }
      }
    }

    // 3. Merge any that were loaded asynchronously into _subordinateRequests
    for (var item in _subordinateRequests) {
      final r = item['request'] as Request;
      if (!combined.any((it) => (it['request'] as Request).id == r.id)) {
        combined.add(item);
      }
    }

    // Sort: Pending requests first, then descending by request ID/time
    combined.sort((a, b) {
      final rA = a['request'] as Request;
      final rB = b['request'] as Request;
      final isPendingA = rA.status.startsWith('Pending');
      final isPendingB = rB.status.startsWith('Pending');
      if (isPendingA && !isPendingB) return -1;
      if (!isPendingA && isPendingB) return 1;
      return rB.id.compareTo(rA.id);
    });

    return combined;
  }

  void _loadAllSubordinateRequests(AttendanceProvider provider) async {
    setState(() {
      _isLoadingSubordinates = true;
    });

    final subordinates = _getSubordinates(provider);
    final List<Map<String, dynamic>> combined = [];

    // 1. Gather all requests from company stream (for HR or supervisors)
    final currentUser = provider.currentEmployee;
    final isHR =
        currentUser?.role == 'hr' ||
        currentUser?.role == 'admin' ||
        provider.canEditCompanyInfo ||
        provider.employeeId == 'emp_2';
    final subordinateIds = subordinates.map((e) => e.id).toSet();

    for (var r in provider.allCompanyRequests) {
      if (r.employeeId != null && r.employeeId != provider.employeeId) {
        if (isHR || subordinateIds.contains(r.employeeId)) {
          final emp = provider.employees.firstWhere(
            (e) => e.id == r.employeeId,
            orElse: () => CompanyEmployee(
              id: r.employeeId!,
              name: 'Employee (${r.employeeId})',
              email: '',
              position: 'Staff',
              salaryCurrency: 'USD',
            ),
          );
          combined.add({'employee': emp, 'request': r});
        }
      }
    }

    // 2. Also check any cached or directly fetched employee requests
    for (var emp in subordinates) {
      final reqs = await provider.getEmployeeRequests(emp.id);
      for (var r in reqs) {
        if (!combined.any((item) => (item['request'] as Request).id == r.id)) {
          combined.add({'employee': emp, 'request': r});
        }
      }
    }

    // Sort: Pending requests first, then descending by request ID/time
    combined.sort((a, b) {
      final rA = a['request'] as Request;
      final rB = b['request'] as Request;
      final isPendingA = rA.status.startsWith('Pending');
      final isPendingB = rB.status.startsWith('Pending');
      if (isPendingA && !isPendingB) return -1;
      if (!isPendingA && isPendingB) return 1;
      return rB.id.compareTo(rA.id);
    });

    if (mounted) {
      setState(() {
        _subordinateRequests = combined;
        _isLoadingSubordinates = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<AttendanceProvider>(context);
    if (_lastEmployeeId != provider.employeeId) {
      _lastEmployeeId = provider.employeeId;
      _showSubordinateRequests = widget.initialSubordinateTab;
      final isSuperOrHR =
          provider.currentEmployee?.role == 'supervisor' ||
          provider.currentEmployee?.role == 'hr' ||
          provider.currentEmployee?.role == 'admin' ||
          provider.canEditCompanyInfo;
      if (isSuperOrHR) {
        _loadAllSubordinateRequests(provider);
      }
    }
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
        return provider.translate('hourly_leave');
      case 'Change Shift':
        return provider.translate('change_shift');
      case 'Missing Punch':
        return provider.translate('missing_punch');
      default:
        return rawType;
    }
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final showTabs =
        provider.currentEmployee?.role == 'supervisor' ||
        provider.currentEmployee?.role == 'hr' ||
        provider.currentEmployee?.role == 'admin' ||
        provider.canEditCompanyInfo;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: kIsWeb ? 1200 : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page Header with action
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 16.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        provider.translate('requests'),
                        style: TextStyle(
                          color:
                              ((Theme.of(context).textTheme.bodyLarge?.color ??
                              Colors.black)),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      _buildAddButton(provider),
                    ],
                  ),
                ),

                // Custom Segmented Sub-Tab Switcher (Matching User Management design)
                if (showTabs) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 6.0,
                    ),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF161F2E)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildRequestsTabButton(
                            isSelected: !_showSubordinateRequests,
                            label: provider.translate('my_requests'),
                            icon: Icons.assignment_outlined,
                            isDark: isDark,
                            onTap: () {
                              setState(() {
                                _showSubordinateRequests = false;
                              });
                            },
                          ),
                          _buildRequestsTabButton(
                            isSelected: _showSubordinateRequests,
                            label: provider.translate('subordinate_requests'),
                            icon: Icons.people_alt_outlined,
                            isDark: isDark,
                            badgeCount: provider.pendingApprovalsCount,
                            onTap: () {
                              setState(() {
                                _showSubordinateRequests = true;
                              });
                              _loadAllSubordinateRequests(provider);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Requests List
                Expanded(
                  child: _showSubordinateRequests
                      ? _buildSubordinateRequestsList(provider)
                      : _buildMyRequestsList(provider),
                ),

                // Spacer for bottom nav bar
                if (!kIsWeb) SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsTabButton({
    required bool isSelected,
    required String label,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF00F0D8), Color(0xFF00BD96)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(50),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF00E5CE).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? const Color(0xFF0A2342)
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF0A2342)
                            : (isDark ? Colors.white70 : const Color(0xFF334155)),
                      ),
                    ),
                  ),
                ),
                if (badgeCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyRequestsList(AttendanceProvider provider) {
    final List<Request> requests = provider.requests;

    if (requests.isEmpty) {
      return Center(
        child: Text(
          provider.translate('no_requests'),
          style: TextStyle(
            color:
                ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)
                    .withValues(alpha: 0.6)),
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: GlassContainer(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _translateRequestType(request.type, provider),
                      style: TextStyle(
                        color:
                            ((Theme.of(context).textTheme.bodyLarge?.color ??
                            Colors.black)),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      request.date,
                      style: TextStyle(
                        color:
                            ((Theme.of(context).textTheme.bodyLarge?.color ??
                                    Colors.black)
                                .withValues(alpha: 0.5)),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      request.type == 'Change Shift' &&
                              request.targetShiftId != null
                          ? '${provider.translate('target_shift')}: ${provider.shifts.firstWhere(
                              (s) => s.id == request.targetShiftId,
                              orElse: () => WorkShift(id: '', name: 'Unknown', startTime: '', endTime: ''),
                            ).name}'
                          : '${provider.translate('duration')}: ${request.duration.replaceAll('Clock In:', provider.translate('clock_in_colon')).replaceAll('Clock Out:', provider.translate('clock_out_colon'))}',
                      style: TextStyle(
                        color:
                            ((Theme.of(context).textTheme.bodyLarge?.color ??
                                    Colors.black)
                                .withValues(alpha: 0.7)),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (request.createdAt != null) ...[
                      SizedBox(height: 4),
                      Text(
                        'Registered: ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.parse(request.createdAt!))}',
                        style: TextStyle(
                          color:
                              ((Theme.of(context).textTheme.bodyLarge?.color ??
                                      Colors.black)
                                  .withValues(alpha: 0.5)),
                          fontSize: 10,
                        ),
                      ),
                    ],
                    if (request.actionBy != null &&
                        request.actionDate != null) ...[
                      SizedBox(height: 2),
                      Text(
                        '${request.status} by: ${provider.employees.firstWhere(
                          (e) => e.id == request.actionBy,
                          orElse: () => CompanyEmployee(id: '', name: 'Unknown', email: '', position: ''),
                        ).name} on ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.parse(request.actionDate!))}',
                        style: TextStyle(
                          color:
                              ((Theme.of(context).textTheme.bodyLarge?.color ??
                                      Colors.black)
                                  .withValues(alpha: 0.5)),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final empId = provider.currentEmployee?.id;
                        if (empId != null) {
                          await provider.deleteRequest(empId, request.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  provider.translate('request_deleted'),
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: request.statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: request.statusColor.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _translateRequestStatus(request.status, provider),
                        style: TextStyle(
                          color: request.statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubordinateRequestsList(AttendanceProvider provider) {
    final subordinateRequests = _getSubordinateRequests(provider);

    if (_isLoadingSubordinates && subordinateRequests.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color:
              ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
        ),
      );
    }

    if (subordinateRequests.isEmpty) {
      return Center(
        child: Text(
          provider.translate('no_requests'),
          style: TextStyle(
            color:
                ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)
                    .withValues(alpha: 0.6)),
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      itemCount: subordinateRequests.length,
      itemBuilder: (context, index) {
        final item = subordinateRequests[index];
        final CompanyEmployee employee = item['employee'];
        final Request request = item['request'];

        return Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: GlassContainer(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Employee Details Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.white24,
                      backgroundImage: getAvatarProvider(employee.avatarUrl),
                      child: getAvatarProvider(employee.avatarUrl) != null
                          ? null
                          : Text(
                              employee.name.isNotEmpty
                                  ? employee.name.substring(0, 1).toUpperCase()
                                  : 'E',
                              style: TextStyle(
                                color:
                                    ((Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color ??
                                    Colors.black)),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee.name,
                            style: TextStyle(
                              color:
                                  ((Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color ??
                                  Colors.black)),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            employee.position,
                            style: TextStyle(
                              color:
                                  ((Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color ??
                                          Colors.black)
                                      .withValues(alpha: 0.6)),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            await provider.deleteRequest(
                              employee.id,
                              request.id,
                            );
                            _loadAllSubordinateRequests(provider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    provider.translate('request_deleted'),
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 16,
                            ),
                          ),
                        ),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: request.statusColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: request.statusColor.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _translateRequestStatus(request.status, provider),
                            style: TextStyle(
                              color: request.statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.0),
                  child: Divider(color: Colors.white12, height: 1),
                ),

                // Request Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _translateRequestType(request.type, provider),
                          style: TextStyle(
                            color:
                                ((Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color ??
                                Colors.black)),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          request.date,
                          style: TextStyle(
                            color:
                                ((Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.color ??
                                        Colors.black)
                                    .withValues(alpha: 0.5)),
                            fontSize: 11,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          request.type == 'Change Shift' &&
                                  request.targetShiftId != null
                              ? '${provider.translate('target_shift')}: ${provider.shifts.firstWhere(
                                  (s) => s.id == request.targetShiftId,
                                  orElse: () => WorkShift(id: '', name: 'Unknown', startTime: '', endTime: ''),
                                ).name}'
                              : '${provider.translate('duration')}: ${request.duration.replaceAll('Clock In:', provider.translate('clock_in_colon')).replaceAll('Clock Out:', provider.translate('clock_out_colon'))}',
                          style: TextStyle(
                            color:
                                ((Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.color ??
                                        Colors.black)
                                    .withValues(alpha: 0.7)),
                            fontSize: 11,
                          ),
                        ),
                        if (request.createdAt != null) ...[
                          SizedBox(height: 4),
                          Text(
                            'Registered: ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.parse(request.createdAt!))}',
                            style: TextStyle(
                              color:
                                  ((Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color ??
                                          Colors.black)
                                      .withValues(alpha: 0.5)),
                              fontSize: 10,
                            ),
                          ),
                        ],
                        if (request.createdAt != null) ...[
                          SizedBox(height: 4),
                          Text(
                            'Registered: ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.parse(request.createdAt!))}',
                            style: TextStyle(
                              color:
                                  ((Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color ??
                                          Colors.black)
                                      .withValues(alpha: 0.5)),
                              fontSize: 10,
                            ),
                          ),
                        ],
                        if (request.supervisorActionBy != null &&
                            request.supervisorActionDate != null) ...[
                          SizedBox(height: 2),
                          Text(
                            'Supervisor: ${request.supervisorStatus ?? "Approved"} by ${provider.employees.firstWhere(
                              (e) => e.id == request.supervisorActionBy,
                              orElse: () => CompanyEmployee(id: '', name: 'Supervisor', email: '', position: ''),
                            ).name} on ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.parse(request.supervisorActionDate!))}',
                            style: TextStyle(
                              color: const Color(0xFF10B981).withValues(alpha: 0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (request.hrActionBy != null &&
                            request.hrActionDate != null) ...[
                          SizedBox(height: 2),
                          Text(
                            'HR: ${request.hrStatus ?? "Approved"} by ${provider.employees.firstWhere(
                              (e) => e.id == request.hrActionBy,
                              orElse: () => CompanyEmployee(id: '', name: 'HR Manager', email: '', position: ''),
                            ).name} on ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.parse(request.hrActionDate!))}',
                            style: TextStyle(
                              color: const Color(0xFF2E65FF).withValues(alpha: 0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ] else if (request.actionBy != null &&
                            request.actionDate != null &&
                            request.supervisorActionBy == null) ...[
                          SizedBox(height: 2),
                          Text(
                            '${request.status} by: ${provider.employees.firstWhere(
                              (e) => e.id == request.actionBy,
                              orElse: () => CompanyEmployee(id: '', name: 'Unknown', email: '', position: ''),
                            ).name} on ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.parse(request.actionDate!))}',
                            style: TextStyle(
                              color:
                                  ((Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color ??
                                          Colors.black)
                                      .withValues(alpha: 0.5)),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                // Approve / Reject actions or awaiting status badge
                Builder(
                  builder: (context) {
                    final currentUser = provider.currentEmployee;
                    final isHR = currentUser?.role == 'hr' ||
                        currentUser?.role == 'admin' ||
                        provider.canEditCompanyInfo;
                    final isSupervisor = currentUser?.role == 'supervisor';

                    final canActAsSupervisor = (isSupervisor || isHR) &&
                        (request.status == 'Pending Supervisor' || request.status == 'Pending');
                    final canActAsHR = isHR &&
                        (request.status == 'Pending HR' || request.status == 'Pending');

                    final canAct = canActAsSupervisor || canActAsHR;

                    if (!canAct) {
                      if (request.status == 'Pending HR' && isSupervisor && !isHR) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.hourglass_top_rounded, size: 12, color: Color(0xFF8B5CF6)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Awaiting HR Manager Approval',
                                      style: TextStyle(
                                        color: Color(0xFF8B5CF6),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Reject Button
                          GestureDetector(
                            onTap: () async {
                              if (provider.isDateStringInClosedMonth(request.date)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(provider.translate('cannot_modify_closed_month')),
                                    backgroundColor: Colors.amber.shade800,
                                  ),
                                );
                                return;
                              }

                              await provider.updateRequestStatus(
                                employee.id,
                                request.id,
                                'Rejected',
                              );
                              _loadAllSubordinateRequests(provider);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${employee.name}\'s request rejected.',
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFEF4444,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(
                                    0xFFEF4444,
                                  ).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.close,
                                    color: Color(0xFFF87171),
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    provider.translate('reject'),
                                    style: TextStyle(
                                      color: Color(0xFFFCA5A5),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 10),

                          // Approve Button
                          GestureDetector(
                            onTap: () async {
                              if (provider.isDateStringInClosedMonth(request.date)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(provider.translate('cannot_modify_closed_month')),
                                    backgroundColor: Colors.amber.shade800,
                                  ),
                                );
                                return;
                              }

                              final hasHRManager = provider.employees.any(
                                (e) => (e.role == 'hr' || e.role == 'admin') && e.id != employee.id,
                              );
                              final nextStatus = (canActAsHR || !hasHRManager) ? 'Approved' : 'Pending HR';
                              await provider.updateRequestStatus(
                                employee.id,
                                request.id,
                                nextStatus,
                              );
                              _loadAllSubordinateRequests(provider);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    nextStatus == 'Approved'
                                        ? '${employee.name}\'s request approved.'
                                        : '${employee.name}\'s request approved and forwarded to HR Manager.',
                                  ),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check,
                                    color: Color(0xFF34D399),
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    provider.translate('approve'),
                                    style: const TextStyle(
                                      color: Color(0xFFA7F3D0),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddButton(AttendanceProvider provider) {
    return NeuButton(
      onPressed: () => _showNewRequestDialog(provider),
      icon: const Icon(Icons.add),
      label: provider.translate('new_request'),
      height: 38,
      fontSize: 12,
      padding: const EdgeInsets.symmetric(horizontal: 14),
    );
  }

  void _showNewRequestDialog(AttendanceProvider provider) {
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

    final subordinates = _getSubordinates(provider);
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

    String selectedType = 'Annual Leave';
    String? selectedShiftId = provider.shifts.isNotEmpty
        ? provider.shifts.first.id
        : null;
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
    final dateController = TextEditingController(
      text:
          '${DateFormat('MMMM d').format(defaultStart)} - ${DateFormat('MMMM d, yyyy').format(defaultEnd)}',
    );
    final durController = TextEditingController(text: '2 Days');
    final timeController = TextEditingController(
      text: DateFormat('HH:mm').format(DateTime.now()),
    );
    final fromTimeController = TextEditingController(text: '17:00');
    final toTimeController = TextEditingController(text: '19:00');
    final noteController = TextEditingController();

    showGlassDialog(
      context: context,
      title: provider.translate('new_request'),
      subtitle: provider.translate('submit_request_subtitle'),
      icon: Icons.edit_calendar,
      iconBackgroundColor: [Color(0xFF2E65FF), Color(0xFF8236FE)],
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
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFF87171),
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (canSubmitForOthers && selectableEmployees.length > 1) ...[
                _buildDropdownField(
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
                              : ((Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color ??
                                    Colors.black)),
                          fontWeight: isSelf
                              ? FontWeight.bold
                              : FontWeight.normal,
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
              _buildDropdownField(
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
                        timeController.text = DateFormat(
                          'HH:mm',
                        ).format(DateTime.now());
                      } else if (selectedType == 'Change Shift') {
                        dateController.text = DateFormat(
                          'MMMM d, yyyy',
                        ).format(DateTime.now());
                        durController.text = '1 Day';
                      } else if (selectedType == 'Hourly Leave') {
                        dateController.text = DateFormat(
                          'MMMM d, yyyy',
                        ).format(DateTime.now());
                        fromTimeController.text = '15:00';
                        toTimeController.text = '16:00';
                        durController.text = formatHourlyLeaveDurationString(
                          fromTimeController.text,
                          toTimeController.text,
                        );
                      } else if (selectedType == 'Overtime Approval') {
                        dateController.text = DateFormat(
                          'MMMM d, yyyy',
                        ).format(DateTime.now());
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
                SizedBox(height: 16),
                _buildDropdownField(
                  context: context,
                  label: provider.translate('target_shift'),
                  value: selectedShiftId ?? provider.shifts.first.id,
                  items: provider.shifts
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
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
              SizedBox(height: 16),
              _buildDialogField(
                (isOvertime || selectedType == 'Hourly Leave')
                    ? provider.translate('date')
                    : provider.translate('dates'),
                dateController,
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
                        dateController.text = DateFormat(
                          'MMMM d, yyyy',
                        ).format(picked.start);
                      } else if (picked.start == picked.end) {
                        dateController.text = DateFormat(
                          'MMMM d, yyyy',
                        ).format(picked.start);
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
              SizedBox(height: 16),
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
                    SizedBox(width: 16),
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
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(provider.translate('clock_in_btn')),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(provider.translate('clock_out_btn')),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _buildDialogField(
                  provider.translate('requested_time'),
                  timeController,
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
                      child: _buildDialogField(
                        provider.translate('from_hour'),
                        fromTimeController,
                        readOnly: true,
                        onTap: () async {
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour:
                                  int.tryParse(
                                    fromTimeController.text.split(':')[0],
                                  ) ??
                                  (selectedType == 'Hourly Leave' ? 15 : 17),
                              minute:
                                  int.tryParse(
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
                              fromTimeController.text = DateFormat(
                                'HH:mm',
                              ).format(dt);

                              // Auto calculate duration
                              try {
                                final fParts = fromTimeController.text.split(
                                  ':',
                                );
                                final tParts = toTimeController.text.split(':');
                                final fMins =
                                    int.parse(fParts[0]) * 60 +
                                    int.parse(fParts[1]);
                                final tMins =
                                    int.parse(tParts[0]) * 60 +
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
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildDialogField(
                        provider.translate('to_hour'),
                        toTimeController,
                        readOnly: true,
                        onTap: () async {
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour:
                                  int.tryParse(
                                    toTimeController.text.split(':')[0],
                                  ) ??
                                  (selectedType == 'Hourly Leave' ? 16 : 19),
                              minute:
                                  int.tryParse(
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
                              toTimeController.text = DateFormat(
                                'HH:mm',
                              ).format(dt);

                              // Auto calculate duration
                              try {
                                final fParts = fromTimeController.text.split(
                                  ':',
                                );
                                final tParts = toTimeController.text.split(':');
                                final fMins =
                                    int.parse(fParts[0]) * 60 +
                                    int.parse(fParts[1]);
                                final tMins =
                                    int.parse(tParts[0]) * 60 +
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
                SizedBox(height: 12),
                _buildDialogField(
                  provider.translate('calculated_duration'),
                  durController,
                  readOnly: true,
                ),
              ] else ...[
                _buildDialogField(
                  provider.translate('duration_description'),
                  durController,
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
                SizedBox(height: 12),
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
                        Icon(
                          Icons.info_outline,
                          color: Color(0xFF34D399),
                          size: 16,
                        ),
                        SizedBox(width: 8),
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
                            style: TextStyle(
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
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFF87171),
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider
                                .translate('overtime_disabled')
                                .replaceAll('{groupName}', group.name),
                            style: TextStyle(
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
              _buildDialogField(
                provider.translate('note_optional'),
                noteController,
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
                          errorMessage = provider.translate(
                            'fill_fields_error',
                          );
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
                            errorMessage = provider.translate(
                              'invalid_duration_error',
                            );
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

                        // Validate against actual extra time
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
                            reqEndMins += 24 * 60; // handle overnight
                          }

                          DateTime reqDate = DateTime.now();
                          try {
                            reqDate = DateFormat('MMMM d, yyyy').parse(dateVal);
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
                          final eParts = activeShift
                              .getEndTimeForDate(reqDate)
                              .split(':');
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
                                ? rec.checkOut!.hour * 60 + rec.checkOut!.minute
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

                        final double hoursVal = minutes / 60;
                        final durationFormatted =
                            'From ${fromTimeController.text} to ${toTimeController.text} (${hoursVal.toStringAsFixed(1).replaceAll('.0', '')} Hours)';

                        _addNewRequest(
                          type,
                          dateVal,
                          durationFormatted,
                          targetEmployee: selectedEmployee,
                          note: noteController.text.trim().isNotEmpty
                              ? noteController.text.trim()
                              : null,
                        );
                      } else if (type == 'Change Shift') {
                        _addNewRequest(
                          type,
                          dateVal,
                          durVal,
                          targetShiftId: selectedShiftId,
                          targetEmployee: selectedEmployee,
                          note: noteController.text.trim().isNotEmpty
                              ? noteController.text.trim()
                              : null,
                        );
                      } else {
                        _addNewRequest(
                          type,
                          dateVal,
                          durVal,
                          targetEmployee: selectedEmployee,
                          note: noteController.text.trim().isNotEmpty
                              ? noteController.text.trim()
                              : null,
                        );
                      }

                      if (!context.mounted) return;
                      Navigator.pop(context);
                      final isForSelf = selectedEmployee.id == currentUser.id;
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

  Widget _buildDropdownField({
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
          data: Theme.of(
            context,
          ).copyWith(
            canvasColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : Colors.white,
          ),
          child: DropdownButton<String>(
            value: value,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            underline: Container(height: 1, color: Colors.white24),
            style: TextStyle(
              color:
                  ((Theme.of(context).textTheme.bodyLarge?.color ??
                  Colors.black)),
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogField(
    String label,
    TextEditingController controller, {
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
                ((Theme.of(context).textTheme.bodyLarge?.color ??
                Colors.black)),
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
}
