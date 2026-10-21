import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/attendance_provider.dart';
import '../models/hr_models.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/order_management_widgets.dart';
import '../widgets/new_request_dialog.dart';
import '../widgets/payslip_dialog.dart';
import '../screens/requests_screen.dart';
import '../screens/history_screen.dart';
import '../services/web_notification_helper.dart';

class HomeScreenWeb extends StatefulWidget {
  const HomeScreenWeb({super.key});

  @override
  State<HomeScreenWeb> createState() => _HomeScreenWebState();
}

class _HomeScreenWebState extends State<HomeScreenWeb> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestWebNotificationPermission();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentUser = provider.currentEmployee;
    final isHRorAdmin = currentUser?.role == 'hr' ||
        currentUser?.role == 'admin' ||
        provider.canEditCompanyInfo;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1350),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 28.0,
                vertical: 24.0,
              ),
              child: isHRorAdmin
                  ? _buildCompanyDashboard(context, provider, isDark)
                  : _buildEmployeeDashboard(context, provider, isDark),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // EMPLOYEE SELF-SERVICE (ESS) PERSONAL DASHBOARD
  // ===========================================================================

  Widget _buildEmployeeDashboard(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    final isWide = MediaQuery.of(context).size.width >= 1080;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Personal Header with Greeting & Quick Submit
        _buildEmployeeHeader(context, provider, isDark),
        const SizedBox(height: 24),

        // 2. Today's Punch & Active Shift Hero Banner
        _buildEmployeeTodayCard(context, provider, isDark),
        const SizedBox(height: 24),

        // 3. Personal KPI Metric Cards Row
        _buildEmployeeMetricCards(context, provider, isDark),
        const SizedBox(height: 28),

        // 4. Middle Section: Weekly Chart + History & Requests
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: My Weekly Hours & Recent Attendance
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _buildMyWeeklyHoursChart(context, provider, isDark),
                    const SizedBox(height: 24),
                    _buildMyRecentAttendance(context, provider, isDark),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right Column: Quick Actions & My Recent Requests
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildEmployeeQuickActions(context, provider, isDark),
                    const SizedBox(height: 24),
                    _buildMyRecentRequests(context, provider, isDark),
                  ],
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _buildMyWeeklyHoursChart(context, provider, isDark),
              const SizedBox(height: 24),
              _buildEmployeeQuickActions(context, provider, isDark),
              const SizedBox(height: 24),
              _buildMyRecentAttendance(context, provider, isDark),
              const SizedBox(height: 24),
              _buildMyRecentRequests(context, provider, isDark),
            ],
          ),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildEmployeeHeader(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    final currentUser = provider.currentEmployee;
    final firstName = currentUser?.name.trim().split(' ').first ?? provider.userName.split(' ').first;
    final position = currentUser?.position.isNotEmpty == true
        ? currentUser!.position
        : provider.userTitle;
    final companyName = provider.companyProfile?.name.isNotEmpty == true
        ? provider.companyProfile!.name
        : 'Company';

    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(now);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Title & Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${provider.translate('welcome_back')}, $firstName! 👋',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: isDark ? Colors.white : const Color(0xFF1E2022),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      position,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                  Text(
                    '•',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.business_rounded,
                        size: 14,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        companyName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Right Date Pill & Action
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 15,
                    color: Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            ElevatedButton.icon(
              onPressed: () {
                showNewRequestDialog(context: context, provider: provider);
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                provider.translate('submit_request'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmployeeTodayCard(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    final now = DateTime.now();
    final todayRecords = provider.records.where((r) =>
        r.checkIn.year == now.year &&
        r.checkIn.month == now.month &&
        r.checkIn.day == now.day).toList();
    final todayRecord = todayRecords.isNotEmpty ? todayRecords.first : provider.activeRecord;

    final isClockedIn = provider.isClockedIn;
    final group = provider.groups.where((g) => g.id == provider.currentEmployee?.groupId).firstOrNull;
    final shift = provider.shifts.where((s) => s.id == group?.shiftId).firstOrNull;
    final shiftTitle = shift != null
        ? '${shift.name} (${shift.startTime} - ${shift.endTime})'
        : 'Standard Shift (09:00 - 17:00)';

    String checkInStr = '--:--';
    String checkOutStr = '--:--';
    String durationStr = '0h 0m';

    if (isClockedIn && provider.activeRecord != null) {
      checkInStr = DateFormat('hh:mm a').format(provider.activeRecord!.checkIn);
      final elapsed = now.difference(provider.activeRecord!.checkIn);
      final h = elapsed.inHours;
      final m = elapsed.inMinutes.remainder(60);
      durationStr = '${h}h ${m}m';
    } else if (todayRecord != null) {
      checkInStr = DateFormat('hh:mm a').format(todayRecord.checkIn);
      if (todayRecord.checkOut != null) {
        checkOutStr = DateFormat('hh:mm a').format(todayRecord.checkOut!);
        durationStr = todayRecord.durationString;
      }
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isClockedIn
              ? const Color(0xFF10B981).withValues(alpha: 0.45)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isClockedIn ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isClockedIn
                ? const Color(0xFF10B981).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 720;

          final statusSection = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isClockedIn ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                  boxShadow: isClockedIn
                      ? [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.translate('current_status'),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    isClockedIn
                        ? provider.translate('clocked_in')
                        : (todayRecord?.checkOut != null
                            ? 'Completed Today'
                            : provider.translate('clocked_out')),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isClockedIn
                          ? const Color(0xFF10B981)
                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                ],
              ),
            ],
          );

          final timePills = Wrap(
            spacing: 16,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildTimeBadge(
                label: 'Check In',
                time: checkInStr,
                icon: Icons.login_rounded,
                color: const Color(0xFF10B981),
                isDark: isDark,
              ),
              _buildTimeBadge(
                label: 'Check Out',
                time: checkOutStr,
                icon: Icons.logout_rounded,
                color: const Color(0xFFF59E0B),
                isDark: isDark,
              ),
              _buildTimeBadge(
                label: 'Duration',
                time: durationStr,
                icon: Icons.timer_outlined,
                color: const Color(0xFF6366F1),
                isDark: isDark,
              ),
            ],
          );

          final shiftBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: Color(0xFF6366F1),
                ),
                const SizedBox(width: 6),
                Text(
                  shiftTitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    statusSection,
                    shiftBadge,
                  ],
                ),
                const SizedBox(height: 16),
                timePills,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  statusSection,
                  const SizedBox(width: 28),
                  timePills,
                ],
              ),
              shiftBadge,
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeBadge({
    required String label,
    required String time,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ),
            Text(
              time,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmployeeMetricCards(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final currentUser = provider.currentEmployee;

    final daysWorkedCard = OrderMetricCard(
      title: provider.translate('days_worked'),
      value: '${provider.daysWorked} days',
      icon: Icons.calendar_today_rounded,
    );

    final weeklyHoursCard = OrderMetricCard(
      title: provider.translate('weekly_hours'),
      value: '${provider.weeklyHours.toStringAsFixed(1)} hrs',
      icon: Icons.access_time_filled_rounded,
    );

    final overtimeCard = OrderMetricCard(
      title: provider.translate('overtime'),
      value: '${provider.overtimeHours.toStringAsFixed(1)} hrs',
      icon: Icons.trending_up_rounded,
    );

    final leaveBalance = currentUser?.annualLeaveBalance ?? 0;
    final leaveDays = (leaveBalance / 8.0).toStringAsFixed(1);
    final leaveCard = OrderMetricCard(
      title: provider.translate('remain_balance'),
      value: '$leaveBalance hrs ($leaveDays d)',
      icon: Icons.beach_access_rounded,
    );

    if (screenWidth >= 1150) {
      return Row(
        children: [
          Expanded(child: daysWorkedCard),
          const SizedBox(width: 18),
          Expanded(child: weeklyHoursCard),
          const SizedBox(width: 18),
          Expanded(child: overtimeCard),
          const SizedBox(width: 18),
          Expanded(child: leaveCard),
        ],
      );
    } else if (screenWidth >= 720) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: daysWorkedCard),
              const SizedBox(width: 16),
              Expanded(child: weeklyHoursCard),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: overtimeCard),
              const SizedBox(width: 16),
              Expanded(child: leaveCard),
            ],
          ),
        ],
      );
    } else {
      return Column(
        children: [
          daysWorkedCard,
          const SizedBox(height: 14),
          weeklyHoursCard,
          const SizedBox(height: 14),
          overtimeCard,
          const SizedBox(height: 14),
          leaveCard,
        ],
      );
    }
  }

  // ===========================================================================
  // MY WEEKLY HOURS CHART (PERSONAL)
  // ===========================================================================

  Widget _buildMyWeeklyHoursChart(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    final Map<int, double> hoursPerDay = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0, 6: 0.0, 7: 0.0};

    for (final rec in provider.records) {
      if (rec.checkIn.isAfter(monday.subtract(const Duration(seconds: 1))) &&
          rec.checkIn.isBefore(sunday.add(const Duration(seconds: 1)))) {
        final day = rec.checkIn.weekday;
        final hours = rec.duration.inMinutes / 60.0;
        hoursPerDay[day] = (hoursPerDay[day] ?? 0.0) + hours;
      }
    }

    double maxHours = 10.0;
    for (var val in hoursPerDay.values) {
      if (val > maxHours) maxHours = (val + 2).ceilToDouble();
    }

    return DashboardCard(
      title: 'My Weekly Working Hours',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Total: ${provider.weeklyHours.toStringAsFixed(1)} hrs',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6366F1),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hours logged each day of the current week (Target: 8h/day)',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxHours,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                      final dayName = days[group.x.toInt()];
                      return BarTooltipItem(
                        '$dayName: ${rod.toY.toStringAsFixed(1)} hrs',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 2,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}h',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              days[value.toInt()],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (val) {
                    if (val == 8.0) {
                      return const FlLine(
                        color: Color(0xFF10B981),
                        strokeWidth: 1.2,
                        dashArray: [5, 4],
                      );
                    }
                    return FlLine(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  final dayIndex = i + 1;
                  final hours = hoursPerDay[dayIndex] ?? 0.0;
                  final isToday = now.weekday == dayIndex;

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: hours,
                        width: 22,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        gradient: LinearGradient(
                          colors: isToday
                              ? const [Color(0xFF6366F1), Color(0xFF8B5CF6)]
                              : (isDark
                                  ? const [Color(0xFF3B82F6), Color(0xFF60A5FA)]
                                  : const [Color(0xFF4F46E5), Color(0xFF818CF8)]),
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxHours,
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MY RECENT ATTENDANCE LIST
  // ===========================================================================

  Widget _buildMyRecentAttendance(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    final recent = provider.records.take(5).toList();

    return DashboardCard(
      title: 'My Recent Attendance',
      trailing: TextButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HistoryScreen()),
          );
        },
        icon: const Icon(Icons.arrow_forward_rounded, size: 15),
        label: const Text(
          'View All',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF6366F1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: recent.isEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 36),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 42,
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    provider.translate('no_records'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final rec = recent[index];
                final dateStr = DateFormat('EEE, MMM d').format(rec.checkIn);
                final inStr = DateFormat('hh:mm a').format(rec.checkIn);
                final outStr = rec.checkOut != null
                    ? DateFormat('hh:mm a').format(rec.checkOut!)
                    : 'Active';

                final isCompleted = rec.checkOut != null;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                  : const Color(0xFF3B82F6).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isCompleted ? Icons.check_circle_rounded : Icons.access_time_rounded,
                              size: 18,
                              color: isCompleted ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$inStr  →  $outStr',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                              : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCompleted
                                ? (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))
                                : const Color(0xFF3B82F6),
                          ),
                        ),
                        child: Text(
                          rec.durationString,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isCompleted
                                ? (isDark ? Colors.white70 : const Color(0xFF475569))
                                : const Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ===========================================================================
  // EMPLOYEE QUICK ACTIONS & MY RECENT REQUESTS
  // ===========================================================================

  Widget _buildEmployeeQuickActions(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    return DashboardCard(
      title: provider.translate('quick_actions'),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        children: [
          _buildQuickActionTile(
            title: provider.translate('new_request'),
            subtitle: 'Apply for Leave, Permission, Overtime',
            icon: Icons.post_add_rounded,
            color: const Color(0xFF6366F1),
            isDark: isDark,
            onTap: () {
              showNewRequestDialog(context: context, provider: provider);
            },
          ),
          const SizedBox(height: 10),
          _buildQuickActionTile(
            title: 'My Payslip',
            subtitle: 'View your latest monthly salary breakdown',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF10B981),
            isDark: isDark,
            onTap: () {
              if (provider.currentEmployee != null) {
                final emp = provider.currentEmployee!;
                final report = provider.generatePayrollReport(emp, provider.selectedMonth);
                final structName = provider.structures
                    .cast<OrgStructure?>()
                    .firstWhere((s) => s?.id == emp.structureId, orElse: () => null)
                    ?.name;
                final grpName = provider.groups
                    .cast<EmployeeGroup?>()
                    .firstWhere((g) => g?.id == emp.groupId, orElse: () => null)
                    ?.name;
                showPayslipDialog(
                  context: context,
                  report: report,
                  month: provider.selectedMonth,
                  structureName: structName,
                  groupName: grpName,
                );
              }
            },
          ),
          const SizedBox(height: 10),
          _buildQuickActionTile(
            title: provider.translate('my_history'),
            subtitle: 'View detailed attendance logs and punches',
            icon: Icons.history_rounded,
            color: const Color(0xFFF59E0B),
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyRecentRequests(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    final myReqs = provider.requests.take(4).toList();

    return DashboardCard(
      title: provider.translate('my_requests'),
      trailing: TextButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RequestsScreen()),
          );
        },
        child: const Text(
          'View All',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Color(0xFF6366F1),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: myReqs.isEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 38,
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.translate('no_requests'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      showNewRequestDialog(context: context, provider: provider);
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text(provider.translate('submit_request')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      side: const BorderSide(color: Color(0xFF6366F1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: myReqs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final req = myReqs[index];

                Color statusColor;
                Color statusBg;
                IconData statusIcon;

                switch (req.status.toLowerCase()) {
                  case 'approved':
                    statusColor = const Color(0xFF10B981);
                    statusBg = const Color(0xFF10B981).withValues(alpha: 0.12);
                    statusIcon = Icons.check_circle_outline_rounded;
                    break;
                  case 'rejected':
                    statusColor = const Color(0xFFEF4444);
                    statusBg = const Color(0xFFEF4444).withValues(alpha: 0.12);
                    statusIcon = Icons.cancel_outlined;
                    break;
                  default: // Pending
                    statusColor = const Color(0xFFF59E0B);
                    statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
                    statusIcon = Icons.hourglass_top_rounded;
                    break;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req.type,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              req.date,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 12, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              req.status,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ===========================================================================
  // EXECUTIVE & HR COMPANY DASHBOARD (FOR HR / ADMIN / SUPERVISOR)
  // ===========================================================================

  Widget _buildCompanyDashboard(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCompanyHeader(context, provider, isDark),
        const SizedBox(height: 28),
        _buildCompanyMetricCards(context, provider, isDark),
        const SizedBox(height: 28),
        _buildCompanyDashboardWidgets(context, provider),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildCompanyHeader(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    final userName = provider.userName.split(' ').first;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider.translate('attendance_management'),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: isDark ? Colors.white : const Color(0xFF1E2022),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${provider.translate('welcome_back')}, $userName!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompanyMetricCards(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    final totalEmployees = provider.employees.length;
    final now = DateTime.now();

    final presentIds = provider.allCompanyRecords
        .where(
          (r) =>
              ((r.checkIn.year == now.year &&
                r.checkIn.month == now.month &&
                r.checkIn.day == now.day) ||
               (r.checkOut == null && now.difference(r.checkIn).inHours.abs() < 24)) &&
              r.employeeId != null,
        )
        .map((r) => r.employeeId!)
        .toSet();

    final onLeaveIds = provider.allCompanyRequests
        .where((req) => req.status == 'Approved' && req.employeeId != null)
        .where((req) {
          final todayStr = DateFormat('MMMM d').format(now);
          return req.date.contains(todayStr);
        })
        .map((req) => req.employeeId!)
        .toSet();

    final actuallyOnLeaveIds = onLeaveIds.difference(presentIds);
    final presentToday = presentIds.length;
    final onLeave = actuallyOnLeaveIds.length;
    final absent = (totalEmployees - presentToday - onLeave).clamp(
      0,
      totalEmployees,
    );

    final screenWidth = MediaQuery.of(context).size.width;

    final staffCard = OrderMetricCard(
      title: provider.translate('total_staff'),
      value: '$totalEmployees',
      icon: Icons.groups_outlined,
    );

    final presentCard = OrderMetricCard(
      title: '${provider.translate('present_today')} ($absent ${provider.translate('absent')})',
      value: '$presentToday',
      icon: Icons.check_circle_outline_rounded,
    );

    final leaveCard = OrderMetricCard(
      title: provider.translate('on_leave'),
      value: '$onLeave',
      icon: Icons.flight_takeoff_rounded,
    );

    final completionCard = OrderCompletionCard(
      title: provider.translate('attendance_overview'),
      completedCount: presentToday,
      totalCount: totalEmployees > 0 ? totalEmployees : 1,
    );

    if (screenWidth >= 1150) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 1, child: staffCard),
          const SizedBox(width: 18),
          Expanded(flex: 1, child: presentCard),
          const SizedBox(width: 18),
          Expanded(flex: 1, child: leaveCard),
          const SizedBox(width: 18),
          Expanded(flex: 2, child: completionCard),
        ],
      );
    } else if (screenWidth >= 760) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: staffCard),
              const SizedBox(width: 16),
              Expanded(child: presentCard),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: leaveCard),
              const SizedBox(width: 16),
              Expanded(child: completionCard),
            ],
          ),
        ],
      );
    } else {
      return Column(
        children: [
          staffCard,
          const SizedBox(height: 14),
          presentCard,
          const SizedBox(height: 14),
          leaveCard,
          const SizedBox(height: 14),
          completionCard,
        ],
      );
    }
  }

  Widget _buildCompanyDashboardWidgets(
    BuildContext context,
    AttendanceProvider provider,
  ) {
    final isWide = MediaQuery.of(context).size.width > 1000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PendingApprovalsCard(),
        const SizedBox(height: 24),

        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(flex: 2, child: AttendanceOverviewChart()),
              SizedBox(width: 24),
              Expanded(flex: 1, child: QuickActionsList()),
            ],
          )
        else
          Column(
            children: const [
              AttendanceOverviewChart(),
              SizedBox(height: 24),
              QuickActionsList(),
            ],
          ),
        const SizedBox(height: 24),

        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(flex: 1, child: DepartmentAttendanceChart()),
              SizedBox(width: 24),
              Expanded(flex: 1, child: RecentActivitiesList()),
            ],
          )
        else
          Column(
            children: const [
              DepartmentAttendanceChart(),
              SizedBox(height: 24),
              RecentActivitiesList(),
            ],
          ),
      ],
    );
  }
}
