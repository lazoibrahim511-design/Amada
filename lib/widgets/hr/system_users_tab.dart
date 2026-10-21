import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/hr_models.dart';
import '../glass_container.dart';
import '../glass_dialog.dart';
import '../neu_button.dart';
import '../../screens/face_auth_screen.dart';

class SystemUsersTab extends StatefulWidget {
  final String searchQuery;
  final Function(CompanyEmployee user)? onEditRole;
  final Function(String id)? onDeleteUser;

  const SystemUsersTab({
    super.key,
    required this.searchQuery,
    this.onEditRole,
    this.onDeleteUser,
  });

  @override
  State<SystemUsersTab> createState() => _SystemUsersTabState();
}

class _SystemUsersTabState extends State<SystemUsersTab> {
  String _selectedRoleFilter = 'all';
  String _selectedStatusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allUsers = provider.employees;

    // Filter users for system accounts
    final filteredUsers = allUsers.where((user) {
      final query = widget.searchQuery.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.role.toLowerCase().contains(query);

      final matchesRole =
          _selectedRoleFilter == 'all' ||
          user.role.toLowerCase() == _selectedRoleFilter.toLowerCase();

      final matchesStatus =
          _selectedStatusFilter == 'all' ||
          (_selectedStatusFilter == 'active' && !user.disabled) ||
          (_selectedStatusFilter == 'disabled' && user.disabled);

      return matchesQuery && matchesRole && matchesStatus;
    }).toList();

    // System account stats
    final totalUsers = allUsers.length;
    final hrAdminCount = allUsers
        .where((u) => u.role == 'hr' || u.role == 'admin')
        .length;
    final supervisorCount = allUsers
        .where((u) => u.role == 'supervisor')
        .length;
    final activeCount = allUsers.where((u) => !u.disabled).length;
    final disabledCount = allUsers.where((u) => u.disabled).length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. KPI Summary Bar for System Accounts
          _buildSystemUserKPI(
            context: context,
            provider: provider,
            isDark: isDark,
            total: totalUsers,
            hrAdmins: hrAdminCount,
            supervisors: supervisorCount,
            active: activeCount,
            disabled: disabledCount,
          ),
          const SizedBox(height: 16),

          // 2. Filter Toolbar & Add Button
          _buildFilterToolbar(context, provider, isDark),
          const SizedBox(height: 16),

