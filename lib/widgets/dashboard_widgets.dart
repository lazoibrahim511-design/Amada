import 'neu_button.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../models/hr_models.dart';
import '../models/request_model.dart';
import '../screens/requests_screen.dart';
import '../screens/hr_management_screen.dart';
import 'avatar_image_helper.dart';

class DashboardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? title;
  final Widget? trailing;

  const DashboardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF1E293B) 
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Theme.of(context).brightness == Brightness.dark 
            ? null 
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.white12 
              : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title!,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String trend;
  final bool isPositiveTrend;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
    this.isPositiveTrend = true,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            trend,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isPositiveTrend ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }
}

class AttendanceOverviewChart extends StatelessWidget {
  const AttendanceOverviewChart({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    return DashboardCard(
      title: provider.translate('attendance_overview'),
      trailing: _buildDropdown(context, provider.translate('this_week')),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SizedBox(
        height: 250,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.05),
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                    if (value.toInt() >= 0 && value.toInt() < days.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          days[value.toInt()],
                          style: TextStyle(
                            color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 25,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    );
                  },
                  reservedSize: 42,
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: 6,
            minY: 0,
            maxY: 100,
            lineBarsData: [
              LineChartBarData(
                spots: const [
                  FlSpot(0, 60),
                  FlSpot(1, 65),
                  FlSpot(2, 55),
                  FlSpot(3, 85),
                  FlSpot(4, 75),
                  FlSpot(5, 60),
                  FlSpot(6, 70),
                ],
                isCurved: true,
                color: const Color(0xFF7E22CE), // Purple line
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7E22CE).withValues(alpha: 0.3),
                      const Color(0xFF7E22CE).withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, size: 16),
        ],
      ),
    );
  }
}

