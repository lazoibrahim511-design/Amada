import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../providers/attendance_provider.dart';
import '../../models/hr_models.dart';
import '../glass_container.dart';
import '../glass_dialog.dart';
import '../neu_button.dart';
import '../compact_date_picker_dialog.dart';
import '../avatar_image_helper.dart';
import '../../screens/face_auth_screen.dart';

class HrEmployeesTab extends StatefulWidget {
  final String searchQuery;
  final Function(CompanyEmployee employee)? onEdit;
  final Function(String id)? onDelete;

  const HrEmployeesTab({
    super.key,
    required this.searchQuery,
    this.onEdit,
    this.onDelete,
  });

  static void showEmployeeFormDialog({
    required BuildContext context,
    required AttendanceProvider provider,
    CompanyEmployee? employee,
  }) {
    _HrEmployeesTabState._showUserFormDialog(
      context: context,
      provider: provider,
      employee: employee,
    );
  }

  static void showLicenseLimitDialog(BuildContext context, AttendanceProvider provider) {
    _HrEmployeesTabState._showLicenseLimitDialog(context, provider);
  }

  @override
  State<HrEmployeesTab> createState() => _HrEmployeesTabState();
}

class _HrEmployeesTabState extends State<HrEmployeesTab> {
  String _selectedRoleFilter = 'all';
  String _selectedStatusFilter = 'all';
  String _selectedStructureFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allEmployees = provider.employees;

    // Filter employees based on search query and selected dropdown filters
    final filteredEmployees = allEmployees.where((emp) {
      // 1. Search Query Filter
      final query = widget.searchQuery.trim().toLowerCase();
      final matchesQuery = query.isEmpty ||
          emp.name.toLowerCase().contains(query) ||
          emp.email.toLowerCase().contains(query) ||
          emp.position.toLowerCase().contains(query) ||
          emp.id.toLowerCase().contains(query);

      // 2. Role Filter
      final matchesRole = _selectedRoleFilter == 'all' ||
          emp.role.toLowerCase() == _selectedRoleFilter.toLowerCase();

      // 3. Status Filter
      final matchesStatus = _selectedStatusFilter == 'all' ||
          (_selectedStatusFilter == 'active' && !emp.disabled) ||
          (_selectedStatusFilter == 'disabled' && emp.disabled);

      // 4. Structure Filter
      final matchesStructure = _selectedStructureFilter == 'all' ||
          emp.structureId == _selectedStructureFilter;

      return matchesQuery && matchesRole && matchesStatus && matchesStructure;
    }).toList();

    // System KPI Stats
    final totalCount = allEmployees.length;
    final activeCount = allEmployees.where((e) => !e.disabled).length;
    final hrCount = allEmployees.where((e) => e.role == 'hr' || e.role == 'admin').length;
    final supervisorCount = allEmployees.where((e) => e.role == 'supervisor').length;
    final faceVerifiedCount = allEmployees.where((e) => e.faceEmbedding != null).length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Summary KPI Cards Bar
          _buildUserSummaryKPI(
            context: context,
            provider: provider,
            isDark: isDark,
            total: totalCount,
            active: activeCount,
            hrAdmins: hrCount,
            supervisors: supervisorCount,
            faceVerified: faceVerifiedCount,
          ),
          const SizedBox(height: 16),

          // 2. Filter & Action Toolbar
          _buildFilterToolbar(context, provider, isDark),
          const SizedBox(height: 16),

