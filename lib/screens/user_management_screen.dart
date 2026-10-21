import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../widgets/hr/hr_employees_tab.dart';
import '../widgets/hr/system_users_tab.dart';
import '../widgets/neu_button.dart';

class UserManagementScreen extends StatefulWidget {
  final bool isEmbedded;
  final int initialSubTab; // 0: System Users, 1: Employees

  const UserManagementScreen({
    super.key,
    this.isEmbedded = false,
    this.initialSubTab = 0,
  });

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  late int _activeSubTab;

  @override
  void initState() {
    super.initState();
    _activeSubTab = widget.initialSubTab;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: provider.currentLanguageDirection,
      child: Scaffold(
        body: Container(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          child: SafeArea(
            child: Column(
              children: [
                // Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      if (!widget.isEmbedded && Navigator.canPop(context)) ...[
                        NeuIconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, size: 20),
                          size: 42,
                          variant: NeuButtonVariant.whitePill,
                        ),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.translate('user_and_access_mgmt'),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              provider.translate('user_and_access_desc'),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Custom Segmented Sub-Tab Switcher
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
                        _buildTabButton(
                          index: 0,
                          label: provider.translate('system_users_tab'),
                          icon: Icons.admin_panel_settings_outlined,
                          isDark: isDark,
                        ),
                        _buildTabButton(
                          index: 1,
                          label: provider.translate('workforce_directory_tab'),
                          icon: Icons.people_alt_outlined,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),

                // Search Bar Field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : const Color(0xFFCBD5E1),
                        width: 1.0,
                      ),
                    ),
                    child: Center(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {});
                        },
                        style: TextStyle(
                          fontSize: 13.5,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: _activeSubTab == 0
                              ? provider.translate('search_system_users_hint')
                              : provider.translate('search_workforce_hint'),
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: isDark ? Colors.white54 : Colors.black45,
                            size: 19,
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  splashRadius: 16,
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Tab View Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: IndexedStack(
                      index: _activeSubTab,
                      children: [
                        // Tab 0: System Users & Web Accounts
                        SystemUsersTab(
                          searchQuery: _searchController.text,
                        ),
                        // Tab 1: Employees & Workforce Directory
                        HrEmployeesTab(
                          searchQuery: _searchController.text,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _activeSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeSubTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
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
                    )
                  ]
                : [],
          ),
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
            ],
          ),
        ),
      ),
    );
  }
}
