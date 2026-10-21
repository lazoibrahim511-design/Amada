import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/hr_models.dart';
import '../glass_container.dart';
import '../glass_dialog.dart';
import '../neu_button.dart';

class HrGroupsTab extends StatefulWidget {
  final String searchQuery;
  final Function(EmployeeGroup group)? onEdit;
  final Function(String id)? onDelete;

  const HrGroupsTab({
    super.key,
    required this.searchQuery,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<HrGroupsTab> createState() => _HrGroupsTabState();
}

class _HrGroupsTabState extends State<HrGroupsTab> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final groups = provider.groups;

    if (groups.isEmpty) {
      return _buildEmptyState(context);
    }

    final filtered = widget.searchQuery.isEmpty
        ? groups
        : groups
            .where((g) => g.name.toLowerCase().contains(widget.searchQuery.toLowerCase()))
            .toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1400
            ? 4
            : constraints.maxWidth > 950
                ? 3
                : constraints.maxWidth > 650
                    ? 2
                    : 1;

        if (crossAxisCount == 1) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              return _buildGroupCard(context, filtered[index], provider);
            },
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: crossAxisCount == 2 ? 1.75 : 1.9,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return _buildGroupCard(context, filtered[index], provider);
          },
        );
      },
    );
  }

  Widget _buildGroupCard(BuildContext context, EmployeeGroup group, AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    WorkShift? assignedShift;
    if (group.shiftId.isNotEmpty) {
      try {
        assignedShift = provider.shifts.firstWhere((s) => s.id == group.shiftId);
      } catch (_) {}
    }

    final memberCount = provider.employees.where((e) => e.groupId == group.id).length;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Group Icon + Name & Subtitle + Edit/Delete Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.group_outlined,
                  color: Color(0xFFF59E0B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      assignedShift != null ? 'Shift: ${assignedShift.name}' : 'No Shift Assigned',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: subtextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Edit Group',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        if (widget.onEdit != null) {
                          widget.onEdit!(group);
                        } else {
                          showGroupDialog(context, group: group);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Delete Group',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        if (widget.onDelete != null) {
                          widget.onDelete!(group.id);
                        } else {
                          _showDeleteConfirm(context, group.id, provider);
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Divider
          Divider(
            height: 16,
            thickness: 1,
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ),

          // Details Grid (2 rows)
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.schedule_rounded,
                      iconColor: const Color(0xFF10B981),
                      label: assignedShift != null ? assignedShift.name : 'No Shift',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.people_alt_outlined,
                      iconColor: const Color(0xFF2E65FF),
                      label: '$memberCount Members',
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.beach_access_outlined,
                      iconColor: const Color(0xFFF59E0B),
                      label: 'Leave: ${group.annualLeaveAdditionType}',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.more_time_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      label:
                          'Overtime: ${group.overtimeAllowed ? (group.nightOvertimeAllowed ? 'Allowed (+Night)' : 'Allowed') : 'Off'}',
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_outlined,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Employee Groups Found',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, String id, AttendanceProvider provider) {
    showGlassDialog(
      context: context,
      title: '${provider.translate('delete')} ${provider.translate('groups')}',
      subtitle: provider.translate('delete_confirm_title'),
      icon: Icons.delete_outline,
      content: Text(provider.translate('delete_confirm_desc')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(provider.translate('cancel')),
        ),
        NeuButton(
          label: provider.translate('delete'),
          variant: NeuButtonVariant.danger,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          onPressed: () {
            provider.deleteGroup(id);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

void showGroupDialog(BuildContext context, {EmployeeGroup? group}) {
  final nameController = TextEditingController(text: group?.name ?? '');
  final provider = Provider.of<AttendanceProvider>(context, listen: false);

  showGlassDialog(
    context: context,
    title: group == null ? provider.translate('add_new_group') : provider.translate('edit_group'),
    subtitle: provider.translate('fill_details_below'),
    icon: Icons.group_outlined,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: provider.translate('group_name'),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(provider.translate('cancel')),
      ),
      NeuButton(
        label: provider.translate('save_changes'),
        variant: NeuButtonVariant.primary,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        onPressed: () {
          if (nameController.text.trim().isEmpty) return;
          final newGroup = group != null
              ? group.copyWith(name: nameController.text.trim())
              : EmployeeGroup(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  shiftId: '',
                );
          if (group == null) {
            provider.addGroup(newGroup);
          } else {
            provider.updateGroup(newGroup);
          }
          Navigator.pop(context);
        },
      ),
    ],
  );
}