          // 3. User Cards Grid or Empty State
          if (filteredEmployees.isEmpty)
            _buildEmptyState(context, isDark)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 768;
                if (isMobile) {
                  return _buildMobileEmployeesList(context, filteredEmployees, provider, isDark);
                }
                return _buildEmployeesTable(context, filteredEmployees, provider, isDark);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildUserSummaryKPI({
    required BuildContext context,
    required AttendanceProvider provider,
    required bool isDark,
    required int total,
    required int active,
    required int hrAdmins,
    required int supervisors,
    required int faceVerified,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final chips = [
          _buildKpiChip(
            context: context,
            label: provider.translate('total_users'),
            value: '$total',
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF2E65FF),
            isDark: isDark,
            width: isMobile ? 140 : 160,
          ),
          _buildKpiChip(
            context: context,
            label: provider.translate('active_users_quota_stat'),
            value: provider.maxActiveUsers > 0 ? '$active / ${provider.maxActiveUsers}' : '$active',
            icon: active >= provider.maxActiveUsers ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
            color: active >= provider.maxActiveUsers ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
            isDark: isDark,
            width: isMobile ? 140 : 160,
          ),
          _buildKpiChip(
            context: context,
            label: provider.translate('hr_admins_stat'),
            value: '$hrAdmins',
            icon: Icons.admin_panel_settings_rounded,
            color: const Color(0xFF8B5CF6),
            isDark: isDark,
            width: isMobile ? 140 : 160,
          ),
          _buildKpiChip(
            context: context,
            label: provider.translate('supervisors_stat'),
            value: '$supervisors',
            icon: Icons.supervisor_account_rounded,
            color: const Color(0xFFF59E0B),
            isDark: isDark,
            width: isMobile ? 140 : 160,
          ),
          _buildKpiChip(
            context: context,
            label: provider.translate('face_verified_stat'),
            value: '$faceVerified',
            icon: Icons.face_retouching_natural,
            color: const Color(0xFF06B6D4),
            isDark: isDark,
            width: isMobile ? 140 : 160,
          ),
        ];

        if (isMobile) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (int i = 0; i < chips.length; i++) ...[
                  chips[i],
                  if (i < chips.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: chips,
        );
      },
    );
  }

  Widget _buildKpiChip({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
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

  Widget _buildFilterToolbar(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        
        if (isMobile) {
          // Mobile Filter Chips / Dropdowns Scrollable Row
          return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildDropdownFilter(
                      context: context,
                      isDark: isDark,
                      value: _selectedRoleFilter,
                      items: [
                        DropdownMenuItem(value: 'all', child: Text(provider.translate('all_roles'))),
                        DropdownMenuItem(value: 'hr', child: Text(provider.translate('hr_admin_role'))),
                        DropdownMenuItem(value: 'supervisor', child: Text(provider.translate('supervisor_role'))),
                        DropdownMenuItem(value: 'employee', child: Text(provider.translate('employee_role'))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRoleFilter = val);
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildDropdownFilter(
                      context: context,
                      isDark: isDark,
                      value: _selectedStatusFilter,
                      items: [
                        DropdownMenuItem(value: 'all', child: Text(provider.translate('all_status'))),
                        DropdownMenuItem(value: 'active', child: Text(provider.translate('active_only'))),
                        DropdownMenuItem(value: 'disabled', child: Text(provider.translate('suspended_status'))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatusFilter = val);
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildDropdownFilter(
                      context: context,
                      isDark: isDark,
                      value: _selectedStructureFilter,
                      items: [
                        DropdownMenuItem(value: 'all', child: Text(provider.translate('all_structures'))),
                        ...provider.structures.map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStructureFilter = val);
                      },
                    ),
                  ],
                ),
              );
        }

        // Desktop layout
        return Row(
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildDropdownFilter(
                  context: context,
                  isDark: isDark,
                  value: _selectedRoleFilter,
                  items: [
                    DropdownMenuItem(value: 'all', child: Text(provider.translate('all_roles'))),
                    DropdownMenuItem(value: 'hr', child: Text(provider.translate('hr_admin_role'))),
                    DropdownMenuItem(value: 'supervisor', child: Text(provider.translate('supervisor_role'))),
                    DropdownMenuItem(value: 'employee', child: Text(provider.translate('employee_role'))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRoleFilter = val);
                  },
                ),
                _buildDropdownFilter(
                  context: context,
                  isDark: isDark,
                  value: _selectedStatusFilter,
                  items: [
                    DropdownMenuItem(value: 'all', child: Text(provider.translate('all_status'))),
                    DropdownMenuItem(value: 'active', child: Text(provider.translate('active_only'))),
                    DropdownMenuItem(value: 'disabled', child: Text(provider.translate('suspended_status'))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatusFilter = val);
                  },
                ),
                _buildDropdownFilter(
                  context: context,
                  isDark: isDark,
                  value: _selectedStructureFilter,
                  items: [
                    DropdownMenuItem(value: 'all', child: Text(provider.translate('all_structures'))),
                    ...provider.structures.map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStructureFilter = val);
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDropdownFilter({
    required BuildContext context,
    required bool isDark,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final isFiltered = value != 'all';

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFiltered
              ? const Color(0xFF2E65FF)
              : (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1)),
          width: isFiltered ? 1.5 : 1.0,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.any((item) => item.value == value)
              ? value
              : (items.isNotEmpty ? items.first.value! : value),
          items: items,
          onChanged: onChanged,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          icon: Icon(
            Icons.arrow_drop_down,
            color: isFiltered
                ? const Color(0xFF2E65FF)
                : (isDark ? Colors.white60 : Colors.black54),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileEmployeesList(
    BuildContext context,
    List<CompanyEmployee> employees,
    AttendanceProvider provider,
    bool isDark,
  ) {
    if (employees.isEmpty) {
      return _buildEmptyState(context, isDark);
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: employees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final employee = employees[index];
        return _buildMobileEmployeeCard(context, employee, provider, isDark);
      },
    );
  }

  Widget _buildMobileEmployeeCard(
    BuildContext context,
    CompanyEmployee employee,
    AttendanceProvider provider,
    bool isDark,
  ) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final isSuspended = employee.disabled;
    final hasFaceId = employee.faceEmbedding != null && employee.faceEmbedding!.isNotEmpty;

    final role = employee.role.toLowerCase().trim();
    final roleColor = role == 'hr' || role == 'admin'
        ? const Color(0xFF8B5CF6)
        : role == 'supervisor'
            ? const Color(0xFF2E65FF)
            : const Color(0xFF10B981);

    final structure = provider.structures.firstWhere(
      (s) => s.id == employee.structureId,
      orElse: () => OrgStructure(id: '', name: 'Unassigned', location: '', capacity: 0),
    );

    final group = provider.groups.firstWhere(
      (g) => g.id == employee.groupId,
      orElse: () => EmployeeGroup(id: '', name: 'Unassigned', shiftId: ''),
    );

    final avatarProvider = getAvatarProvider(employee.avatarUrl);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSuspended ? Colors.redAccent.withValues(alpha: 0.3) : borderColor,
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showUserDetailsDialog(context, employee, provider, isDark),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar + Name + ID + More Actions Menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: roleColor.withValues(alpha: 0.15),
                          backgroundImage: avatarProvider,
                          child: avatarProvider == null
                              ? Text(
                                  employee.name.trim().isNotEmpty
                                      ? employee.name.trim()[0].toUpperCase()
                                      : 'E',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: roleColor,
                                  ),
                                )
                              : null,
                        ),
                        if (isSuspended)
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, size: 10, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  employee.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E65FF).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'ID: ${employee.id}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E65FF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            employee.position.isNotEmpty ? employee.position : 'Team Member',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: subtextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (employee.email.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              employee.email,
                              style: TextStyle(
                                fontSize: 11,
                                color: subtextColor.withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: subtextColor,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      elevation: 8,
                      onSelected: (value) {
                        if (value == 'view') {
                          _showUserDetailsDialog(context, employee, provider, isDark);
                        } else if (value == 'edit') {
                          _showUserFormDialog(context: context, provider: provider, employee: employee);
                        } else if (value == 'face') {
                          _showFaceIdManageDialog(context, employee, provider);
                        } else if (value == 'toggle_status') {
                          final updated = employee.copyWith(disabled: !employee.disabled);
                          provider.updateEmployee(updated);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                employee.disabled
                                    ? '${employee.name}\'s account activated.'
                                    : '${employee.name}\'s account suspended.',
                              ),
                            ),
                          );
                        } else if (value == 'delete') {
                          _showDeleteConfirm(context, employee, provider);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('View Full Details', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('Edit User', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'face',
                          child: Row(
                            children: [
                              Icon(
                                hasFaceId ? Icons.face_retouching_natural : Icons.face_outlined,
                                size: 18,
                                color: hasFaceId ? const Color(0xFF10B981) : null,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                hasFaceId ? 'Manage Face ID' : 'Register Face ID',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggle_status',
                          child: Row(
                            children: [
                              Icon(
                                isSuspended ? Icons.check_circle_outline : Icons.block_outlined,
                                size: 18,
                                color: isSuspended ? const Color(0xFF10B981) : Colors.orangeAccent,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isSuspended ? 'Activate User' : 'Suspend User',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isSuspended ? const Color(0xFF10B981) : Colors.orangeAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                              SizedBox(width: 10),
                              Text('Delete User', style: TextStyle(fontSize: 13, color: Color(0xFFEF4444))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Middle Row: Department, Group & Info Badges
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        employee.role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: roleColor,
                        ),
                      ),
                    ),

                    // Department Badge
                    if (structure.name != 'Unassigned')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.business_rounded, size: 12, color: subtextColor),
                            const SizedBox(width: 4),
                            Text(
                              structure.name,
                              style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),

                    // Group Badge
                    if (group.name != 'Unassigned')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 12, color: subtextColor),
                            const SizedBox(width: 4),
                            Text(
                              group.name,
                              style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),

                    // Suspended Status Badge
                    if (isSuspended)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'SUSPENDED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),


                  ],
                ),
                const SizedBox(height: 12),

                // Bottom Action Bar: Quick Face ID status + Quick Action Buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Face ID indicator button
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _showFaceIdManageDialog(context, employee, provider),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hasFaceId ? Icons.face_retouching_natural : Icons.face_outlined,
                                size: 16,
                                color: hasFaceId ? const Color(0xFF10B981) : Colors.grey,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                hasFaceId ? provider.translate('face_id_active') : provider.translate('no_face_id'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: hasFaceId ? FontWeight.w600 : FontWeight.normal,
                                  color: hasFaceId ? const Color(0xFF10B981) : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Quick Action Buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            tooltip: 'Edit',
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                            onPressed: () {
                              _showUserFormDialog(context: context, provider: provider, employee: employee);
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 18),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            tooltip: 'Details',
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                            onPressed: () => _showUserDetailsDialog(context, employee, provider, isDark),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeesTable(
    BuildContext context,
    List<CompanyEmployee> employees,
    AttendanceProvider provider,
    bool isDark,
  ) {
    if (employees.isEmpty) {
      return _buildEmptyState(context, isDark);
    }

    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final dividerColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    return GlassContainer(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Theme(
                  data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
                    dividerColor: dividerColor,
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFF1F5F9),
                    ),
                    headingRowHeight: 46,
                    dataRowMaxHeight: 62,
                    dataRowMinHeight: 52,
                    columnSpacing: 24,
                    horizontalMargin: 20,
                    columns: [
                      DataColumn(
                        label: Text(
                          provider.translate('col_employee'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textColor,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          provider.translate('col_job_details'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textColor,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          provider.translate('col_role_access'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textColor,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          provider.translate('col_actions'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                    rows: employees.map((employee) {
                      final structure = provider.structures.firstWhere(
                        (s) => s.id == employee.structureId,
                        orElse: () => OrgStructure(id: '', name: 'Unassigned', location: '', capacity: 0),
                      );

                      final isUserDisabled = employee.disabled;
                      final roleColor = employee.role == 'hr' || employee.role == 'admin'
                          ? const Color(0xFF8B5CF6)
                          : employee.role == 'supervisor'
                              ? const Color(0xFF2E65FF)
                              : const Color(0xFF10B981);

                      return DataRow(
                        color: WidgetStateProperty.all(isUserDisabled ? Colors.red.withValues(alpha: 0.05) : Colors.transparent),
                        cells: [
                          // Employee Info
                          DataCell(
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: roleColor.withValues(alpha: 0.15),
                                  child: Text(
                                    employee.name.isNotEmpty ? employee.name[0].toUpperCase() : 'U',
                                    style: TextStyle(
                                      color: roleColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          employee.name,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2E65FF).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFF2E65FF).withValues(alpha: 0.35),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            'ID: ${employee.id}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2E65FF),
                                            ),
                                          ),
                                        ),
                                        if (isUserDisabled)
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'SUSPENDED',
                                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Text(
                                      employee.email,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Job Details
                          DataCell(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  employee.position.isNotEmpty ? employee.position : 'Team Member',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'Dept: ${structure.name}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25), width: 0.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.beach_access_rounded, size: 10, color: Color(0xFF10B981)),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${employee.annualLeaveBalance.toStringAsFixed(1)}h',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF10B981),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Role & Access
                          DataCell(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: roleColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    employee.role.toUpperCase(),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  borderRadius: BorderRadius.circular(4),
                                  onTap: () => _showFaceIdManageDialog(context, employee, provider),
                                  child: Row(
                                    children: [
                                      Icon(
                                        employee.faceEmbedding != null ? Icons.face_retouching_natural : Icons.face_outlined,
                                        size: 13,
                                        color: employee.faceEmbedding != null ? const Color(0xFF10B981) : Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        employee.faceEmbedding != null ? 'Face Verified' : 'No Face ID',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: employee.faceEmbedding != null ? FontWeight.w600 : FontWeight.normal,
                                          color: employee.faceEmbedding != null ? const Color(0xFF10B981) : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Actions
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: employee.faceEmbedding != null ? 'Manage Face ID (Enrolled)' : 'Enroll Face ID',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => _showFaceIdManageDialog(context, employee, provider),
                                    child: Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: Icon(
                                        employee.faceEmbedding != null ? Icons.face_retouching_natural : Icons.face_outlined,
                                        size: 18,
                                        color: employee.faceEmbedding != null ? const Color(0xFF10B981) : (isDark ? Colors.white70 : Colors.black54),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'View Profile',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => _showUserDetailsDialog(context, employee, provider, isDark),
                                    child: Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: Icon(Icons.visibility_outlined, size: 18, color: isDark ? Colors.white70 : Colors.black54),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'Edit User',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () {
                                      _showUserFormDialog(context: context, provider: provider, employee: employee);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: Icon(Icons.edit_outlined, size: 18, color: isDark ? Colors.white70 : Colors.black54),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: employee.disabled ? 'Activate User' : 'Suspend User',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () {
                                      final updated = employee.copyWith(disabled: !employee.disabled);
                                      provider.updateEmployee(updated);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            employee.disabled
                                                ? '${employee.name}\'s account activated.'
                                                : '${employee.name}\'s account suspended.',
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: Icon(
                                        employee.disabled ? Icons.check_circle_outline : Icons.block_outlined,
                                        size: 18,
                                        color: employee.disabled ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'Delete User',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () {
                                      _showDeleteConfirm(context, employee, provider);
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(5),
                                      child: Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Matching System Users',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search query or role/status filters.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  static bool _isPdfDocument(String source) {
    final clean = source.trim();
    if (clean.toLowerCase().endsWith('.pdf')) return true;
    if (clean.startsWith('data:application/pdf')) return true;
    if (clean.contains('application/pdf')) return true;
    try {
      String base64Str = clean;
      if (base64Str.contains(',')) {
        base64Str = base64Str.split(',').last;
      }
      base64Str = base64Str.replaceAll(RegExp(r'\s+'), '');
      if (base64Str.length > 8) {
        final decodedHeader = utf8.decode(base64Decode(base64Str.substring(0, 8)), allowMalformed: true);
        if (decodedHeader.startsWith('%PDF')) return true;
      }
    } catch (_) {}
    return false;
  }

  static Uint8List? _getDocumentBytes(String source) {
    try {
      String base64Str = source.trim();
      if (base64Str.contains(',')) {
        base64Str = base64Str.split(',').last;
      }
      base64Str = base64Str.replaceAll(RegExp(r'\s+'), '');
      return base64Decode(base64Str);
    } catch (e) {
      debugPrint('Error decoding document bytes: $e');
      return null;
    }
  }

  static Future<void> _downloadDocumentFile(BuildContext context, String title, String source) async {
    try {
      final isPdf = _isPdfDocument(source);
      final bytes = _getDocumentBytes(source);
      if (bytes == null || bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to read file data for download.'), backgroundColor: Colors.redAccent),
        );
        return;
      }

      final cleanTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final fileName = '${cleanTitle}_${DateTime.now().millisecondsSinceEpoch}';

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: isPdf ? 'pdf' : 'jpg',
        mimeType: isPdf ? MimeType.pdf : MimeType.jpeg,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('$title downloaded successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving file: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download document: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  static void _showDocumentPreviewDialog(BuildContext context, String title, String documentSource) {
    final isPdf = _isPdfDocument(documentSource);
    final docBytes = _getDocumentBytes(documentSource);
    final imageProvider = !isPdf ? getAvatarProvider(documentSource) : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        bool isFullScreen = false;
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: isFullScreen ? EdgeInsets.zero : const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isFullScreen ? 0 : 20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: isFullScreen ? screenWidth : 780,
                  height: isFullScreen ? screenHeight : 820,
                  constraints: BoxConstraints(
                    maxWidth: isFullScreen ? screenWidth : screenWidth * 0.94,
                    maxHeight: isFullScreen ? screenHeight : screenHeight * 0.92,
                  ),
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                          border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                              color: isPdf ? Colors.redAccent : const Color(0xFF2E65FF),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    isPdf ? 'PDF Document Viewer' : 'Image File',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                                size: 22,
                              ),
                              tooltip: isFullScreen ? 'Exit Full Screen' : 'Full Screen',
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              onPressed: () {
                                setModalState(() {
                                  isFullScreen = !isFullScreen;
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              onPressed: () => Navigator.pop(dialogCtx),
                            ),
                          ],
                        ),
                      ),

                      // Content Body
                      Expanded(
                        child: Container(
                          color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                          child: isPdf
                              ? (docBytes != null && docBytes.isNotEmpty
                                  ? ClipRRect(
                                      child: SfPdfViewer.memory(
                                        docBytes,
                                        enableDoubleTapZooming: true,
                                        canShowScrollHead: true,
                                        canShowScrollStatus: true,
                                        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                                          debugPrint('SfPdfViewer load failed: ${details.error} - ${details.description}');
                                        },
                                      ),
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Unable to decode PDF content',
                                            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                                          ),
                                        ],
                                      ),
                                    ))
                              : InteractiveViewer(
                                  minScale: 0.5,
                                  maxScale: 4.0,
                                  child: imageProvider != null
                                      ? Image(image: imageProvider, fit: BoxFit.contain)
                                      : const Center(
                                          child: Text('Unable to display file preview', style: TextStyle(color: Colors.white70)),
                                        ),
                                ),
                        ),
                      ),

                      // Footer Actions
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                          border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              docBytes != null ? '${(docBytes.lengthInBytes / 1024).toStringAsFixed(1)} KB' : '',
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                            ),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _downloadDocumentFile(context, title, documentSource),
                                  icon: const Icon(Icons.download_rounded, size: 16),
                                  label: const Text('Download File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  child: Text('Close', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B))),
                                ),
                              ],
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

  void _showUserDetailsDialog(
    BuildContext context,
    CompanyEmployee employee,
    AttendanceProvider provider,
    bool isDark,
  ) {
    int activeTab = 0;
    final primaryColor = const Color(0xFF2E65FF);
    final tabBg = isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF1F5F9);
    final tabActiveBg = primaryColor.withValues(alpha: 0.18);

    showGlassDialog(
      context: context,
      title: employee.name,
      subtitle: 'Employee Profile & Records',
      icon: Icons.person,
      content: StatefulBuilder(
        builder: (ctx, setDetailsState) {
          return SizedBox(
            width: double.maxFinite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Segmented Tabs
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: tabBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => setDetailsState(() => activeTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: activeTab == 0 ? tabActiveBg : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.badge_outlined,
                                  size: 15,
                                  color: activeTab == 0 ? primaryColor : (isDark ? Colors.white60 : Colors.black54),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'General Info',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: activeTab == 0 ? FontWeight.bold : FontWeight.normal,
                                    color: activeTab == 0 ? primaryColor : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => setDetailsState(() => activeTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: activeTab == 1 ? tabActiveBg : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.work_outline_rounded,
                                  size: 15,
                                  color: activeTab == 1 ? primaryColor : (isDark ? Colors.white60 : Colors.black54),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'System Info',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: activeTab == 1 ? FontWeight.bold : FontWeight.normal,
                                    color: activeTab == 1 ? primaryColor : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => setDetailsState(() => activeTab = 2),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: activeTab == 2 ? tabActiveBg : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.folder_shared_outlined,
                                  size: 15,
                                  color: activeTab == 2 ? primaryColor : (isDark ? Colors.white60 : Colors.black54),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Documents',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: activeTab == 2 ? FontWeight.bold : FontWeight.normal,
                                    color: activeTab == 2 ? primaryColor : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Content for selected tab
                if (activeTab == 0) ...[
                  // General Info Tab
                  _buildDetailRow('Full Name', employee.name, isDark),
                  _buildDetailRow('Date of Birth', employee.dateOfBirth?.isNotEmpty == true ? employee.dateOfBirth! : 'N/A', isDark),
                  _buildDetailRow('Gender', employee.gender?.isNotEmpty == true ? employee.gender! : 'N/A', isDark),
                  _buildDetailRow('Marital Status', employee.maritalStatus?.isNotEmpty == true ? employee.maritalStatus! : 'N/A', isDark),
                  _buildDetailRow('Phone No', employee.phoneNumber.isNotEmpty ? employee.phoneNumber : 'N/A', isDark),
                  _buildDetailRow('Nationality', employee.nationality?.isNotEmpty == true ? employee.nationality! : 'N/A', isDark),
                  _buildDetailRow('Blood Group', employee.bloodGroup?.isNotEmpty == true ? employee.bloodGroup! : 'N/A', isDark),
                  _buildDetailRow('Address', employee.address?.isNotEmpty == true ? employee.address! : 'N/A', isDark),
                  const Divider(height: 16),
                  _buildDetailRow('Emergency Contact', employee.emergencyContact?.isNotEmpty == true ? employee.emergencyContact! : 'N/A', isDark),
                  _buildDetailRow('Emergency Phone', employee.emergencyPhone?.isNotEmpty == true ? employee.emergencyPhone! : 'N/A', isDark),
                ] else if (activeTab == 1) ...[
                  // Employment & System Tab
                  _buildDetailRow('User ID', employee.id, isDark),
                  _buildDetailRow('Email', employee.email, isDark),
                  _buildDetailRow('Role', employee.role.toUpperCase(), isDark),
                  _buildDetailRow('Position', employee.position, isDark),
                  _buildDetailRow('Hire Date', employee.startDate.isNotEmpty ? employee.startDate : 'N/A', isDark),
                  _buildDetailRow('Annual Leave Balance', '${employee.annualLeaveBalance} hours', isDark),
                  _buildDetailRow('Account Status', employee.disabled ? 'SUSPENDED' : 'ACTIVE', isDark),

                  _buildDetailRow(
                    'Face ID Biometrics',
                    employee.faceEmbedding != null ? 'ENROLLED & VERIFIED' : 'NOT ENROLLED',
                    isDark,
                    valueColor: employee.faceEmbedding != null ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ] else ...[
                  // Documents Info Tab
                  _buildDetailRow('National Card No', employee.nationalCardNo?.isNotEmpty == true ? employee.nationalCardNo! : 'N/A', isDark),
                  _buildDetailRow('Passport No', employee.passportNo?.isNotEmpty == true ? employee.passportNo! : 'N/A', isDark),
                  _buildDetailRow('Passport Expire Date', employee.passportExpiryDate?.isNotEmpty == true ? employee.passportExpiryDate! : 'N/A', isDark),
                  _buildDetailRow('Residence Card No', employee.residenceCardNo?.isNotEmpty == true ? employee.residenceCardNo! : 'N/A', isDark),
                  _buildDetailRow('Residence Card Expire Date', employee.residenceCardExpiryDate?.isNotEmpty == true ? employee.residenceCardExpiryDate! : 'N/A', isDark),
                  const SizedBox(height: 12),
                  Text(
                    'Document Attachments',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDocAttachmentCard(
                          context,
                          'National Card',
                          employee.nationalCardAttachment,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDocAttachmentCard(
                          context,
                          'Passport',
                          employee.passportAttachment,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDocAttachmentCard(
                          context,
                          'Residence Card',
                          employee.residenceCardAttachment,
                          isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _showFaceIdManageDialog(context, employee, provider);
          },
          icon: Icon(
            employee.faceEmbedding != null ? Icons.face_retouching_natural : Icons.face_outlined,
            size: 16,
            color: const Color(0xFF00E5CE),
          ),
          label: Text(
            employee.faceEmbedding != null ? 'Manage Face ID' : 'Enroll Face ID',
            style: const TextStyle(color: Color(0xFF00E5CE), fontWeight: FontWeight.bold),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B))),
        ),
      ],
    );
  }

  Widget _buildDocAttachmentCard(BuildContext context, String title, String? attachment, bool isDark) {
    final hasAttachment = attachment != null && attachment.trim().isNotEmpty;
    final isPdf = hasAttachment ? _isPdfDocument(attachment) : false;
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: hasAttachment ? () => _showDocumentPreviewDialog(context, title, attachment) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasAttachment
                ? (isPdf ? Colors.redAccent.withValues(alpha: 0.5) : const Color(0xFF2E65FF).withValues(alpha: 0.4))
                : borderColor,
          ),
        ),
        child: Column(
          children: [
            Icon(
              hasAttachment
                  ? (isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded)
                  : Icons.insert_drive_file_outlined,
              size: 26,
              color: hasAttachment
                  ? (isPdf ? Colors.redAccent : const Color(0xFF2E65FF))
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hasAttachment ? (isPdf ? 'PDF File' : 'View File') : 'No File',
              style: TextStyle(
                fontSize: 9.5,
                color: hasAttachment
                    ? (isPdf ? Colors.redAccent : const Color(0xFF10B981))
                    : (isDark ? Colors.white38 : Colors.black38),
                fontWeight: hasAttachment ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {Color? valueColor}) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: subtextColor,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: valueColor ?? textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _showUserFormDialog({
    required BuildContext context,
    required AttendanceProvider provider,
    CompanyEmployee? employee,
  }) {
    final isEditing = employee != null;
    final targetCompany = (employee != null && employee.companyCode.isNotEmpty)
        ? employee.companyCode
        : (provider.currentCompanyCode == 'all' ? '' : provider.currentCompanyCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final labelColor = isDark ? Colors.white70 : const Color(0xFF475569);
    final hintColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);
    final iconColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final dropdownBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03);
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;
    final cancelColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final primaryColor = const Color(0xFF2E65FF);
    final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Basic & System Controllers
    final userIdController = TextEditingController(
      text: employee != null
          ? employee.id
          : provider.getNextEmployeeId(companyCode: targetCompany.isNotEmpty ? targetCompany : null),
    );
    final nameController = TextEditingController(text: employee?.name ?? '');
    final emailController = TextEditingController(text: employee?.email ?? '');
    final positionController = TextEditingController(text: employee?.position ?? '');
    final passwordController = TextEditingController(text: employee?.password ?? '');
    final phoneController = TextEditingController(text: employee?.phoneNumber ?? '');
    final salaryController = TextEditingController(text: employee?.basicSalary.toString() ?? '0');

    final annualLeaveBalanceController = TextEditingController(
      text: employee != null ? employee.annualLeaveBalance.toString() : '24.0',
    );
    final startDateController = TextEditingController(
      text: employee?.startDate.isNotEmpty == true
          ? employee!.startDate
          : nowStr,
    );
    final groupStartDateController = TextEditingController(
      text: employee?.groupStartDate.isNotEmpty == true
          ? employee!.groupStartDate
          : (employee?.startDate.isNotEmpty == true
              ? employee!.startDate
              : nowStr),
    );
    final groupEndDateController = TextEditingController();

    // General Info Controllers & State
    final dobController = TextEditingController(text: employee?.dateOfBirth ?? '');
    final validGenders = ['Male', 'Female'];
    String? selectedGender = validGenders.contains(employee?.gender) ? employee?.gender : null;
    final validMarital = ['Single', 'Married', 'Divorced', 'Widowed'];
    String? selectedMaritalStatus = validMarital.contains(employee?.maritalStatus) ? employee?.maritalStatus : null;
    final emergencyContactController = TextEditingController(text: employee?.emergencyContact ?? '');
    final emergencyPhoneController = TextEditingController(text: employee?.emergencyPhone ?? '');
    final validBlood = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    String? selectedBloodGroup = validBlood.contains(employee?.bloodGroup) ? employee?.bloodGroup : null;
    final nationalityController = TextEditingController(text: employee?.nationality ?? '');
    final addressController = TextEditingController(text: employee?.address ?? '');

    // Documents Info Controllers & State
    final nationalCardNoController = TextEditingController(text: employee?.nationalCardNo ?? '');
    final passportNoController = TextEditingController(text: employee?.passportNo ?? '');
    final passportExpiryController = TextEditingController(text: employee?.passportExpiryDate ?? '');
    final residenceCardNoController = TextEditingController(text: employee?.residenceCardNo ?? '');
    final residenceCardExpiryController = TextEditingController(text: employee?.residenceCardExpiryDate ?? '');

    String? nationalCardAttachment = employee?.nationalCardAttachment;
    String? passportAttachment = employee?.passportAttachment;
    String? residenceCardAttachment = employee?.residenceCardAttachment;
    
    int activeFormTab = 0; // 0: General Info, 1: System & Job, 2: Documents Info
    String selectedRole = employee?.role ?? 'employee';
    String? selectedStructure = employee?.structureId;
    String? selectedGroup = employee?.groupId;
    bool isDisabled = employee?.disabled ?? false;
    List<double>? formFaceEmbedding = employee?.faceEmbedding;

    List<GroupHistoryEntry> tempGroupHistory = [];
    if (employee != null) {
      if (employee.groupHistory.isNotEmpty) {
        tempGroupHistory = List<GroupHistoryEntry>.from(employee.groupHistory);
      } else if (employee.groupId != null && employee.groupId!.isNotEmpty) {
        tempGroupHistory = [
          GroupHistoryEntry(
            groupId: employee.groupId!,
            startDate: employee.groupStartDate.isNotEmpty
                ? employee.groupStartDate
                : (employee.startDate.isNotEmpty
                    ? employee.startDate
                    : nowStr),
            endDate: '',
          ),
        ];
      }
    }

    Future<void> pickAttachment({
      required BuildContext ctx,
      required String docTitle,
      required Function(String? base64) onPicked,
    }) async {
      final picker = ImagePicker();
      showModalBottomSheet(
        context: ctx,
        backgroundColor: dropdownBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (bCtx) => SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  provider.translate('attach_doc_title').replaceAll('{title}', docTitle),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
                title: Text(provider.translate('select_pdf_document'), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                subtitle: Text(provider.translate('attach_pdf_file'), style: TextStyle(color: subtextColor, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(bCtx);
                  await Future.delayed(const Duration(milliseconds: 150));
                  try {
                    FilePickerResult? result;
                    try {
                      result = await FilePicker.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'PDF'],
                        withData: true,
                      );
                    } catch (e1) {
                      debugPrint('FilePicker custom extension failed, trying any: $e1');
                      result = await FilePicker.pickFiles(
                        type: FileType.any,
                        withData: true,
                      );
                    }

                    if (result != null && result.files.isNotEmpty) {
                      final file = result.files.first;
                      final nameLower = file.name.toLowerCase();
                      if (!nameLower.endsWith('.pdf')) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Please select a valid PDF (.pdf) file.'),
                              backgroundColor: Colors.orangeAccent,
                            ),
                          );
                        }
                        return;
                      }

                      Uint8List? fileBytes = file.bytes;
                      final filePath = file.path;
                      if (fileBytes == null && filePath != null) {
                        try {
                          final f = File(filePath);
                          if (f.existsSync()) {
                            fileBytes = await f.readAsBytes();
                          }
                        } catch (readErr) {
                          debugPrint('Error reading file from path: $readErr');
                        }
                      }

                      if (fileBytes != null && fileBytes.isNotEmpty) {
                        if (fileBytes.lengthInBytes > 4 * 1024 * 1024) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('PDF is too large (max 4 MB). Please select a smaller file.'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                          return;
                        }

                        onPicked(base64Encode(fileBytes));
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('${file.name} attached successfully!'),
                              backgroundColor: const Color(0xFF10B981),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } else {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Could not read the selected PDF file content.'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    }
                  } catch (e, stack) {
                    debugPrint('PDF picker error: $e\n$stack');
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text('Error opening file picker: $e'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF10B981)),
                title: Text(provider.translate('choose_image_gallery'), style: TextStyle(color: textColor)),
                subtitle: Text(provider.translate('attach_photo_scanned'), style: TextStyle(color: subtextColor, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(bCtx);
                  try {
                    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200, imageQuality: 80);
                    if (image != null) {
                      final bytes = await image.readAsBytes();
                      try {
                        final decoded = img.decodeImage(bytes);
                        if (decoded != null) {
                          final resized = img.copyResize(decoded, width: 800);
                          final compressed = img.encodeJpg(resized, quality: 75);
                          onPicked(base64Encode(compressed));
                        } else {
                          onPicked(base64Encode(bytes));
                        }
                      } catch (_) {
                        onPicked(base64Encode(bytes));
                      }
                    }
                  } catch (e) {
                    debugPrint('Gallery error: $e');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF2E65FF)),
                title: Text(provider.translate('take_photo_camera'), style: TextStyle(color: textColor)),
                subtitle: Text(provider.translate('capture_id_doc'), style: TextStyle(color: subtextColor, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(bCtx);
                  try {
                    final photo = await picker.pickImage(source: ImageSource.camera, maxWidth: 1200, maxHeight: 1200, imageQuality: 80);
                    if (photo != null) {
                      final bytes = await photo.readAsBytes();
                      try {
                        final decoded = img.decodeImage(bytes);
                        if (decoded != null) {
                          final resized = img.copyResize(decoded, width: 800);
                          final compressed = img.encodeJpg(resized, quality: 75);
                          onPicked(base64Encode(compressed));
                        } else {
                          onPicked(base64Encode(bytes));
                        }
                      } catch (_) {
                        onPicked(base64Encode(bytes));
                      }
                    }
                  } catch (e) {
                    debugPrint('Camera error: $e');
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    Widget buildAttachmentPickerBox({
      required BuildContext ctx,
      required String title,
      required String? attachmentValue,
      required VoidCallback onPick,
      required VoidCallback onRemove,
    }) {
      final hasFile = attachmentValue != null && attachmentValue.trim().isNotEmpty;
      final isPdf = hasFile ? _isPdfDocument(attachmentValue) : false;
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasFile
                ? (isPdf ? Colors.redAccent.withValues(alpha: 0.5) : primaryColor.withValues(alpha: 0.5))
                : borderColor,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: hasFile
                    ? (isPdf ? Colors.redAccent.withValues(alpha: 0.15) : primaryColor.withValues(alpha: 0.15))
                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                hasFile
                    ? (isPdf ? Icons.picture_as_pdf_rounded : Icons.check_circle_rounded)
                    : Icons.attach_file_rounded,
                color: hasFile ? (isPdf ? Colors.redAccent : primaryColor) : iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasFile
                        ? (isPdf ? provider.translate('pdf_attached') : provider.translate('image_attached'))
                        : provider.translate('no_file_attached'),
                    style: TextStyle(
                      color: hasFile ? (isPdf ? Colors.redAccent : const Color(0xFF10B981)) : subtextColor,
                      fontSize: 11,
                      fontWeight: hasFile ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (hasFile) ...[
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 20, color: Color(0xFF2E65FF)),
                tooltip: provider.translate('preview_download'),
                onPressed: () => _showDocumentPreviewDialog(ctx, title, attachmentValue),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                tooltip: provider.translate('remove_action'),
                onPressed: onRemove,
              ),
            ] else ...[
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.upload_file, size: 15),
                label: Text(provider.translate('attach_action'), style: const TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      );
    }

    showGlassDialog(
      context: context,
      title: isEditing ? provider.translate('edit_user') : provider.translate('add_new_user'),
      subtitle: isEditing ? provider.translate('update_user_properties') : provider.translate('create_new_system_account'),
      icon: isEditing ? Icons.edit_note_rounded : Icons.person_add_rounded,
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          final tabBg = isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF1F5F9);
          final tabActiveBg = primaryColor.withValues(alpha: 0.18);

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tab Bar
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: tabBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => setDialogState(() => activeFormTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: activeFormTab == 0 ? tabActiveBg : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.badge_outlined,
                                  size: 15,
                                  color: activeFormTab == 0 ? primaryColor : (isDark ? Colors.white60 : Colors.black54),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  provider.translate('general_info'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: activeFormTab == 0 ? FontWeight.bold : FontWeight.normal,
                                    color: activeFormTab == 0 ? primaryColor : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => setDialogState(() => activeFormTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: activeFormTab == 1 ? tabActiveBg : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.work_outline_rounded,
                                  size: 15,
                                  color: activeFormTab == 1 ? primaryColor : (isDark ? Colors.white60 : Colors.black54),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  provider.translate('job_and_system'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: activeFormTab == 1 ? FontWeight.bold : FontWeight.normal,
                                    color: activeFormTab == 1 ? primaryColor : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => setDialogState(() => activeFormTab = 2),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: activeFormTab == 2 ? tabActiveBg : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.folder_shared_outlined,
                                  size: 15,
                                  color: activeFormTab == 2 ? primaryColor : (isDark ? Colors.white60 : Colors.black54),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  provider.translate('documents'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: activeFormTab == 2 ? FontWeight.bold : FontWeight.normal,
                                    color: activeFormTab == 2 ? primaryColor : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ================= TAB 0: GENERAL INFO =================
                if (activeFormTab == 0) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: userIdController,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            labelText: '${provider.translate('user_id')} *',
                            labelStyle: TextStyle(color: labelColor),
                            prefixIcon: const Icon(Icons.tag_rounded, size: 18, color: Color(0xFF2E65FF)),
                            helperText: isEditing ? provider.translate('device_system_id') : provider.translate('auto_sequence_id'),
                            helperStyle: TextStyle(color: subtextColor, fontSize: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 7,
                        child: TextField(
                          controller: nameController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: '${provider.translate('full_name')} *',
                            labelStyle: TextStyle(color: labelColor),
                            prefixIcon: Icon(Icons.person_outline, size: 18, color: iconColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Date of Birth & Gender
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final current = DateTime.tryParse(dobController.text) ?? DateTime(1995, 1, 1);
                            final picked = await showCompactDatePicker(
                              context: context,
                              initialDate: current,
                              firstDate: DateTime(1940),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                dobController.text = DateFormat('yyyy-MM-dd').format(picked);
                              });
                            }
                          },
                          child: IgnorePointer(
                            child: TextField(
                              controller: dobController,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: provider.translate('birthday'),
                                labelStyle: TextStyle(color: labelColor),
                                prefixIcon: Icon(Icons.cake_outlined, size: 18, color: iconColor),
                                hintText: 'YYYY-MM-DD',
                                hintStyle: TextStyle(color: hintColor),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: selectedGender,
                          dropdownColor: dropdownBg,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: provider.translate('gender'),
                            labelStyle: TextStyle(color: labelColor),
                            prefixIcon: Icon(Icons.wc_outlined, size: 18, color: iconColor),
                          ),
                          items: [
                            DropdownMenuItem(value: null, child: Text(provider.translate('not_specified'), style: TextStyle(color: textColor))),
                            DropdownMenuItem(value: 'Male', child: Text(provider.translate('male'), style: TextStyle(color: textColor))),
                            DropdownMenuItem(value: 'Female', child: Text(provider.translate('female'), style: TextStyle(color: textColor))),
                          ],
                          onChanged: (val) => setDialogState(() => selectedGender = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Marital Status & Blood Group
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: selectedMaritalStatus,
                          dropdownColor: dropdownBg,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: provider.translate('marital_status'),
                            labelStyle: TextStyle(color: labelColor),
                            prefixIcon: Icon(Icons.favorite_border_rounded, size: 18, color: iconColor),
                          ),
                          items: [
                            DropdownMenuItem(value: null, child: Text(provider.translate('not_specified'), style: TextStyle(color: textColor))),
                            DropdownMenuItem(value: 'Single', child: Text(provider.translate('single'), style: TextStyle(color: textColor))),
                            DropdownMenuItem(value: 'Married', child: Text(provider.translate('married'), style: TextStyle(color: textColor))),
                            DropdownMenuItem(value: 'Divorced', child: Text(provider.translate('divorced'), style: TextStyle(color: textColor))),
                            DropdownMenuItem(value: 'Widowed', child: Text(provider.translate('widowed'), style: TextStyle(color: textColor))),
                          ],
                          onChanged: (val) => setDialogState(() => selectedMaritalStatus = val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: selectedBloodGroup,
                          dropdownColor: dropdownBg,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: provider.translate('blood_group'),
                            labelStyle: TextStyle(color: labelColor),
                            prefixIcon: Icon(Icons.bloodtype_outlined, size: 18, color: iconColor),
                          ),
                          items: [
                            DropdownMenuItem(value: null, child: Text(provider.translate('not_specified'), style: TextStyle(color: textColor))),
                            ...['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map(
                              (bg) => DropdownMenuItem(value: bg, child: Text(bg, style: TextStyle(color: textColor))),
                            ),
                          ],
                          onChanged: (val) => setDialogState(() => selectedBloodGroup = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Phone No & Nationality
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          style: TextStyle(color: textColor),
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: provider.translate('phone_no'),
                            labelStyle: TextStyle(color: labelColor),
                            prefixIcon: Icon(Icons.phone_outlined, size: 18, color: iconColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: nationalityController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: provider.translate('nationality'),
                            labelStyle: TextStyle(color: labelColor),
                            prefixIcon: Icon(Icons.public_outlined, size: 18, color: iconColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Address
                  TextField(
                    controller: addressController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: provider.translate('address'),
                      labelStyle: TextStyle(color: labelColor),
                      prefixIcon: Icon(Icons.home_outlined, size: 18, color: iconColor),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Emergency / Close personal relations
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.translate('emergency_and_close_contacts'),
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: emergencyContactController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: provider.translate('close_personal_relationships'),
                            labelStyle: TextStyle(color: labelColor, fontSize: 12),
                            prefixIcon: Icon(Icons.people_outline, size: 18, color: iconColor),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: emergencyPhoneController,
                          style: TextStyle(color: textColor),
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: provider.translate('close_personal_phone_no'),
                            labelStyle: TextStyle(color: labelColor, fontSize: 12),
                            prefixIcon: Icon(Icons.contact_phone_outlined, size: 18, color: iconColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]

                // ================= TAB 1: SYSTEM & JOB =================
                else if (activeFormTab == 1) ...[
                  TextField(
                    controller: emailController,
                    style: TextStyle(color: textColor),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: '${provider.translate('email_address_label')} *',
                      labelStyle: TextStyle(color: labelColor),
                      prefixIcon: Icon(Icons.email_outlined, size: 18, color: iconColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: positionController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: provider.translate('position_job_title'),
                      labelStyle: TextStyle(color: labelColor),
                      prefixIcon: Icon(Icons.badge_outlined, size: 18, color: iconColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Employee Start Date (Hire Date)
                  InkWell(
                    onTap: () async {
                      final initial = DateTime.tryParse(startDateController.text) ?? DateTime.now();
                      final picked = await showCompactDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                        });
                      }
                    },
                    child: IgnorePointer(
                      child: TextField(
                        controller: startDateController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: '${provider.translate('hire_date')} *',
                          labelStyle: TextStyle(color: labelColor),
                          prefixIcon: Icon(Icons.calendar_today_rounded, size: 18, color: iconColor),
                          helperText: provider.translate('start_date_hint'),
                          helperStyle: TextStyle(color: subtextColor, fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    style: TextStyle(color: textColor),
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: provider.translate('login_password_optional'),
                      labelStyle: TextStyle(color: labelColor),
                      prefixIcon: Icon(Icons.lock_outline, size: 18, color: iconColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Role Selection Dropdown
                  Builder(
                    builder: (context) {
                      final validRoles = ['employee', 'supervisor', 'hr'];
                      final safeRole = validRoles.contains(selectedRole.toLowerCase())
                          ? selectedRole.toLowerCase()
                          : 'employee';
                      return DropdownButtonFormField<String>(
                        initialValue: safeRole,
                        dropdownColor: dropdownBg,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: provider.translate('access_role'),
                          labelStyle: TextStyle(color: labelColor),
                          prefixIcon: Icon(Icons.security_outlined, size: 18, color: iconColor),
                        ),
                        items: [
                          DropdownMenuItem(value: 'employee', child: Text(provider.translate('employee_role'), style: TextStyle(color: textColor))),
                          DropdownMenuItem(value: 'supervisor', child: Text(provider.translate('supervisor_role'), style: TextStyle(color: textColor))),
                          DropdownMenuItem(value: 'hr', child: Text(provider.translate('role_hr_admin'), style: TextStyle(color: textColor))),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedRole = val);
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Structure Dropdown
                  Builder(
                    builder: (context) {
                      final seenStructs = <String?>{};
                      final structItems = <DropdownMenuItem<String?>>[
                        DropdownMenuItem(value: null, child: Text(provider.translate('none_unassigned'), style: TextStyle(color: textColor))),
                      ];
                      seenStructs.add(null);

                      for (final s in provider.structures) {
                        if (!seenStructs.contains(s.id)) {
                          seenStructs.add(s.id);
                          structItems.add(DropdownMenuItem(value: s.id, child: Text(s.name, style: TextStyle(color: textColor))));
                        }
                      }

                      if (selectedStructure != null && !seenStructs.contains(selectedStructure)) {
                        final structMatch = provider.structures.where((s) => s.id == selectedStructure).firstOrNull;
                        final label = structMatch?.name ?? '(${provider.translate('department')}: $selectedStructure)';
                        structItems.add(
                          DropdownMenuItem(
                            value: selectedStructure,
                            child: Text(label, style: TextStyle(color: textColor)),
                          ),
                        );
                      }

                      return DropdownButtonFormField<String?>(
                        initialValue: selectedStructure,
                        dropdownColor: dropdownBg,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: provider.translate('structure_department'),
                          labelStyle: TextStyle(color: labelColor),
                          prefixIcon: Icon(Icons.corporate_fare_outlined, size: 18, color: iconColor),
                        ),
                        items: structItems,
                        onChanged: (val) {
                          setDialogState(() => selectedStructure = val);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Group / Shift Dropdown
                  Builder(
                    builder: (context) {
                      final seenGroups = <String?>{};
                      final groupItems = <DropdownMenuItem<String?>>[
                        DropdownMenuItem(value: null, child: Text(provider.translate('none_standard'), style: TextStyle(color: textColor))),
                      ];
                      seenGroups.add(null);

                      for (final g in provider.groups) {
                        if (!seenGroups.contains(g.id)) {
                          seenGroups.add(g.id);
                          final shift = provider.shifts.where((s) => s.id == g.shiftId).firstOrNull;
                          final shiftName = shift != null ? ' (${shift.name})' : '';
                          groupItems.add(
                            DropdownMenuItem(value: g.id, child: Text('${g.name}$shiftName', style: TextStyle(color: textColor))),
                          );
                        }
                      }

                      if (selectedGroup != null && !seenGroups.contains(selectedGroup)) {
                        final groupMatch = provider.groups.where((g) => g.id == selectedGroup).firstOrNull;
                        final label = groupMatch?.name ?? '(${provider.translate('shift')}: $selectedGroup)';
                        groupItems.add(
                          DropdownMenuItem(
                            value: selectedGroup,
                            child: Text(label, style: TextStyle(color: textColor)),
                          ),
                        );
                      }

                      return DropdownButtonFormField<String?>(
                        initialValue: selectedGroup,
                        dropdownColor: dropdownBg,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: provider.translate('employee_group_shift'),
                          labelStyle: TextStyle(color: labelColor),
                          prefixIcon: Icon(Icons.schedule_outlined, size: 18, color: iconColor),
                        ),
                        items: groupItems,
                        onChanged: (val) {
                          setDialogState(() {
                            selectedGroup = val;
                            if (val != employee?.groupId) {
                              groupStartDateController.text = nowStr;
                              groupEndDateController.clear();
                            }
                          });
                        },
                      );
                    },
                  ),
                  if (selectedGroup != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF2E65FF)),
                              const SizedBox(width: 6),
                              Text(
                                provider.translate('shift_change_effective_dates'),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final initial = DateTime.tryParse(groupStartDateController.text) ?? DateTime.now();
                                    final picked = await showCompactDatePicker(
                                      context: context,
                                      initialDate: initial,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        groupStartDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                                      });
                                    }
                                  },
                                  child: IgnorePointer(
                                    child: TextField(
                                      controller: groupStartDateController,
                                      style: TextStyle(color: textColor, fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: provider.translate('start_date_required'),
                                        labelStyle: TextStyle(color: labelColor, fontSize: 12),
                                        suffixIcon: Icon(Icons.calendar_today, size: 16, color: iconColor),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final initial = DateTime.tryParse(groupEndDateController.text) ?? DateTime.now();
                                    final picked = await showCompactDatePicker(
                                      context: context,
                                      initialDate: initial,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        groupEndDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                                      });
                                    }
                                  },
                                  child: IgnorePointer(
                                    child: TextField(
                                      controller: groupEndDateController,
                                      style: TextStyle(color: textColor, fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: provider.translate('end_date_optional'),
                                        labelStyle: TextStyle(color: labelColor, fontSize: 12),
                                        hintText: provider.translate('ongoing'),
                                        hintStyle: TextStyle(color: hintColor, fontSize: 12),
                                        suffixIcon: groupEndDateController.text.isNotEmpty
                                            ? IconButton(
                                                icon: Icon(Icons.clear, size: 16, color: iconColor),
                                                onPressed: () {
                                                  setDialogState(() => groupEndDateController.clear());
                                                },
                                              )
                                            : Icon(Icons.calendar_today, size: 16, color: iconColor),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            provider.translate('shift_change_help_text'),
                            style: TextStyle(
                              color: subtextColor,
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          if (tempGroupHistory.length > 1) ...[
                            const SizedBox(height: 10),
                            Divider(color: dividerColor, height: 1),
                            const SizedBox(height: 8),
                            Text(
                              provider.translate('recorded_shift_periods'),
                              style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            ...tempGroupHistory.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final h = entry.value;
                              final grp = provider.groups.where((g) => g.id == h.groupId).firstOrNull;
                              final shf = provider.shifts.where((s) => s.id == grp?.shiftId).firstOrNull;
                              final gTitle = grp != null
                                  ? '${grp.name}${shf != null ? ' (${shf.name})' : ''}'
                                  : 'Unknown Group';
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '• $gTitle: ${h.startDate} to ${h.endDate.isEmpty ? provider.translate('ongoing') : h.endDate}',
                                        style: TextStyle(color: subtextColor, fontSize: 11),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        setDialogState(() {
                                          tempGroupHistory.removeAt(idx);
                                        });
                                      },
                                      child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  TextField(
                    controller: annualLeaveBalanceController,
                    style: TextStyle(color: textColor),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: provider.translate('annual_leave_balance_hours'),
                      labelStyle: TextStyle(color: labelColor),
                      prefixIcon: const Icon(Icons.beach_access_rounded, size: 18, color: Color(0xFF10B981)),
                      helperText: provider.translate('annual_leave_balance_helper'),
                      helperStyle: TextStyle(color: subtextColor, fontSize: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Basic Salary
                  TextField(
                    controller: salaryController,
                    style: TextStyle(color: textColor),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: '${provider.translate('basic_salary')} (${employee?.salaryCurrency.isNotEmpty == true ? employee!.salaryCurrency : 'USD'})',
                      labelStyle: TextStyle(color: labelColor),
                      prefixIcon: const Icon(Icons.monetization_on_outlined, size: 18, color: Color(0xFF10B981)),
                    ),
                  ),
                  const SizedBox(height: 12),



                  // Face ID Biometrics Section
                  if (provider.isHRManager)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                formFaceEmbedding != null ? Icons.face_retouching_natural : Icons.face_outlined,
                                size: 18,
                                color: formFaceEmbedding != null ? const Color(0xFF10B981) : iconColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                provider.translate('face_id_biometrics'),
                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: formFaceEmbedding != null
                                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  formFaceEmbedding != null ? provider.translate('enrolled_badge') : provider.translate('not_enrolled_badge'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: formFaceEmbedding != null ? const Color(0xFF10B981) : subtextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            provider.translate('form_face_id_desc'),
                            style: TextStyle(color: subtextColor, fontSize: 11),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final res = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (c) => FaceAuthScreen(
                                          title: 'Scan Face: ${nameController.text.trim().isNotEmpty ? nameController.text.trim() : "User"}',
                                          checkForDuplicate: true,
                                          excludeEmployeeId: employee?.id,
                                        ),
                                      ),
                                    );
                                    if (res != null && res is List<double>) {
                                      final duplicate = provider.findDuplicateFaceEmployee(res, excludeEmployeeId: employee?.id);
                                      if (duplicate != null) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      provider.translate('duplicate_face_detected').replaceAll('{name}', duplicate.name),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: const Color(0xFFEF4444),
                                              duration: const Duration(seconds: 4),
                                            ),
                                          );
                                        }
                                        return;
                                      }
                                      setDialogState(() {
                                        formFaceEmbedding = res;
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                  label: Text(provider.translate('scan_camera'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              if (formFaceEmbedding != null) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                                  tooltip: provider.translate('remove_face_id'),
                                  onPressed: () {
                                    setDialogState(() {
                                      formFaceEmbedding = null;
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Active / Suspended Switch
                  SwitchListTile(
                    title: Text(provider.translate('suspend_account'), style: TextStyle(color: textColor, fontSize: 13)),
                    subtitle: Text(provider.translate('prevent_login_clocking'), style: TextStyle(color: subtextColor, fontSize: 11)),
                    value: isDisabled,
                    activeThumbColor: Colors.redAccent,
                    onChanged: (val) {
                      setDialogState(() => isDisabled = val);
                    },
                  ),
                ]

                // ================= TAB 2: DOCUMENTS INFO =================
                else ...[
                  // National Card No
                  TextField(
                    controller: nationalCardNoController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: provider.translate('national_card_no'),
                      labelStyle: TextStyle(color: labelColor),
                      prefixIcon: Icon(Icons.credit_card_outlined, size: 18, color: iconColor),
                    ),
                  ),
                  const SizedBox(height: 10),
                  buildAttachmentPickerBox(
                    ctx: context,
                    title: provider.translate('national_card_attach'),
                    attachmentValue: nationalCardAttachment,
                    onPick: () => pickAttachment(
                      ctx: context,
                      docTitle: provider.translate('national_card_attach'),
                      onPicked: (val) => setDialogState(() => nationalCardAttachment = val),
                    ),
                    onRemove: () => setDialogState(() => nationalCardAttachment = null),
                  ),
                  const SizedBox(height: 16),

                  // Passport No & Expire Date
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: passportNoController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: provider.translate('passport_no'),
                            labelStyle: TextStyle(color: labelColor),
                            prefixIcon: Icon(Icons.flight_outlined, size: 18, color: iconColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final current = DateTime.tryParse(passportExpiryController.text) ?? DateTime.now().add(const Duration(days: 365));
                            final picked = await showCompactDatePicker(
                              context: context,
                              initialDate: current,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2050),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                passportExpiryController.text = DateFormat('yyyy-MM-dd').format(picked);
                              });
                            }
                          },
                          child: IgnorePointer(
                            child: TextField(
                              controller: passportExpiryController,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: provider.translate('passport_expire_date'),
                                labelStyle: TextStyle(color: labelColor),
                                prefixIcon: Icon(Icons.event_outlined, size: 18, color: iconColor),
                                hintText: 'YYYY-MM-DD',
                                hintStyle: TextStyle(color: hintColor),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  buildAttachmentPickerBox(
                    ctx: context,
                    title: provider.translate('passport_attach'),
                    attachmentValue: passportAttachment,
                    onPick: () => pickAttachment(
                      ctx: context,
                      docTitle: provider.translate('passport_attach'),
                      onPicked: (val) => setDialogState(() => passportAttachment = val),
                    ),
                    onRemove: () => setDialogState(() => passportAttachment = null),
                  ),
                  const SizedBox(height: 16),

                  // Residence Card No & Expire Date
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: residenceCardNoController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: provider.translate('residence_card_no'),
                            labelStyle: TextStyle(color: labelColor),
                            prefixIcon: Icon(Icons.perm_identity_rounded, size: 18, color: iconColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final current = DateTime.tryParse(residenceCardExpiryController.text) ?? DateTime.now().add(const Duration(days: 365));
                            final picked = await showCompactDatePicker(
                              context: context,
                              initialDate: current,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2050),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                residenceCardExpiryController.text = DateFormat('yyyy-MM-dd').format(picked);
                              });
                            }
                          },
                          child: IgnorePointer(
                            child: TextField(
                              controller: residenceCardExpiryController,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: provider.translate('residence_card_expire_date'),
                                labelStyle: TextStyle(color: labelColor),
                                prefixIcon: Icon(Icons.event_outlined, size: 18, color: iconColor),
                                hintText: 'YYYY-MM-DD',
                                hintStyle: TextStyle(color: hintColor),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  buildAttachmentPickerBox(
                    ctx: context,
                    title: provider.translate('residence_card_attach'),
                    attachmentValue: residenceCardAttachment,
                    onPick: () => pickAttachment(
                      ctx: context,
                      docTitle: provider.translate('residence_card_attach'),
                      onPicked: (val) => setDialogState(() => residenceCardAttachment = val),
                    ),
                    onRemove: () => setDialogState(() => residenceCardAttachment = null),
                  ),
                ],
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(provider.translate('cancel'), style: TextStyle(color: cancelColor)),
        ),
        NeuButton(
          label: isEditing ? provider.translate('save_changes') : provider.translate('create_user'),
          variant: NeuButtonVariant.primary,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          onPressed: () async {
            final enteredId = userIdController.text.trim().isNotEmpty
                ? userIdController.text.trim()
                : (employee != null
                    ? employee.id
                    : provider.getNextEmployeeId(companyCode: targetCompany.isNotEmpty ? targetCompany : null));
            final name = nameController.text.trim();
            final email = emailController.text.trim();
            final pos = positionController.text.trim();

            if (enteredId.isEmpty || name.isEmpty || email.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(provider.translate('user_required_fields_error'))),
              );
              return;
            }

            final conflict = provider.getEmployeeConflict(
              enteredId,
              companyCode: targetCompany.isNotEmpty ? targetCompany : null,
              excludeEmpId: employee?.id,
            );
            if (conflict != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    provider.translate('user_id_conflict_error')
                        .replaceAll('{id}', enteredId)
                        .replaceAll('{name}', conflict.name),
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              );
              return;
            }

            final salaryVal = double.tryParse(salaryController.text) ?? 0.0;

            final leaveBalanceVal = double.tryParse(annualLeaveBalanceController.text.trim()) ?? (employee?.annualLeaveBalance ?? 24.0);

            List<GroupHistoryEntry> gHistory = List<GroupHistoryEntry>.from(tempGroupHistory);
            String? finalGroupId = selectedGroup;
            String finalGroupStartDate = groupStartDateController.text.trim().isNotEmpty
                ? groupStartDateController.text.trim()
                : nowStr;
            String finalGroupEndDate = groupEndDateController.text.trim();

            if (selectedGroup == null) {
              finalGroupId = null;
              finalGroupStartDate = '';
              gHistory = [];
            } else if (isEditing) {
              if (selectedGroup != employee.groupId) {
                // The shift is changing!
                final newStartStr = finalGroupStartDate;
                final newEndStr = finalGroupEndDate;

                try {
                  final newStart = DateTime.parse(newStartStr);
                  final prevDay = newStart.subtract(const Duration(days: 1));
                  final prevDayStr =
                      "${prevDay.year.toString().padLeft(4, '0')}-${prevDay.month.toString().padLeft(2, '0')}-${prevDay.day.toString().padLeft(2, '0')}";

                  // Close previous ongoing period up to (newStart - 1 day)
                  String? previousOngoingGroup = employee.groupId;
                  if (gHistory.isEmpty && employee.groupId != null && employee.groupId!.isNotEmpty) {
                    gHistory.add(
                      GroupHistoryEntry(
                        groupId: employee.groupId!,
                        startDate: employee.startDate.isNotEmpty ? employee.startDate : '2020-01-01',
                        endDate: prevDayStr,
                      ),
                    );
                  } else {
                    for (int i = 0; i < gHistory.length; i++) {
                      if (gHistory[i].endDate.isEmpty) {
                        previousOngoingGroup = gHistory[i].groupId;
                        gHistory[i] = GroupHistoryEntry(
                          groupId: gHistory[i].groupId,
                          startDate: gHistory[i].startDate,
                          endDate: prevDayStr,
                        );
                      }
                    }
                  }

                  // If new period has an end date, resume previous ongoing group afterwards
                  if (newEndStr.isNotEmpty && previousOngoingGroup != null && previousOngoingGroup.isNotEmpty) {
                    final endDt = DateTime.parse(newEndStr);
                    final nextDay = endDt.add(const Duration(days: 1));
                    final nextDayStr =
                        "${nextDay.year.toString().padLeft(4, '0')}-${nextDay.month.toString().padLeft(2, '0')}-${nextDay.day.toString().padLeft(2, '0')}";
                    gHistory.add(
                      GroupHistoryEntry(
                        groupId: previousOngoingGroup,
                        startDate: nextDayStr,
                        endDate: '',
                      ),
                    );
                  }
                } catch (_) {}

                // Add the new shift period
                gHistory.add(
                  GroupHistoryEntry(
                    groupId: selectedGroup!,
                    startDate: newStartStr,
                    endDate: newEndStr,
                  ),
                );
              } else {
                // Same group, ensure current period is recorded with updated dates
                if (gHistory.isEmpty) {
                  gHistory.add(
                    GroupHistoryEntry(
                      groupId: selectedGroup!,
                      startDate: finalGroupStartDate,
                      endDate: finalGroupEndDate,
                    ),
                  );
                } else {
                  bool found = false;
                  for (int i = 0; i < gHistory.length; i++) {
                    if (gHistory[i].groupId == selectedGroup && gHistory[i].endDate.isEmpty) {
                      gHistory[i] = GroupHistoryEntry(
                        groupId: selectedGroup!,
                        startDate: finalGroupStartDate,
                        endDate: finalGroupEndDate,
                      );
                      found = true;
                      break;
                    }
                  }
                  if (!found) {
                    gHistory.add(
                      GroupHistoryEntry(
                        groupId: selectedGroup!,
                        startDate: finalGroupStartDate,
                        endDate: finalGroupEndDate,
                      ),
                    );
                  }
                }
              }

              gHistory.sort((a, b) => b.startDate.compareTo(a.startDate));

              final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
              for (var h in gHistory) {
                if (h.startDate.compareTo(todayStr) <= 0 &&
                    (h.endDate.isEmpty || h.endDate.compareTo(todayStr) >= 0)) {
                  finalGroupId = h.groupId;
                  finalGroupStartDate = h.startDate;
                  break;
                }
              }
            } else {
              gHistory = [
                GroupHistoryEntry(
                  groupId: selectedGroup!,
                  startDate: finalGroupStartDate,
                  endDate: finalGroupEndDate,
                ),
              ];
            }

            CompanyEmployee newOrUpdatedEmp;
            if (isEditing) {
              List<SalaryHistoryEntry> sHistory = List.from(employee.salaryHistory);
              if (sHistory.isEmpty && (salaryVal > 0 || employee.workingHours > 0)) {
                sHistory.add(
                  SalaryHistoryEntry(
                    basicSalary: salaryVal > 0 ? salaryVal : employee.basicSalary,
                    workingHours: employee.workingHours > 0 ? employee.workingHours : 160.0,
                    currency: employee.salaryCurrency.isNotEmpty ? employee.salaryCurrency : 'USD',
                    startDate: employee.startDate.isNotEmpty ? employee.startDate : nowStr,
                    endDate: null,
                    foodAllowance: employee.foodAllowance,
                    transportationAllowance: employee.transportationAllowance,
                    otherAllowance: employee.otherAllowance,
                    hasInsurance: employee.hasInsurance,
                    insuranceSalary: employee.insuranceSalary,
                  ),
                );
              } else if (sHistory.isNotEmpty) {
                final lastIdx = sHistory.length - 1;
                sHistory[lastIdx] = sHistory[lastIdx].copyWith(
                  basicSalary: salaryVal > 0 ? salaryVal : sHistory[lastIdx].basicSalary,
                );
              }
              newOrUpdatedEmp = employee.copyWith(
                id: enteredId,
                name: name,
                email: email,
                position: pos.isNotEmpty ? pos : 'Team Member',
                role: selectedRole,
                password: passwordController.text.trim().isNotEmpty ? passwordController.text.trim() : employee.password,
                startDate: startDateController.text.trim().isNotEmpty ? startDateController.text.trim() : employee.startDate,
                structureId: selectedStructure,
                overrideStructureId: true,
                groupId: finalGroupId,
                overrideGroupId: true,
                groupStartDate: finalGroupStartDate,
                groupHistory: gHistory,
                phoneNumber: phoneController.text.trim(),
                disabled: isDisabled,
                annualLeaveBalance: leaveBalanceVal,
                basicSalary: salaryVal,
                workingHours: employee.workingHours > 0 ? employee.workingHours : 160.0,
                salaryHistory: sHistory,
                hasInsurance: employee.hasInsurance,
                insuranceSalary: employee.insuranceSalary,
                faceEmbedding: formFaceEmbedding,
                overrideFaceEmbedding: true,
                // General Info
                dateOfBirth: dobController.text.trim(),
                gender: selectedGender,
                maritalStatus: selectedMaritalStatus,
                emergencyContact: emergencyContactController.text.trim(),
                emergencyPhone: emergencyPhoneController.text.trim(),
                bloodGroup: selectedBloodGroup,
                nationality: nationalityController.text.trim(),
                address: addressController.text.trim(),
                // Documents Info
                nationalCardNo: nationalCardNoController.text.trim(),
                passportNo: passportNoController.text.trim(),
                passportExpiryDate: passportExpiryController.text.trim(),
                residenceCardNo: residenceCardNoController.text.trim(),
                residenceCardExpiryDate: residenceCardExpiryController.text.trim(),
                nationalCardAttachment: nationalCardAttachment,
                overrideNationalCardAttachment: true,
                passportAttachment: passportAttachment,
                overridePassportAttachment: true,
                residenceCardAttachment: residenceCardAttachment,
                overrideResidenceCardAttachment: true,
              );
              if (newOrUpdatedEmp.companyCode.isEmpty && targetCompany.isNotEmpty) {
                newOrUpdatedEmp = newOrUpdatedEmp.copyWith(companyCode: targetCompany);
              }
              await provider.updateEmployee(newOrUpdatedEmp, oldId: employee.id);
            } else {
              List<SalaryHistoryEntry> initialHistory = [];
              if (salaryVal > 0) {
                initialHistory.add(
                  SalaryHistoryEntry(
                    basicSalary: salaryVal,
                    workingHours: 160.0,
                    currency: 'USD',
                    startDate: startDateController.text.trim().isNotEmpty ? startDateController.text.trim() : nowStr,
                    endDate: null,
                    hasInsurance: false,
                    insuranceSalary: 0.0,
                  ),
                );
              }
              newOrUpdatedEmp = CompanyEmployee(
                id: enteredId,
                companyCode: targetCompany,
                name: name,
                email: email,
                position: pos.isNotEmpty ? pos : 'Team Member',
                role: selectedRole,
                password: passwordController.text.trim().isNotEmpty ? passwordController.text.trim() : null,
                structureId: selectedStructure,
                groupId: finalGroupId,
                groupStartDate: finalGroupStartDate,
                groupHistory: gHistory,
                phoneNumber: phoneController.text.trim(),
                disabled: isDisabled,
                startDate: startDateController.text.trim().isNotEmpty ? startDateController.text.trim() : nowStr,
                basicSalary: salaryVal,
                workingHours: 160.0,
                salaryHistory: initialHistory,
                hasInsurance: false,
                insuranceSalary: 0.0,
                annualLeaveBalance: leaveBalanceVal,
                faceEmbedding: formFaceEmbedding,
                // General Info
                dateOfBirth: dobController.text.trim(),
                gender: selectedGender,
                maritalStatus: selectedMaritalStatus,
                emergencyContact: emergencyContactController.text.trim(),
                emergencyPhone: emergencyPhoneController.text.trim(),
                bloodGroup: selectedBloodGroup,
                nationality: nationalityController.text.trim(),
                address: addressController.text.trim(),
                // Documents Info
                nationalCardNo: nationalCardNoController.text.trim(),
                passportNo: passportNoController.text.trim(),
                passportExpiryDate: passportExpiryController.text.trim(),
                residenceCardNo: residenceCardNoController.text.trim(),
                residenceCardExpiryDate: residenceCardExpiryController.text.trim(),
                nationalCardAttachment: nationalCardAttachment,
                passportAttachment: passportAttachment,
                residenceCardAttachment: residenceCardAttachment,
              );
              final success = await provider.addEmployee(newOrUpdatedEmp);
              if (!success) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        provider.translate('user_id_conflict_error')
                            .replaceAll('{id}', enteredId)
                            .replaceAll('{name}', ''),
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
                return;
              }
            }

            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isEditing ? provider.translate('user_updated_success') : provider.translate('user_created_success_msg')),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  static void _showLicenseLimitDialog(BuildContext context, AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final license = provider.currentLicense;
    final planName = license?.planName ?? 'Standard';
    final maxUsers = provider.maxActiveUsers;
    final currentActive = provider.activeEmployeesCount;

    showGlassDialog(
      context: context,
      title: provider.translate('user_limit_reached_title'),
      subtitle: '$currentActive / $maxUsers ${provider.translate('active_licenses_quota')}',
      icon: Icons.workspace_premium_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.translate('user_limit_reached_desc')
                            .replaceAll('{max}', '$maxUsers')
                            .replaceAll('{current}', '$currentActive'),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${provider.translate('plan_label')}: $planName',
                        style: const TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'To add more workforce accounts, please contact your account manager or upgrade to a higher tier plan.',
            style: TextStyle(color: subtextColor, fontSize: 12, height: 1.35),
          ),
        ],
      ),
      actions: [
        NeuButton(
          label: provider.translate('cancel'),
          variant: NeuButtonVariant.navy,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }


  void _showDeleteConfirm(BuildContext context, CompanyEmployee employee, AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final cancelColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    showGlassDialog(
      context: context,
      title: provider.translate('delete_user'),
      subtitle: provider.translate('delete_confirm_title'),
      icon: Icons.delete_forever_rounded,
      content: Text(
        provider.translate(
          'delete_employee_confirm',
          params: {
            'name': employee.name,
            'email': employee.email,
          },
        ),
        style: TextStyle(color: textColor, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(provider.translate('cancel'), style: TextStyle(color: cancelColor)),
        ),
        NeuButton(
          onPressed: () async {
            Navigator.pop(context);
            await provider.deleteEmployee(employee.id, companyCode: employee.companyCode);
            if (widget.onDelete != null) {
              widget.onDelete!(employee.id);
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${employee.name} - ${provider.translate('completed')}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          variant: NeuButtonVariant.danger,
          label: provider.translate('delete'),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ],
    );
  }

  void _showFaceIdManageDialog(
    BuildContext context,
    CompanyEmployee employee,
    AttendanceProvider provider,
  ) {
    if (!provider.isHRManager) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.translate('only_hr_manage_face')),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03);
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    showGlassDialog(
      context: context,
      title: '${provider.translate('face_id')} - ${employee.name}',
      subtitle: provider.translate('face_id_desc'),
      icon: Icons.face_retouching_natural,
      content: StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentEmp = provider.employees.firstWhere(
            (e) => e.id == employee.id,
            orElse: () => employee,
          );
          final hasFace = currentEmp.faceEmbedding != null && currentEmp.faceEmbedding!.isNotEmpty;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasFace
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        border: Border.all(
                          color: hasFace ? const Color(0xFF10B981) : borderColor,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        hasFace ? Icons.face_retouching_natural : Icons.face_outlined,
                        color: hasFace ? const Color(0xFF10B981) : subtextColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentEmp.name,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${currentEmp.id} • ${currentEmp.position}',
                            style: TextStyle(color: subtextColor, fontSize: 11),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasFace
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              hasFace ? provider.translate('face_id_enrolled') : provider.translate('face_id_not_enrolled'),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: hasFace ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                provider.translate('face_id_desc'),
                style: TextStyle(color: subtextColor, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Button 1: Live Camera Scan
              ElevatedButton.icon(
                onPressed: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => FaceAuthScreen(
                        title: '${provider.translate('face_verification')}: ${currentEmp.name}',
                        checkForDuplicate: true,
                        excludeEmployeeId: currentEmp.id,
                      ),
                    ),
                  );

                  if (result != null && result is List<double> && context.mounted) {
                    final duplicate = provider.findDuplicateFaceEmployee(result, excludeEmployeeId: currentEmp.id);
                    if (duplicate != null) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  provider.translate('duplicate_face_detected').replaceAll('{name}', duplicate.name),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFFEF4444),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                      return;
                    }
                    await provider.updateEmployeeFaceEmbedding(currentEmp.id, result);
                    setDialogState(() {});
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(child: Text(provider.translate('face_id_enrolled_success'))),
                          ],
                        ),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: Text(hasFace ? provider.translate('rescan_face_id') : provider.translate('setup_face_id')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5CE),
                  foregroundColor: const Color(0xFF0A2342),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),

              if (hasFace) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    await provider.updateEmployeeFaceEmbedding(currentEmp.id, null);
                    setDialogState(() {});
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(provider.translate('face_id_removed_success')),
                        backgroundColor: Colors.blueGrey,
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                  label: Text(provider.translate('remove_face_id'), style: const TextStyle(color: Color(0xFFEF4444))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(provider.translate('close'), style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B))),
        ),
      ],
    );
  }

}