          // 3. System User Cards Grid
          if (filteredUsers.isEmpty)
            _buildEmptyState(context, provider, isDark)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return _buildUsersTable(
                  context,
                  filteredUsers,
                  provider,
                  isDark,
                );
              },
            ),
        ],
      ),
    );
  }

  // 1. KPI Summary Bar Widget
  Widget _buildSystemUserKPI({
    required BuildContext context,
    required AttendanceProvider provider,
    required bool isDark,
    required int total,
    required int hrAdmins,
    required int supervisors,
    required int active,
    required int disabled,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final chipWidth = isMobile ? (constraints.maxWidth - 12) / 2 : 160.0;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiChip(
              context: context,
              label: provider.translate('total_accounts'),
              value: '$total',
              icon: Icons.manage_accounts_outlined,
              color: const Color(0xFF2E65FF),
              isDark: isDark,
              width: chipWidth,
            ),
            _buildKpiChip(
              context: context,
              label: provider.translate('hr_admins_stat'),
              value: '$hrAdmins',
              icon: Icons.admin_panel_settings_outlined,
              color: const Color(0xFF8B5CF6),
              isDark: isDark,
              width: chipWidth,
            ),
            _buildKpiChip(
              context: context,
              label: provider.translate('supervisors_stat'),
              value: '$supervisors',
              icon: Icons.supervisor_account_outlined,
              color: const Color(0xFF06B6D4),
              isDark: isDark,
              width: chipWidth,
            ),
            _buildKpiChip(
              context: context,
              label: provider.translate('active_access'),
              value: '$active',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF10B981),
              isDark: isDark,
              width: chipWidth,
            ),
            if (disabled > 0)
              _buildKpiChip(
                context: context,
                label: provider.translate('disabled_stat'),
                value: '$disabled',
                icon: Icons.block_outlined,
                color: const Color(0xFFEF4444),
                isDark: isDark,
                width: chipWidth,
              ),
          ],
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
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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

  // 2. Filter Toolbar
  Widget _buildFilterToolbar(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        return Flex(
          direction: isMobile ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: isMobile
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.center,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Role Filter Dropdown
                _buildDropdownFilter(
                  context: context,
                  isDark: isDark,
                  value: _selectedRoleFilter,
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(provider.translate('all_system_roles')),
                    ),
                    DropdownMenuItem(
                      value: 'hr',
                      child: Text(provider.translate('role_hr_admin_mgr')),
                    ),
                    DropdownMenuItem(
                      value: 'supervisor',
                      child: Text(provider.translate('role_supervisor_title')),
                    ),
                    DropdownMenuItem(
                      value: 'employee',
                      child: Text(provider.translate('role_employee_user')),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRoleFilter = val);
                  },
                ),

                // Status Filter Dropdown
                _buildDropdownFilter(
                  context: context,
                  isDark: isDark,
                  value: _selectedStatusFilter,
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(provider.translate('all_access_statuses')),
                    ),
                    DropdownMenuItem(
                      value: 'active',
                      child: Text(provider.translate('active_access')),
                    ),
                    DropdownMenuItem(
                      value: 'disabled',
                      child: Text(provider.translate('disabled_revoked')),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedStatusFilter = val);
                    }
                  },
                ),
              ],
            ),

            if (!isMobile) const Spacer() else const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                // Restore Super Admin Button
                SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await provider.restoreSuperAdminUser();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              provider.translate('super_admin_restored_msg'),
                            ),
                            backgroundColor: Colors.purple,
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 16,
                      color: Color(0xFF00E5CE),
                    ),
                    label: Text(
                      provider.translate('restore_super_admin'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: Color(0xFF00E5CE),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      side: const BorderSide(
                        color: Color(0xFF00E5CE),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                  ),
                ),

                // Add New System User Button
                NeuButton(
                  onPressed: () => _showAddSystemUserDialog(context, provider),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: provider.translate('add_system_account'),
                  variant: NeuButtonVariant.primary,
                  height: 38,
                  fontSize: 12.5,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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

  // 3. System Users CRUD Table Widget
  Widget _buildUsersTable(
    BuildContext context,
    List<CompanyEmployee> users,
    AttendanceProvider provider,
    bool isDark,
  ) {
    if (users.isEmpty) {
      return _buildEmptyState(context, provider, isDark);
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
                          provider.translate('user_details'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textColor,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          provider.translate('role'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textColor,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          provider.translate('access_status'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textColor,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          provider.translate('face_id'),
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
                    rows: users.map((user) {
                      final isHR = user.role == 'hr' || user.role == 'admin';
                      final isSupervisor = user.role == 'supervisor';

                      final roleColor = isHR
                          ? const Color(0xFF8B5CF6)
                          : isSupervisor
                          ? const Color(0xFF06B6D4)
                          : const Color(0xFF64748B);

                      final roleLabel = isHR
                          ? provider.translate('hr_admin_role')
                          : isSupervisor
                          ? provider.translate('role_supervisor_title')
                          : provider.translate('employee_role');

                      return DataRow(
                        cells: [
                          // User Details
                          DataCell(
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: roleColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  child: Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : 'U',
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
                                      user.name,
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
                                             'ID: ${user.id}',
                                             style: const TextStyle(
                                               fontSize: 10,
                                               fontWeight: FontWeight.bold,
                                               color: Color(0xFF2E65FF),
                                             ),
                                           ),
                                         ),
                                       ],
                                     ),
                                    Text(
                                      user.email,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Role
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: roleColor.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                roleLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: roleColor,
                                ),
                              ),
                            ),
                          ),

                          // Access Status
                          DataCell(
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: user.disabled
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  user.disabled
                                      ? provider.translate('disabled_stat')
                                      : provider.translate('active_only'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: user.disabled
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Face ID Status
                          DataCell(
                            InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () => _showFaceIdManageDialog(context, user, provider),
                              child: Row(
                                children: [
                                  Icon(
                                    user.faceEmbedding != null
                                        ? Icons.face_retouching_natural
                                        : Icons.no_photography_outlined,
                                    size: 15,
                                    color: user.faceEmbedding != null
                                        ? const Color(0xFF10B981)
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    user.faceEmbedding != null
                                        ? provider.translate('face_id_enabled')
                                        : provider.translate('face_id_none'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: user.faceEmbedding != null ? FontWeight.w600 : FontWeight.normal,
                                      color: user.faceEmbedding != null
                                          ? const Color(0xFF10B981)
                                          : (isDark ? Colors.white54 : Colors.black54),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Actions
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: user.faceEmbedding != null
                                      ? provider.translate('manage_face_id_enrolled')
                                      : provider.translate('enroll_face_id'),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => _showFaceIdManageDialog(
                                      context,
                                      user,
                                      provider,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: Icon(
                                        user.faceEmbedding != null
                                            ? Icons.face_retouching_natural
                                            : Icons.face_outlined,
                                        size: 18,
                                        color: user.faceEmbedding != null
                                            ? const Color(0xFF10B981)
                                            : (isDark ? Colors.white70 : Colors.black54),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: provider.translate('edit_role'),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => _showEditRoleDialog(
                                      context,
                                      user,
                                      provider,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: Icon(
                                        Icons.shield_outlined,
                                        size: 18,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: provider.translate('set_password'),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => _showSetPasswordDialog(
                                      context,
                                      user,
                                      provider,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: Icon(
                                        Icons.key_outlined,
                                        size: 18,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: user.disabled
                                      ? provider.translate('enable_access')
                                      : provider.translate('disable_access'),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () {
                                      final newStatus = !user.disabled;
                                      final updated = user.copyWith(
                                        disabled: newStatus,
                                      );
                                      provider.updateEmployee(updated);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            newStatus
                                                ? provider.translate('account_access_disabled').replaceAll('{name}', user.name)
                                                : provider.translate('account_access_enabled').replaceAll('{name}', user.name),
                                          ),
                                          backgroundColor: newStatus
                                              ? Colors.redAccent
                                              : Colors.green,
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: Icon(
                                        user.disabled
                                            ? Icons.lock_open_rounded
                                            : Icons.lock_person_outlined,
                                        size: 18,
                                        color: user.disabled
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ), // End DataTable
                ), // End Theme
              ), // End ConstrainedBox
            ); // End return SingleChildScrollView
          }, // End builder
        ), // End LayoutBuilder
      ), // End ClipRRect
    ); // End GlassContainer
  }

  // Empty State Widget
  Widget _buildEmptyState(BuildContext context, AttendanceProvider provider, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.manage_accounts_outlined,
              size: 54,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              provider.translate('no_system_users_found'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              provider.translate('adjust_filters_hint'),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modal: Edit System Role
  void _showEditRoleDialog(
    BuildContext context,
    CompanyEmployee user,
    AttendanceProvider provider,
  ) {
    String selectedRole = user.role;

    showGlassDialog(
      context: context,
      title: provider.translate('edit_system_role'),
      subtitle: provider.translate('edit_role_subtitle').replaceAll('{name}', user.name),
      icon: Icons.shield_outlined,
      content: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                provider.translate('select_role_permissions'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(provider.translate('role_hr_mgr_title')),
                subtitle: Text(
                  provider.translate('role_hr_mgr_desc'),
                ),
                leading: Radio<String>(
                  value: 'hr',
                  // ignore: deprecated_member_use
                  groupValue: selectedRole,
                  // ignore: deprecated_member_use
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedRole = val);
                  },
                ),
                onTap: () => setModalState(() => selectedRole = 'hr'),
              ),
              ListTile(
                title: Text(provider.translate('role_supervisor_title')),
                subtitle: Text(
                  provider.translate('role_supervisor_desc'),
                ),
                leading: Radio<String>(
                  value: 'supervisor',
                  // ignore: deprecated_member_use
                  groupValue: selectedRole,
                  // ignore: deprecated_member_use
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedRole = val);
                  },
                ),
                onTap: () => setModalState(() => selectedRole = 'supervisor'),
              ),
              ListTile(
                title: Text(provider.translate('role_employee_title')),
                subtitle: Text(
                  provider.translate('role_employee_desc'),
                ),
                leading: Radio<String>(
                  value: 'employee',
                  // ignore: deprecated_member_use
                  groupValue: selectedRole,
                  // ignore: deprecated_member_use
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedRole = val);
                  },
                ),
                onTap: () => setModalState(() => selectedRole = 'employee'),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(provider.translate('cancel')),
        ),
        NeuButton(
          onPressed: () {
            final updatedUser = user.copyWith(role: selectedRole);
            provider.updateEmployee(updatedUser);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  provider.translate('role_updated_success').replaceAll('{name}', user.name).replaceAll('{role}', selectedRole),
                ),
                backgroundColor: Colors.blueAccent,
              ),
            );
          },
          variant: NeuButtonVariant.primary,
          label: provider.translate('save_changes'),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
      ],
    );
  }

  // Modal: Set Password
  void _showSetPasswordDialog(
    BuildContext context,
    CompanyEmployee user,
    AttendanceProvider provider,
  ) {
    final passCtrl = TextEditingController(text: user.password ?? '');

    showGlassDialog(
      context: context,
      title: provider.translate('update_password'),
      subtitle: provider.translate('set_pwd_subtitle').replaceAll('{name}', user.name),
      icon: Icons.key_outlined,
      content: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passCtrl,
                decoration: InputDecoration(
                  labelText: provider.translate('new_password'),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                obscureText: true,
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(provider.translate('cancel')),
        ),
        NeuButton(
          onPressed: () {
            if (passCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(provider.translate('enter_password_prompt'))),
              );
              return;
            }
            final updatedUser = user.copyWith(
              password: passCtrl.text.trim(),
              overridePassword: true,
            );
            provider.updateEmployee(updatedUser);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(provider.translate('password_updated_success').replaceAll('{name}', user.name)),
                backgroundColor: Colors.green,
              ),
            );
          },
          variant: NeuButtonVariant.primary,
          label: provider.translate('save_password'),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
      ],
    );
  }

  // Modal: Add System Account
  void _showAddSystemUserDialog(
    BuildContext context,
    AttendanceProvider provider,
  ) {
    final userIdCtrl = TextEditingController(text: provider.getNextEmployeeId());
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final posCtrl = TextEditingController(text: 'System Administrator');
    final passCtrl = TextEditingController();
    String role = 'hr';

    showGlassDialog(
      context: context,
      title: provider.translate('add_system_account'),
      subtitle: provider.translate('add_system_account_subtitle'),
      icon: Icons.person_add_alt_1_rounded,
      content: StatefulBuilder(
        builder: (context, setModalState) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: userIdCtrl,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: provider.translate('user_id_label'),
                          prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                          helperText: provider.translate('auto_sequence_id'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 7,
                      child: TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: provider.translate('full_name_label'),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: InputDecoration(
                    labelText: provider.translate('system_login_email'),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: posCtrl,
                  decoration: InputDecoration(
                    labelText: provider.translate('position_title'),
                    prefixIcon: const Icon(Icons.work_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  decoration: InputDecoration(
                    labelText: provider.translate('login_password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: InputDecoration(
                    labelText: provider.translate('system_access_role'),
                    prefixIcon: const Icon(Icons.shield_outlined),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'hr',
                      child: Text(provider.translate('role_hr_admin_mgr')),
                    ),
                    DropdownMenuItem(
                      value: 'supervisor',
                      child: Text(provider.translate('role_supervisor_title')),
                    ),
                    DropdownMenuItem(
                      value: 'employee',
                      child: Text(provider.translate('role_employee_user')),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => role = val);
                  },
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(provider.translate('cancel')),
        ),
        NeuButton(
          onPressed: () async {
            final targetCompany = (provider.currentCompanyCode == 'all' ? '' : provider.currentCompanyCode);
            final enteredId = userIdCtrl.text.trim().isNotEmpty
                ? userIdCtrl.text.trim()
                : provider.getNextEmployeeId(companyCode: targetCompany.isNotEmpty ? targetCompany : null);

            if (enteredId.isEmpty || nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(provider.translate('enter_required_user_fields')),
                ),
              );
              return;
            }

            final conflict = provider.getEmployeeConflict(
              enteredId,
              companyCode: targetCompany.isNotEmpty ? targetCompany : null,
            );
            if (conflict != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    provider.translate('user_id_in_use').replaceAll('{id}', enteredId).replaceAll('{name}', conflict.name),
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              );
              return;
            }

            final newEmp = CompanyEmployee(
              id: enteredId,
              companyCode: targetCompany,
              name: nameCtrl.text.trim(),
              email: emailCtrl.text.trim(),
              position: posCtrl.text.trim(),
              role: role,
              password: passCtrl.text.trim().isNotEmpty
                  ? passCtrl.text.trim()
                  : null,
              startDate: DateTime.now().toIso8601String().split('T')[0],
              positionStartDate: DateTime.now().toIso8601String().split('T')[0],
              groupStartDate: DateTime.now().toIso8601String().split('T')[0],
              positionHistory: [],
              groupHistory: [],
              salaryHistory: [],
            );

            final success = await provider.addEmployee(newEmp);
            if (!success) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      provider.translate('user_id_in_use').replaceAll('{id}', enteredId).replaceAll('{name}', ''),
                    ),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
              return;
            }

            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    provider.translate('user_created_success').replaceAll('{name}', newEmp.name),
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          variant: NeuButtonVariant.primary,
          label: provider.translate('create_account'),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
      ],
    );
  }

  void _showFaceIdManageDialog(
    BuildContext context,
    CompanyEmployee user,
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
      title: provider.translate('face_id_title').replaceAll('{name}', user.name),
      subtitle: provider.translate('face_id_subtitle'),
      icon: Icons.face_retouching_natural,
      content: StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentUser = provider.employees.firstWhere(
            (e) => e.id == user.id,
            orElse: () => user,
          );
          final hasFace = currentUser.faceEmbedding != null && currentUser.faceEmbedding!.isNotEmpty;

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
                            currentUser.name,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            provider.translate('role_id_label')
                                .replaceAll('{role}', currentUser.role.toUpperCase())
                                .replaceAll('{id}', currentUser.id),
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
                              hasFace ? provider.translate('face_id_enrolled') : provider.translate('no_face_id'),
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
                provider.translate('biometric_face_desc'),
                style: TextStyle(color: subtextColor, fontSize: 12),
              ),
              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => FaceAuthScreen(
                        title: provider.translate('scan_face_title').replaceAll('{name}', currentUser.name),
                        checkForDuplicate: true,
                        excludeEmployeeId: currentUser.id,
                      ),
                    ),
                  );

                  if (result != null && result is List<double> && context.mounted) {
                    final duplicate = provider.findDuplicateFaceEmployee(result, excludeEmployeeId: currentUser.id);
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
                    await provider.updateEmployeeFaceEmbedding(currentUser.id, result);
                    setDialogState(() {});
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(child: Text(provider.translate('face_id_registered_success').replaceAll('{name}', currentUser.name))),
                          ],
                        ),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: Text(hasFace ? provider.translate('rescan_camera') : provider.translate('enroll_camera')),
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
                    await provider.updateEmployeeFaceEmbedding(currentUser.id, null);
                    setDialogState(() {});
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(provider.translate('face_id_removed_msg').replaceAll('{name}', currentUser.name)),
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
