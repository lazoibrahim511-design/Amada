import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_provider.dart';
import '../models/hr_models.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/neu_button.dart';
import '../widgets/avatar_image_helper.dart';
import 'map_picker_screen.dart';
import '../widgets/picker_theme.dart';

import 'hr_management_screen.dart';
import '../widgets/hr/hr_structures_tab.dart';
import '../widgets/hr/hr_shifts_tab.dart';
import '../widgets/hr/hr_groups_tab.dart';
import '../widgets/hr/hr_locations_tab.dart';
import '../widgets/hr/hr_holidays_tab.dart';
import '../widgets/hr/hr_employees_tab.dart';
import '../widgets/hr/hr_daily_report_tab.dart';
import '../widgets/hr/hr_periodic_report_tab.dart';
import '../widgets/hr/hr_device_tab.dart';


class HrManagementScreenWeb extends StatefulWidget {
  final HrTab? initialTab;
  final bool isEmbedded;
  const HrManagementScreenWeb({
    super.key,
    this.initialTab,
    this.isEmbedded = false,
  });

  @override
  State<HrManagementScreenWeb> createState() => _HrManagementScreenWebState();
}

class _HrManagementScreenWebState extends State<HrManagementScreenWeb> {
  late HrTab _activeTab;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription? _providerSub;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab ?? HrTab.structures;
  }

  Future<void> _loadDailyReportData() async {
    // Data is now loaded globally in AttendanceProvider
  }

  @override
  void dispose() {
    _searchController.dispose();
    _providerSub?.cancel();
    super.dispose();
  }


  Widget _buildWebTabBar(AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabs = [
      (HrTab.structures, Icons.business_outlined, provider.translate('structures')),
      (HrTab.shifts, Icons.schedule_outlined, provider.translate('shifts')),
      (HrTab.groups, Icons.people_outline, provider.translate('groups')),
      (HrTab.employees, Icons.badge_outlined, provider.translate('employees')),
      (HrTab.holidays, Icons.event_available_outlined, provider.translate('holidays')),
      (HrTab.locations, Icons.place_outlined, provider.translate('locations')),
      (HrTab.payroll, Icons.monetization_on_outlined, provider.translate('payroll')),
      (HrTab.dailyReport, Icons.analytics_outlined, provider.translate('daily_report')),
      (HrTab.periodicReport, Icons.assessment_outlined, provider.translate('periodic_report')),
      (HrTab.device, Icons.fingerprint_outlined, provider.translate('device')),
    ];

    return Container(
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!widget.isEmbedded) ...[
            _buildBackButton(),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final (tab, icon, label) = tabs[index];
                final isActive = _activeTab == tab;

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      if (_activeTab != tab) {
                        _activeTab = tab;
                        _searchQuery = '';
                        _searchController.clear();
                      }
                    });
                    if (tab == HrTab.dailyReport) {
                      _loadDailyReportData();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF3B82F6)
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF3B82F6)
                            : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
                        width: 1,
                      ),
                      boxShadow: [
                        if (isActive)
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        else if (!isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 18,
                          color: isActive
                              ? Colors.white
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            fontSize: 13.5,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Directionality(
      textDirection: provider.currentLanguageDirection,
      child: Column(
        children: [
          _buildWebTabBar(provider),
          const SizedBox(height: 6),
          Expanded(child: _buildActiveList(provider)),
        ],
      ),
    );

    if (widget.isEmbedded) {
      return Container(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: content,
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: !isDark
              ? const LinearGradient(
                  colors: [Color(0xFFFCFDFD), Color(0xFFEDF2FE), Color(0xFFE0EAFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isDark ? const Color(0xFF0F172A) : null,
        ),
        child: SafeArea(
          bottom: false,
          child: content,
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return NeuIconButton(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.arrow_back, size: 20),
      size: 44,
      variant: NeuButtonVariant.whitePill,
    );
  }

  Widget _buildAddNewButton(AttendanceProvider provider) {
    if (_activeTab == HrTab.payroll || _activeTab == HrTab.dailyReport || _activeTab == HrTab.periodicReport || _activeTab == HrTab.device)
      // ignore: curly_braces_in_flow_control_structures
      return const SizedBox.shrink();
    String label = '';
    switch (_activeTab) {
      case HrTab.structures:
        label = provider.translate('add_structure');
        break;
      case HrTab.shifts:
        label = provider.translate('add_shift');
        break;
      case HrTab.groups:
        label = provider.translate('add_group');
        break;
      case HrTab.employees:
        label = provider.translate('add_employee');
        break;
      case HrTab.holidays:
        label = provider.translate('add_holiday');
        break;
      case HrTab.locations:
        label = provider.translate('add_location');
        break;
      case HrTab.payroll:
      case HrTab.dailyReport:
      case HrTab.periodicReport:
      case HrTab.device:
        break;
    }

    return NeuButton(
      onPressed: () {
        if (_activeTab == HrTab.employees) {
          if (!provider.canAddActiveEmployee) {
            HrEmployeesTab.showLicenseLimitDialog(context, provider);
          } else {
            HrEmployeesTab.showEmployeeFormDialog(context: context, provider: provider);
          }
        } else {
          _showAddEditDialog();
        }
      },
      icon: const Icon(Icons.add_rounded, size: 18),
      label: label,
      variant: NeuButtonVariant.primary,
      height: 42,
      fontSize: 13.5,
      padding: const EdgeInsets.symmetric(horizontal: 18),
    );
  }

  Widget _buildSearchBar(String hint) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasAddButton = _activeTab != HrTab.payroll &&
        _activeTab != HrTab.dailyReport &&
        _activeTab != HrTab.periodicReport &&
        _activeTab != HrTab.device;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  hintText: hint,
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  icon: Icon(
                    Icons.search,
                    size: 20,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          color: isDark ? Colors.white60 : Colors.black54,
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          ),
          if (hasAddButton) ...[
            const SizedBox(width: 12),
            _buildAddNewButton(provider),
          ],
        ],
      ),
    );
  }

  Widget _buildResponsiveList({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1400
            ? 3
            : constraints.maxWidth > 850
                ? 2
                : 1;

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: crossAxisCount == 1 ? 4.5 : 2.7,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }

  Widget _buildActiveList(AttendanceProvider provider) {
    switch (_activeTab) {
      case HrTab.structures:
        return Column(
          children: [
            _buildSearchBar(provider.translate('search_structures')),
            const SizedBox(height: 16),
            Expanded(
              child: HrStructuresTab(
                searchQuery: _searchQuery,
                onEdit: (structure) => _showAddEditDialog(structure: structure),
                onDelete: (id) => provider.deleteStructure(id),
              ),
            ),
          ],
        );
      case HrTab.shifts:
        return Column(
          children: [
            _buildSearchBar(provider.translate('search_shifts')),
            const SizedBox(height: 16),
            Expanded(
              child: HrShiftsTab(
                searchQuery: _searchQuery,
                onEdit: (shift) => _showAddEditDialog(shift: shift),
                onDelete: (id) => provider.deleteShift(id),
              ),
            ),
          ],
        );
      case HrTab.groups:
        return Column(
          children: [
            _buildSearchBar(provider.translate('search_groups')),
            const SizedBox(height: 16),
            Expanded(
              child: HrGroupsTab(
                searchQuery: _searchQuery,
                onEdit: (group) => _showAddEditDialog(group: group),
                onDelete: (id) => provider.deleteGroup(id),
              ),
            ),
          ],
        );
      case HrTab.employees:
        return Column(
          children: [
            _buildSearchBar(provider.translate('search_employees')),
            const SizedBox(height: 16),
            Expanded(
              child: HrEmployeesTab(
                searchQuery: _searchQuery,
                onEdit: (employee) => HrEmployeesTab.showEmployeeFormDialog(
                  context: context,
                  provider: provider,
                  employee: employee,
                ),
              ),
            ),
          ],
        );
      case HrTab.holidays:
        return Column(
          children: [
            _buildSearchBar(provider.translate('search_holidays')),
            const SizedBox(height: 16),
            Expanded(
              child: HrHolidaysTab(
                searchQuery: _searchQuery,
                onEdit: (holiday) => _showAddEditDialog(holiday: holiday),
                onDelete: (id) => provider.deleteHoliday(id),
              ),
            ),
          ],
        );
      case HrTab.locations:
        return Column(
          children: [
            _buildSearchBar(provider.translate('search_locations')),
            const SizedBox(height: 16),
            Expanded(
              child: HrLocationsTab(
                searchQuery: _searchQuery,
                onEdit: (location) => _showAddEditDialog(location: location),
                onDelete: (id) => provider.deleteLocation(id),
              ),
            ),
          ],
        );
      case HrTab.payroll:
        if (provider.employees.isEmpty) return _buildEmptyState('employees');
        return _buildPayrollList(provider);
      case HrTab.dailyReport:
        return HrDailyReportTab(searchQuery: _searchQuery);
      case HrTab.periodicReport:
        return HrPeriodicReportTab(searchQuery: _searchQuery);
      case HrTab.device:
        return const HrDeviceTab();
    }
  }

  

  

  Widget _buildEmptyState(String name) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                size: 46,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No $name found',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the "+ Add New" button above to create one\nor adjust your search filter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Card Widgets Matching Aesthetics ---

  

  

  

  

  

  

  

  

  // --- Modals Add/Edit Dialogs ---

  void _showAddEditDialog({
    OrgStructure? structure,
    WorkShift? shift,
    EmployeeGroup? group,
    CompanyEmployee? employee,
    Holiday? holiday,
    WorkLocation? location,
  }) {
    if (shift != null ||
        (structure == null &&
            group == null &&
            employee == null &&
            holiday == null &&
            location == null &&
            _activeTab == HrTab.shifts)) {
      showShiftDialog(context, shift: shift);
      return;
    }

    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final isEditing =
        (structure != null ||
        shift != null ||
        group != null ||
        employee != null ||
        holiday != null ||
        location != null);

    // Controllers
    final nameController = TextEditingController();
    final extraController1 =
        TextEditingController(); // location / startTime / shiftId / email
    final extraController2 =
        TextEditingController(); // capacity / endTime / graceMinutes / position
    final extraController3 =
        TextEditingController(); // forgivenessOfDelay / requiredDailyHours
    final earlyExitController =
        TextEditingController(); // earlyExit (shifts only)
    final breakStartController =
        TextEditingController(); // breakStart (shifts only)
    final breakEndController =
        TextEditingController(); // breakEnd (shifts only)
    final breakDurationController =
        TextEditingController(); // breakDurationMinutes (shifts only)
    final minOvertimeController =
        TextEditingController(); // minOvertimeMinutes (groups only)
    final maxOvertimeController =
        TextEditingController(); // maxOvertimeMinutes (groups only)
    final annualLeaveAdditionHoursController =
        TextEditingController(); // annualLeaveAdditionHours (groups only)
    final missedPunchLimitController =
        TextEditingController(); // missedPunchLimitPerMonth (groups only)
    final annualLeaveDeadlineController =
        TextEditingController(); // annualLeaveRequestDeadlineDays (groups only)
    final annualLeaveMinNoticeController =
        TextEditingController(); // annualLeaveMinNoticeDays (groups only)
    final annualLeaveMaxRequestsController =
        TextEditingController(); // annualLeaveMaxRequestsPerPeriod (groups only)
    final hourlyLeaveMinDurationController =
        TextEditingController(); // e.g. "01:30" (groups only)
    final hourlyLeaveMaxDurationController =
        TextEditingController(); // e.g. "04:00" (groups only)
    String annualLeavePeriodTypeValue = 'Month';

    // Employee extended controllers
    final phoneController = TextEditingController();
    final startDateController = TextEditingController();
    final endDateController = TextEditingController();
    final positionStartDateController = TextEditingController();
    final groupStartDateController = TextEditingController();
    List<GroupHistoryEntry> tempGroupHistory = [];
    final annualLeaveBalanceController = TextEditingController();
    bool disabledValue = false;
    List<int> selectedWorkingDays = [6, 7, 1, 2, 3, 4, 5];

    // Rotation Shift properties
    bool isRotationValue = false;
    bool isOvernightValue = false;
    final crossMidnightCutoffController = TextEditingController();
    Map<int, DayShiftConfig> weeklyScheduleValue = {
      6: DayShiftConfig(
        isWorkingDay: true,
        startTime: '09:00',
        endTime: '17:00',
      ),
      7: DayShiftConfig(
        isWorkingDay: true,
        startTime: '09:00',
        endTime: '17:00',
      ),
      1: DayShiftConfig(
        isWorkingDay: true,
        startTime: '09:00',
        endTime: '17:00',
      ),
      2: DayShiftConfig(
        isWorkingDay: true,
        startTime: '09:00',
        endTime: '17:00',
      ),
      3: DayShiftConfig(
        isWorkingDay: true,
        startTime: '09:00',
        endTime: '17:00',
      ),
      4: DayShiftConfig(
        isWorkingDay: true,
        startTime: '09:00',
        endTime: '17:00',
      ),
      5: DayShiftConfig(
        isWorkingDay: true,
        startTime: '09:00',
        endTime: '17:00',
      ),
    };

    // Holiday controllers
    final fromDateController = TextEditingController();
    final toDateController = TextEditingController();
    List<String> selectedHolidayGroupIds = [];

    // Location controllers
    List<String> selectedLocationGroupIds = [];

    String? selectedShiftId; // groups only
    String? selectedStructureId; // employees only
    String? selectedParentId; // structures only
    String? selectedSupervisorId; // structures only
    bool overtimeAllowedValue = false; // groups only
    double holidayOvertimeRatioValue = 1.5; // groups only
    double weekendOvertimeRatioValue = 1.5; // groups only
    bool nightOvertimeAllowedValue = false; // groups only
    final nightOvertimeStartController = TextEditingController(text: '22:00');
    final nightOvertimeEndController = TextEditingController(text: '06:00');
    double nightOvertimeRatioValue = 1.5; // groups only
    bool delayPenaltiesEnabledValue = true; // groups only
    bool earlyExitPenaltiesEnabledValue = true; // groups only
    String annualLeaveAdditionTypeValue = 'None'; // groups only

    // Delay Penalty controllers
    final delayT1MinController = TextEditingController();
    final delayT1MaxController = TextEditingController();
    final delayT1PenaltyController = TextEditingController();
    final delayT1ForgivenessController = TextEditingController();
    final delayT2MinController = TextEditingController();
    final delayT2MaxController = TextEditingController();
    final delayT2PenaltyController = TextEditingController();
    final delayT2ForgivenessController = TextEditingController();
    final delayT3MinController = TextEditingController();
    final delayT3PenaltyController = TextEditingController();
    final delayT3ForgivenessController = TextEditingController();

    // Early Exit Penalty controllers
    final earlyExitT1MinController = TextEditingController();
    final earlyExitT1MaxController = TextEditingController();
    final earlyExitT1PenaltyController = TextEditingController();
    final earlyExitT1ForgivenessController = TextEditingController();
    final earlyExitT2MinController = TextEditingController();
    final earlyExitT2MaxController = TextEditingController();
    final earlyExitT2PenaltyController = TextEditingController();
    final earlyExitT2ForgivenessController = TextEditingController();
    final earlyExitT3MinController = TextEditingController();
    final earlyExitT3PenaltyController = TextEditingController();
    final earlyExitT3ForgivenessController = TextEditingController();

    // Map Settings for Structure
    double? selectedLatitude;
    double? selectedLongitude;
    double? selectedRadius;

    // Wi-Fi Verification controllers
    final wifiBssidController = TextEditingController();
    final wifiSsidController = TextEditingController();
    bool requireWifiValue = false;
    bool isDetectingWifi = false;

    // Populate controllers if editing
    if (isEditing) {
      if (structure != null) {
        nameController.text = structure.name;
        extraController1.text = structure.location;
        extraController2.text = structure.capacity.toString();
        selectedParentId = structure.parentId;
        selectedSupervisorId = structure.supervisorId;
        extraController2.text = structure.capacity.toString();
        selectedLatitude = structure.latitude;
        selectedLongitude = structure.longitude;
        selectedRadius = structure.radius;
      } else if (shift != null) {
        nameController.text = shift.name;
        extraController1.text = shift.startTime;
        extraController2.text = shift.endTime;
        extraController3.text = shift.forgivenessOfDelay.toString();
        earlyExitController.text = shift.earlyExit.toString();
        breakStartController.text = shift.breakStart;
        breakEndController.text = shift.breakEnd;
        breakDurationController.text = shift.breakDurationMinutes > 0
            ? shift.breakDurationMinutes.toString()
            : '';
        selectedWorkingDays = List<int>.from(shift.workingDays);
        isRotationValue = shift.isRotation;
        isOvernightValue = shift.isOvernight || WorkShift.isTimeCrossMidnight(shift.startTime, shift.endTime);
        crossMidnightCutoffController.text = shift.crossMidnightCutoff;
        if (shift.weeklySchedule.isNotEmpty) {
          weeklyScheduleValue = Map.from(shift.weeklySchedule);
        }
      } else if (group != null) {
        nameController.text = group.name;
        selectedShiftId = group.shiftId.isNotEmpty ? group.shiftId : null;
        annualLeaveAdditionTypeValue = group.annualLeaveAdditionType;
        annualLeaveAdditionHoursController.text =
            group.annualLeaveAdditionHours > 0
            ? group.annualLeaveAdditionHours.toString()
            : '';
        missedPunchLimitController.text = group.missedPunchLimitPerMonth
            .toString();
        annualLeaveDeadlineController.text = group
            .annualLeaveRequestDeadlineDays
            .toString();
        annualLeaveMinNoticeController.text = group
            .annualLeaveMinNoticeDays
            .toString();
        annualLeaveMaxRequestsController.text = group
            .annualLeaveMaxRequestsPerPeriod
            .toString();
        hourlyLeaveMinDurationController.text =
            group.hourlyLeaveMinDurationFormatted;
        hourlyLeaveMaxDurationController.text =
            group.hourlyLeaveMaxDurationFormatted;
        annualLeavePeriodTypeValue = group.annualLeavePeriodType.isNotEmpty
            ? group.annualLeavePeriodType
            : 'Month';
        overtimeAllowedValue = group.overtimeAllowed;
        minOvertimeController.text = group.minOvertimeMinutes > 0
            ? group.minOvertimeMinutes.toString()
            : '';
        maxOvertimeController.text = group.maxOvertimeMinutes > 0
            ? group.maxOvertimeMinutes.toString()
            : '';
        holidayOvertimeRatioValue = group.holidayOvertimeRatio;
        weekendOvertimeRatioValue = group.weekendOvertimeRatio;
        nightOvertimeAllowedValue = group.nightOvertimeAllowed;
        nightOvertimeStartController.text = group.nightOvertimeStart.isNotEmpty ? group.nightOvertimeStart : '22:00';
        nightOvertimeEndController.text = group.nightOvertimeEnd.isNotEmpty ? group.nightOvertimeEnd : '06:00';
        nightOvertimeRatioValue = group.nightOvertimeRatio;
        delayPenaltiesEnabledValue = group.delayPenaltiesEnabled;
        earlyExitPenaltiesEnabledValue = group.earlyExitPenaltiesEnabled;

        // Populate Delay Penalties
        delayT1MinController.text = group.delayTier1Min > 0
            ? group.delayTier1Min.toString()
            : '';
        delayT1MaxController.text = group.delayTier1Max > 0
            ? group.delayTier1Max.toString()
            : '';
        delayT1PenaltyController.text = group.delayTier1Penalty > 0
            ? group.delayTier1Penalty.toStringAsFixed(0)
            : '';
        delayT1ForgivenessController.text = group.delayTier1Forgiveness > 0
            ? group.delayTier1Forgiveness.toString()
            : '';
        delayT2MinController.text = group.delayTier2Min > 0
            ? group.delayTier2Min.toString()
            : '';
        delayT2MaxController.text = group.delayTier2Max > 0
            ? group.delayTier2Max.toString()
            : '';
        delayT2PenaltyController.text = group.delayTier2Penalty > 0
            ? group.delayTier2Penalty.toStringAsFixed(0)
            : '';
        delayT2ForgivenessController.text = group.delayTier2Forgiveness > 0
            ? group.delayTier2Forgiveness.toString()
            : '';
        delayT3MinController.text = group.delayTier3Min > 0
            ? group.delayTier3Min.toString()
            : '';
        delayT3PenaltyController.text = group.delayTier3Penalty > 0
            ? group.delayTier3Penalty.toStringAsFixed(0)
            : '';
        delayT3ForgivenessController.text = group.delayTier3Forgiveness > 0
            ? group.delayTier3Forgiveness.toString()
            : '';

        // Populate Early Exit Penalties
        earlyExitT1MinController.text = group.earlyExitTier1Min > 0
            ? group.earlyExitTier1Min.toString()
            : '';
        earlyExitT1MaxController.text = group.earlyExitTier1Max > 0
            ? group.earlyExitTier1Max.toString()
            : '';
        earlyExitT1PenaltyController.text = group.earlyExitTier1Penalty > 0
            ? group.earlyExitTier1Penalty.toStringAsFixed(0)
            : '';
        earlyExitT1ForgivenessController.text = group.earlyExitTier1Forgiveness > 0
            ? group.earlyExitTier1Forgiveness.toString()
            : '';
        earlyExitT2MinController.text = group.earlyExitTier2Min > 0
            ? group.earlyExitTier2Min.toString()
            : '';
        earlyExitT2MaxController.text = group.earlyExitTier2Max > 0
            ? group.earlyExitTier2Max.toString()
            : '';
        earlyExitT2PenaltyController.text = group.earlyExitTier2Penalty > 0
            ? group.earlyExitTier2Penalty.toStringAsFixed(0)
            : '';
        earlyExitT2ForgivenessController.text = group.earlyExitTier2Forgiveness > 0
            ? group.earlyExitTier2Forgiveness.toString()
            : '';
        earlyExitT3MinController.text = group.earlyExitTier3Min > 0
            ? group.earlyExitTier3Min.toString()
            : '';
        earlyExitT3PenaltyController.text = group.earlyExitTier3Penalty > 0
            ? group.earlyExitTier3Penalty.toStringAsFixed(0)
            : '';
        earlyExitT3ForgivenessController.text = group.earlyExitTier3Forgiveness > 0
            ? group.earlyExitTier3Forgiveness.toString()
            : '';
      } else if (employee != null) {
        nameController.text = employee.name;
        extraController1.text = employee.email;
        extraController2.text = employee.position;
        selectedStructureId = employee.structureId;
        phoneController.text = employee.phoneNumber;
        startDateController.text = employee.startDate;
        endDateController.text = employee.endDate ?? '';
        positionStartDateController.text = employee.positionStartDate;
        groupStartDateController.text = employee.groupStartDate;
        if (employee.groupHistory.isNotEmpty) {
          tempGroupHistory = List.from(employee.groupHistory);
        } else if (employee.groupId != null && employee.groupId!.isNotEmpty) {
          tempGroupHistory = [
            GroupHistoryEntry(
              groupId: employee.groupId!,
              startDate: employee.groupStartDate.isNotEmpty
                  ? employee.groupStartDate
                  : (employee.startDate.isNotEmpty
                      ? employee.startDate
                      : DateFormat('yyyy-MM-dd').format(DateTime.now())),
              endDate: '',
            ),
          ];
        } else {
          tempGroupHistory = [];
        }
        disabledValue = employee.disabled;
        annualLeaveBalanceController.text = employee.annualLeaveBalance > 0
            ? employee.annualLeaveBalance.toString()
            : '';
      } else if (holiday != null) {
        nameController.text = holiday.name;
        fromDateController.text = holiday.fromDate;
        toDateController.text = holiday.toDate;
        selectedHolidayGroupIds = List<String>.from(holiday.groupIds);
      } else if (location != null) {
        nameController.text = location.name;
        selectedLatitude = location.latitude;
        selectedLongitude = location.longitude;
        selectedRadius = location.radius;
        selectedLocationGroupIds = List<String>.from(location.groupIds);
        wifiBssidController.text = location.wifiBssid ?? '';
        wifiSsidController.text = location.wifiSsid ?? '';
        requireWifiValue = location.requireWifi;
      }
    } else {
      // Default pre-fills for adding
      if (_activeTab == HrTab.shifts) {
        extraController1.text = '09:00';
        extraController2.text = '17:00';
        extraController3.text = '15';
        earlyExitController.text = '10';
        breakStartController.text = '12:00';
        breakEndController.text = '14:00';
        breakDurationController.text = '60';
        isOvernightValue = false;
        crossMidnightCutoffController.text = '';
      } else if (_activeTab == HrTab.groups) {
        if (provider.shifts.isNotEmpty) {
          selectedShiftId = provider.shifts.first.id;
        }
        overtimeAllowedValue = false;
        minOvertimeController.text = '60';
        maxOvertimeController.text = '240';
        holidayOvertimeRatioValue = 1.5;
        weekendOvertimeRatioValue = 1.5;
        nightOvertimeAllowedValue = false;
        nightOvertimeStartController.text = '22:00';
        nightOvertimeEndController.text = '06:00';
        nightOvertimeRatioValue = 1.5;
        annualLeaveAdditionTypeValue = 'None';
        annualLeaveAdditionHoursController.text = '';
        missedPunchLimitController.text = '3';
        annualLeaveDeadlineController.text = '0';
        annualLeaveMinNoticeController.text = '0';
        annualLeaveMaxRequestsController.text = '0';
        annualLeavePeriodTypeValue = 'Month';
        hourlyLeaveMinDurationController.text = '';
        hourlyLeaveMaxDurationController.text = '';

        // Default penalties (1-5m, 6-30m, 31m+)
        delayT1MinController.text = '1';
        delayT1MaxController.text = '5';
        delayT1PenaltyController.text = '5000';
        delayT2MinController.text = '6';
        delayT2MaxController.text = '30';
        delayT2PenaltyController.text = '20000';
        delayT3MinController.text = '31';
        delayT3PenaltyController.text = '30000';

        earlyExitT1MinController.text = '1';
        earlyExitT1MaxController.text = '5';
        earlyExitT1PenaltyController.text = '5000';
        earlyExitT2MinController.text = '6';
        earlyExitT2MaxController.text = '30';
        earlyExitT2PenaltyController.text = '20000';
        earlyExitT3MinController.text = '31';
        earlyExitT3PenaltyController.text = '30000';
      } else if (_activeTab == HrTab.employees) {
        startDateController.text = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime.now());
        positionStartDateController.text = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime.now());
        groupStartDateController.text = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime.now());
        if (provider.structures.isNotEmpty) {
          selectedStructureId = provider.structures.first.id;
        }
      } else if (_activeTab == HrTab.holidays) {
        fromDateController.text = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime.now());
        toDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      }
    }

    int? calculateMinutesDifference(String startStr, String endStr) {
      final startParts = startStr.trim().split(':');
      final endParts = endStr.trim().split(':');
      if (startParts.length == 2 && endParts.length == 2) {
        final startH = int.tryParse(startParts[0]);
        final startM = int.tryParse(startParts[1]);
        final endH = int.tryParse(endParts[0]);
        final endM = int.tryParse(endParts[1]);
        if (startH != null && startM != null && endH != null && endM != null) {
          final startMinutes = startH * 60 + startM;
          var endMinutes = endH * 60 + endM;
          if (endMinutes < startMinutes) {
            endMinutes += 24 * 60; // handle overnight transitions
          }
          return endMinutes - startMinutes;
        }
      }
      return null;
    }

    String? dialogErrorMessage;
    String getTabDialogTitle() {
      if (isEditing) {
        switch (_activeTab) {
          case HrTab.structures:
            return provider.translate('edit_structure');
          case HrTab.shifts:
            return provider.translate('edit_shift');
          case HrTab.groups:
            return provider.translate('edit_group');
          case HrTab.employees:
            return provider.translate('edit_employee');
          case HrTab.holidays:
            return provider.translate('edit_holiday');
          case HrTab.locations:
            return provider.translate('edit_location');
          default:
            return '${provider.translate('edit')} ${_activeTab.name}';
        }
      } else {
        switch (_activeTab) {
          case HrTab.structures:
            return provider.translate('add_new_structure');
          case HrTab.shifts:
            return provider.translate('add_new_shift');
          case HrTab.groups:
            return provider.translate('add_new_group');
          case HrTab.employees:
            return provider.translate('add_new_employee');
          case HrTab.holidays:
            return provider.translate('add_new_holiday');
          case HrTab.locations:
            return provider.translate('add_new_location');
          default:
            return '${provider.translate('add')} ${_activeTab.name}';
        }
      }
    }

    showGlassDialog(
      context: context,
      title: getTabDialogTitle(),
      subtitle: provider.translate('fill_details_below'),
      icon: isEditing ? Icons.edit_rounded : Icons.add_rounded,
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
          final subtextColor = isDark ? Colors.white70 : const Color(0xFF475569);
          final mutedColor = isDark ? Colors.white54 : const Color(0xFF64748B);

          void updateAutoDuration() {
            final diff = calculateMinutesDifference(
              breakStartController.text,
              breakEndController.text,
            );
            if (diff != null) {
              breakDurationController.text = diff.toString();
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Structure Form Fields
              if (_activeTab == HrTab.structures) ...[
                _buildDialogField(provider.translate('structure_name_label'), nameController),
                const SizedBox(height: 12),
                if (provider.locations.isNotEmpty) ...[
                  _buildDropdownField(
                    label: provider.translate('company_location_preset_optional'),
                    value: null,
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(provider.translate('custom_location')),
                      ),
                      ...provider.locations.map(
                        (loc) => DropdownMenuItem(
                          value: loc.id,
                          child: Text('${loc.name} (${loc.radius.round()}m)'),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        final found = provider.locations.firstWhere((l) => l.id == val);
                        setDialogState(() {
                          extraController1.text = found.name;
                          selectedLatitude = found.latitude;
                          selectedLongitude = found.longitude;
                          selectedRadius = found.radius;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                _buildDialogField(provider.translate('location_eg_downtown'), extraController1),
                const SizedBox(height: 12),
                _buildDialogField(
                  provider.translate('capacity_eg_100'),
                  extraController2,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selectedLatitude != null
                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                          : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            size: 16,
                            color: selectedLatitude != null ? const Color(0xFF10B981) : mutedColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            provider.translate('gps_geofencing_settings'),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedLatitude != null &&
                                      selectedLongitude != null
                                  ? 'Lat: ${selectedLatitude!.toStringAsFixed(4)}, Lng: ${selectedLongitude!.toStringAsFixed(4)}\nRadius: ${selectedRadius?.round() ?? 0}m'
                                  : provider.translate('no_location_set'),
                              style: TextStyle(
                                color: selectedLatitude != null ? const Color(0xFF10B981) : mutedColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          NeuButton(
                            variant: NeuButtonVariant.navy,
                            icon: const Icon(Icons.map, size: 16),
                            label: provider.translate(selectedLatitude != null ? 'change_on_map' : 'pick_on_map'),
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MapPickerScreen(
                                    initialLatitude:
                                        selectedLatitude ?? 33.3152,
                                    initialLongitude:
                                        selectedLongitude ?? 44.3661,
                                    initialRadius: selectedRadius ?? 100.0,
                                    fetchCurrentLocation:
                                        selectedLatitude == null,
                                  ),
                                ),
                              );
                              if (result != null) {
                                setDialogState(() {
                                  selectedLatitude = result['latitude'];
                                  selectedLongitude = result['longitude'];
                                  selectedRadius = result['radius'];
                                });
                              }
                            },
                          ),
                          if (selectedLatitude != null) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                setDialogState(() {
                                  selectedLatitude = null;
                                  selectedLongitude = null;
                                  selectedRadius = null;
                                });
                              },
                              child: Text(provider.translate('clear_btn'), style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildDropdownField(
                  label: provider.translate('parent_structure'),
                  value: selectedParentId,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(provider.translate('none_no_parent')),
                    ),
                    ...provider.structures
                        .where((s) => structure == null || s.id != structure.id)
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        ),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      selectedParentId = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _buildDropdownField(
                  label: provider.translate('supervisor_of_structure'),
                  value: selectedSupervisorId,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(provider.translate('none_no_supervisor')),
                    ),
                    ...provider.employees.map(
                      (e) => DropdownMenuItem(
                        value: e.id,
                        child: Text('${e.name} (${e.position})'),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      selectedSupervisorId = val;
                    });
                  },
                ),
              ],
              // Shift Form Fields
              if (_activeTab == HrTab.shifts) ...[
                _buildDialogField(
                  'Shift Name',
                  nameController,
                  hintText: 'e.g., Morning Shift',
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(
                    'Is Weekly Rotation Shift?',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Configure different times for each day of the week',
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: 12,
                    ),
                  ),
                  value: isRotationValue,
                  activeThumbColor: const Color(0xFF10B981),
                  onChanged: (val) {
                    setDialogState(() {
                      isRotationValue = val;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (!isRotationValue) ...[
                  _buildGroupedContainer(
                    title: 'Work Hours',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              'Start Time',
                              extraController1,
                              suffixIcon: Icons.access_time,
                              onSuffixTap: () =>
                                  _selectTime(context, extraController1, () {
                                    setDialogState(() {
                                      if (WorkShift.isTimeCrossMidnight(extraController1.text, extraController2.text)) {
                                        isOvernightValue = true;
                                        if (crossMidnightCutoffController.text.isEmpty) {
                                          crossMidnightCutoffController.text = '03:00';
                                        }
                                      }
                                    });
                                  }),
                              hintText: '--:--',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDialogField(
                              'End Time',
                              extraController2,
                              suffixIcon: Icons.access_time,
                              onSuffixTap: () =>
                                  _selectTime(context, extraController2, () {
                                    setDialogState(() {
                                      if (WorkShift.isTimeCrossMidnight(extraController1.text, extraController2.text)) {
                                        isOvernightValue = true;
                                        if (crossMidnightCutoffController.text.isEmpty) {
                                          crossMidnightCutoffController.text = '03:00';
                                        }
                                      }
                                    });
                                  }),
                              hintText: '--:--',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Overnight Shift (Crosses Midnight)',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Starts on one day and finishes past 00:00 next day',
                          style: TextStyle(
                            color: mutedColor,
                            fontSize: 11,
                          ),
                        ),
                        value: isOvernightValue,
                        activeThumbColor: const Color(0xFF10B981),
                        onChanged: (val) {
                          setDialogState(() {
                            isOvernightValue = val;
                            if (val && crossMidnightCutoffController.text.isEmpty) {
                              crossMidnightCutoffController.text = '03:00';
                            }
                          });
                        },
                      ),
                      if (isOvernightValue) ...[
                        const SizedBox(height: 10),
                        _buildDialogField(
                          'Next-Day Attribution Cutoff',
                          crossMidnightCutoffController,
                          suffixIcon: Icons.access_time,
                          onSuffixTap: () => _selectTime(
                            context,
                            crossMidnightCutoffController,
                            null,
                          ),
                          hintText: '03:00',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Checkouts and punches before this time next morning calculate towards yesterday\'s date.',
                          style: TextStyle(
                            color: mutedColor,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildGroupedContainer(
                    title: 'Working Days',
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [
                              {'label': 'S', 'value': 6},
                              {'label': 'S', 'value': 7},
                              {'label': 'M', 'value': 1},
                              {'label': 'T', 'value': 2},
                              {'label': 'W', 'value': 3},
                              {'label': 'T', 'value': 4},
                              {'label': 'F', 'value': 5},
                            ].map((dayMap) {
                              final isSelected = selectedWorkingDays.contains(
                                dayMap['value'] as int,
                              );
                              return FilterChip(
                                label: Text(
                                  dayMap['label'] as String,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: const Color(0xFF10B981),
                                backgroundColor: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : const Color(0xFFE2E8F0),
                                checkmarkColor: Colors.white,
                                onSelected: (bool selected) {
                                  setDialogState(() {
                                    if (selected) {
                                      selectedWorkingDays.add(
                                        dayMap['value'] as int,
                                      );
                                    } else {
                                      selectedWorkingDays.remove(
                                        dayMap['value'] as int,
                                      );
                                    }
                                  });
                                },
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ] else ...[
                  _buildGroupedContainer(
                    title: 'Weekly Schedule',
                    children: [
                      ...[
                        {'label': 'Saturday', 'value': 6},
                        {'label': 'Sunday', 'value': 7},
                        {'label': 'Monday', 'value': 1},
                        {'label': 'Tuesday', 'value': 2},
                        {'label': 'Wednesday', 'value': 3},
                        {'label': 'Thursday', 'value': 4},
                        {'label': 'Friday', 'value': 5},
                      ].map((dayMap) {
                        final dayIndex = dayMap['value'] as int;
                        final dayLabel = dayMap['label'] as String;
                        final config = weeklyScheduleValue[dayIndex]!;
                        return Column(
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    dayLabel,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: config.isWorkingDay,
                                  activeThumbColor: const Color(0xFF10B981),
                                  onChanged: (val) {
                                    setDialogState(() {
                                      weeklyScheduleValue[dayIndex] =
                                          DayShiftConfig(
                                            isWorkingDay: val,
                                            startTime: config.startTime,
                                            endTime: config.endTime,
                                            breakStart: config.breakStart,
                                            breakEnd: config.breakEnd,
                                            breakDurationMinutes:
                                                config.breakDurationMinutes,
                                          );
                                    });
                                  },
                                ),
                                Text(
                                  'Work Day',
                                  style: TextStyle(
                                    color: subtextColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (config.isWorkingDay) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final timeStr = config.startTime;
                                        TimeOfDay initialTime = const TimeOfDay(
                                          hour: 9,
                                          minute: 0,
                                        );
                                        if (timeStr.isNotEmpty) {
                                          final parts = timeStr.split(':');
                                          if (parts.length == 2) {
                                            initialTime = TimeOfDay(
                                              hour: int.tryParse(parts[0]) ?? 9,
                                              minute:
                                                  int.tryParse(parts[1]) ?? 0,
                                            );
                                          }
                                        }
                                        final TimeOfDay? picked =
                                            await showTimePicker(
                                              context: context,
                                              initialTime: initialTime,
                                            );
                                        if (picked != null) {
                                          setDialogState(() {
                                            final hh = picked.hour
                                                .toString()
                                                .padLeft(2, '0');
                                            final mm = picked.minute
                                                .toString()
                                                .padLeft(2, '0');
                                            weeklyScheduleValue[dayIndex] =
                                                DayShiftConfig(
                                                  isWorkingDay:
                                                      config.isWorkingDay,
                                                  startTime: '$hh:$mm',
                                                  endTime: config.endTime,
                                                  breakStart: config.breakStart,
                                                  breakEnd: config.breakEnd,
                                                  breakDurationMinutes: config
                                                      .breakDurationMinutes,
                                                );
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.05,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.03,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.1,
                                                  ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                config.startTime,
                                                style: TextStyle(
                                                  color: textColor,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Icon(
                                              Icons.access_time,
                                              color: mutedColor,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'to',
                                    style: TextStyle(color: mutedColor),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final timeStr = config.endTime;
                                        TimeOfDay initialTime = const TimeOfDay(
                                          hour: 17,
                                          minute: 0,
                                        );
                                        if (timeStr.isNotEmpty) {
                                          final parts = timeStr.split(':');
                                          if (parts.length == 2) {
                                            initialTime = TimeOfDay(
                                              hour:
                                                  int.tryParse(parts[0]) ?? 17,
                                              minute:
                                                  int.tryParse(parts[1]) ?? 0,
                                            );
                                          }
                                        }
                                        final TimeOfDay? picked =
                                            await showTimePicker(
                                              context: context,
                                              initialTime: initialTime,
                                            );
                                        if (picked != null) {
                                          setDialogState(() {
                                            final hh = picked.hour
                                                .toString()
                                                .padLeft(2, '0');
                                            final mm = picked.minute
                                                .toString()
                                                .padLeft(2, '0');
                                            weeklyScheduleValue[dayIndex] =
                                                DayShiftConfig(
                                                  isWorkingDay:
                                                      config.isWorkingDay,
                                                  startTime: config.startTime,
                                                  endTime: '$hh:$mm',
                                                  breakStart: config.breakStart,
                                                  breakEnd: config.breakEnd,
                                                  breakDurationMinutes: config
                                                      .breakDurationMinutes,
                                                );
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.05,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.03,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.1,
                                                  ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                config.endTime,
                                                style: TextStyle(
                                                  color: textColor,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Icon(
                                              Icons.access_time,
                                              color: mutedColor,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    'Break:',
                                    style: TextStyle(
                                      color: subtextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final timeStr =
                                            config.breakStart.isNotEmpty
                                            ? config.breakStart
                                            : '12:00';
                                        TimeOfDay initialTime = const TimeOfDay(
                                          hour: 12,
                                          minute: 0,
                                        );
                                        if (timeStr.isNotEmpty) {
                                          final parts = timeStr.split(':');
                                          if (parts.length == 2) {
                                            initialTime = TimeOfDay(
                                              hour:
                                                  int.tryParse(parts[0]) ?? 12,
                                              minute:
                                                  int.tryParse(parts[1]) ?? 0,
                                            );
                                          }
                                        }
                                        final TimeOfDay? picked =
                                            await showTimePicker(
                                              context: context,
                                              initialTime: initialTime,
                                            );
                                        if (picked != null) {
                                          setDialogState(() {
                                            final hh = picked.hour
                                                .toString()
                                                .padLeft(2, '0');
                                            final mm = picked.minute
                                                .toString()
                                                .padLeft(2, '0');

                                            final newBreakStart = '$hh:$mm';
                                            final diff =
                                                calculateMinutesDifference(
                                                  newBreakStart,
                                                  config.breakEnd,
                                                );

                                            weeklyScheduleValue[dayIndex] =
                                                DayShiftConfig(
                                                  isWorkingDay:
                                                      config.isWorkingDay,
                                                  startTime: config.startTime,
                                                  endTime: config.endTime,
                                                  breakStart: newBreakStart,
                                                  breakEnd: config.breakEnd,
                                                  breakDurationMinutes:
                                                      diff ??
                                                      config
                                                          .breakDurationMinutes,
                                                );
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.05,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.03,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.1,
                                                  ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                config.breakStart.isEmpty
                                                    ? '--:--'
                                                    : config.breakStart,
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Icon(
                                              Icons.access_time,
                                              color: mutedColor,
                                              size: 14,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'to',
                                    style: TextStyle(
                                      color: mutedColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final timeStr =
                                            config.breakEnd.isNotEmpty
                                            ? config.breakEnd
                                            : '13:00';
                                        TimeOfDay initialTime = const TimeOfDay(
                                          hour: 13,
                                          minute: 0,
                                        );
                                        if (timeStr.isNotEmpty) {
                                          final parts = timeStr.split(':');
                                          if (parts.length == 2) {
                                            initialTime = TimeOfDay(
                                              hour:
                                                  int.tryParse(parts[0]) ?? 13,
                                              minute:
                                                  int.tryParse(parts[1]) ?? 0,
                                            );
                                          }
                                        }
                                        final TimeOfDay? picked =
                                            await showTimePicker(
                                              context: context,
                                              initialTime: initialTime,
                                            );
                                        if (picked != null) {
                                          setDialogState(() {
                                            final hh = picked.hour
                                                .toString()
                                                .padLeft(2, '0');
                                            final mm = picked.minute
                                                .toString()
                                                .padLeft(2, '0');

                                            final newBreakEnd = '$hh:$mm';
                                            final diff =
                                                calculateMinutesDifference(
                                                  config.breakStart,
                                                  newBreakEnd,
                                                );

                                            weeklyScheduleValue[dayIndex] =
                                                DayShiftConfig(
                                                  isWorkingDay:
                                                      config.isWorkingDay,
                                                  startTime: config.startTime,
                                                  endTime: config.endTime,
                                                  breakStart: config.breakStart,
                                                  breakEnd: newBreakEnd,
                                                  breakDurationMinutes:
                                                      diff ??
                                                      config
                                                          .breakDurationMinutes,
                                                );
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.05,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.03,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.1,
                                                  ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                config.breakEnd.isEmpty
                                                    ? '--:--'
                                                    : config.breakEnd,
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Icon(
                                              Icons.access_time,
                                              color: mutedColor,
                                              size: 14,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () async {
                                      TextEditingController controller =
                                          TextEditingController(
                                            text: config.breakDurationMinutes
                                                .toString(),
                                          );
                                      await showGlassDialog(
                                        context: context,
                                        title: 'Break Duration',
                                        subtitle: 'Set duration in minutes',
                                        icon: Icons.timer,
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              controller: controller,
                                              keyboardType:
                                                  TextInputType.number,
                                              style: TextStyle(
                                                color: textColor,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: 'e.g. 30',
                                                hintStyle: TextStyle(
                                                  color: mutedColor,
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: isDark ? Colors.white24 : Colors.black26,
                                                      ),
                                                    ),
                                                focusedBorder:
                                                    const OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: Color(
                                                          0xFF10B981,
                                                        ),
                                                      ),
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: Text(
                                                    'Cancel',
                                                    style: TextStyle(
                                                      color: subtextColor,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                NeuButton(
                                                  label: 'Save',
                                                  variant: NeuButtonVariant.primary,
                                                  height: 36,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    setDialogState(() {
                                                      weeklyScheduleValue[dayIndex] =
                                                          DayShiftConfig(
                                                            isWorkingDay: config
                                                                .isWorkingDay,
                                                            startTime: config
                                                                .startTime,
                                                            endTime:
                                                                config.endTime,
                                                            breakStart: config
                                                                .breakStart,
                                                            breakEnd:
                                                                config.breakEnd,
                                                            breakDurationMinutes:
                                                                int.tryParse(
                                                                  controller
                                                                      .text,
                                                                ) ??
                                                                config
                                                                    .breakDurationMinutes,
                                                          );
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.1)
                                            : Colors.black.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${config.breakDurationMinutes}m',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (dayIndex != 5)
                              Divider(
                                color: isDark ? Colors.white24 : Colors.black12,
                                height: 24,
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                _buildGroupedContainer(
                  title: 'Shift Rules',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogField(
                            'Forgiveness of Delay (mins)',
                            extraController3,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDialogField(
                            'Early Exit (mins)',
                            earlyExitController,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!isRotationValue)
                  _buildGroupedContainer(
                    title: 'Break Time',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              'Break Start',
                              breakStartController,
                              suffixIcon: Icons.access_time,
                              onSuffixTap: () => _selectTime(
                                context,
                                breakStartController,
                                () {
                                  setDialogState(() {
                                    updateAutoDuration();
                                  });
                                },
                              ),
                              onChanged: (_) {
                                setDialogState(() {
                                  updateAutoDuration();
                                });
                              },
                              hintText: '--:--',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDialogField(
                              'Break End',
                              breakEndController,
                              suffixIcon: Icons.access_time,
                              onSuffixTap: () =>
                                  _selectTime(context, breakEndController, () {
                                    setDialogState(() {
                                      updateAutoDuration();
                                    });
                                  }),
                              onChanged: (_) {
                                setDialogState(() {
                                  updateAutoDuration();
                                });
                              },
                              hintText: '--:--',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDialogField(
                        'Duration (minutes)',
                        breakDurationController,
                        keyboardType: TextInputType.number,
                        hintText: 'Auto-calculated',
                      ),
                    ],
                  ),
              ],
              // Group Form Fields
              if (_activeTab == HrTab.groups) ...[
                _buildDialogField(
                  provider.translate('group_name'),
                  nameController,
                  hintText: 'e.g., Engineering Team',
                ),
                const SizedBox(height: 12),
                _buildDropdownField(
                  label: provider.translate('single_shift'),
                  value: selectedShiftId,
                  items: provider.shifts
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selectedShiftId = val;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildGroupedContainer(
                  title: provider.translate('annual_leave_settings'),
                  children: [
                    if (annualLeaveAdditionTypeValue != 'None')
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildDropdownField(
                              label: provider.translate('annual_leave_addition_type'),
                              value: annualLeaveAdditionTypeValue,
                              items: [
                                DropdownMenuItem(value: 'None', child: Text(provider.translate('opt_none'))),
                                DropdownMenuItem(
                                  value: 'Monthly',
                                  child: Text(provider.translate('opt_monthly')),
                                ),
                                DropdownMenuItem(
                                  value: 'Yearly',
                                  child: Text(provider.translate('opt_yearly')),
                                ),
                              ],
                              onChanged: (val) {
                                setDialogState(() {
                                  annualLeaveAdditionTypeValue = val!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('annual_leave_addition_hours'),
                              annualLeaveAdditionHoursController,
                              keyboardType: TextInputType.number,
                              hintText: 'e.g., 160',
                            ),
                          ),
                        ],
                      )
                    else
                      _buildDropdownField(
                        label: provider.translate('annual_leave_addition_type'),
                        value: annualLeaveAdditionTypeValue,
                        items: [
                          DropdownMenuItem(value: 'None', child: Text(provider.translate('opt_none'))),
                          DropdownMenuItem(
                            value: 'Monthly',
                            child: Text(provider.translate('opt_monthly')),
                          ),
                          DropdownMenuItem(
                            value: 'Yearly',
                            child: Text(provider.translate('opt_yearly')),
                          ),
                        ],
                        onChanged: (val) {
                          setDialogState(() {
                            annualLeaveAdditionTypeValue = val!;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGroupedContainer(
                  title: provider.translate('form_rules'),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildDialogField(
                            provider.translate('missed_punch_limit_per_month'),
                            missedPunchLimitController,
                            keyboardType: TextInputType.number,
                            hintText: 'e.g., 3',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDialogField(
                            provider.translate('annual_leave_deadline_days'),
                            annualLeaveDeadlineController,
                            keyboardType: TextInputType.number,
                            hintText: 'e.g., 2',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildDialogField(
                            provider.translate('annual_leave_min_notice_days'),
                            annualLeaveMinNoticeController,
                            keyboardType: TextInputType.number,
                            hintText: 'e.g., 2 (0 = none)',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDialogField(
                            provider.translate('annual_leave_max_requests_per_month'),
                            annualLeaveMaxRequestsController,
                            keyboardType: TextInputType.number,
                            hintText: 'e.g., 1 (0 = unlimited)',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: isDark ? Colors.white10 : Colors.black12),
                    const SizedBox(height: 8),
                    Text(
                      provider.translate('hourly_leave_rules'),
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildDialogField(
                            provider.translate('hourly_leave_min_duration'),
                            hourlyLeaveMinDurationController,
                            suffixIcon: Icons.access_time,
                            onSuffixTap: () => _selectTime(
                              context,
                              hourlyLeaveMinDurationController,
                              () => setDialogState(() {}),
                            ),
                            hintText: '00:00 (e.g. 01:30)',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDialogField(
                            provider.translate('hourly_leave_max_duration'),
                            hourlyLeaveMaxDurationController,
                            suffixIcon: Icons.access_time,
                            onSuffixTap: () => _selectTime(
                              context,
                              hourlyLeaveMaxDurationController,
                              () => setDialogState(() {}),
                            ),
                            hintText: '00:00 (e.g. 04:00)',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGroupedContainer(
                  title: provider.translate('permissions_rules'),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          provider.translate('overtime_allowed'),
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Switch(
                          value: overtimeAllowedValue,
                          activeThumbColor: const Color(0xFF34D399),
                          onChanged: (val) {
                            setDialogState(() {
                              overtimeAllowedValue = val;
                            });
                          },
                        ),
                      ],
                    ),

                    if (overtimeAllowedValue) ...[
                      const SizedBox(height: 12),
                      Divider(color: isDark ? Colors.white10 : Colors.black12),
                      const SizedBox(height: 8),
                      Text(
                        provider.translate('overtime_settings'),
                        style: TextStyle(
                          color: subtextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('min_overtime_mins'),
                              minOvertimeController,
                              keyboardType: TextInputType.number,
                              hintText: 'e.g., 60',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('max_overtime_mins'),
                              maxOvertimeController,
                              keyboardType: TextInputType.number,
                              hintText: 'e.g., 240',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildRatioSelector(
                        label: provider.translate('holiday_overtime_multiplier'),
                        currentValue: holidayOvertimeRatioValue,
                        onChanged: (val) {
                          setDialogState(() {
                            holidayOvertimeRatioValue = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildRatioSelector(
                        label: provider.translate('weekend_overtime_multiplier'),
                        currentValue: weekendOvertimeRatioValue,
                        onChanged: (val) {
                          setDialogState(() {
                            weekendOvertimeRatioValue = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Divider(color: isDark ? Colors.white10 : Colors.black12),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            provider.translate('enable_night_overtime'),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Switch(
                            value: nightOvertimeAllowedValue,
                            activeThumbColor: const Color(0xFF34D399),
                            onChanged: (val) {
                              setDialogState(() {
                                nightOvertimeAllowedValue = val;
                              });
                            },
                          ),
                        ],
                      ),
                      if (nightOvertimeAllowedValue) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDialogField(
                                provider.translate('night_start_time'),
                                nightOvertimeStartController,
                                suffixIcon: Icons.access_time,
                                onSuffixTap: () => _selectTime(
                                  context,
                                  nightOvertimeStartController,
                                  () => setDialogState(() {}),
                                ),
                                hintText: '22:00',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDialogField(
                                provider.translate('night_end_time'),
                                nightOvertimeEndController,
                                suffixIcon: Icons.access_time,
                                onSuffixTap: () => _selectTime(
                                  context,
                                  nightOvertimeEndController,
                                  () => setDialogState(() {}),
                                ),
                                hintText: '06:00',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildRatioSelector(
                          label: provider.translate('night_overtime_multiplier'),
                          currentValue: nightOvertimeRatioValue,
                          onChanged: (val) {
                            setDialogState(() {
                              nightOvertimeRatioValue = val;
                            });
                          },
                        ),
                      ],
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _buildGroupedContainer(
                  title: provider.translate('delay_penalties_levels'),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          provider.translate('enable_delay_penalties'),
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Switch(
                          value: delayPenaltiesEnabledValue,
                          activeThumbColor: const Color(0xFF34D399),
                          onChanged: (val) {
                            setDialogState(() {
                              delayPenaltiesEnabledValue = val;
                            });
                          },
                        ),
                      ],
                    ),
                    if (delayPenaltiesEnabledValue) ...[
                      const SizedBox(height: 12),
                      Divider(color: isDark ? Colors.white10 : Colors.black12),
                      const SizedBox(height: 8),
                      Text(
                        provider.translate('level_1_penalty'),
                        style: TextStyle(
                          color: subtextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('min_min'),
                              delayT1MinController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('max_min'),
                              delayT1MaxController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('penalty_iqd'),
                              delayT1PenaltyController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('forgiveness_times'),
                              delayT1ForgivenessController,
                              keyboardType: TextInputType.number,
                              hintText: '0',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(color: isDark ? Colors.white10 : Colors.black12),
                      const SizedBox(height: 8),
                      Text(
                        provider.translate('level_2_penalty'),
                        style: TextStyle(
                          color: subtextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('min_min'),
                              delayT2MinController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('max_min'),
                              delayT2MaxController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('penalty_iqd'),
                              delayT2PenaltyController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('forgiveness_times'),
                              delayT2ForgivenessController,
                              keyboardType: TextInputType.number,
                              hintText: '0',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(color: isDark ? Colors.white10 : Colors.black12),
                      const SizedBox(height: 8),
                      Text(
                        provider.translate('level_3_penalty'),
                        style: TextStyle(
                          color: subtextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('min_min'),
                              delayT3MinController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.translate('max_min'),
                                  style: TextStyle(
                                    color: mutedColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '+',
                                  style: TextStyle(
                                    color: subtextColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('penalty_iqd'),
                              delayT3PenaltyController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('forgiveness_times'),
                              delayT3ForgivenessController,
                              keyboardType: TextInputType.number,
                              hintText: '0',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _buildGroupedContainer(
                  title: provider.translate('early_exit_penalties_levels'),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          provider.translate('enable_early_exit_penalties'),
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Switch(
                          value: earlyExitPenaltiesEnabledValue,
                          activeThumbColor: const Color(0xFF34D399),
                          onChanged: (val) {
                            setDialogState(() {
                              earlyExitPenaltiesEnabledValue = val;
                            });
                          },
                        ),
                      ],
                    ),
                    if (earlyExitPenaltiesEnabledValue) ...[
                      const SizedBox(height: 12),
                      Divider(color: isDark ? Colors.white10 : Colors.black12),
                      const SizedBox(height: 8),
                      Text(
                        provider.translate('level_1_penalty'),
                        style: TextStyle(
                          color: subtextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('min_min'),
                              earlyExitT1MinController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('max_min'),
                              earlyExitT1MaxController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('penalty_iqd'),
                              earlyExitT1PenaltyController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('forgiveness_times'),
                              earlyExitT1ForgivenessController,
                              keyboardType: TextInputType.number,
                              hintText: '0',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(color: isDark ? Colors.white10 : Colors.black12),
                      const SizedBox(height: 8),
                      Text(
                        provider.translate('level_2_penalty'),
                        style: TextStyle(
                          color: subtextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('min_min'),
                              earlyExitT2MinController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('max_min'),
                              earlyExitT2MaxController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('penalty_iqd'),
                              earlyExitT2PenaltyController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('forgiveness_times'),
                              earlyExitT2ForgivenessController,
                              keyboardType: TextInputType.number,
                              hintText: '0',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(color: isDark ? Colors.white10 : Colors.black12),
                      const SizedBox(height: 8),
                      Text(
                        provider.translate('level_3_penalty'),
                        style: TextStyle(
                          color: subtextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('min_min'),
                              earlyExitT3MinController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.translate('max_min'),
                                  style: TextStyle(
                                    color: mutedColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '+',
                                  style: TextStyle(
                                    color: subtextColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('penalty_iqd'),
                              earlyExitT3PenaltyController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              provider.translate('forgiveness_times'),
                              earlyExitT3ForgivenessController,
                              keyboardType: TextInputType.number,
                              hintText: '0',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
              // Employee Form Fields
              if (_activeTab == HrTab.employees) ...[
                _buildDialogField(provider.translate('employee_name_label'), nameController),
                const SizedBox(height: 12),
                _buildDialogField(
                  provider.translate('email_address_label'),
                  extraController1,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _buildDialogField(
                  provider.translate('phone_number_label'),
                  phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDialogField(
                        provider.translate('employment_start_date'),
                        startDateController,
                        suffixIcon: Icons.calendar_today,
                        onSuffixTap: () =>
                            _selectDate(context, startDateController),
                        hintText: 'yyyy-MM-dd',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDialogField(
                        provider.translate('employment_end_date'),
                        endDateController,
                        suffixIcon: Icons.calendar_today,
                        onSuffixTap: () =>
                            _selectDate(context, endDateController),
                        hintText: provider.translate('date_optional_hint'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDropdownField(
                  label: provider.translate('organization_structure'),
                  value: selectedStructureId,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(provider.translate('none_no_structure')),
                    ),
                    ...provider.structures.map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      selectedStructureId = val;
                    });
                  },
                ),

                const SizedBox(height: 12),
                Text(
                  provider.translate('group_history'),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (tempGroupHistory.isEmpty)
                  Text(
                    provider.translate('no_group_history'),
                    style: TextStyle(color: mutedColor, fontSize: 12),
                  )
                else
                  Column(
                    children: tempGroupHistory.asMap().entries.map((entry) {
                      final int idx = entry.key;
                      final GroupHistoryEntry h = entry.value;
                      final hGroup = provider.groups.firstWhere(
                        (g) => g.id == h.groupId,
                        orElse: () => EmployeeGroup(
                          id: '',
                          name: 'Unknown',
                          shiftId: '',
                          overtimeAllowed: false,
                          canEditCompanyInfo: false,
                          minOvertimeMinutes: 0,
                          maxOvertimeMinutes: 0,
                          weekendOvertimeRatio: 0,
                          delayPenaltiesEnabled: false,
                          delayTier1Min: 0,
                          delayTier1Max: 0,
                          delayTier1Penalty: 0,
                          delayTier2Min: 0,
                          delayTier2Max: 0,
                          delayTier2Penalty: 0,
                          delayTier3Min: 0,
                          delayTier3Penalty: 0,
                          earlyExitPenaltiesEnabled: false,
                          earlyExitTier1Min: 0,
                          earlyExitTier1Max: 0,
                          earlyExitTier1Penalty: 0,
                          earlyExitTier2Min: 0,
                          earlyExitTier2Max: 0,
                          earlyExitTier2Penalty: 0,
                          earlyExitTier3Min: 0,
                          earlyExitTier3Penalty: 0,
                        ),
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hGroup.name,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${h.startDate} - ${h.endDate.isEmpty ? provider.translate('to_ongoing') : h.endDate}',
                                    style: TextStyle(
                                      color: subtextColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Color(0xFF2E65FF),
                                size: 19,
                              ),
                              onPressed: () {
                                _showAddGroupHistoryDialog(
                                  context,
                                  tempGroupHistory,
                                  setDialogState,
                                  provider,
                                  entryToEdit: h,
                                  editIndex: idx,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  tempGroupHistory.removeAt(idx);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(provider.translate('add_group_period_btn')),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2E65FF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    backgroundColor: const Color(
                      0xFF2E65FF,
                    ).withValues(alpha: 0.1),
                  ),
                  onPressed: () {
                    _showAddGroupHistoryDialog(
                      context,
                      tempGroupHistory,
                      setDialogState,
                      provider,
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildDialogField(
                  provider.translate('annual_leave_balance_hours'),
                  annualLeaveBalanceController,
                  keyboardType: TextInputType.number,
                  hintText: provider.translate('annual_leave_hours_hint'),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      provider.translate('disable_user'),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Switch(
                      value: disabledValue,
                      activeThumbColor: const Color(0xFFEF4444),
                      onChanged: (val) {
                        setDialogState(() {
                          disabledValue = val;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGroupedContainer(
                  title: 'Active Position Settings',
                  children: [
                    _buildDialogField(
                      'Position / Title',
                      extraController2,
                      onChanged: (_) {
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      'Position Start Date',
                      positionStartDateController,
                      suffixIcon: Icons.calendar_today,
                      onSuffixTap: () =>
                          _selectDate(context, positionStartDateController),
                      hintText: 'yyyy-MM-dd',
                    ),
                    if (isEditing &&
                        employee != null &&
                        extraController2.text.trim() != employee.position) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFFFBBF24,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFFBBF24),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Changing position from "${employee.position}" to "${extraController2.text.trim()}" will archive the old one to history.',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              // Holiday Form Fields
              if (_activeTab == HrTab.holidays) ...[
                _buildDialogField(
                  provider.translate('holiday_name_label'),
                  nameController,
                  hintText: 'e.g. Eid al-Fitr',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDialogField(
                        provider.translate('from_date_label'),
                        fromDateController,
                        suffixIcon: Icons.calendar_today,
                        onSuffixTap: () =>
                            _selectDate(context, fromDateController),
                        hintText: 'yyyy-MM-dd',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDialogField(
                        provider.translate('to_date_label'),
                        toDateController,
                        suffixIcon: Icons.calendar_today,
                        onSuffixTap: () =>
                            _selectDate(context, toDateController),
                        hintText: 'yyyy-MM-dd',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGroupedContainer(
                  title: provider.translate('applies_to_groups'),
                  children: [
                    Text(
                      provider.translate('select_groups_holiday'),
                      style: TextStyle(color: mutedColor, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: provider.groups.map((g) {
                        final isSelected = selectedHolidayGroupIds.contains(
                          g.id,
                        );
                        return FilterChip(
                          label: Text(
                            g.name,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : const Color(0xFF334155)),
                              fontSize: 12,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF2E65FF),
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : const Color(0xFFE2E8F0),
                          checkmarkColor: Colors.white,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedHolidayGroupIds.add(g.id);
                              } else {
                                selectedHolidayGroupIds.remove(g.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
              // Location Form Fields
              if (_activeTab == HrTab.locations) ...[
                _buildDialogField(
                  provider.translate('location_name_label'),
                  nameController,
                  hintText: 'e.g. Main Office HQ',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDialogField(
                        provider.translate('latitude_label'),
                        TextEditingController(
                          text: selectedLatitude?.toStringAsFixed(4) ?? '',
                        ),
                        readOnly: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDialogField(
                        provider.translate('longitude_label'),
                        TextEditingController(
                          text: selectedLongitude?.toStringAsFixed(4) ?? '',
                        ),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                NeuButton(
                  variant: NeuButtonVariant.navy,
                  icon: const Icon(Icons.map, size: 16),
                  label: provider.translate(selectedLatitude != null
                      ? 'update_map_settings'
                      : 'pick_on_map'),
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  onPressed: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MapPickerScreen(
                          initialLatitude: selectedLatitude ?? 33.3152,
                          initialLongitude: selectedLongitude ?? 44.3661,
                          initialRadius: selectedRadius ?? 100.0,
                          fetchCurrentLocation: selectedLatitude == null,
                        ),
                      ),
                    );
                    if (result != null) {
                      setDialogState(() {
                        selectedLatitude = result['latitude'];
                        selectedLongitude = result['longitude'];
                        selectedRadius = result['radius'];
                      });
                    }
                  },
                ),
                if (selectedRadius != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    provider.translate('selected_radius_meters').replaceAll('{radius}', selectedRadius!.round().toString()),
                    style: TextStyle(
                      color: subtextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _buildGroupedContainer(
                  title: provider.translate('assigned_to_groups'),
                  children: [
                    Text(
                      provider.translate('select_groups_clock_location'),
                      style: TextStyle(color: mutedColor, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: provider.groups.map((g) {
                        final isSelected = selectedLocationGroupIds.contains(
                          g.id,
                        );
                        return FilterChip(
                          label: Text(
                            g.name,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : const Color(0xFF334155)),
                              fontSize: 12,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF2E65FF),
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : const Color(0xFFE2E8F0),
                          checkmarkColor: Colors.white,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedLocationGroupIds.add(g.id);
                              } else {
                                selectedLocationGroupIds.remove(g.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGroupedContainer(
                  title: provider.translate('office_wifi_verification'),
                  children: [
                    Text(
                      provider.translate('wifi_bssid_help'),
                      style: TextStyle(color: mutedColor, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogField(
                            provider.translate('wifi_ssid'),
                            wifiSsidController,
                            hintText: 'e.g. Office_WiFi',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDialogField(
                            provider.translate('wifi_bssid'),
                            wifiBssidController,
                            hintText: 'e.g. 00:11:22:33:44:55',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        NeuButton(
                          variant: NeuButtonVariant.primary,
                          isLoading: isDetectingWifi,
                          icon: const Icon(Icons.wifi_find_rounded, size: 16),
                          label: provider.translate('detect_current_wifi'),
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          onPressed: isDetectingWifi
                              ? null
                              : () async {
                                  setDialogState(() => isDetectingWifi = true);
                                  try {
                                    final wifi = await provider.getCurrentWifiDetails();
                                    setDialogState(() {
                                      isDetectingWifi = false;
                                      if (wifi['bssid'] != null) wifiBssidController.text = wifi['bssid']!;
                                      if (wifi['ssid'] != null) wifiSsidController.text = wifi['ssid']!;
                                    });
                                    if (context.mounted) {
                                      if (wifi['bssid'] != null || wifi['ssid'] != null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              provider.translate('wifi_detected', params: {
                                                'ssid': wifi['ssid'] ?? 'Wi-Fi',
                                                'bssid': wifi['bssid'] ?? '',
                                              }),
                                            ),
                                            backgroundColor: const Color(0xFF00CBB4),
                                            duration: const Duration(seconds: 3),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(wifi['error'] ?? provider.translate('no_wifi_detected')),
                                            backgroundColor: Colors.redAccent,
                                            duration: const Duration(seconds: 4),
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    setDialogState(() => isDetectingWifi = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  }
                                },
                        ),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: requireWifiValue,
                              activeThumbColor: const Color(0xFF00CBB4),
                              onChanged: (val) {
                                setDialogState(() {
                                  requireWifiValue = val;
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                            Text(
                              provider.translate('require_wifi'),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
              if (dialogErrorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dialogErrorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      provider.translate('cancel'),
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  NeuButton(
                    label: provider.translate(isEditing ? 'save_changes' : 'create_btn'),
                    variant: NeuButtonVariant.primary,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    onPressed: () {
                      if (nameController.text.trim().isEmpty) {
                        setDialogState(() {
                          dialogErrorMessage = provider.translate('name_is_required');
                        });
                        return;
                      }

                      // Execute Save based on Active Tab
                      if (_activeTab == HrTab.structures) {
                        final capacityVal =
                            int.tryParse(extraController2.text) ?? 0;
                        if (isEditing && structure != null) {
                          provider.updateStructure(
                            structure.copyWith(
                              name: nameController.text.trim(),
                              location: extraController1.text.trim(),
                              capacity: capacityVal,
                              parentId: selectedParentId,
                              overrideParentId: true,
                              supervisorId: selectedSupervisorId,
                              overrideSupervisorId: true,
                              latitude: selectedLatitude,
                              overrideLatitude: true,
                              longitude: selectedLongitude,
                              overrideLongitude: true,
                              radius: selectedRadius,
                              overrideRadius: true,
                            ),
                          );
                          _showSuccessSnackBar(
                            'Structure updated successfully',
                          );
                        } else {
                          provider.addStructure(
                            OrgStructure(
                              id: 'struct_${DateTime.now().millisecondsSinceEpoch}',
                              name: nameController.text.trim(),
                              location: extraController1.text.trim(),
                              capacity: capacityVal,
                              parentId: selectedParentId,
                              supervisorId: selectedSupervisorId,
                              latitude: selectedLatitude,
                              longitude: selectedLongitude,
                              radius: selectedRadius,
                            ),
                          );
                          _showSuccessSnackBar('Structure added successfully');
                        }
                      } else if (_activeTab == HrTab.shifts) {
                        final forgivenessVal =
                            int.tryParse(extraController3.text) ?? 0;
                        final earlyExitVal =
                            int.tryParse(earlyExitController.text) ?? 0;
                        final durationVal =
                            int.tryParse(breakDurationController.text) ?? 0;
                        if (isEditing && shift != null) {
                          provider.updateShift(
                            shift.copyWith(
                              name: nameController.text.trim(),
                              startTime: extraController1.text.trim(),
                              endTime: extraController2.text.trim(),
                              forgivenessOfDelay: forgivenessVal,
                              earlyExit: earlyExitVal,
                              breakStart: breakStartController.text.trim(),
                              breakEnd: breakEndController.text.trim(),
                              breakDurationMinutes: durationVal,
                              workingDays: selectedWorkingDays,
                              isRotation: isRotationValue,
                              weeklySchedule: weeklyScheduleValue,
                              isOvernight: isOvernightValue || WorkShift.isTimeCrossMidnight(extraController1.text.trim(), extraController2.text.trim()),
                              crossMidnightCutoff: crossMidnightCutoffController.text.trim(),
                            ),
                          );
                          _showSuccessSnackBar('Shift updated successfully');
                        } else {
                          provider.addShift(
                            WorkShift(
                              id: 'shift_${DateTime.now().millisecondsSinceEpoch}',
                              name: nameController.text.trim(),
                              startTime: extraController1.text.trim(),
                              endTime: extraController2.text.trim(),
                              forgivenessOfDelay: forgivenessVal,
                              earlyExit: earlyExitVal,
                              breakStart: breakStartController.text.trim(),
                              breakEnd: breakEndController.text.trim(),
                              breakDurationMinutes: durationVal,
                              workingDays: selectedWorkingDays,
                              isRotation: isRotationValue,
                              weeklySchedule: weeklyScheduleValue,
                              isOvernight: isOvernightValue || WorkShift.isTimeCrossMidnight(extraController1.text.trim(), extraController2.text.trim()),
                              crossMidnightCutoff: crossMidnightCutoffController.text.trim(),
                            ),
                          );
                          _showSuccessSnackBar('Shift added successfully');
                        }
                      } else if (_activeTab == HrTab.groups) {
                        if (selectedShiftId == null) {
                          setDialogState(() {
                            dialogErrorMessage = 'Please select a shift first';
                          });
                          return;
                        }

                        final minOt =
                            int.tryParse(minOvertimeController.text) ?? 0;
                        final maxOt =
                            int.tryParse(maxOvertimeController.text) ?? 0;
                        final annualLeaveHours =
                            double.tryParse(
                              annualLeaveAdditionHoursController.text,
                            ) ??
                            0.0;
                        final missedPunchLimit =
                            int.tryParse(missedPunchLimitController.text) ?? 3;
                        final annualLeaveDeadline =
                            int.tryParse(annualLeaveDeadlineController.text) ??
                            0;
                        final annualLeaveMinNotice =
                            int.tryParse(annualLeaveMinNoticeController.text) ??
                            0;
                        final annualLeaveMaxRequests =
                            int.tryParse(annualLeaveMaxRequestsController.text) ??
                            0;
                        int hourlyLeaveMinHours = 0;
                        int hourlyLeaveMinMinutes = 0;
                        final minDurStr =
                            hourlyLeaveMinDurationController.text.trim();
                        if (minDurStr.isNotEmpty) {
                          final parts = minDurStr.split(':');
                          if (parts.length == 2) {
                            hourlyLeaveMinHours = int.tryParse(parts[0]) ?? 0;
                            hourlyLeaveMinMinutes = int.tryParse(parts[1]) ?? 0;
                          } else {
                            final mins =
                                parseHourlyLeaveDurationMinutes(minDurStr);
                            hourlyLeaveMinHours = mins ~/ 60;
                            hourlyLeaveMinMinutes = mins % 60;
                          }
                        }

                        int hourlyLeaveMaxHours = 0;
                        int hourlyLeaveMaxMinutes = 0;
                        final maxDurStr =
                            hourlyLeaveMaxDurationController.text.trim();
                        if (maxDurStr.isNotEmpty) {
                          final parts = maxDurStr.split(':');
                          if (parts.length == 2) {
                            hourlyLeaveMaxHours = int.tryParse(parts[0]) ?? 0;
                            hourlyLeaveMaxMinutes = int.tryParse(parts[1]) ?? 0;
                          } else {
                            final mins =
                                parseHourlyLeaveDurationMinutes(maxDurStr);
                            hourlyLeaveMaxHours = mins ~/ 60;
                            hourlyLeaveMaxMinutes = mins % 60;
                          }
                        }

                        final d1Min =
                            int.tryParse(delayT1MinController.text) ?? 0;
                        final d1Max =
                            int.tryParse(delayT1MaxController.text) ?? 0;
                        final d1Pen =
                            double.tryParse(delayT1PenaltyController.text) ??
                            0.0;
                        final d1Forgive =
                            int.tryParse(delayT1ForgivenessController.text) ?? 0;
                        final d2Min =
                            int.tryParse(delayT2MinController.text) ?? 0;
                        final d2Max =
                            int.tryParse(delayT2MaxController.text) ?? 0;
                        final d2Pen =
                            double.tryParse(delayT2PenaltyController.text) ??
                            0.0;
                        final d2Forgive =
                            int.tryParse(delayT2ForgivenessController.text) ?? 0;
                        final d3Min =
                            int.tryParse(delayT3MinController.text) ?? 0;
                        final d3Pen =
                            double.tryParse(delayT3PenaltyController.text) ??
                            0.0;
                        final d3Forgive =
                            int.tryParse(delayT3ForgivenessController.text) ?? 0;

                        final e1Min =
                            int.tryParse(earlyExitT1MinController.text) ?? 0;
                        final e1Max =
                            int.tryParse(earlyExitT1MaxController.text) ?? 0;
                        final e1Pen =
                            double.tryParse(
                              earlyExitT1PenaltyController.text,
                            ) ??
                            0.0;
                        final e1Forgive =
                            int.tryParse(earlyExitT1ForgivenessController.text) ?? 0;
                        final e2Min =
                            int.tryParse(earlyExitT2MinController.text) ?? 0;
                        final e2Max =
                            int.tryParse(earlyExitT2MaxController.text) ?? 0;
                        final e2Pen =
                            double.tryParse(
                              earlyExitT2PenaltyController.text,
                            ) ??
                            0.0;
                        final e2Forgive =
                            int.tryParse(earlyExitT2ForgivenessController.text) ?? 0;
                        final e3Min =
                            int.tryParse(earlyExitT3MinController.text) ?? 0;
                        final e3Pen =
                            double.tryParse(
                              earlyExitT3PenaltyController.text,
                            ) ??
                            0.0;
                        final e3Forgive =
                            int.tryParse(earlyExitT3ForgivenessController.text) ?? 0;

                        if (isEditing && group != null) {
                          provider.updateGroup(
                            group.copyWith(
                              name: nameController.text.trim(),
                              shiftId: selectedShiftId!,
                              annualLeaveAdditionType:
                                  annualLeaveAdditionTypeValue,
                              annualLeaveAdditionHours: annualLeaveHours,
                              missedPunchLimitPerMonth: missedPunchLimit,
                              annualLeaveRequestDeadlineDays:
                                  annualLeaveDeadline,
                              annualLeaveMinNoticeDays: annualLeaveMinNotice,
                              annualLeaveMaxRequestsPerPeriod: annualLeaveMaxRequests,
                              annualLeavePeriodType: annualLeavePeriodTypeValue,
                              hourlyLeaveMinHours: hourlyLeaveMinHours,
                              hourlyLeaveMinMinutes: hourlyLeaveMinMinutes,
                              hourlyLeaveMaxHours: hourlyLeaveMaxHours,
                              hourlyLeaveMaxMinutes: hourlyLeaveMaxMinutes,
                              overtimeAllowed: overtimeAllowedValue,
                              minOvertimeMinutes: minOt,
                              maxOvertimeMinutes: maxOt,
                              holidayOvertimeRatio: holidayOvertimeRatioValue,
                              weekendOvertimeRatio: weekendOvertimeRatioValue,
                              nightOvertimeAllowed: nightOvertimeAllowedValue,
                              nightOvertimeStart: nightOvertimeStartController.text.trim().isNotEmpty
                                  ? nightOvertimeStartController.text.trim()
                                  : '22:00',
                              nightOvertimeEnd: nightOvertimeEndController.text.trim().isNotEmpty
                                  ? nightOvertimeEndController.text.trim()
                                  : '06:00',
                              nightOvertimeRatio: nightOvertimeRatioValue,
                              delayPenaltiesEnabled: delayPenaltiesEnabledValue,
                              earlyExitPenaltiesEnabled:
                                  earlyExitPenaltiesEnabledValue,
                              delayTier1Min: d1Min,
                              delayTier1Max: d1Max,
                              delayTier1Penalty: d1Pen,
                              delayTier1Forgiveness: d1Forgive,
                              delayTier2Min: d2Min,
                              delayTier2Max: d2Max,
                              delayTier2Penalty: d2Pen,
                              delayTier2Forgiveness: d2Forgive,
                              delayTier3Min: d3Min,
                              delayTier3Penalty: d3Pen,
                              delayTier3Forgiveness: d3Forgive,
                              earlyExitTier1Min: e1Min,
                              earlyExitTier1Max: e1Max,
                              earlyExitTier1Penalty: e1Pen,
                              earlyExitTier1Forgiveness: e1Forgive,
                              earlyExitTier2Min: e2Min,
                              earlyExitTier2Max: e2Max,
                              earlyExitTier2Penalty: e2Pen,
                              earlyExitTier2Forgiveness: e2Forgive,
                              earlyExitTier3Min: e3Min,
                              earlyExitTier3Penalty: e3Pen,
                              earlyExitTier3Forgiveness: e3Forgive,
                            ),
                          );
                          _showSuccessSnackBar('Group updated successfully');
                        } else {
                          provider.addGroup(
                            EmployeeGroup(
                              id: 'group_${DateTime.now().millisecondsSinceEpoch}',
                              name: nameController.text.trim(),
                              shiftId: selectedShiftId!,
                              annualLeaveAdditionType:
                                  annualLeaveAdditionTypeValue,
                              annualLeaveAdditionHours: annualLeaveHours,
                              missedPunchLimitPerMonth: missedPunchLimit,
                              annualLeaveRequestDeadlineDays:
                                  annualLeaveDeadline,
                              annualLeaveMinNoticeDays: annualLeaveMinNotice,
                              annualLeaveMaxRequestsPerPeriod: annualLeaveMaxRequests,
                              annualLeavePeriodType: annualLeavePeriodTypeValue,
                              hourlyLeaveMinHours: hourlyLeaveMinHours,
                              hourlyLeaveMinMinutes: hourlyLeaveMinMinutes,
                              hourlyLeaveMaxHours: hourlyLeaveMaxHours,
                              hourlyLeaveMaxMinutes: hourlyLeaveMaxMinutes,
                              overtimeAllowed: overtimeAllowedValue,
                              minOvertimeMinutes: minOt,
                              maxOvertimeMinutes: maxOt,
                              holidayOvertimeRatio: holidayOvertimeRatioValue,
                              weekendOvertimeRatio: weekendOvertimeRatioValue,
                              nightOvertimeAllowed: nightOvertimeAllowedValue,
                              nightOvertimeStart: nightOvertimeStartController.text.trim().isNotEmpty
                                  ? nightOvertimeStartController.text.trim()
                                  : '22:00',
                              nightOvertimeEnd: nightOvertimeEndController.text.trim().isNotEmpty
                                  ? nightOvertimeEndController.text.trim()
                                  : '06:00',
                              nightOvertimeRatio: nightOvertimeRatioValue,
                              delayPenaltiesEnabled: delayPenaltiesEnabledValue,
                              earlyExitPenaltiesEnabled:
                                  earlyExitPenaltiesEnabledValue,
                              delayTier1Min: d1Min,
                              delayTier1Max: d1Max,
                              delayTier1Penalty: d1Pen,
                              delayTier1Forgiveness: d1Forgive,
                              delayTier2Min: d2Min,
                              delayTier2Max: d2Max,
                              delayTier2Penalty: d2Pen,
                              delayTier2Forgiveness: d2Forgive,
                              delayTier3Min: d3Min,
                              delayTier3Penalty: d3Pen,
                              delayTier3Forgiveness: d3Forgive,
                              earlyExitTier1Min: e1Min,
                              earlyExitTier1Max: e1Max,
                              earlyExitTier1Penalty: e1Pen,
                              earlyExitTier1Forgiveness: e1Forgive,
                              earlyExitTier2Min: e2Min,
                              earlyExitTier2Max: e2Max,
                              earlyExitTier2Penalty: e2Pen,
                              earlyExitTier2Forgiveness: e2Forgive,
                              earlyExitTier3Min: e3Min,
                              earlyExitTier3Penalty: e3Pen,
                              earlyExitTier3Forgiveness: e3Forgive,
                            ),
                          );
                          _showSuccessSnackBar('Group added successfully');
                        }
                      } else if (_activeTab == HrTab.employees) {
                        if (tempGroupHistory.isEmpty) {
                          setDialogState(() {
                            dialogErrorMessage =
                                'Employee must be assigned to at least one group.';
                          });
                          return;
                        }

                        final emailVal = extraController1.text.trim();
                        final newPos = extraController2.text.trim();
                        final phoneVal = phoneController.text.trim();
                        final startVal = startDateController.text.trim();
                        final endVal = endDateController.text.trim();
                        final posStartVal = positionStartDateController.text
                            .trim();
                        final annualLeaveBalanceVal =
                            double.tryParse(
                              annualLeaveBalanceController.text,
                            ) ??
                            0.0;

                        if (isEditing && employee != null) {
                          List<PositionHistoryEntry> history = List.from(
                            employee.positionHistory,
                          );
                          String activePosStart = employee.positionStartDate;

                          // Check if position title has changed
                          if (newPos != employee.position) {
                            // Archive old position
                            history.add(
                              PositionHistoryEntry(
                                position: employee.position,
                                startDate: employee.positionStartDate.isNotEmpty
                                    ? employee.positionStartDate
                                    : employee.startDate,
                                endDate: posStartVal.isNotEmpty
                                    ? posStartVal
                                    : DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(DateTime.now()),
                              ),
                            );
                            activePosStart = posStartVal.isNotEmpty
                                ? posStartVal
                                : DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(DateTime.now());
                          } else {
                            if (posStartVal.isNotEmpty) {
                              activePosStart = posStartVal;
                            }
                          }

                          List<GroupHistoryEntry> gHistory = List.from(
                            tempGroupHistory,
                          );
                          final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                          String? derivedGroupId;
                          String activeGroupStart = '';
                          for (var h in gHistory) {
                            if (h.startDate.compareTo(todayStr) <= 0 &&
                                (h.endDate.isEmpty || h.endDate.compareTo(todayStr) >= 0)) {
                              derivedGroupId = h.groupId;
                              activeGroupStart = h.startDate;
                              break;
                            }
                          }
                          if (derivedGroupId == null && gHistory.isNotEmpty) {
                            final sorted = List<GroupHistoryEntry>.from(gHistory)
                              ..sort((a, b) => b.startDate.compareTo(a.startDate));
                            derivedGroupId = sorted.first.groupId;
                            activeGroupStart = sorted.first.startDate;
                          }

                          provider.updateEmployee(
                            employee.copyWith(
                              name: nameController.text.trim(),
                              email: emailVal,
                              position: newPos,
                              groupId: derivedGroupId,
                              overrideGroupId: true,
                              structureId: selectedStructureId,
                              overrideStructureId: true,
                              phoneNumber: phoneVal,
                              startDate: startVal,
                              endDate: endVal.isNotEmpty ? endVal : null,
                              overrideEndDate: true,
                              disabled: disabledValue,
                              positionStartDate: activePosStart,
                              positionHistory: history,
                              groupStartDate: activeGroupStart,
                              groupHistory: gHistory,
                              annualLeaveBalance: annualLeaveBalanceVal,
                            ),
                          );
                          _showSuccessSnackBar('Employee updated successfully');
                        } else {
                          final targetCompany = provider.currentCompanyCode == 'all' ? '' : provider.currentCompanyCode;
                          provider.addEmployee(
                            CompanyEmployee(
                              id: provider.getNextEmployeeId(companyCode: targetCompany.isNotEmpty ? targetCompany : null),
                              companyCode: targetCompany,
                              name: nameController.text.trim(),
                              email: emailVal,
                              position: newPos,
                              groupId: tempGroupHistory.isNotEmpty
                                  ? tempGroupHistory.first.groupId
                                  : null,
                              structureId: selectedStructureId,
                              phoneNumber: phoneVal,
                              startDate: startVal.isNotEmpty
                                  ? startVal
                                  : DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(DateTime.now()),
                              endDate: endVal.isNotEmpty ? endVal : null,
                              disabled: disabledValue,
                              positionStartDate: posStartVal.isNotEmpty
                                  ? posStartVal
                                  : DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(DateTime.now()),
                              groupStartDate: tempGroupHistory.isNotEmpty
                                  ? tempGroupHistory.first.startDate
                                  : '',
                              positionHistory: [],
                              groupHistory: List.from(tempGroupHistory),
                              annualLeaveBalance: annualLeaveBalanceVal,
                            ),
                          );
                          _showSuccessSnackBar('Employee added successfully');
                        }
                      } else if (_activeTab == HrTab.holidays) {
                        final fromVal = fromDateController.text.trim();
                        final toVal = toDateController.text.trim();
                        if (fromVal.isEmpty || toVal.isEmpty) {
                          setDialogState(() {
                            dialogErrorMessage = 'Dates are required';
                          });
                          return;
                        }
                        if (isEditing && holiday != null) {
                          provider.updateHoliday(
                            holiday.copyWith(
                              name: nameController.text.trim(),
                              fromDate: fromVal,
                              toDate: toVal,
                              groupIds: selectedHolidayGroupIds,
                            ),
                          );
                          _showSuccessSnackBar('Holiday updated successfully');
                        } else {
                          provider.addHoliday(
                            Holiday(
                              id: 'holiday_${DateTime.now().millisecondsSinceEpoch}',
                              name: nameController.text.trim(),
                              fromDate: fromVal,
                              toDate: toVal,
                              groupIds: selectedHolidayGroupIds,
                            ),
                          );
                          _showSuccessSnackBar('Holiday added successfully');
                        }
                      } else if (_activeTab == HrTab.locations) {
                        if (selectedLatitude == null ||
                            selectedLongitude == null ||
                            selectedRadius == null) {
                          setDialogState(() {
                            dialogErrorMessage =
                                'Please pick a location on the map';
                          });
                          return;
                        }
                        if (isEditing && location != null) {
                          provider.updateLocation(
                            location.copyWith(
                              name: nameController.text.trim(),
                              latitude: selectedLatitude,
                              longitude: selectedLongitude,
                              radius: selectedRadius,
                              groupIds: selectedLocationGroupIds,
                              wifiBssid: wifiBssidController.text.trim().isNotEmpty
                                  ? wifiBssidController.text.trim()
                                  : null,
                              overrideWifiBssid: true,
                              wifiSsid: wifiSsidController.text.trim().isNotEmpty
                                  ? wifiSsidController.text.trim()
                                  : null,
                              overrideWifiSsid: true,
                              requireWifi: requireWifiValue,
                            ),
                          );
                          _showSuccessSnackBar('Location updated successfully');
                        } else {
                          final targetCompany = provider.currentCompanyCode == 'all' ? '' : provider.currentCompanyCode;
                          provider.addLocation(
                            WorkLocation(
                              id: 'loc_${DateTime.now().millisecondsSinceEpoch}',
                              name: nameController.text.trim(),
                              latitude: selectedLatitude!,
                              longitude: selectedLongitude!,
                              radius: selectedRadius!,
                              groupIds: selectedLocationGroupIds,
                              companyCode: targetCompany,
                              wifiBssid: wifiBssidController.text.trim().isNotEmpty
                                  ? wifiBssidController.text.trim()
                                  : null,
                              wifiSsid: wifiSsidController.text.trim().isNotEmpty
                                  ? wifiSsidController.text.trim()
                                  : null,
                              requireWifi: requireWifiValue,
                            ),
                          );
                          _showSuccessSnackBar('Location added successfully');
                        }
                      }

                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddGroupHistoryDialog(
    BuildContext parentContext,
    List<GroupHistoryEntry> tempGroupHistory,
    StateSetter parentSetState,
    AttendanceProvider provider, {
    GroupHistoryEntry? entryToEdit,
    int? editIndex,
  }) {
    String? selectedGroupId = entryToEdit?.groupId;
    final startDateController =
        TextEditingController(text: entryToEdit?.startDate ?? '');
    final endDateController =
        TextEditingController(text: entryToEdit?.endDate ?? '');

    String? dialogErrorMessage;
    showGlassDialog(
      context: parentContext,
      title: entryToEdit != null
          ? 'Edit Group Period'
          : 'Add Group History Period',
      subtitle: entryToEdit != null
          ? 'Update period start and end dates'
          : 'Add a new shift period',
      icon: Icons.history_rounded,
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dialogErrorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dialogErrorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildDropdownField(
                label: 'Employee Group',
                value: selectedGroupId,
                items: provider.groups
                    .map(
                      (g) => DropdownMenuItem(value: g.id, child: Text(g.name)),
                    )
                    .toList(),
                onChanged: (val) {
                  setDialogState(() {
                    selectedGroupId = val;
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildDialogField(
                'Start Date',
                startDateController,
                suffixIcon: Icons.calendar_today,
                onSuffixTap: () => _selectDate(context, startDateController),
                hintText: 'yyyy-MM-dd',
              ),
              const SizedBox(height: 12),
              _buildDialogField(
                'End Date',
                endDateController,
                suffixIcon: Icons.calendar_today,
                onSuffixTap: () => _selectDate(context, endDateController),
                hintText: 'yyyy-MM-dd (Optional, leave blank for ongoing)',
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(width: 8),
                  NeuButton(
                    label: entryToEdit != null ? 'Save' : 'Add',
                    variant: NeuButtonVariant.primary,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    onPressed: () {
                      if (selectedGroupId == null ||
                          startDateController.text.trim().isEmpty) {
                        setDialogState(() {
                          dialogErrorMessage =
                              'Please select a group and start date.';
                        });
                        return;
                      }
                      parentSetState(() {
                        if (editIndex != null &&
                            editIndex < tempGroupHistory.length) {
                          tempGroupHistory[editIndex] = GroupHistoryEntry(
                            groupId: selectedGroupId!,
                            startDate: startDateController.text.trim(),
                            endDate: endDateController.text.trim(),
                          );
                        } else {
                          try {
                            final newStartDate = DateTime.parse(
                              startDateController.text.trim(),
                            );
                            final previousDay = newStartDate.subtract(
                              const Duration(days: 1),
                            );
                            final prevDayStr =
                                "${previousDay.year.toString().padLeft(4, '0')}-${previousDay.month.toString().padLeft(2, '0')}-${previousDay.day.toString().padLeft(2, '0')}";

                            String? previousOngoingGroup;
                            for (int i = 0; i < tempGroupHistory.length; i++) {
                              if (tempGroupHistory[i].endDate.isEmpty) {
                                previousOngoingGroup =
                                    tempGroupHistory[i].groupId;
                                tempGroupHistory[i] = GroupHistoryEntry(
                                  groupId: tempGroupHistory[i].groupId,
                                  startDate: tempGroupHistory[i].startDate,
                                  endDate: prevDayStr,
                                );
                              }
                            }

                            final newEndText = endDateController.text.trim();
                            if (newEndText.isNotEmpty &&
                                previousOngoingGroup != null) {
                              final endDt = DateTime.parse(newEndText);
                              final nextDay = endDt.add(
                                const Duration(days: 1),
                              );
                              final nextDayStr =
                                  "${nextDay.year.toString().padLeft(4, '0')}-${nextDay.month.toString().padLeft(2, '0')}-${nextDay.day.toString().padLeft(2, '0')}";
                              tempGroupHistory.add(
                                GroupHistoryEntry(
                                  groupId: previousOngoingGroup,
                                  startDate: nextDayStr,
                                  endDate: '',
                                ),
                              );
                            }
                          } catch (_) {
                            // Ignore if date parsing fails
                          }

                          tempGroupHistory.add(
                            GroupHistoryEntry(
                              groupId: selectedGroupId!,
                              startDate: startDateController.text.trim(),
                              endDate: endDateController.text.trim(),
                            ),
                          );
                        }

                        tempGroupHistory.sort(
                          (a, b) => b.startDate.compareTo(a.startDate),
                        );
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialogField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
    String? hintText,
    ValueChanged<String>? onChanged,
    bool readOnly = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF334155),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          readOnly: readOnly,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 15,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: isDark
                ? const Color(0xFF0F172A)
                : const Color(0xFFF8FAFC),
            hintText: hintText,
            hintStyle: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.35)
                  : const Color(0xFF94A3B8),
              fontSize: 14,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            suffixIcon: suffixIcon != null
                ? InkWell(
                    onTap: onSuffixTap,
                    child: Icon(
                      suffixIcon,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      size: 18,
                    ),
                  )
                : null,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2E65FF), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFCBD5E1),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 1. De-duplicate items by item.value
    final seen = <T?>{};
    final cleanItems = <DropdownMenuItem<T>>[];
    for (final item in items) {
      if (!seen.contains(item.value)) {
        seen.add(item.value);
        cleanItems.add(item);
      }
    }

    // 2. Ensure current value exists in cleanItems
    T? effectiveValue = value;
    if (value != null && !cleanItems.any((it) => it.value == value)) {
      cleanItems.add(
        DropdownMenuItem<T>(
          value: value,
          child: Text('$value (Current)'),
        ),
      );
      effectiveValue = value;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF334155),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Theme(
          data: Theme.of(
            context,
          ).copyWith(
            canvasColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          ),
          child: DropdownButtonFormField<T>(
            key: ValueKey(effectiveValue),
            initialValue: effectiveValue,
            items: cleanItems,
            onChanged: onChanged,
            isExpanded: true,
            icon: Icon(
              Icons.arrow_drop_down,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2E65FF), width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : const Color(0xFFCBD5E1),
                ),
              ),
            ),
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatioSelector({
    required String label,
    required double currentValue,
    required ValueChanged<double> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final values = [1.0, 1.5, 2.0, 3.0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: values.map((val) {
            final isSelected = (currentValue - val).abs() < 0.05;
            final labelText = val == 1.0 ? '1x' : '${val}x';
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(val),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2E65FF)
                        : (isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2E65FF)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFCBD5E1)),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    labelText,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : const Color(0xFF334155)),
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGroupedContainer({
    required String title,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.5)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final initialDate = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: buildAdaptivePickerTheme,
    );
    if (picked != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _selectTime(
    BuildContext context,
    TextEditingController controller,
    VoidCallback? onSelect,
  ) async {
    final parts = controller.text.split(':');
    var initialTime = TimeOfDay.now();
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        initialTime = TimeOfDay(hour: h, minute: m);
      }
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: buildAdaptivePickerTheme,
    );
    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      controller.text = '$hour:$minute';
      if (onSelect != null) {
        onSelect();
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2E65FF),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildPayrollList(AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    final filtered = _searchQuery.isEmpty
        ? provider.employees
        : provider.employees
              .where(
                (e) =>
                    e.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    e.position.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList();

    return Column(
      children: [
        _buildSearchBar('Search employees for payroll...'),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          Expanded(child: _buildEmptyState('employees'))
        else
          Expanded(
            child: _buildResponsiveList(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final employee = filtered[index];
                final hourlyRate = employee.workingHours > 0
                    ? employee.basicSalary / employee.workingHours
                    : 0.0;
                final dailyRate = employee.basicSalary / 30.0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showPayrollConfigDialog(employee, provider),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundImage: getAvatarProvider(employee.avatarUrl),
                            backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                            child: (getAvatarProvider(employee.avatarUrl) == null)
                                ? Text(
                                    employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  employee.name,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Salary: ${employee.basicSalary.toStringAsFixed(2)} ${employee.salaryCurrency} | Hours: ${employee.workingHours.toStringAsFixed(1)}',
                                  style: TextStyle(
                                    color: subtextColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Hourly Rate: ${hourlyRate.toStringAsFixed(2)} ${employee.salaryCurrency}/hr | Daily Rate: ${dailyRate.toStringAsFixed(2)} ${employee.salaryCurrency}/day',
                                  style: TextStyle(
                                    color: subtextColor,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                              size: 18,
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
      ],
    );
  }

  void _showPayrollConfigDialog(
    CompanyEmployee employee,
    AttendanceProvider provider,
  ) {
    _showPayrollHistoryDialog(employee, provider);
  }

  void _showPayrollHistoryDialog(
    CompanyEmployee employee,
    AttendanceProvider provider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    final List<SalaryHistoryEntry> displayHistory = List.from(employee.salaryHistory);
    if (displayHistory.isEmpty && (employee.basicSalary > 0 || employee.workingHours > 0)) {
      displayHistory.add(
        SalaryHistoryEntry(
          basicSalary: employee.basicSalary,
          workingHours: employee.workingHours > 0 ? employee.workingHours : 160.0,
          currency: employee.salaryCurrency.isNotEmpty ? employee.salaryCurrency : 'USD',
          startDate: employee.startDate.isNotEmpty ? employee.startDate : '2024-01-01',
          endDate: null,
          foodAllowance: employee.foodAllowance,
          transportationAllowance: employee.transportationAllowance,
          otherAllowance: employee.otherAllowance,
        ),
      );
    }

    showGlassDialog(
      context: context,
      title: provider.translate('payroll_history_title'),
      subtitle: employee.name,
      icon: Icons.monetization_on,
      content: SizedBox(
        width: double.maxFinite,
        child: displayHistory.isEmpty
            ? Text(
                provider.translate('no_payroll_history'),
                style: TextStyle(color: subtextColor),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: displayHistory.length,
                itemBuilder: (context, index) {
                  final entry = displayHistory[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${entry.basicSalary} ${entry.currency} | ${entry.workingHours} hrs',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${entry.startDate} - ${entry.endDate ?? provider.translate('present_label')}${entry.hasInsurance ? ' • ${provider.translate('social_insurance_title')}' : ''}',
                      style: TextStyle(
                        color: subtextColor,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.edit_outlined, color: isDark ? Colors.white70 : Colors.black54),
                      onPressed: () {
                        Navigator.pop(context);
                        _showPayrollEditDialog(employee, provider, entry);
                      },
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(provider.translate('close'), style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
        ),
        NeuButton(
          icon: const Icon(Icons.add_rounded, size: 18),
          label: provider.translate('add'),
          variant: NeuButtonVariant.primary,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          onPressed: () {
            Navigator.pop(context);
            _showPayrollEditDialog(employee, provider, null);
          },
        ),
      ],
    );
  }

  void _showPayrollEditDialog(
    CompanyEmployee employee,
    AttendanceProvider provider,
    SalaryHistoryEntry? existingEntry,
  ) {
    final isEditing = existingEntry != null;
    final salaryController = TextEditingController(
      text: isEditing
          ? existingEntry.basicSalary.toString()
          : employee.basicSalary.toString(),
    );
    final hoursController = TextEditingController(
      text: isEditing
          ? existingEntry.workingHours.toString()
          : employee.workingHours.toString(),
    );
    final foodAllowanceController = TextEditingController(
      text: isEditing
          ? existingEntry.foodAllowance.toString()
          : employee.foodAllowance.toString(),
    );
    final transportAllowanceController = TextEditingController(
      text: isEditing
          ? existingEntry.transportationAllowance.toString()
          : employee.transportationAllowance.toString(),
    );
    final otherAllowanceController = TextEditingController(
      text: isEditing
          ? existingEntry.otherAllowance.toString()
          : employee.otherAllowance.toString(),
    );
    bool hasInsurance = isEditing
        ? existingEntry.hasInsurance
        : employee.hasInsurance;
    final insuranceSalaryController = TextEditingController(
      text: (isEditing ? existingEntry.insuranceSalary : employee.insuranceSalary) > 0
          ? (isEditing ? existingEntry.insuranceSalary : employee.insuranceSalary).toString()
          : (salaryController.text.isNotEmpty && salaryController.text != '0' ? salaryController.text : ''),
    );
    String selectedCurrency = isEditing
        ? existingEntry.currency
        : (employee.salaryCurrency.isNotEmpty
              ? employee.salaryCurrency
              : 'USD');
    DateTime selectedStartDate = isEditing
        ? DateTime.parse(existingEntry.startDate)
        : DateTime.now();
    DateTime? selectedEndDate = isEditing && existingEntry.endDate != null
        ? DateTime.parse(existingEntry.endDate!)
        : null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final borderCol = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15);

    showGlassDialog(
      context: context,
      title: provider.translate(isEditing ? 'edit_payroll_config' : 'add_payroll_config'),
      subtitle: employee.name,
      icon: isEditing ? Icons.edit_note : Icons.add_circle_outline,
      content: StatefulBuilder(
        builder: (context, setState) {
          final double? currentSalary = double.tryParse(salaryController.text);
          final double? currentHours = double.tryParse(hoursController.text);

          double hourlyRate = 0.0;
          double dailyRate = 0.0;
          if (currentSalary != null &&
              currentHours != null &&
              currentHours > 0) {
            hourlyRate = currentSalary / currentHours;
            dailyRate = currentSalary / 30.0;
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: salaryController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(color: textColor),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: provider.translate('basic_salary'),
                        labelStyle: TextStyle(
                          color: subtextColor,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: borderCol,
                          ),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF2E65FF)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedCurrency,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: provider.translate('currency'),
                        labelStyle: TextStyle(
                          color: subtextColor,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: borderCol,
                          ),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF2E65FF)),
                        ),
                      ),
                      items: ['USD', 'IQD']
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedCurrency = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hoursController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(color: textColor),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: provider.translate('working_hours_month'),
                  labelStyle: TextStyle(
                    color: subtextColor,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: borderCol,
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF2E65FF)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: foodAllowanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: provider.translate('food_allowance'),
                  labelStyle: TextStyle(
                    color: subtextColor,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: borderCol,
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF2E65FF)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: transportAllowanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: provider.translate('transportation_allowance'),
                  labelStyle: TextStyle(
                    color: subtextColor,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: borderCol,
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF2E65FF)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: otherAllowanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: provider.translate('other_allowance'),
                  labelStyle: TextStyle(
                    color: subtextColor,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: borderCol,
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF2E65FF)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasInsurance
                        ? const Color(0xFF2E65FF).withValues(alpha: 0.4)
                        : borderCol,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 18,
                              color: hasInsurance ? const Color(0xFF2E65FF) : subtextColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              provider.translate('social_insurance_title'),
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: hasInsurance,
                          activeThumbColor: const Color(0xFF2E65FF),
                          onChanged: (val) {
                            setState(() {
                              hasInsurance = val;
                              if (val && insuranceSalaryController.text.trim().isEmpty) {
                                insuranceSalaryController.text = salaryController.text;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    if (hasInsurance) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: insuranceSalaryController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: textColor),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: '${provider.translate('insurance_salary_label')} ($selectedCurrency)',
                          labelStyle: TextStyle(color: subtextColor),
                          helperText: provider.translate('optional_insurance_hint'),
                          helperStyle: TextStyle(color: subtextColor, fontSize: 10),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: borderCol),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF2E65FF)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Builder(
                        builder: (context) {
                          final insSal = double.tryParse(insuranceSalaryController.text) ?? (double.tryParse(salaryController.text) ?? 0.0);
                          final ins5 = insSal * 0.05;
                          final ins12 = insSal * 0.12;
                          return Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF5C5C).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFF5C5C).withValues(alpha: 0.25)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        provider.translate('ins_5_short'),
                                        style: const TextStyle(color: Color(0xFFFF5C5C), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '-${NumberFormat('#,##0').format(ins5)} $selectedCurrency',
                                        style: const TextStyle(color: Color(0xFFFF5C5C), fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        provider.translate('insurance_5_desc'),
                                        style: TextStyle(color: subtextColor, fontSize: 9.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E5CE).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF00E5CE).withValues(alpha: 0.25)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        provider.translate('ins_12_short'),
                                        style: const TextStyle(color: Color(0xFF00E5CE), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${NumberFormat('#,##0').format(ins12)} $selectedCurrency',
                                        style: const TextStyle(color: Color(0xFF00E5CE), fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        provider.translate('insurance_12_desc'),
                                        style: TextStyle(color: subtextColor, fontSize: 9.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: selectedStartDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) {
                    setState(() => selectedStartDate = d);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: borderCol,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: subtextColor,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${provider.translate('start_date_label')}: ${DateFormat('yyyy-MM-dd').format(selectedStartDate)}',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: selectedEndDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) {
                    setState(() => selectedEndDate = d);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: borderCol,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_busy,
                        color: subtextColor,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedEndDate != null
                              ? '${provider.translate('end_date_optional_label')}: ${DateFormat('yyyy-MM-dd').format(selectedEndDate!)}'
                              : '${provider.translate('end_date_optional_label')}: ${provider.translate('present_label')}',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (selectedEndDate != null)
                        IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => selectedEndDate = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.translate('calculated_duration'),
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${provider.translate('hourly_rate')}: ${hourlyRate.toStringAsFixed(2)} $selectedCurrency/hr',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${provider.translate('daily_rate')}: ${dailyRate.toStringAsFixed(2)} $selectedCurrency/day',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isEditing)
                    TextButton(
                      onPressed: () {
                        List<SalaryHistoryEntry> newHistory = List.from(
                          employee.salaryHistory,
                        );
                        newHistory.removeWhere(
                          (e) =>
                              e.startDate == existingEntry.startDate &&
                              e.basicSalary == existingEntry.basicSalary,
                        );

                         final lastEntry = newHistory.isNotEmpty ? newHistory.last : null;
                        final updatedEmployee = employee.copyWith(
                          basicSalary: lastEntry?.basicSalary ?? 0.0,
                          workingHours: lastEntry?.workingHours ?? 0.0,
                          salaryCurrency: lastEntry?.currency ?? employee.salaryCurrency,
                          foodAllowance: lastEntry?.foodAllowance ?? 0.0,
                          transportationAllowance: lastEntry?.transportationAllowance ?? 0.0,
                          otherAllowance: lastEntry?.otherAllowance ?? 0.0,
                          hasInsurance: lastEntry?.hasInsurance ?? false,
                          insuranceSalary: lastEntry?.insuranceSalary ?? 0.0,
                          salaryHistory: newHistory,
                        );
                        provider.updateEmployee(updatedEmployee);
                        Navigator.pop(context);
                        _showPayrollHistoryDialog(updatedEmployee, provider);
                      },
                      child: Text(
                        provider.translate('delete'),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showPayrollHistoryDialog(employee, provider);
                    },
                    child: Text(
                      provider.translate('cancel'),
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                  NeuButton(
                    label: provider.translate(isEditing ? 'save' : 'add'),
                    variant: NeuButtonVariant.primary,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    onPressed: () {
                      final double? newSalary = double.tryParse(
                        salaryController.text,
                      );
                      final double? newHours = double.tryParse(
                        hoursController.text,
                      );
                      final double? newFoodAllowance = double.tryParse(
                        foodAllowanceController.text,
                      );
                      final double? newTransportAllowance = double.tryParse(
                        transportAllowanceController.text,
                      );
                      final double? newOtherAllowance = double.tryParse(
                        otherAllowanceController.text,
                      );
                      final double? newInsuranceSalary = double.tryParse(
                        insuranceSalaryController.text,
                      );
                      final double finalInsSalary = hasInsurance
                          ? (newInsuranceSalary != null && newInsuranceSalary > 0
                              ? newInsuranceSalary
                              : (newSalary ?? 0.0))
                          : 0.0;

                      if (newSalary != null && newHours != null) {
                        List<SalaryHistoryEntry> newHistory = List.from(
                          employee.salaryHistory,
                        );

                        if (isEditing) {
                          newHistory.removeWhere(
                            (e) =>
                                e.startDate == existingEntry.startDate &&
                                e.basicSalary == existingEntry.basicSalary,
                          );
                        }

                        newHistory.add(
                          SalaryHistoryEntry(
                            basicSalary: newSalary,
                            workingHours: newHours,
                            currency: selectedCurrency,
                            startDate: DateFormat(
                              'yyyy-MM-dd',
                            ).format(selectedStartDate),
                            endDate: selectedEndDate != null
                                ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(selectedEndDate!)
                                : null,
                            foodAllowance: newFoodAllowance ?? 0.0,
                            transportationAllowance:
                                newTransportAllowance ?? 0.0,
                            otherAllowance: newOtherAllowance ?? 0.0,
                            hasInsurance: hasInsurance,
                            insuranceSalary: finalInsSalary,
                          ),
                        );

                        newHistory.sort(
                          (a, b) => a.startDate.compareTo(b.startDate),
                        );

                        final lastEntry = newHistory.isNotEmpty
                            ? newHistory.last
                            : null;
                        final updatedEmployee = employee.copyWith(
                          basicSalary:
                              lastEntry?.basicSalary ?? employee.basicSalary,
                          workingHours:
                              lastEntry?.workingHours ?? employee.workingHours,
                          salaryCurrency:
                              lastEntry?.currency ?? employee.salaryCurrency,
                          salaryHistory: newHistory,
                          foodAllowance:
                              lastEntry?.foodAllowance ??
                              employee.foodAllowance,
                          transportationAllowance:
                              lastEntry?.transportationAllowance ??
                              employee.transportationAllowance,
                          otherAllowance:
                              lastEntry?.otherAllowance ??
                              employee.otherAllowance,
                          hasInsurance:
                              lastEntry?.hasInsurance ?? hasInsurance,
                          insuranceSalary:
                              lastEntry?.insuranceSalary ?? finalInsSalary,
                        );

                        provider.updateEmployee(updatedEmployee);
                        Navigator.pop(context);
                        _showPayrollHistoryDialog(updatedEmployee, provider);
                      }
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