class QuickActionsList extends StatelessWidget {
  const QuickActionsList({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isHR = provider.currentEmployee?.role == 'hr' ||
        provider.currentEmployee?.role == 'admin' ||
        provider.canEditCompanyInfo;
    final isSuper = provider.currentEmployee?.role == 'supervisor';
    final hasApprovalRights = isHR || isSuper;

    return DashboardCard(
      title: provider.translate('quick_actions'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          if (hasApprovalRights)
            _buildActionItem(
              context,
              '${provider.translate('approve')} ${provider.translate('requests')}',
              Icons.how_to_reg_outlined,
              iconColor: const Color(0xFF10B981),
              badgeCount: provider.pendingApprovalsCount,
              badgeColor: const Color(0xFFF59E0B),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const RequestsScreen(initialSubordinateTab: true),
                  ),
                );
              },
            ),
          _buildActionItem(
            context,
            provider.translate('submit_request'),
            Icons.post_add_outlined,
            iconColor: const Color(0xFF3B82F6),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RequestsScreen(),
                ),
              );
            },
          ),
          if (isHR) ...[
            _buildActionItem(
              context,
              provider.translate('employees'),
              Icons.manage_accounts_outlined,
              iconColor: const Color(0xFF8B5CF6),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HrManagementScreen(
                      isEmbedded: false,
                      initialTab: HrTab.employees,
                    ),
                  ),
                );
              },
            ),
            _buildActionItem(
              context,
              provider.translate('holidays'),
              Icons.event_available_outlined,
              iconColor: const Color(0xFFEC4899),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HrManagementScreen(
                      isEmbedded: false,
                      initialTab: HrTab.holidays,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    String title,
    IconData icon, {
    Color iconColor = const Color(0xFF3B82F6),
    int? badgeCount,
    Color badgeColor = const Color(0xFFEF4444),
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                ),
              ),
            ),
            if (badgeCount != null && badgeCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Icon(
              Icons.chevron_right,
              color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeptAttendanceData {
  final String name;
  final int presentCount;
  final int totalCount;
  final double percentage;
  final Color color;

  const _DeptAttendanceData({
    required this.name,
    required this.presentCount,
    required this.totalCount,
    required this.percentage,
    required this.color,
  });
}

class DepartmentAttendanceChart extends StatelessWidget {
  const DepartmentAttendanceChart({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    // 1. Identify present employees today
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

    // 2. Map structures / departments
    final structures = provider.structures;
    final employees = provider.employees;

    // Group employees by department/structure
    final Map<String, List<CompanyEmployee>> deptEmployees = {};
    for (final emp in employees) {
      String deptName = '';
      if (emp.structureId != null && emp.structureId!.isNotEmpty) {
        final struct = structures.where((s) => s.id == emp.structureId).firstOrNull;
        if (struct != null) deptName = struct.name;
      }
      if (deptName.isEmpty) {
        deptName = emp.position.isNotEmpty ? emp.position : 'General';
      }
      deptEmployees.putIfAbsent(deptName, () => []).add(emp);
    }

    // Modern color palette for slices
    const sliceColors = [
      Color(0xFF2E65FF), // Royal Tech Blue
      Color(0xFF10B981), // Emerald Green
      Color(0xFFF59E0B), // Amber Gold
      Color(0xFF8B5CF6), // Purple
      Color(0xFF00E5CE), // Electric Cyan
      Color(0xFFEC4899), // Pink
      Color(0xFF64748B), // Slate
    ];

    final List<_DeptAttendanceData> deptDataList = [];
    final int totalPresentToday = employees.where((e) => presentIds.contains(e.id)).length;

    if (deptEmployees.isEmpty) {
      // Empty state
      return DashboardCard(
        title: provider.translate('department_attendance'),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pie_chart_outline_rounded, size: 36, color: isDark ? Colors.white24 : Colors.black26),
                const SizedBox(height: 10),
                Text(
                  'No department records found',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    int colorIndex = 0;
    // Calculate either present proportion or employee distribution if no one is checked in yet
    for (final entry in deptEmployees.entries) {
      final deptName = entry.key;
      final emps = entry.value;
      final presentInDept = emps.where((e) => presentIds.contains(e.id)).length;
      final totalInDept = emps.length;

      double percentage = 0.0;
      if (totalPresentToday > 0) {
        percentage = (presentInDept / totalPresentToday) * 100.0;
      } else if (employees.isNotEmpty) {
        percentage = (totalInDept / employees.length) * 100.0;
      }

      deptDataList.add(
        _DeptAttendanceData(
          name: deptName,
          presentCount: presentInDept,
          totalCount: totalInDept,
          percentage: percentage,
          color: sliceColors[colorIndex % sliceColors.length],
        ),
      );
      colorIndex++;
    }

    // Sort by percentage descending
    deptDataList.sort((a, b) => b.percentage.compareTo(a.percentage));

    // Build chart sections
    final sections = deptDataList.map((data) {
      final val = data.percentage > 0 ? data.percentage : 1.0;
      return PieChartSectionData(
        color: data.color,
        value: val,
        title: '',
        radius: 20,
      );
    }).toList();

    return DashboardCard(
      title: provider.translate('department_attendance'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF00E5CE).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          totalPresentToday > 0 
              ? '$totalPresentToday Present' 
              : '${employees.length} Staff',
          style: const TextStyle(
            color: Color(0xFF00BD96),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 38,
                sections: sections,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: deptDataList.take(4).map((data) {
                return _buildLegendItem(
                  context,
                  data.name,
                  data.percentage.round(),
                  data.color,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, int percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityLogItem {
  final DateTime timestamp;
  final String employeeName;
  final String? avatarUrl;
  final String actionText;
  final IconData icon;
  final Color color;

  const _ActivityLogItem({
    required this.timestamp,
    required this.employeeName,
    this.avatarUrl,
    required this.actionText,
    required this.icon,
    required this.color,
  });
}

class RecentActivitiesList extends StatelessWidget {
  const RecentActivitiesList({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<_ActivityLogItem> activities = [];

    // Helper to resolve employee by ID
    CompanyEmployee getEmployee(String? empId) {
      if (empId == null || empId.isEmpty) {
        return CompanyEmployee(id: '', name: 'Staff Member', email: '', position: 'Staff', salaryCurrency: 'USD');
      }
      return provider.employees.firstWhere(
        (e) => e.id == empId,
        orElse: () => CompanyEmployee(
          id: empId,
          name: empId == provider.employeeId ? provider.userName : 'Employee $empId',
          email: '',
          position: 'Staff',
          salaryCurrency: 'USD',
        ),
      );
    }

    final companyEmpIds = provider.employees.map((e) => e.id).toSet();
    if (provider.employeeId.isNotEmpty) companyEmpIds.add(provider.employeeId);
    final currentComp = provider.currentCompanyCode.trim().toLowerCase();

    // 1. Process Attendance Records
    for (final record in provider.allCompanyRecords) {
      if (record.companyCode != null && record.companyCode!.isNotEmpty && currentComp.isNotEmpty && currentComp != 'all') {
        if (record.companyCode!.toLowerCase() != currentComp) continue;
      }
      if (record.employeeId != null && !companyEmpIds.contains(record.employeeId)) {
        continue;
      }
      final emp = getEmployee(record.employeeId);
      if (currentComp != 'all' && (emp.email == 'admin@company.com' || emp.id == 'admin_super_account' || AttendanceProvider.isSystemAdminAccount(emp))) {
        continue;
      }
      
      // Check In event
      activities.add(
        _ActivityLogItem(
          timestamp: record.checkIn,
          employeeName: emp.name,
          avatarUrl: emp.avatarUrl,
          actionText: '${emp.name} ${provider.translate('checked_in')}',
          icon: Icons.login_rounded,
          color: const Color(0xFF2E65FF), // Blue
        ),
      );

      // Check Out event (if completed)
      if (record.checkOut != null) {
        activities.add(
          _ActivityLogItem(
            timestamp: record.checkOut!,
            employeeName: emp.name,
            avatarUrl: emp.avatarUrl,
            actionText: '${emp.name} ${provider.translate('checked_out')}',
            icon: Icons.logout_rounded,
            color: const Color(0xFF10B981), // Green
          ),
        );
      }
    }

    // 2. Process Requests
    for (final req in provider.allCompanyRequests) {
      if (req.companyCode != null && req.companyCode!.isNotEmpty && currentComp.isNotEmpty && currentComp != 'all') {
        if (req.companyCode!.toLowerCase() != currentComp) continue;
      }
      if (req.employeeId != null && !companyEmpIds.contains(req.employeeId)) {
        continue;
      }
      final emp = getEmployee(req.employeeId);
      if (currentComp != 'all' && (emp.email == 'admin@company.com' || emp.id == 'admin_super_account' || AttendanceProvider.isSystemAdminAccount(emp))) {
        continue;
      }
      DateTime? reqTime;
      if (req.createdAt != null && req.createdAt!.isNotEmpty) {
        reqTime = DateTime.tryParse(req.createdAt!);
      }
      reqTime ??= DateTime.now();

      final typeStr = req.type.isNotEmpty ? req.type : 'leave';
      activities.add(
        _ActivityLogItem(
          timestamp: reqTime,
          employeeName: emp.name,
          avatarUrl: emp.avatarUrl,
          actionText: '${emp.name} requested $typeStr',
          icon: Icons.assignment_outlined,
          color: const Color(0xFFF59E0B), // Amber
        ),
      );
    }

    // Sort by timestamp descending
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final displayItems = activities.take(5).toList();

    return DashboardCard(
      title: provider.translate('recent_activities'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: displayItems.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 36,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No recent activities recorded',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: displayItems.map((item) => _buildActivityRow(context, item, isDark)).toList(),
            ),
    );
  }

  String _formatActivityTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 2) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (now.year == time.year && now.month == time.month && now.day == time.day) {
      return DateFormat('hh:mm a').format(time);
    } else if (now.difference(DateTime(time.year, time.month, time.day)).inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(time);
    } else {
      return DateFormat('MMM d').format(time);
    }
  }

  Widget _buildActivityRow(BuildContext context, _ActivityLogItem item, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: item.color.withValues(alpha: isDark ? 0.20 : 0.12),
            child: Icon(item.icon, size: 16, color: item.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              item.actionText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatActivityTime(item.timestamp),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class PendingApprovalsCard extends StatelessWidget {
  const PendingApprovalsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isHR = provider.currentEmployee?.role == 'hr' ||
        provider.currentEmployee?.role == 'admin' ||
        provider.canEditCompanyInfo;
    final isSuper = provider.currentEmployee?.role == 'supervisor';

    if (!isHR && !isSuper) {
      return const SizedBox.shrink();
    }

    final List<Map<String, dynamic>> pendingItems = [];
    final currentEmpId = provider.employeeId;

    final validEmpIds = provider.employees.map((e) => e.id).toSet();

    if (isHR) {
      for (var req in provider.allCompanyRequests) {
        if ((req.status == 'Pending' || req.status == 'Pending HR') &&
            req.employeeId != currentEmpId &&
            validEmpIds.contains(req.employeeId)) {
          final emp = provider.employees.firstWhere(
            (e) => e.id == req.employeeId,
          );
          pendingItems.add({'employee': emp, 'request': req});
        }
      }
    } else if (isSuper) {
      final subordinateIds = provider.structures
          .where((s) => s.supervisorId == currentEmpId)
          .expand((s) => provider.employees.where((e) => e.structureId == s.id).map((e) => e.id))
          .toSet();
      for (var req in provider.allCompanyRequests) {
        if ((req.status == 'Pending' || req.status == 'Pending Supervisor') &&
            subordinateIds.contains(req.employeeId) &&
            validEmpIds.contains(req.employeeId)) {
          final emp = provider.employees.firstWhere(
            (e) => e.id == req.employeeId,
          );
          pendingItems.add({'employee': emp, 'request': req});
        }
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DashboardCard(
      title: provider.translate('pending_approvals'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pendingItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Text(
                '${pendingItems.length} ${provider.translate('status_pending')}',
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RequestsScreen(initialSubordinateTab: true),
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: const [
                  Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFF3B82F6),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: Color(0xFF3B82F6)),
                ],
              ),
            ),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: pendingItems.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF10B981),
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      provider.translate('no_requests'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No pending subordinate requests awaiting approval.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                ...pendingItems.take(4).map((item) {
                  final emp = item['employee'] as CompanyEmployee;
                  final req = item['request'] as Request;
                  return _buildPendingItem(context, provider, emp, req, isDark);
                }),
                if (pendingItems.length > 4)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const RequestsScreen(initialSubordinateTab: true),
                            ),
                          );
                        },
                        child: Text(
                          '+ ${pendingItems.length - 4} more requests awaiting review',
                          style: const TextStyle(
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildPendingItem(
    BuildContext context,
    AttendanceProvider provider,
    CompanyEmployee emp,
    Request req,
    bool isDark,
  ) {
    Color typeColor;
    IconData typeIcon;
    switch (req.type) {
      case 'Annual Leave':
        typeColor = const Color(0xFF3B82F6);
        typeIcon = Icons.beach_access;
        break;
      case 'Sick Leave':
        typeColor = const Color(0xFFEF4444);
        typeIcon = Icons.medical_services_outlined;
        break;
      case 'Overtime Approval':
        typeColor = const Color(0xFFF59E0B);
        typeIcon = Icons.more_time;
        break;
      case 'Missing Punch':
        typeColor = const Color(0xFF8B5CF6);
        typeIcon = Icons.fingerprint;
        break;
      case 'Forgot to Clock Out':
        typeColor = const Color(0xFFEC4899);
        typeIcon = Icons.lock_clock;
        break;
      default:
        typeColor = const Color(0xFF10B981);
        typeIcon = Icons.assignment_outlined;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: isDark ? Colors.white24 : Colors.black12,
            backgroundImage: getAvatarProvider(emp.avatarUrl),
            child: emp.avatarUrl == null
                ? Text(
                    emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          // Employee & Request Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        emp.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 12, color: typeColor),
                          const SizedBox(width: 4),
                          Text(
                            req.type,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: typeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)
                          .withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${req.date} (${req.duration})',
                      style: TextStyle(
                        fontSize: 12,
                        color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Action Buttons: Reject and Approve
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reject Button
              NeuButton(
                onPressed: () async {
                  await provider.updateRequestStatus(
                    emp.id,
                    req.id,
                    'Rejected',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("${emp.name}'s request was rejected."),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.close, size: 14),
                label: 'Reject',
                variant: NeuButtonVariant.danger,
                height: 32,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              const SizedBox(width: 8),
              // Approve Button
              NeuButton(
                onPressed: () async {
                  final isSuper = provider.currentEmployee?.role == 'supervisor' &&
                      provider.currentEmployee?.role != 'hr' &&
                      provider.currentEmployee?.role != 'admin' &&
                      !provider.canEditCompanyInfo;
                  final hasHRManager = provider.employees.any(
                    (e) => (e.role == 'hr' || e.role == 'admin') && e.id != emp.id,
                  );
                  final shouldMoveToHR = isSuper && hasHRManager;
                  await provider.updateRequestStatus(
                    emp.id,
                    req.id,
                    shouldMoveToHR ? 'Pending HR' : 'Approved',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          shouldMoveToHR
                              ? "${emp.name}'s request was approved and forwarded to HR."
                              : "${emp.name}'s request was approved.",
                        ),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check, size: 14),
                label: 'Approve',
                variant: NeuButtonVariant.primary,
                height: 32,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
